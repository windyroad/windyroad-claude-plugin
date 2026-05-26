# Ask Hygiene — 2026-05-26 (review-decisions drain + P314 rework chunk)

Per ADR-044. Second retro this session (covers the oversight drain + the P314 gate-design rework). Lazy count is the regression metric — target 0. Note: the user explicitly directed *"use askuserquestion"* this chunk, so ask-count is high by design; the metric is lazy-count, not total.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Next step | direction | Gap: post-task "what work next" — multiple valid directions (confirm ADRs / fix P312 / P313 / wrap); the user directs. |
| 2 | ADR-072 / ADR-073 (confirm) | deviation-approval | Framework-required: `/wr-architect:review-decisions` IS the ADR-066/P283 human-confirm surface for recorded decisions. Surfaced two rejections. |
| 3 | ADR-072 detail + auto-create scope | direction | Gap: the user's substantive design choices (placement; auto-create scope) the framework couldn't resolve — and was actively reversing ADR-073. |
| 4 | Gate placement (propose-fix options) | direction | Gap: genuine ≥2-option design decision (where the fix-time gate fires) under the corrected Known Error model; not framework-resolvable. |
| 5 | ADR-034/047/055/063 (drain) | deviation-approval | Framework-required: review-decisions human-confirm of four recorded decisions' dispositions (all rejected/superseding). |
| 6 | P078 capture (P315) | correction-followup | Gap: P078 capture-on-correction — the user flagged "didn't get my confirmation before you implemented." |
| 7 | ADR filenames (git mv) | taste | Gap: no guide settles the slug rename; the architect explicitly flagged it as a user judgment call. |

**Lazy count: 0**
**Direction count: 3**
**Deviation-approval count: 2**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 1**
**Correction-followup count: 1**

Note: this chunk's two strong corrections (no-shortcuts P311 earlier; confirm-substance-before-building P315 this chunk) were content/process errors, NOT ask-hygiene regressions. P315 is in fact the INVERSE of lazy — *under*-asking on a decision's substance. The asks here were the corrective: putting the gate-design substance to the user before rebuilding.
