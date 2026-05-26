# Ask Hygiene — 2026-05-26 work-problems iter (P260 Option C)

AFK `/wr-itil:work-problems` iteration subprocess. `AskUserQuestion` is forbidden mid-loop (P135 / ADR-044); observations queue at `ITERATION_SUMMARY.outstanding_questions` for loop-end batched presentation.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| (none) | — | — | No `AskUserQuestion` calls fired this iteration. |

**Lazy count: 0**
**Direction count: 0**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

Decisions this iteration were all framework-resolved and applied silently per ADR-044's framework-resolution boundary: Option C fix-shape (already architect-resolved + human-confirmed 2026-05-26), K→V transition deferral (release-gated per work-problems Step 5 line 268 + manage-problem Step 7), ADR-050 Confirmation-update deferral (architect-flagged non-blocking; deferred to avoid the multi-decision-file gate-relock hazard per briefing Critical Point), `.claude/settings.json` exclusion from the commit (P131), commit-gate via wr-risk-scorer:pipeline, external-comms dual-gate recovery (releases-and-ci.md documented pattern). No decision was sub-contracted back to the user.

R6 numeric gate (lazy ≥2 across 3 consecutive retros): NOT met — this retro lazy=0; the cross-session trend's only ≥2 entry is the prior `p177-salvage-release` retro (isolated, not 3-consecutive).
