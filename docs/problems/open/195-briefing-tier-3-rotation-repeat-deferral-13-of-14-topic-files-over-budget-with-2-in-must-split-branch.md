# Problem 195: Briefing Tier 3 rotation repeat-deferral — 13 of 14 topic files over ADR-040 budget with 2 in MUST_SPLIT (≥2× ceiling) branch

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 6 (Med) — Impact: 3 (Moderate — briefing bucket compounds session-start cost across all sessions) x Likelihood: 2 (Possible — pattern repeats every retro) (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The 2026-05-15 retrospective's `check-briefing-budgets.sh` advisory fired with 13 of 14 topic files at or above the ADR-040 Tier 3 ceiling (5120 bytes). Two files fall in the MUST_SPLIT branch (≥2× ceiling) per P145's sibling-rotation contract:

- `docs/briefing/hooks-and-gates-archive.md` — 12,795 bytes (2.50× ceiling — MUST_SPLIT)
- `docs/briefing/governance-workflow-archive.md` — 10,154 bytes (1.98× ceiling, borderline MUST_SPLIT)

The remaining 11 files are in the OVER (Branch B) range (1.0× to 2.0× ceiling).

Per P099 / P145, the run-retro Step 3 Tier 3 budget rotation pass is supposed to mechanically apply rotation per file. In the 2026-05-15 retro the rotation was deferred (recorded as "flagged (non-interactive — deferred to next retro)" in the Topic File Rotation Candidates table) because the session was goal-pinned to P064/P038/P079 and per-file silent rotation would have consumed substantial budget without serving the goal. This is the **repeat-deferral pattern** — the same Topic File Rotation Candidates table appears in retro after retro without resolution.

The pattern matches P145's anti-pattern definition (recurring-defer escapes the cascade). The deep-layer context analysis names this as Suggestion 5 / Stage 1 ticket worthy.

## Symptoms

- `check-briefing-budgets.sh` emits OVER lines on 13 of 14 files every retro.
- 2 files at MUST_SPLIT threshold (≥2× ceiling); per Branch A, do-nothing options should not be eligible — but the rotation keeps getting deferred.
- `briefing` bucket measures 119,103 bytes / 3.6% of total cheap-layer context (small in absolute terms but every byte loaded at session start).
- **Session-8 evidence appended 2026-05-19**: at session-wrap retro start, `check-briefing-budgets.sh` reported **15 OVER files** with `plugin-distribution.md` at MUST_SPLIT (10370 bytes / 2.03× ceiling). Briefing bucket now 136835 bytes (up from 119103 measured at P195 capture — +14.9%). Session 8 retro rotated 1 file (plugin-distribution.md → split-by-subtopic to `plugin-distribution-cache-mechanics.md`); plugin-distribution.md now 3118 bytes (under threshold), sibling 7971 bytes (still Branch B OVER but no longer MUST_SPLIT). **14 Branch B OVER files remain unrotated** after session 8 retro. The pattern continues — per-retro rotation pace (~1 file/retro) is not keeping up with accretion across 12 plugin files + 17 topic files. Branch A escalation (P145 stricter contract / CI gate / sibling rotation skill) is increasingly warranted as evidence accumulates.

## Workaround

None — the rotation has been documented in retro summaries but not executed. The advisory script does its job (surfaces the OVER state); the discipline at the action-time has been deferred each cycle.

## Impact Assessment

- **Who is affected**: solo-developer (JTBD-001) / AFK orchestrator (JTBD-006) at session-start when briefing is loaded.
- **Frequency**: every session loads the briefing tree at start; rotation has been deferred across 5+ retros (estimate from README-history.md entries naming briefing topics).
- **Severity**: Moderate — context-bucket impact is small in absolute bytes but signals discipline-erosion (the very pattern P145 was designed to catch).
- **Analytics**: see `docs/retros/2026-05-15-context-analysis.md` Policy Breaches table + Topic File Rotation Candidates section of the latest retro summary.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit the run-retro Step 3 Tier 3 rotation contract: does the SKILL allow defer-when-goal-pinned, or is that an agent-side rationalisation? If allowed, the SKILL should name the goal-pinned-defer carve-out explicitly; if not allowed, the SKILL contract is being violated.
- [ ] Apply Branch A rotation to the two MUST_SPLIT files this iter — `hooks-and-gates-archive.md` and `governance-workflow-archive.md` — pick split-by-date (safe default per the SKILL's rationale).
- [ ] Apply Branch B rotation to the 11 OVER files in priority order (largest first).
- [ ] If the rotation is consistently deferred, escalate to a load-bearing CI gate per ADR-040 Reassessment Trigger (per P099 / P145 escalation pattern).
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.

### Preliminary Hypothesis

The current SKILL allows the agent to defer rotation when the session is goal-pinned, which is consistent with JTBD-001's "without slowing down" outcome but creates the cascade P145 documents: every session is goal-pinned to something, so rotation never happens. The fix candidates:

1. **Tighten the SKILL contract** to forbid defer-when-goal-pinned for Branch A (MUST_SPLIT) files specifically — the ≥2× threshold IS the cascade signal.
2. **Add a CI step** that fails on Branch A MUST_SPLIT files older than N retros (per ADR-040 Reassessment Trigger).
3. **Spawn a sibling skill** `/wr-retrospective:rotate-briefing` that does the rotation in one focused invocation, so a session can dispatch the rotation without doing it inline.

(1) is the lowest-cost fix; (2) is the strictest; (3) is the most flexible.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P099 (parent ticket — briefing tier 3 advisory enforcement), P145 (sibling — defer-pattern at the rotation prompt), P194 (sibling content-class problem on ADR surface — same display-vs-history pattern), P101 (deep-layer measurement that surfaced the breach)

## Related

- `packages/retrospective/scripts/check-briefing-budgets.sh` — the advisory script.
- `packages/retrospective/skills/run-retro/SKILL.md` Step 3 Tier 3 rotation pass.
- `docs/retros/2026-05-15-context-analysis.md` — measurement evidence (13 of 14 over).
- P099 (`docs/problems/closed/099-...md`) — parent ticket.
- P145 (`docs/problems/closed/145-...md`) — defer-pattern sibling.
- P194 (`docs/problems/open/194-...md`) — sibling content-class problem on ADR surface.
- ADR-040 — Tier 3 budget policy + Reassessment Trigger.
- Captured by `/wr-retrospective:run-retro` Step 4b Stage 1 + user direction "don't defer the stage 1 ticketing" (2026-05-15).

## Change Log

- **2026-05-25** — Worsened: `check-briefing-budgets.sh` now reports **15 files OVER** the 5120-byte ceiling (up from 13), with **0 in MUST_SPLIT** (the prior 2 MUST_SPLIT files were split since, but the split *targets* — the `*-archive*.md` siblings — are THEMSELVES now over budget: `hooks-and-gates-archive.md` 10009, `releases-and-ci-archive.md` 9941, `governance-workflow-archive*.md` 5529-6086). This is the key systemic signal: **per-file split-by-date rotation can no longer keep pace because the archive targets are saturated too** — splitting an over-budget file into an over-budget archive does not reduce the briefing bucket. The Step 3 Tier 3 per-retro rotation (Branch B "rotate, don't defer") is structurally unable to converge when the entire surface including rotation targets exceeds the ceiling. Recommends a systemic fix over per-file rotation: candidates — (a) raise the Tier 3 ceiling (ADR-040 amendment; the 5120 bound may be too low for a mature suite's accumulated learnings), (b) aggressive Step 1.5 signal-score decay + delete-queue to shrink low-signal entries rather than archive them, (c) a different briefing organization (e.g. a single rolling archive with its own budget exemption). The 2026-05-25 retro added 2 high-value entries (E404/2FA + global-cache) and did NOT rotate, recording this systemic-saturation evidence instead of churning 15 files into full archives.
