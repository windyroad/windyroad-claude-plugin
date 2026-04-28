# Problem 145: `/wr-retrospective:run-retro` Tier 3 budget rotation prompt accumulates "defer" answers across retros — topic files exceed budget recurringly without action

**Status**: Open
**Reported**: 2026-04-29
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3) — observed recurring across multiple recent retros; user surfaced explicitly today: *"we need to do better at splitting. We can\'t just keep deferring."*
**Effort**: M — design + ship an escalating-pressure mechanism on the Step 3 Tier 3 prompt (per-file defer-count in HTML comment trailer, or auto-strip the `Defer — record only` option after K consecutive defers, or split run-retro Step 3 rotation into a sibling `/wr-retrospective:rotate-briefing` skill that is non-deferrable). Plus matching behavioural bats per ADR-037 + P081.
**WSJF**: (9 × 1.0) / 2 = **4.5**

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

- [ ] Audit recent `docs/retros/*.md` files: how many retros have surfaced `Defer` rotation decisions vs other actions? Count per topic file.
- [ ] Investigate why the Step 3 prompt\'s 4 options bias toward `Defer`. Hypotheses:
  - **End-of-session pressure**: the rotation prompt fires LAST in Step 3, after all other retro work. Agents at end-of-session pick the lowest-effort option.
  - **No clear sub-topic boundary**: agents lack the context to pick a meaningful split. The `Defer — record only` description literally says "Use this when no clean split boundary exists" — which is most cases mid-retro.
  - **No escalating pressure**: the prompt looks identical on retro 1 (file just barely over budget) and retro 5 (file at 4× ceiling, after 4 prior defers). No accumulating-defer signal in the question body.
  - **AFK-fallback shape leaks into interactive**: P099\'s AFK fallback (record-only in summary) is the right answer for AFK; but in interactive sessions the same `defer` option is presented — and the orchestrator main turn IS interactive but treats the user as transient (P130), so `defer` gets picked anyway.
- [ ] Check whether the existing entry-level HTML comment trailers (`<!-- signal-score: N | last-classified: <date> | first-written: <date> -->` per Step 1.5) could be extended at the FILE level to track defer-count and `last-rotation-decision`.
- [ ] Decide enforcement mechanism (see Fix Strategy options below).
- [ ] Behavioural bats per ADR-037 + P081 covering the chosen mechanism.

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
- **ADR-040** (`docs/decisions/040-progressive-disclosure-budget-policy.proposed.md`) — Tier 3 envelope (2-5 KB / topic file). Reassessment trigger ("≥3 files exceed 2× ceiling for ≥2 cycles") satisfied today.
- **`packages/retrospective/skills/run-retro/SKILL.md`** Step 3 Tier 3 budget rotation pass — the Edit target.
- **`packages/retrospective/scripts/check-briefing-budgets.sh`** — the read-only advisory script that fires today; potential extension surface for defer-count tracking.
- **`packages/retrospective/scripts/test/check-briefing-budgets.bats`** — behavioural-test parent for the chosen fix.
- 2026-04-29 retro evidence: today\'s retro Topic File Rotation Candidates table — all 6 entries `defer`.
