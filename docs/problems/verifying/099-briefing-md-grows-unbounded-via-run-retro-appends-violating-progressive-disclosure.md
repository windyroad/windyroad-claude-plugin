# Problem 099: `docs/BRIEFING.md` grows unbounded via run-retro appends — violates progressive disclosure

**Status**: Verification Pending
**Reported**: 2026-04-22
**Released**: 2026-04-26
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Effort**: L
**WSJF**: (15 × 1.0) / 4 = **3.75**

> Third child of P091 (Session-wide context budget) identified 2026-04-22 by the user while reviewing the P098 fix. P098 shipped a project-level `CLAUDE.md` that explicitly points to `docs/BRIEFING.md` as "Session learnings — read first each session", which makes BRIEFING.md's current bloat more visible: every session now pays its session-start token cost AND is invited to read it first.

## Description

`docs/BRIEFING.md` is the canonical cross-session learnings file. `run-retro` (wr-retrospective plugin) appends new learnings to it at the end of every retrospective. Over time this file grows unbounded:

- **Current state (2026-04-22)**: 72 lines / ~20KB / ~5000 tokens. Stated budget in `run-retro` Step 3: "Keep the file concise — under 2000 tokens." **2.5× over budget.**
- **Shape**: Each bullet is 5-10 lines of dense prose — observations, dates, ticket references, remediations, all inline. Stated target: "Each item should be 1-2 lines." Not enforced; violated on most entries.
- **Write pattern**: `run-retro` Step 3 documents add / remove / update. It does NOT document rotation or archival into topical sub-files. There is no affordance for the consumer (the assistant on next session start) to load only the recent or the relevant — the entire file is read eagerly.
- **No enforcement**: no bats test, no CI check, no hook. The budget is honour-system and has failed.

This is the same root cause pattern as P095 (UserPromptSubmit prose re-emission), P097 (SKILL.md runtime size), and P098 (project/user-owned contributors): eager emission with no progressive-disclosure affordance. BRIEFING.md is a user-project-owned surface, same category as P098's targets, but wasn't audited there because it's managed by a plugin (run-retro) rather than user-authored directly.

The user's framing (2026-04-22): *"the briefing notes themselves violate progressive disclosure and run-retro will, left unchanged, continue to bloat docs/BRIEFING.md over time."*

## Symptoms

- BRIEFING.md loads at every session start (referenced by project `CLAUDE.md`, pointed at by retrospectives, explicitly recommended to read first).
- ~5000 tokens of preamble before any task-specific work — ~2.5% of a 200K context window just on historical learnings that are mostly not relevant to the current session.
- Bullets accumulate without consolidation: P095-era notes sit alongside 2026-04-16 Discord setup notes.
- Every run-retro session adds more. No retro has ever rotated content out (beyond occasional ad-hoc removal prompts).

## Workaround

Manual trim during `run-retro` if the user notices bloat. No automatic mechanism.

## Impact Assessment

- **Who is affected**: Every contributor to this project (all sessions load BRIEFING.md at start). Secondary: downstream adopters who mirror the run-retro → BRIEFING.md pattern in their own repos.
- **Frequency**: Every session. Bloat compounds monotonically.
- **Severity**: Moderate cumulative. Smaller per-session cost than P095 (hook prose) but persistent and growing.
- **Analytics**: Measurement harness on P091 meta. Current BRIEFING.md: 72 lines / 5000 tokens.

## Root Cause Analysis

### Confirmed (2026-04-22 audit)

- `run-retro` Step 3 prescribes "under 2000 tokens" and "1-2 lines per item" but the actual file is 2.5× over and most items are 5-10 lines.
- `run-retro` Step 3 documents add / remove / update operations. No rotation, archival, or extraction pattern is documented — there is no expected workflow for "this entry is no longer day-1-relevant but still load-bearing; move it to `docs/briefing/<topic>.md`."
- No CI check enforces the budget. `packages/retrospective/hooks/` has no byte-count hook on BRIEFING.md.
- No behavioural test on run-retro asserts that BRIEFING.md stays under budget after a retro append. Structural grep tests on run-retro's SKILL.md exist (P081 surface); behavioural budget assertions do not.

### Design flaw (per P091 meta's unifying pattern)

Same eager-emission default as P095/P097/P098:

- Consumer (assistant on next session) loads the entire file at start, not "recent entries + pointer to topical archives."
- Producer (run-retro) appends without rotation, with no feedback loop that fires when budget is exceeded.
- The affordance for progressive disclosure (topical archive + pointer) is missing entirely — BRIEFING.md has no `docs/briefing/` sibling directory structure to offload to.

### Investigation tasks

- [x] Measure current BRIEFING.md (72 lines, ~20KB, ~5000 tokens — confirmed 2026-04-22)
- [x] Read `run-retro` Step 3 and confirm the budget-and-shape targets vs actuals (confirmed 2026-04-22)
- [x] Design topical archive structure — completed via P100 slice 1 (commit 5d367e9, 2026-04-22). Six topic files: `hooks-and-gates.md`, `releases-and-ci.md`, `governance-workflow.md`, `afk-subprocess.md`, `plugin-distribution.md`, `agent-interaction-patterns.md`.
- [x] Trim current BRIEFING.md / migrate to topical archives — completed via P100 slice 1 (commit 5d367e9). Legacy `docs/BRIEFING.md` retired entirely via P100 slice 2 (commit 2c30de2).
- [x] Update `run-retro` Step 3 with rotation step — completed 2026-04-26 (this slice). Step 3 gains the Tier 3 budget rotation pass with `check-briefing-budgets.sh` invocation, interactive `AskUserQuestion` (split-by-subtopic / split-by-date / trim-noise / defer per ADR-013 Rule 1), and AFK fallback to retro summary's "Topic File Rotation Candidates" section per ADR-013 Rule 6.
- [x] Add behavioural bats test — completed 2026-04-26. `packages/retrospective/scripts/test/check-briefing-budgets.bats` covers existence + executable + empty-dir + under-threshold + over-threshold + boundary-exact + README-excluded + env-var-override + non-md-ignored + missing-dir-exit-2 + sort-stability (14 tests, all green).
- [x] ADR shape decided — amendment to **ADR-040** (not ADR-038). ADR-040 owns the SessionStart briefing tier model; this slice promotes Tier 3 from informational to advisory enforcement. Architect confirmed 2026-04-26: amendment, not sibling. Reasoning: budget itself is unchanged, only enforcement mechanism added; ADR-040 already encodes the Reassessment-on-budget-breach pattern.

## Fix Released

- **Released**: 2026-04-26 — commit `<TBD>` on main
- **Source**:
  - `packages/retrospective/scripts/check-briefing-budgets.sh` — new advisory diagnostic
  - `packages/retrospective/scripts/test/check-briefing-budgets.bats` — new behavioural fixture (14/14 green)
  - `packages/retrospective/skills/run-retro/SKILL.md` — Step 3 rotation pass + Step 5 summary table
  - `docs/decisions/040-session-start-briefing-surface.proposed.md` — Tier 3 budget amendment + Reassessment triggers + reusable-pattern note (JTBD-101)
- **Plugin bump**: `@windyroad/retrospective` 0.7.0 → 0.8.0 (minor — Step 3 contract gains a sub-step consumers should see)
- **Verification path**: future retro cycles invoke the script; over-budget topic files surface as rotation candidates (interactive) or in the retro summary (AFK). Boundary state observable in `docs/briefing/*.md` shrinking toward the 5 KB/topic ceiling across cycles.

## Fix Strategy

**Progressive disclosure applied to accumulator docs** — same principle as ADR-038, new surface:

1. **Lean root file (`docs/BRIEFING.md`)** — recent entries + topic index. Each bullet: 1-2 lines with a stable title + date + pointer to the topical archive for deeper context. Budget: ≤ 2000 tokens.
2. **Topical archives (`docs/briefing/<topic>.md`)** — deep-dive entries grouped by theme. Loaded on demand when a session's work intersects the topic. Example topics (to be finalised): hooks-and-gates, release-cadence-and-ci, afk-loops-and-orchestration, skills-and-patterns, subprocess-dispatch-and-workers.
3. **run-retro rotation step** — when run-retro appends push BRIEFING.md over budget, the skill rotates oldest-matching entries into the appropriate topical archive, leaving 1-line summary + pointer in BRIEFING.md. Interactive: `AskUserQuestion` confirms each rotation when the user is present; AFK fallback runs the rotation silently per ADR-013 Rule 6.
4. **CI enforcement** — bats test on run-retro that asserts the budget; CI step that reports BRIEFING.md byte count so regressions are visible.

The ADR anchor on P091 ("Progressive disclosure for governance tooling context") already names accumulator surfaces as candidates; this ticket either amends ADR-038 to cover accumulator docs explicitly or authors a thin sibling ADR. Architect decides at implementation time.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P091 (parent meta), P098 (sibling — same progressive-disclosure pattern applied to project/user-owned contributors), P088 (run-retro context visibility), P050 (run-retro codification axis), P044 (run-retro skill recommendations)

## Related

- **P091 (Session-wide context budget — meta)** — parent meta ticket. This is the third child audited on the user-owned surface cluster (after P098's CLAUDE.md / install-updates / memory audit).
- **P098 (Project and user-owned context contributors)** — sibling; P098's fix missed BRIEFING.md because its audit focused on static-user-authored files (`~/CLAUDE.md`, `MEMORY.md`) and project-level skills, not on plugin-written accumulator docs. P099 closes that gap.
- **P050 (run-retro codification axis)** — adjacent run-retro quality issue (codification shapes); not a blocker but touches the same SKILL.md.
- **P088 (run-retro cannot see full context)** — adjacent run-retro quality issue (context visibility); same SKILL.md surface.
- **P044 (run-retro does not recommend new skills)** — adjacent run-retro quality issue; Verification Pending.
- **P081 (structural content tests are wasteful)** — the new behavioural bats test for the budget should be behavioural (measure file size) not structural (grep for a specific string in run-retro's SKILL.md).
- **ADR-038** — progressive-disclosure anchor. This ticket either amends it to cover accumulator surfaces or authors a sibling ADR.
- **ADR anchor**: P091's "Progressive disclosure for governance tooling context" umbrella covers this ticket too.
