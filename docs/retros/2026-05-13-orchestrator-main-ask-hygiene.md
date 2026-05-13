# Ask Hygiene — 2026-05-13 (orchestrator main turn, /wr-itil:work-problems loop)

Scope: orchestrator's main turn from `/wr-itil:work-problems` invocation through Step 6.75 halt + Step 2.5b surfacing + user-interactive briefing rotation + write-back commits. Excludes iter 1 and iter 2 subprocess invocations (those have their own ask-hygiene trails at `2026-05-13-p162-phase-2a-ask-hygiene.md` and `2026-05-13-ask-hygiene.md` respectively).

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 (Q1) | P162 Phase 2b | direction | Gap: agent cannot decide whether to schedule Phase 2b atomic-cohort work next iter, defer until atomic-cohort accumulates, or capture as separate ticket — this is direction-setting on framework evolution (when ADR-061 Phase 2b lands relative to empirical baseline). Framework provides scope guidance but not the timing question. |
| 1 (Q2) | external-comms | direction | Gap: agent cannot decide the fix shape for the P163 external-comms agent sha256 marker key issue (grant Bash / move computation / content-address / defer-as-ticket) — this is direction-setting on remediation shape across three candidate ADRs (ADR-028 tool grant, hook redesign, content-addressing). Framework provides the problem class but not the fix preference. |
| 1 (Q3) | TMPDIR variance | direction | Gap: agent cannot decide whether the TMPDIR-resolution-variance fix bundles with the external-comms fix, stays standalone, captures-as-ticket, or investigates further — direction-setting on dependency coupling. Framework provides observability but not the coupling preference. |
| 1 (Q4) | Briefing rotate | direction | Gap: agent cannot decide whether MUST_SPLIT rotation runs as a dedicated AFK iter, defers to interactive retro, auto-splits-by-date AFK, or skips this loop — direction-setting on operational pacing. **Framing defect**: the option-set was AFK-biased even though the AskUserQuestion firing IS proof of interactivity (user correction "you're not being very smart" → P188 captured the class). The question itself was still direction-class; the option-shape framing was wrong. |

**Lazy count: 0**
**Direction count: 4**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

The orchestrator's main turn invoked AskUserQuestion exactly once (a 4-question batched call at Step 2.5b loop-end surfacing per the SKILL contract). All 4 questions were direction-class — they sit in the framework-resolution-gap zone where the user is the load-bearing authority per ADR-044 categories 1 (direction) / 2 (deviation-approval). None were lazy.

**Cross-classification note**: Q4's option-set framing was defective (AFK-biased), but the question itself was correctly classified as direction. The framing defect is the class P188 captures — it's an option-shape pattern, not a question-classification pattern. The lazy-count regression metric per ADR-044 R6 stays at 0 for this surface.

Cumulative lazy count across 2026-05-13 retros (iter 1 + iter 2 + this orchestrator-main retro): 0 + 0 + 0 = **0 across 3 retros today**. R6 gate remains far from threshold (≥2 across 3 consecutive retros).
