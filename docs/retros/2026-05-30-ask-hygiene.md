# Ask Hygiene — 2026-05-30 session

Per ADR-044 (Decision-Delegation Contract — framework-resolution boundary). Lazy count is the regression metric; target 0.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 1 | Mechanism | direction | Gap: genuine ≥2-option ADR decision (sort tier vs WSJF formula change vs likelihood inflation), framework cannot resolve, about to be built on (ADR-074) |
| 2 | Review path | direction | Gap: genuine ≥2-option operational decision (release + refresh vs drive-from-source vs stop) for how the upcoming review picks up ADR-076 |
| 3 | Format | direction | Gap: genuine ≥2-option ADR decision (compendium vs frontmatter vs sibling files vs section), framework cannot resolve, about to be built on (ADR-074) |

**Lazy count: 0**
**Direction count: 3**
**Override count: 0**
**Silent-framework count: 0**
**Taste count: 0**
**Correction-followup count: 0**

R6 gate: not triggered (lazy count 0 across 3 consecutive retros — well below the ≥2 threshold).

---

## Session 8 (work-problems wrap retro after Step 6.5 CI-failure halt)

Two `AskUserQuestion` calls in the orchestrator main turn.

| Call # | Header | Classification | Citation |
|--------|--------|----------------|----------|
| 4 | Session continuity | **lazy** | Framework: /wr-itil:work-problems Step 0 session-continuity contract on `.afk-run-state/iter-*.json` is_error markers — the marker mtime + the related ticket's current state (closed-vs-open) are observable signals the framework could resolve from. Agent could have applied "marker older than HEAD by N commits AND related ticket closed → silent pass-through" and avoided round-tripping the user. The user's answer ("Proceed, but capture a problem for not being able to detect that it's stale and having to ask") explicitly tagged this ask as the lazy pattern. New ticket P333 captures the framework gap. |
| 5 | Cohort grad | **deviation-approval** | Gap: genuine ≥2-option decision — Approve+amend SKILL / Approve+supersede via evaluator / Approve+one-time / Reject. The framework (Step 6.5 SKILL prose vs holding-README Process line 22 vs P308 documented workaround) contains contradictory load-bearing artefacts; choosing the fix locus is ADR-044 cat-2 deviation-approval the framework cannot resolve. User selected "Approve + amend SKILL (preserve workaround)". |

**Session 8 lazy count: 1**
**Session 8 deviation-approval count: 1**

R6 gate (cross-session, including this session): prior retros today lazy=0 + lazy=0 + this lazy=1 — does NOT trip ≥2-across-3 R6. P132 enforcement hook stays gated.

