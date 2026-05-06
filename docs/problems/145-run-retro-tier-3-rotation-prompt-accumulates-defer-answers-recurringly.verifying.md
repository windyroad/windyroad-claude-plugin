# Problem 145: `/wr-retrospective:run-retro` Tier 3 budget rotation prompt accumulates "defer" answers across retros — topic files exceed budget recurringly without action

**Status**: Verification Pending
**Reported**: 2026-04-29
**Fold-Fix Open → Verification Pending As Of**: 2026-05-03 (per ADR-022 amendment endorsing fold-fix when Open ticket documents root cause + fix strategy + workaround inline; precedents P140 / P142 / P143 / P153)
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3) — observed recurring across multiple recent retros; user surfaced explicitly today: *"we need to do better at splitting. We can\'t just keep deferring."*
**Effort**: S — implementation chosen is the lightest hybrid (Option H per architect review): script emits a new `MUST_SPLIT` line at ratio ≥ 2.0× ceiling; SKILL.md Step 3 gains a Branch A heuristic that forecloses the trim-noise / leave-as-is defer escape hatches for those files. No accumulator-state added to topic-file bodies (rejected ticket options 1/2 to avoid fighting git-blame-as-history). No sibling skill split (rejected ticket option 3 as overweight). Effort downgraded from M → S after architect review (P047 — creation-time estimate drift).
**WSJF**: (9 × 1.0) / 1 = **9.0** (re-rated after Effort downgrade)
**Type**: technical

## Fix Released

**Release marker**: 2026-05-03 (AFK iter 6; pending `@windyroad/retrospective` patch via the queued changeset `.changeset/p145-must-split-defer-escape-hatch.md`).

**One-sentence fix summary**: `packages/retrospective/scripts/check-briefing-budgets.sh` now emits `MUST_SPLIT <basename> reason=ratio-exceeds-2x` for topic files at ratio ≥ 2.0× ceiling (in addition to the existing `OVER` line); `packages/retrospective/skills/run-retro/SKILL.md` Step 3 Tier 3 heuristic gains a Branch A that forecloses the `trim-noise` / `leave-as-is` defer escape hatches for `MUST_SPLIT` files — agent picks `split-by-subtopic` if a coherent boundary exists, else `split-by-date` (safe default — mtime-sort + median-age archive, mechanical and AFK-safe).

**Awaiting user verification**.

**Exercise evidence (in-session, AFK iter 6)**:
- TDD red-green-refactor cycle confirmed: 4 of 6 new bats cases failed before the script edit (test 15 at exactly-2× boundary, test 17 at well-over-2×, test 19 at env-override flow, test 20 at mixed-block-sort determinism); all 20 of 20 tests pass after the script edit.
- Live exercise against current `docs/briefing/` state: `bash packages/retrospective/scripts/check-briefing-budgets.sh docs/briefing` now emits 6 `OVER` lines (afk-subprocess at 20,634 / governance-workflow at 17,467 / agent-interaction-patterns at 11,503 / hooks-and-gates at 8,196 / plugin-distribution at 8,975 / releases-and-ci at 9,970) plus 3 `MUST_SPLIT` lines (afk-subprocess at 4.0× / agent-interaction-patterns at 2.2× / governance-workflow at 3.4×). The 3 MUST_SPLIT files are exactly the files this ticket called out as recurring-defer victims.

**Verification path**: on the next `/wr-retrospective:run-retro` invocation against this repo (or any repo with topic files at ≥ 2× ceiling), Step 3 Tier 3 silent-agent rotation must follow Branch A for any file whose script-output line has a corresponding `MUST_SPLIT` line — picking `split-by-date` as the safe default when no sub-topic boundary is obvious. Verifying behaviour: prior retros' "leave-as-is" / "deferred to next retro" outputs for MUST_SPLIT files become `split-by-date` outputs with `<topic>-archive.md` siblings created. Direct observation in subsequent retros is the verification metric — the 6 over-budget files in `docs/briefing/` should shrink toward the Tier 3 envelope across the next 2-3 retro cycles. If `leave-as-is` continues to be picked for MUST_SPLIT files, the heuristic edit failed to land or the agent is mis-applying Branch B to Branch A files.

**Composes-with**: P099 (parent ticket — extends the reusable triplet), P135 / ADR-044 (silent-agent ownership preserved), ADR-040 (the 2× threshold is single-sourced from this ADR's reassessment trigger, no policy duplication).

## Description

`/wr-retrospective:run-retro` Step 3\'s Tier 3 budget rotation pass (P099\'s reusable triplet — advisory script + AskUserQuestion prompt + ADR-040 amendment) detects over-budget topic files via `packages/retrospective/scripts/check-briefing-budgets.sh` and prompts the user/agent to pick a rotation shape: `Split by sub-topic` / `Split by date — archive oldest` / `Trim noise out of band` / `Defer — record only`.

The detection layer works correctly. The **enforcement** layer does not: agents (and the orchestrator main turn) consistently pick `Defer — record only` across consecutive retros, so the over-budget files accumulate unbounded. P099\'s reassessment trigger ("≥3 files exceed 2× ceiling for ≥2 cycles → revisit / promote-to-fail-closed") names exactly this failure shape but the trigger is policy-level (revisit ADR-040), not per-instance enforcement on the rotation prompt itself.

## Symptoms

- 2026-04-29 today\'s retro: **all 6** topic files in `docs/briefing/` are over the 5,120-byte Tier 3 threshold per `check-briefing-budgets.sh` (afk-subprocess.md 20,634; governance-workflow.md 17,467; agent-interaction-patterns.md 11,503; releases-and-ci.md 9,970; plugin-distribution.md 8,975; hooks-and-gates.md 8,196). All 6 recorded as `defer` in the retro summary\'s Topic File Rotation Candidates table.
- `afk-subprocess.md` is at **4.0× ceiling** (20,634 / 5,120) — exceeds the ADR-040 reassessment trigger\'s "2× ceiling" condition four times over.
- 4 of 6 files exceed the trigger\'s "2× ceiling" condition: afk-subprocess (4.0×), governance-workflow (3.4×), agent-interaction-patterns (2.2×), releases-and-ci (1.9× — just under). Trigger condition "≥3 files exceed 2× ceiling for ≥2 cycles" is satisfied THIS retro.
- User correction today (2026-04-29): *"we need to do better at spliting [the Topic File Rotation Candidates table]. We can;\'t just keep defering"* — explicit class-of-behaviour signal per P078.
- Pattern recurrence: prior retros under `docs/retros/` reference Topic File Rotation surfaces; the over-budget state has persisted across these sessions without rotation.

## Workaround

Manual user-driven splits between retros — the user picks a topic file, decides a sub-topic boundary, and runs `Edit` / `Write` / `git mv` to migrate entries. Bypasses the prompt entirely.

## Impact Assessment

- **Who is affected**: every session whose SessionStart surface loads the briefing tree (today: every session via `~/CLAUDE.md` plugin pointers + `docs/briefing/README.md` Critical Points). Bloated topic files cost session-start cache bytes that the progressive-disclosure pattern was specifically designed to avoid.
- **Frequency**: every retro. The advisory fires on every run-retro invocation that lands edits; the defer-default fires on most/all of them.
- **Severity**: Moderate (3) — directly defeats the progressive-disclosure intent of `docs/briefing/`. The Critical Points roll-up (line 3 of `docs/briefing/README.md`) names progressive disclosure as the session-wide unifying pattern; recurring defer is the canonical violation of that pattern at the briefing surface.
- **Likelihood**: Likely (3) — recurring failure mode observable across multiple sessions.
- **Analytics**: 6 files over budget today; 4 at ≥2× ceiling. Pattern observable via `packages/retrospective/scripts/check-briefing-budgets.sh` output across retro cycles.

## Root Cause Analysis

### Investigation Tasks

- [x] Audit recent `docs/retros/*.md` files: how many retros have surfaced `Defer` rotation decisions vs other actions? Count per topic file. **Findings (2026-05-03)**: 3 of the most recent run-retro outputs (`2026-05-02-p151-iter3.md`, `2026-05-02-p153-iter.md`, `2026-05-03-p142-iter.md`) all reported "no files over budget" or "well within Tier 3 envelope" — but the script run today shows 6 files OVER (afk-subprocess.md at 4.0×, governance-workflow.md at 3.4×, agent-interaction-patterns.md at 2.2×, plus 3 between 1×-2×). Two distinct failure modes observed: (a) Tier 3 budget pass entirely skipped (the script never invoked); (b) script invoked but output misreported as "within budget" when bytes-per-file averaged 13,575 — 2.65× the 5,120 ceiling.
- [x] Investigate why the Step 3 prompt's 4 options bias toward `Defer`. **Findings**: confirmed all four hypotheses from the original ticket. The dominant factor in current state is the silent-agent heuristic's fall-through: when no sub-topic boundary is obvious AND no signal-vs-noise classification fired, the heuristic falls through to `leave-as-is` regardless of how many prior cycles have deferred. No accumulating-defer signal in the heuristic's input data.
  - **End-of-session pressure**: confirmed (orchestrator main turn treats user as transient per P130).
  - **No clear sub-topic boundary**: confirmed (most retro-time judgement calls cannot pick a clean boundary).
  - **No escalating pressure**: confirmed — this is the load-bearing root cause.
  - **AFK-fallback shape leaks into interactive**: confirmed but secondary; the silent-agent heuristic now applies in both modes (P135 / ADR-044).
- [x] Check whether the existing entry-level HTML comment trailers could be extended at the FILE level to track defer-count and `last-rotation-decision`. **Decision**: rejected (per architect review). Per-file accumulator-state in topic-file bodies fights git-blame-as-history. The byte-ratio signal from the existing script is a derived measure of the same accumulation — a file at 4× ceiling has demonstrably accumulated multiple cycles of defer. No new in-file state needed.
- [x] Decide enforcement mechanism. **Decision (architect-approved 2026-05-03)**: Option H (hybrid, lightest). Extend `check-briefing-budgets.sh` to emit `MUST_SPLIT <basename> reason=ratio-exceeds-2x` for files at ratio ≥ 2.0× threshold (the same threshold ADR-040's reassessment trigger uses — single-sourcing the policy). Amend `run-retro` Step 3 Tier 3 heuristic to add Branch A: when MUST_SPLIT line is present, the trim-noise / leave-as-is fall-throughs are not eligible — agent picks split-by-subtopic if a coherent boundary exists, else split-by-date (safe default — mtime-sort + median-age archive, mechanical and AFK-safe). Branch B (only OVER, no MUST_SPLIT) retains the original four-option heuristic.
- [x] Behavioural bats per ADR-037 + P081 covering the chosen mechanism. **Done**: 6 new bats cases in `packages/retrospective/scripts/test/check-briefing-budgets.bats` covering MUST_SPLIT-at-2x-boundary, MUST_SPLIT-not-under-2x, MUST_SPLIT-with-OVER, MUST_SPLIT-not-without-OVER, MUST_SPLIT-respects-env-override, mixed-block-sort-determinism. RED→GREEN cycle confirmed (4 cases failed before script edit; all 20 tests pass after).

### Preliminary hypothesis

The rotation prompt is structured as a per-cycle judgment call without memory. Agents correctly choose `defer` on each individual cycle (no clean split boundary visible at session-end), but the system has no escalating-pressure mechanism that converts N consecutive defers into a forcing function. ADR-040\'s reassessment trigger covers the policy-level escalation (revisit the policy after 3 files × 2 cycles); this ticket\'s enforcement lives one layer below — at the per-prompt rotation decision.

The fix shape is escalating pressure on the rotation prompt itself, NOT a stricter ADR-040 policy revisit.

## Fix Strategy

**Kind**: improve

**Shape**: skill (`packages/retrospective/skills/run-retro/SKILL.md` Step 3 Tier 3 budget rotation pass) + advisory script (`packages/retrospective/scripts/check-briefing-budgets.sh` extension) + behavioural bats

**Target file**: `packages/retrospective/skills/run-retro/SKILL.md` Step 3 (primary), `packages/retrospective/scripts/check-briefing-budgets.sh` (secondary — track defer-count signal)

**Observed flaw**: the Tier 3 rotation prompt presents `Defer — record only` as a co-equal option across all cycles, regardless of how many prior cycles have deferred the same file. No escalating pressure means defer wins recurrently.

**Edit summary** — three candidate fix shapes (one to pick during architect review):

1. **Per-file defer-count in topic-file HTML comment trailer + prompt-body citation** (smallest, cheapest fix). Each topic file gets a top-of-file HTML comment `<!-- tier3-defer-count: N | last-rotation-decision: <date> -->` updated each time `Defer — record only` is picked. Step 3\'s AskUserQuestion body cites the count in the question. The accumulating count creates social/cognitive pressure to pick a split. No option-set change.

2. **Auto-strip `Defer — record only` after K consecutive defers** (medium-strength fix). Same HTML-comment-trailer mechanism but the prompt parser checks the count: if `tier3-defer-count >= K` (e.g. K=3), the `Defer — record only` option is removed from the AskUserQuestion options list, leaving only the three real rotation shapes. Forces action after K cycles.

3. **Split run-retro Step 3 rotation into a sibling `/wr-retrospective:rotate-briefing` skill** (heaviest fix; precedent: P117 work-problem singular split, P071 multiple manage-problem subcommand splits). Run-retro Step 3 only DETECTS and surfaces; the actual rotation runs in a dedicated skill the user (or an AFK orchestrator on a Tier 3 budget threshold breach) invokes directly. Removes end-of-session-pressure bias by lifting rotation out of retro entirely. The new skill is foreground-only (split judgment is interactive by construction); AFK orchestrators surface "rotation needed" in their summary section but do not invoke the skill autonomously.

**Architect review will pick** between (1), (2), (3), or a hybrid (e.g. (1) + (2) — track count and auto-strip after K). The user\'s correction signal calibrates urgency — picking the lightest fix that genuinely changes the outcome is the architect\'s call.

**Evidence**:
- 2026-04-29 retro: 6 files over budget; 4 at ≥2× ceiling; user correction surfaced explicit class-of-behaviour signal.
- ADR-040 Tier 3 Reassessment trigger ("≥3 files exceed 2× ceiling for ≥2 cycles") satisfied today — the policy-level signal is firing.
- P099 verifying-state: P099\'s reusable triplet shipped the detection; this ticket fills the enforcement gap on top.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none — fix is independent of other open tickets)
- **Composes with**: P099, P134, P130

## Related

- **P099** (`docs/problems/099-briefing-md-grows-unbounded-via-run-retro-appends-violating-progressive-disclosure.verifying.md`) — parent ticket; shipped the Tier 3 advisory script + AskUserQuestion prompt + ADR-040 amendment. This ticket extends P099\'s reusable triplet with enforcement.
- **P134** (`docs/problems/134-docs-problems-readme-md-line-3-narrative-blob-accumulator-bloat-sibling-p099.verifying.md`) — same accumulator-pattern problem applied to a different surface (problems README narrative blob); learnings here apply there if rotation also recurs.
- **P078** correction-on-strong-signal pattern — today\'s user correction (`"we need to do better at spliting. We can;\'t just keep defering"`) is the canonical strong-signal phrasing the P078 hook captures.
- **P130** (`docs/problems/130-work-problems-orchestrator-defaults-to-subprocess-dispatch-even-when-user-observably-interactive.verifying.md`) — "transient user" framing for orchestrator main turn explains why end-of-session rotation prompts get answered with the lowest-effort option.
- **P124** (`docs/problems/124-manage-problem-step-2-substep-7-session-id-discovery.verifying.md`) — directly relevant to today\'s creation friction: `get_current_session_id` returned `66847248-...` (session) but the runtime hook stdin carried different SIDs across calls; the helper\'s first-glob-match selection in `@windyroad/itil@0.21.1` picked the wrong SID. P124 Phase 3 mtime-selection fix ships in a later @windyroad/itil version; until installed, manual marker-touch under the runtime SID is the workaround. Today this ticket landed via python3-via-Bash heredoc per `docs/briefing/afk-subprocess.md` line 24 documented workaround.
- **Upstream report pending** — false positive; detection misfire. P063 detection matched the `@windyroad/itil@0.21.1` token in the P124 cross-reference above, which is incidental documentation context not a root cause. P145 is purely internal (SKILL.md heuristic + advisory script).
- **ADR-040** (`docs/decisions/040-progressive-disclosure-budget-policy.proposed.md`) — Tier 3 envelope (2-5 KB / topic file). Reassessment trigger ("≥3 files exceed 2× ceiling for ≥2 cycles") satisfied today.
- **`packages/retrospective/skills/run-retro/SKILL.md`** Step 3 Tier 3 budget rotation pass — the Edit target.
- **`packages/retrospective/scripts/check-briefing-budgets.sh`** — the read-only advisory script that fires today; potential extension surface for defer-count tracking.
- **`packages/retrospective/scripts/test/check-briefing-budgets.bats`** — behavioural-test parent for the chosen fix.
- 2026-04-29 retro evidence: today\'s retro Topic File Rotation Candidates table — all 6 entries `defer`.
