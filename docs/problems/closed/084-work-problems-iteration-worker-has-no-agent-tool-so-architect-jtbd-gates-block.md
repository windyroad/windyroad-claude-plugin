# Problem 084: work-problems iteration-worker has no Agent tool so architect + JTBD edit gates AND risk-scorer commit gate block all progress

**Status**: Closed
**Reported**: 2026-04-21 (AFK iter 6, during P071 slice 5 attempt)
**Priority**: 16 (High) — Impact: High (4) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: 8.0 — (16 × 1.0) / 2 — High-severity discoverability/progress block on every edit-gated iteration; moderate effort to fix (wire Agent tool into the worker subagent's allowed tool surface, or provide a Skill-tool-compatible path to set the architect/jtbd markers).

## Description

The `/wr-itil:work-problems` AFK orchestrator's Step 5 (shipped in P077 — commit `a0ec231`) correctly delegates each iteration to a spawned subagent via the Agent tool with `subagent_type: general-purpose` for isolation (per ADR-032 AFK iteration-isolation wrapper sub-pattern). The orchestrator side is correct.

However, the iteration-worker subagent inherits a tool surface that does NOT include the Agent/Task tool. This blocks the worker from satisfying the architect + JTBD PreToolUse edit gates (packages/architect/hooks/architect-enforce-edit.sh and packages/jtbd/hooks/jtbd-enforce-edit.sh), because:

1. The `/tmp/architect-reviewed-<SESSION_ID>` and `/tmp/jtbd-reviewed-<SESSION_ID>` markers that unlock the PreToolUse gate are set **only** by the Agent-tool PostToolUse hook (architect-mark-reviewed.sh + the analogous jtbd hook), which reads `subagent_type` and matches `*architect*` / `*jtbd*`.
2. The Skill tool does NOT trigger those PostToolUse hooks — invoking `/wr-architect:review-design` or `/wr-jtbd:review-jobs` via the Skill tool runs the skill's own Steps 1–6 but the Steps 5 ("Delegate to wr-architect:agent") actually require the Agent tool to produce the marker.
3. Without the Agent tool in the worker's allowed tool surface, steps 5 of both review skills are un-executable. The worker can reason about the design inline but cannot set the marker.
4. Every Write/Edit on gate-covered paths (anything outside the excluded list — docs/problems/, docs/BRIEFING.md, .changeset/, memory/, etc.) is BLOCKED.
5. The same Agent-tool-dependency also blocks `git commit` via `packages/risk-scorer/hooks/risk-score-commit-gate.sh`, which requires a bypass marker set by the `wr-risk-scorer:pipeline` subagent's PostToolUse hook. Invoking `/wr-risk-scorer:assess-release` via the Skill tool runs the prose steps but can't spawn the subagent — so the marker isn't written, and `git commit` is blocked even for docs-only commits that were supposed to be exempt. Effective result: the iteration worker cannot commit AT ALL, even changes to `docs/problems/` which are edit-gate-excluded.

Observed 2026-04-21 during P071 slice 5 (list-incidents split) attempt: the iteration worker wrote the architect and JTBD review verdicts inline (PASS on both), but could not persist markers, and every Write attempt to `packages/itil/skills/list-incidents/test/list-incidents-contract.bats` was blocked by both hooks in sequence. Falling back to docs-only work: the worker WAS able to Write the P084 ticket and Edit the P071 ticket (both excluded from edit gates), but `git commit` was then blocked by the risk-scorer commit gate for the same reason — no Agent tool, no bypass marker. **The block is total: the worker cannot land ANY persistent work, even the diagnosis ticket.**

This is the iteration-worker counterpart of P077 (which addressed the orchestrator→worker dispatch). P077 is shipped and correct; this ticket addresses the NEXT gap down: the worker→subagent dispatch surface is incomplete.

## Symptoms

- AFK iteration worker attempting to work any gate-covered ticket (i.e. most tickets — list-incidents in packages/itil/skills/, ADRs, SKILL.md files, hooks, agent definitions, bats tests outside docs/problems/) gets blocked at every Write/Edit.
- The worker correctly invokes `/wr-architect:review-design` and `/wr-jtbd:review-jobs` via the Skill tool per manage-problem Step 1's architect-review instruction, but those skills delegate to subagents via the Agent tool — which is absent.
- No error message surfaces to the orchestrator unless the worker returns with explicit diagnosis; silent halt risk is material.
- The worker CAN edit docs/problems/*.md (excluded from both gates per P004 / P009) — so diagnosis can be written to a ticket. Everything else is blocked.

## Workaround

- The worker can edit docs/problems/*.md unblocked (both gates exclude that path) — so it can document the block and return `outcome: skipped` with `skip_reason_category: upstream-blocked`.
- The user can run the iteration synchronously in the main session (where Agent tool IS available) instead of spawning a subagent.
- The worker cannot progress any gate-covered ticket without either (a) the Agent tool appearing in its surface, or (b) a Skill-tool-compatible path that sets the marker.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — AFK mode promises iteration-by-iteration progress. When the worker hits gate-covered paths, progress halts silently.
  - **Every P071 slice 5+ attempt** — list-incidents, mitigate-incident, restore-incident, close-incident, link-incident are all gate-covered (packages/itil/skills/ paths). The entire remaining P071 phased plan is blocked until this is fixed.
  - Any AFK iteration working ADRs, SKILL.md edits, hook edits, or anything outside the gate-exclusion list.
- **Frequency**: every AFK iteration that touches gate-covered paths, which is most iterations. Only the `docs/problems/` editing axis (ticket updates, README refresh) works unblocked.
- **Severity**: High. AFK mode's value proposition depends on sustained unattended progress. This gap turns most iterations into silent halts or skipped-with-diagnosis cycles.

## Root Cause Analysis

### Structural

The three-layer gate architecture (PreToolUse deny by default → Agent-tool PostToolUse marker → sliding-TTL allow) was designed for the main session where the Agent tool is always available. P077 added the AFK iteration-isolation wrapper but did not audit the spawned worker's tool surface against the gate-satisfaction requirements.

The worker's surface (as observed this session): Bash, Edit, Glob, Grep, Read, Write, ToolSearch, ScheduleWakeup, Skill — plus deferred tools findable via ToolSearch. Agent/Task does not appear in the deferred list either (confirmed via `select:Agent` and `select:Task` searches returning "No matching deferred tools found").

### Evidence update (2026-04-21, post-initial-diagnosis)

Three independent evidence sources confirm this is a hard platform restriction, not a configurable tool-surface gap:

1. **ToolSearch probe (general-purpose subagent).** `select:Agent,Task` returns "No matching deferred tools found". Keyword search `"agent subagent task"` surfaces `TaskStop` (background-Bash control) but no `Agent` or `Task` dispatch tool. Agent is absent from both top-level and deferred surfaces.
2. **Claude Code docs.** `https://code.claude.com/docs/en/subagents.md` states verbatim: *"Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions."* And separately: *"If your workflow requires nested delegation, use Skills or chain subagents from the main conversation."* The `Task` tool was renamed to `Agent` in 2.1.63; both names are aliases for the same restricted capability.
3. **Empirical call attempt (general-purpose subagent, no ToolSearch prefetch).** Direct invocation of `Agent` returns the literal runtime error: *"No such tool available: Agent. Agent is not available inside subagents. Complete the task with the tools provided and return findings to the orchestrator."*

### Candidate fixes (evidence-updated 2026-04-21)

1. ~~**Add Agent tool to the worker's allowed surface.**~~ **CONFIRMED IMPOSSIBLE.** Subagents cannot spawn subagents at the platform level — no custom `subagent_type` or tool-surface declaration can lift this restriction. Listed here only to document the ruled-out path and prevent re-proposal.
2. **Extend the PostToolUse marker hook to also fire on Skill-tool invocations of `/wr-architect:review-design` / `/wr-jtbd:review-jobs`.** The skills already do the right work (reading diff, constructing prompt, delegating); the hook could parse the Skill tool's output for the same "Architecture Review: PASS" / "ISSUES FOUND" verdict the current hook looks for. Risk: skill-level review may be shallower than subagent review; verdicts in free-text output may be harder to parse reliably. **Still blocked by the same restriction internally** — today's review skills delegate to `wr-architect:agent` / `wr-jtbd:agent` via the Agent tool, which the worker cannot call. Fix (2) would only work if the review skills ALSO had an in-worker inline path that produced the verdict without the Agent hop — which collapses Fix (2) into Fix (3).
3. **Add a thin `/wr-governance:mark-reviewed <gate> <verdict> <justification>` skill** that writes the marker directly given a verdict the worker produced inline (worker reads diff, produces PASS/FAIL verdict in its own turn, calls the skill to persist the marker). Risk: bypass path that could be abused; needs audit-trail discipline (the skill records gate, verdict, justification, and worker-identity into an append-only log). **LEAD CANDIDATE post-evidence-update.**
4. **Chain-from-orchestrator pattern (NEW candidate, per Claude Code docs' "chain subagents from the main conversation" guidance).** The orchestrator (main session) runs architect + JTBD review for each iteration BEFORE spawning the iteration worker, sets the markers via its own Agent tool, then dispatches the worker with the markers already live. Pros: preserves the existing Agent-tool-backed review depth; no hook or skill additions needed. Cons: orchestrator has no preview of the diff the worker will produce, so the review is either scope-level (ticket's intended change) rather than diff-level (actual lines changed), or the orchestrator must loop (dispatch → worker stages diff → worker returns for orchestrator review → orchestrator re-spawns worker to commit). The loop variant doubles the per-iteration turn count. **Context-cost regression**: Fix (4) runs architect + JTBD subagents in the orchestrator's main turn, so each iteration adds ~4K tokens of review output to main context — re-introducing the exact context-burn problem P077 solved.

5. **`claude -p` subprocess per iteration (NEW candidate, 2026-04-21 evidence-update iter 2).** The orchestrator shells out via Bash to a fresh `claude -p` (headless print-mode) invocation per iteration instead of spawning a subagent via the Agent tool. The subprocess is a full main Claude Code session — it HAS the Agent tool in its surface, so architect/JTBD/risk-scorer reviews run via the normal subagent path and the gate markers are set natively. Orchestrator reads stdout (the `ITERATION_SUMMARY` block); context isolation is preserved by the process boundary.

   **Pros:**
   - **Closes P084 natively** rather than working around it. The tool-surface gap disappears entirely.
   - **Preserves review depth** — full architect + JTBD subagent review per normal path (not inline verdict reasoning). Aligns with ADR-015's on-demand-assessment model.
   - **ADR-014 PASS** — subprocess commits from its own session; commit gate operates inside the subprocess's session with Agent available.
   - **No new skill required** (no `/wr-governance:mark-reviewed`).

   **Cons / architect-flagged issues (wr-architect:agent review 2026-04-21):**
   - **ADR-032 amendment mandatory.** ADR-032 line 91 explicitly names "Agent-tool dispatch" as the AFK iteration-isolation wrapper mechanism. A subprocess variant is either a sibling sub-pattern or a new ADR — it cannot ship without being pinned down in the decision record.
   - **ADR-013 Rule 6 audit scope is large.** `claude -p` is a non-interactive context; every AskUserQuestion branch reachable from inside the subprocess (including transitive branches in manage-problem, architect review, JTBD review, risk-scorer, voice-tone) must be pre-audited as either (a) policy-authorisable or (b) deferrable via the pending-questions artefact contract. Otherwise iterations silently halt on a Rule 6 fail-safe inside the subprocess and the orchestrator only sees a partial summary. Fix (3) has the same requirement with a much smaller surface (only the inline verdict-producing skill needs auditing).
   - **Token cost envelope needs quantifying.** Architect's honest worst-case: ~10–20K tokens of system-prompt + SKILL.md re-expansion per iteration on the subprocess side (no prompt-cache carry across subprocesses). Main-context cost remains ~0 (just the stdout parse), but a 30-iteration loop compounds to 300–600K subprocess-side tokens. Trade: cheaper main context vs more total tokens. Must be measured before committing.
   - **Hook session-id isolation must be documented.** `architect-mark-reviewed.sh` uses `$CLAUDE_SESSION_ID`; the subprocess has a distinct SESSION_ID from the orchestrator, so markers set inside the subprocess are isolated to that subprocess. That's the correct behaviour but must be explicitly documented in the amendment to prevent future contributors from wiring marker-sharing.
   - **Post-subprocess state re-read by the orchestrator.** ADR-018 Step 6.5 drain trigger must rely on `ITERATION_SUMMARY.commit_sha` rather than session-state continuity, because the subprocess's commit is invisible to the main orchestrator until main re-reads the working tree. Current contract does use the summary field, so PASS — but must be stated in the amendment.
   - **Reversibility cost** — changing the orchestrator's dispatch mechanism is an amendment-level change; rolling back is harder than removing a skill.

### Empirical verification of Fix (5) (probes ran 2026-04-21 afternoon)

Four probes, total cost $0.94, all passed:

**Probe 1** — basic invocation: `claude -p "Output PROBE_1_OK" --output-format json --max-budget-usd 1.00` → succeeded. Duration 2.8s; cost $0.25; cache-creation 40K tokens (baseline: system prompt + CLAUDE.md + plugins + memory loading).

**Probe 2** — Agent tool in subprocess surface: `claude -p` invoked with instruction to call Agent(general-purpose) for a trivial echo → returned `AGENT_AVAILABLE: INNER_PROBE_OK`. Subprocess successfully spawned sub-subagent via Agent tool. Cost $0.23; note: cache-read 65K tokens — **prompt cache DOES reuse across `claude -p` invocations in the same Bash session**, meaningfully reducing per-iteration cost below the architect's 10–20K re-expansion worst-case after the first invocation.

**Probe 3** — PostToolUse hook integration: `claude -p` invoked to call `wr-architect:agent` via Agent tool, then check for the marker file → returned `AGENT_INVOCATION: success`, `AGENT_VERDICT_LINE: Architecture Review: PASS`, `MARKER_FOUND_ARCHITECT: yes` at `/tmp/architect-reviewed-326a474f-12ed-45f6-bb85-f4f91fb66630` matching the subprocess's own `session_id`. Both architect and JTBD marker files observed. Cost $0.32.

**Probe 4** — permission mode: `claude -p --permission-mode bypassPermissions` allowed Bash without prompts. Cost $0.14.

### Revised recommendation (evidence-update iter 2, 2026-04-21 afternoon)

**Fix (5) `claude -p` subprocess is the LEAD** after empirical verification. All four architect concerns that looked blocking at review time resolve to non-blockers under probe evidence:

| Architect concern | Empirical status | Blocker? |
|---|---|---|
| ADR-032 amendment needed | True — amendment required; ADRs are updatable | No |
| ADR-013 Rule 6 audit scope | Pre-existing AFK requirement; every skill on the AFK path must already satisfy Rule 6 regardless of dispatch mechanism | No |
| Token cost envelope | Cache reuse observed at 65K read / 15K creation on probe 2; cappable via `--max-budget-usd`; user direction — wasted tokens aren't wasted if used | No |
| Hook session-id isolation | Confirmed: subprocess markers use subprocess SESSION_ID (as desired) | Documentation only |
| Post-subprocess state re-read | Already works via `ITERATION_SUMMARY.commit_sha` | No |
| Reversibility | Dispatch-line swap; trivial rollback | No |
| Rate-limit / subscription quota | Not verified; user direction — not treating as a blocker | No |

**Dispatch-flag set for Step 5**: `claude -p --permission-mode bypassPermissions --output-format json --max-budget-usd <cap>` with the iteration prompt on stdin or as a positional argument.

**Ranking:**
- **Fix (5) `claude -p` subprocess** — LEAD. Closes P084 natively; preserves full architect/JTBD review depth via normal Agent-tool path in the subprocess.
- **Fix (3) `/wr-governance:mark-reviewed`** — demoted to secondary / audit-trail primitive. Still useful in mixed-context governance calls where a subprocess is overkill, but no longer on the critical path for AFK iterations.
- Fix (4) loop-variant as third-tier fallback only.
- Fix (1) impossible; Fix (2) collapses into Fix (3).

**ADR amendment scope**: ADR-032 gains a subprocess-boundary sub-pattern entry under the AFK iteration-isolation wrapper. Contract pins down (a) subprocess spawn flags, (b) `ITERATION_SUMMARY` stdout parse shape, (c) hook session-id isolation behaviour, (d) post-subprocess state re-read requirement. Rule 6 audit remains a follow-up investigation task but does not gate the shipment — the audit applies to AFK mode regardless of dispatch mechanism.

## Related

- **P071** (argument-based skill subcommands not discoverable) — this ticket blocks P071 slices 5+. The P071 phased plan cannot progress via AFK iterations until this is fixed or worked around.
- **P077** (work-problems Step 5 does not delegate to subagent) — shipped; fixes the orchestrator→worker dispatch. This ticket addresses the NEXT gap (worker→sub-subagent).
- **ADR-032** (governance skill invocation patterns) — AFK iteration-isolation wrapper sub-pattern added by P077. This ticket identifies that the sub-pattern's worker-side contract is incomplete.
- **ADR-010 amended** (Skill Granularity) — the decision the P071 slices implement.
- **ADR-013** (structured user interaction for governance decisions) — Rule 1 names user control; Rule 6 AFK fallback path. This ticket reveals a new AFK fallback gap: architect/jtbd verdict cannot currently be expressed by the worker.
- `packages/architect/hooks/architect-enforce-edit.sh` + `packages/architect/hooks/architect-mark-reviewed.sh` — the gate code to amend.
- `packages/jtbd/hooks/jtbd-enforce-edit.sh` + `packages/jtbd/hooks/lib/review-gate.sh` — sibling gate code.
- `packages/architect/skills/review-design/SKILL.md` + `packages/jtbd/skills/review-jobs/SKILL.md` — the on-demand review skills that currently cannot set the marker.
- **JTBD-006** (Work the backlog AFK) — the persona outcome this ticket directly degrades.
- **Claude Code docs — subagents reference**: `https://code.claude.com/docs/en/subagents.md` lines 318 + 694 document the hard platform restriction ("Subagents cannot spawn other subagents"). Canonical tool name is `Agent`; `Task` is a legacy alias. Evidence source for the Candidate fixes evidence-update above.

### Investigation Tasks

- [x] Confirm the worker's tool-surface limitation by reproducing with a fresh general-purpose subagent probe. **Confirmed 2026-04-21 via three-source evidence (ToolSearch absence + Claude Code docs + empirical Agent-tool invocation returning `No such tool available: Agent. Agent is not available inside subagents.`).** See Evidence update section above.
- [x] Rule out Fix (1) (Agent in worker surface). **Confirmed impossible** — platform-level restriction, no custom subagent_type can lift it.
- [ ] Architect review on Fix (3)'s shape: (a) gate coverage scope, (b) audit-trail shape, (c) composition with existing review skills. May require a new ADR or an ADR-032 amendment.
- [ ] Design the `/wr-governance:mark-reviewed` skill — SKILL.md contract + marker-write mechanism + audit-log record shape.
- [ ] Implement Fix (3) + behavioural bats contract assertions (per `feedback_behavioural_tests.md`: spawn a probe subagent, have it invoke the skill with a PASS verdict, assert the marker file exists at the expected path and a subsequent Write on a gate-covered path succeeds).
- [ ] Amend ADR-032's AFK iteration-isolation wrapper sub-pattern with the worker-tool-surface contract (explicit: "subagents cannot spawn subagents; verdict-producing path is Skill-tool-based only").
- [ ] If Fix (3) proves unworkable in architect review, pivot to Fix (4) (chain-from-orchestrator) with the loop-variant's per-iteration turn cost accepted.
- [ ] **Fix (5) track (concurrent with Fix (3) implementation):** draft ADR-032 amendment (or new ADR) for the `claude -p` subprocess sub-pattern. Amendment must pin down: (a) subprocess spawn mechanism + stdout contract for `ITERATION_SUMMARY`, (b) exit-code semantics + stderr handling + timeout, (c) hook-parity validation across the process boundary, (d) documented hook session-id isolation behaviour, (e) ADR-018 post-subprocess state re-read requirement.
- [ ] **Fix (5) Rule 6 audit**: inventory every AskUserQuestion branch reachable from inside a `claude -p` iteration subprocess — including transitive branches in manage-problem, `/wr-architect:review-design`, `/wr-jtbd:review-jobs`, `/wr-risk-scorer:assess-release`, and any voice-tone / style-guide review skills invoked during iteration. Classify each as (a) policy-authorisable (ADR-013 Rule 5), (b) deferrable via pending-questions artefact contract (ADR-032), or (c) binding blocker (iteration must halt). If any branch is class (c), Fix (5) is not viable without upstream changes to the affected skill.
- [ ] **Fix (5) cost envelope measurement**: instrument a single `claude -p` invocation against a representative iteration workload (e.g. P071 slice 5 dry-run) and measure actual subprocess-side token cost (system prompt expansion + SKILL.md loading + review-skill delegation). Compare to the architect's estimated 10–20K tokens/iteration to validate the envelope.
- [ ] Once Fix (3) is in production AND the Rule 6 audit clears AND the cost envelope is within acceptable bounds: promote Fix (5) as the primary AFK iteration dispatch mechanism. Keep `/wr-governance:mark-reviewed` as an audit-trail primitive for mixed-context uses.

## Fix Released

Fix (5) `claude -p` subprocess dispatch shipped in two commits, both merged to `main` via the changesets release train:

- **`@windyroad/itil@0.13.0`** — commit `260768f` — `/wr-itil:work-problems` Step 5 dispatch swap from Agent-tool subagent to `claude -p --permission-mode bypassPermissions --output-format json` subprocess. The subprocess is a full main Claude Code session with the Agent tool in its surface, so architect / JTBD / risk-scorer reviews run via the normal subagent path and PreToolUse edit-gate + risk-scorer commit-gate markers set natively inside the subprocess's own SESSION_ID. Orchestrator extracts `ITERATION_SUMMARY` from the subprocess's JSON `.result` field. ADR-032 amended with the AFK iteration-isolation wrapper — subprocess-boundary variant.
- **`@windyroad/itil@0.14.0`** — commit `7670ffb` — follow-up that wires per-iteration cost metadata (`.total_cost_usd`, `.duration_ms`, `.usage.{input,output,cache_creation,cache_read}_tokens`) from the subprocess JSON into the orchestrator's progress lines and the ALL_DONE Session Cost section. Observability overlay only; dispatch contract unchanged.

**In-session evidence**: this very AFK iteration (the one producing this transition commit) is running inside the `claude -p` subprocess dispatched by the orchestrator. The architect + JTBD + risk-scorer gate reviews earlier in this iteration ran via the Agent tool in the subprocess's own surface, confirming the fix is live end-to-end on the shipped code path.

**User-verifiable checks**:
- Run `/wr-itil:work-problems` in AFK mode against a backlog ticket that requires editing a gate-covered path (e.g. anything under `packages/` outside the exclusion list). The iteration should progress — write + commit — without silent halt on the edit gate.
- Check `@windyroad/itil` is at ≥ 0.14.0 (`npm view @windyroad/itil version`).
- Session Cost summary should render on ALL_DONE with measured token + cost actuals per iteration.

**Awaiting user verification**. Transition to `.closed.md` after user confirms an AFK run delivered gate-covered progress without the silent halt P084 described.
