# Problem 089: work-problems Step 5 dispatch has two robustness gaps — stdin warning pollutes JSON output, and cost metadata undercounts when subprocess exits via background-task-notification ack

**Status**: Closed
**Reported**: 2026-04-21 (post-AFK-iter-7 retrospective Step 2b)
**Priority**: 6 (Medium) — Impact: Minor (2) x Likelihood: Almost Certain (3)
**Effort**: S — two bounded edits to `packages/itil/skills/work-problems/SKILL.md` Step 5 dispatch block + one new bats assertion per fix. Marginal cost; both improvements on the same target (coordinating-ticket rule per `/wr-retrospective:run-retro` SKILL.md).
**WSJF**: 3.0 — (6 × 1.0) / 2 — Medium severity (first-run adopters hit the stdin warning immediately; cost-logging gives wrong numbers in common subprocess-resume case); small effort. Coordinating ticket for two same-target improvements per P075's coordinating-ticket rule.

## Description

Two adjacent robustness gaps in `packages/itil/skills/work-problems/SKILL.md` Step 5 (the `claude -p` subprocess dispatch shipped in `@windyroad/itil@0.13.0` and cost-metadata extraction shipped in `0.14.0`), observed during the AFK-iter-7 real-world exercise 2026-04-21.

### Gap 1: stdin warning contaminates JSON output

The shipped dispatch command in `work-problems` SKILL.md Step 5:

```bash
claude -p \
  --permission-mode bypassPermissions \
  --output-format json \
  "$ITERATION_PROMPT"
```

...when invoked from a non-interactive parent context with `2>&1` capturing (which the orchestrator uses to parse the JSON response), receives a warning prepended to stdout:

```
Warning: no stdin data received in 3s, proceeding without it. If piping from a slow command, redirect stdin explicitly: < /dev/null to skip, or wait longer.
{"type":"result","subtype":"success",...}
```

Because the warning is emitted to stderr but `2>&1` merges stderr into stdout, strict JSON parsers (`jq`, Python `json.load`, Node's `JSON.parse`) fail at "line 1, column 1: Expecting value" or equivalent. Iter 1 of AFK-iter-7 hit this — the warning prefix broke `jq -r '.result'` extraction, and cost metadata was invisible until a regex-based JSON extraction was written ad-hoc.

**Workaround observed 2026-04-21**: adding `< /dev/null` to the dispatch command suppresses the warning. The `claude -p` CLI help literally suggests this. Iter 2-7 used the workaround.

**Fix**: SKILL.md Step 5 dispatch command gains `< /dev/null`:

```bash
claude -p \
  --permission-mode bypassPermissions \
  --output-format json \
  "$ITERATION_PROMPT" \
  < /dev/null
```

### Gap 2: cost-metadata `usage.*` undercounts when subprocess exits via background-task-notification ack

Observed iter 5 of AFK-iter-7: subprocess committed `6f3265a` after running for 1071s wall-clock with 60+ tool uses. But the JSON returned reported:

- `duration_ms: 8546` (8.5s, not 1071s)
- `num_turns: 1` (not 60+)
- `usage.input_tokens: 6`
- `usage.output_tokens: 287`
- `usage.cache_creation_input_tokens: 2506`
- `usage.cache_read_input_tokens: 134684` (134K, not multi-million)
- `total_cost_usd: 6.08` — **cumulative**, matches the real cost

Root cause inferred: the subprocess completed the real work, started a background bats task, received its completion notification, and responded with a final acknowledgement turn. The JSON `usage.*` fields reflect ONLY that final-turn's usage (287 output tokens of acknowledgment) while `total_cost_usd` is cumulative across the subprocess's lifetime.

Contract implication for work-problems Step 5's Per-iteration cost metadata block (shipped in 0.14.0): the `total_tokens` computation from summing `usage.*` undercounts when this edge case fires. The Session Cost "Total tokens" column reports significantly less than actual.

**Fix**: SKILL.md Step 5 Per-iteration cost metadata block should:
- Treat `total_cost_usd` as **authoritative** for dollar cost (cumulative by contract).
- Treat `usage.*` fields as **best-effort approximate** — reliable when `num_turns > 1` corresponds to real turn count; unreliable when subprocess exits after a background-task-notification ack (detectable by `num_turns == 1` combined with `duration_ms << wall_clock` from the Bash wrapper's timer).
- Session-aggregation uses `total_cost_usd` for the Total Cost column and wall-clock timer for Total Duration. Token columns stay (they're the best available signal for cache-reuse ratio) but the Session Cost table should note that tokens are best-effort.

Optional follow-up: the orchestrator Bash wrapper can detect the anomaly (`duration_ms` << wall-clock) and log a caveat in Step 6's progress line.

## Symptoms

- First AFK-iter-7 iteration hit the stdin warning immediately; JSON parsing failed; cost metadata was invisible until workaround.
- Iter 5 Session Cost aggregation undercounted tokens by ~10× (reported 137K instead of estimated 2-3M based on 60 turns at typical per-turn load).
- No user-facing error — the undercount is silent and only visible on close inspection of per-iteration token fields.

## Workaround

Described inline in each Gap above. Both workarounds used during AFK-iter-7 iterations 2-7.

## Impact Assessment

- **Who is affected**:
  - **JTBD-006 (Progress the Backlog While I'm Away)** — first-run adopters of the shipped 0.14.0 dispatch will hit the stdin warning. Worked around in this session's script but not in the shipped SKILL.md — every new adopter re-discovers.
  - **Session Cost observability** — undercount makes cost envelope harder to reason about; cache-read ratio (primary warm-cache signal) still reliable because ratio stays correct within the final turn.
- **Frequency**: stdin warning fires on every `claude -p` invocation from a non-TTY Bash context without `< /dev/null`. Cost-metadata edge case fires whenever the subprocess exits via a background-task-notification ack (P086's retro-on-exit pattern + any skill that spawns background tasks inside the subprocess).
- **Severity**: Minor. Neither gap breaks the iteration or loses work; both are observability/ergonomics concerns.

## Root Cause Analysis

Both gaps are shipped-code-edge-cases that real-world exercise of the AFK-iter-7 surfaced. P084's probes were too short to trigger the stdin warning (first probe ran for 2.8s, well within the 3s warning threshold; later probes also had different stdin handling). The cost-metadata edge case requires a subprocess that spawns background tasks AND exits on their completion notification — P086's retro-on-exit pattern is the first widespread surface that triggers this.

The shipped Step 5 dispatch shape (ADR-032 subprocess-boundary amendment, P084) is correct. The gaps are dispatch-robustness refinements on the same block, hence this coordinating ticket.

## Related

- **P084** (`docs/problems/084-*.verifying.md`) — parent: subprocess-boundary dispatch where these gaps live.
- **P086** (`docs/problems/086-*.verifying.md`) — retro-on-exit pattern that triggers the cost-metadata edge case (background task spawned inside subprocess → completion notification → final-turn ack → usage.* undercounted).
- **ADR-032** (`docs/decisions/032-*.proposed.md`) — subprocess-boundary sub-pattern; both fixes are refinements within this ADR's scope. No ADR amendment needed.
- **ADR-026** (`docs/decisions/026-*.proposed.md`) — Session Cost grounding; Gap 2's fix updates the grounding language on `usage.*` vs `total_cost_usd` authority.
- **JTBD-006** (Progress the Backlog While I'm Away) — first-run adopter experience.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — primary target.
- `packages/itil/skills/work-problems/test/work-problems-cost-logging.bats` — gains 1-2 assertions for `< /dev/null` + `total_cost_usd` authority language.
- `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` — gains 1 assertion for `< /dev/null` in the dispatch command example.

## Fix Strategy (per `/wr-retrospective:run-retro` Step 4b Stage 2, 2026-04-22)

- **Kind**: improve
- **Shape**: skill
- **Target file**: `packages/itil/skills/work-problems/SKILL.md` (Step 5 dispatch block + Per-iteration cost metadata block)
- **Observed flaw**: two robustness gaps in the shipped 0.13.0 / 0.14.0 dispatch — (1) missing `< /dev/null` lets stdin warning contaminate JSON output; (2) `usage.*` undercounts when subprocess exits via background-task-notification ack while `total_cost_usd` stays cumulative.
- **Edit summary**: (1) add `< /dev/null` to the Step 5 dispatch command shape block; (2) update the Per-iteration cost metadata block with an "Authority hierarchy" note (`total_cost_usd` is authoritative for cost; `usage.*` is best-effort and may be final-turn-only when `num_turns == 1` alongside `duration_ms` << wall-clock).
- **Evidence** (from AFK-iter-7 session 2026-04-21):
  1. Iter 1 citation — `$(claude -p ... 2>&1)` output contained `"Warning: no stdin data received in 3s..."` prepended to JSON; `jq` and Python `json.load` failed with "Invalid numeric literal at line 1, column 8".
  2. Iter 5 citation — subprocess ran 1071s wall-clock with 60+ tool uses, committed 6f3265a; JSON returned `duration_ms: 8546, num_turns: 1, usage.*: 137K tokens, total_cost_usd: 6.08` — cost cumulative but tokens final-turn-only.
  3. Iter 2-7 used the `< /dev/null` workaround and parsed successfully; confirms the fix shape.

**Why Option 1 and not Option 2 (create helper script)**: the dispatch shape is 8 lines of Bash plus a jq expression. Extracting to a helper would hide the SKILL.md contract behind an indirection adopters would then have to trace to understand what the loop does. The SKILL.md IS the contract document per ADR-037. Keep it inline; add the two robustness refinements.

**Patch bump** @windyroad/itil to 0.17.1 (not minor — both fixes are within the existing 0.13.0+0.14.0 contract shape).

### Investigation Tasks

- [x] Gap 1 fix: add `< /dev/null` to the SKILL.md Step 5 dispatch example.
- [x] Gap 1 bats: assert SKILL.md's dispatch block contains `< /dev/null`.
- [x] Gap 2 fix: update the Per-iteration cost metadata block in SKILL.md noting `total_cost_usd` is authoritative and `usage.*` is best-effort when `num_turns == 1` with subprocess-resume anomaly.
- [x] Gap 2 bats: assert SKILL.md notes the authority hierarchy (total_cost_usd > usage.*).
- [x] Changeset: @windyroad/itil patch bump (not minor — two small robustness fixes within the already-shipped 0.14.0 dispatch + metadata block).

## Fix Released

- **Released**: pending — this AFK iteration's commit; release cadence owned by the orchestrator's Step 6.5.
- **Target**: `@windyroad/itil` patch bump (changeset `.changeset/wr-itil-p089-step-5-stdin-redirect.md`).
- **Gap 1** (SKILL.md Step 5 dispatch block): added `< /dev/null` as the last line of the canonical `claude -p` dispatch command, plus Flag rationale prose stating the warning is emitted to stderr and becomes a stdout problem only under `2>&1` capture — so adopters who separate streams know they don't need the redirect.
- **Gap 2** (SKILL.md Step 5 Per-iteration cost metadata block + Session Cost output section): added the "Authority hierarchy" paragraph naming `.total_cost_usd` as cumulative-authoritative and `.usage.*` as best-effort (may reflect only the final-turn ack under background-task-notification exit). Detection criterion stated descriptively (final-turn-sized usage alongside `duration_ms` orders of magnitude smaller than wall-clock) per architect option-b — keeps `num_turns` off the extracted field deny-list. Session Cost output section gained an inline Authority note so adopters see the caveat at the point of rendering.
- **Tests**: `packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` — 6 new assertions covering both gaps (dispatch redirect, stderr prose, total_cost_usd authoritative, usage.* best-effort, Session Cost best-effort tokens, P089 Related citation). All 30 tests in the file pass; full `npm test` suite stays green.
- **Governance**: architect + JTBD reviews approved Option C (both gaps in one ticket, no ADR amendment, no report-upstream); ADR-032 subprocess-boundary variant is the parent pattern and already scopes these refinements. No ADR-026 amendment — the Authority paragraph satisfies ADR-026's grounding discipline rather than straining it.

### Verification Steps

1. Open `packages/itil/skills/work-problems/SKILL.md` and confirm the Step 5 dispatch code block ends with `< /dev/null` and the Flag rationale block explains the stderr / `2>&1` merge interaction.
2. Confirm the Per-iteration cost metadata block has an **Authority hierarchy (P089 Gap 2)** paragraph naming `total_cost_usd` as authoritative and `usage.*` as best-effort under the early-ack anomaly.
3. Confirm the Output Format Session Cost section has an **Authority note** paragraph linking back to Step 5's Authority hierarchy.
4. Run `npx bats packages/itil/skills/work-problems/test/work-problems-step-5-delegation.bats` — 30 tests pass.
5. Next AFK-iter run: confirm iter 1's JSON parses cleanly without ad-hoc regex workaround; confirm Session Cost table renders both the authoritative cost total and the best-effort-labelled token totals.
