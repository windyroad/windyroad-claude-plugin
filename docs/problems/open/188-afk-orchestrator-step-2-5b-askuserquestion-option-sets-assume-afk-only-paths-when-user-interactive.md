# Problem 188: AFK orchestrator Step 2.5b AskUserQuestion option-sets assume AFK-only paths even when the user's answering the AskUserQuestion is itself proof of interactivity — should include "do it interactively now" options when user-presence is proven by the surface firing

**Status**: Open
**Reported**: 2026-05-13
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

AFK orchestrator Step 2.5b AskUserQuestion option-sets assume AFK-only paths even when the user's answering the AskUserQuestion is itself proof of interactivity — should include "do it interactively now" options when user-presence is proven by the surface firing.

Captured 2026-05-13 mid-`/wr-itil:work-problems` loop, Step 6.75 dirty-for-unknown-reason halt, after iter 2 (P185 derive-first refactor) completed. The orchestrator's Step 2.5b accumulated 4 user-answerable items and surfaced them via `AskUserQuestion`. One item — "3 briefing topic files at MUST_SPLIT; rotation needs human judgment on split-by-date archive boundaries" — was framed with 4 AFK-shaped options:

1. Defer to interactive retro
2. Dedicated AFK rotation iter now
3. Capture as P-ticket and defer
4. Skip rotation for this loop

The user's correction (verbatim): *"You're not being very smart. You've convinced yourself that it has to done AFK, but you're asking me about it, which means I've returned. Use that opportinity to do it iteractively now."*

The class-of-behaviour: the agent framed Step 2.5b options assuming the user is still AFK at the time the question fires. But the user can ONLY answer the question by returning to the keyboard — so the act of receiving an answer is itself proof the user is no longer AFK. The option set should reflect that: a "do it interactively right now (you're here)" option belongs in the menu wherever the question would otherwise route work to a future-AFK-iter or future-interactive-session.

This is a structural sibling of:
- **P132** — agents over-ask in interactive sessions; conflating mechanical-stages with user-interactive-stages.
- **P175** — agent over-narrows scope-pin words into halt; misclassifies signal as constraint.
- **P185** — `/wr-itil:capture-problem` asks classification question it can derive itself; SKILL-surface inverse-P078 trap.
- **P186** — VQ "Likely verified?" uses age heuristic instead of session-evidence; same proxy-for-evidence anti-pattern at the rendering surface.
- **P187** — AFK orchestrator halts with "Recommended next step" when it could auto-dispatch the mechanical unblock; orchestrator-control-flow surface.

The common pattern: agent treats a "mode" (AFK / interactive / mechanical / structured) as fixed when the surface firing is itself evidence of mode-transition. Per `feedback_act_on_obvious_decisions.md`: act on what's observable in front of you, not on assumed prior state.

## Symptoms

- Step 2.5b option-sets framed entirely as defer / capture / AFK-iter / skip when the user is right there reading the question.
- User must add "do it now" as a custom Other response or explicitly correct the framing.
- Compounds friction at loop-end (the one time the user IS explicitly present) by routing work AWAY from the present moment.

## Workaround

User adds "Other → do it interactively now" or sends a correction message. The workaround works but defeats the purpose of structured AskUserQuestion options.

## Impact Assessment

- **Who is affected**: maintainers returning to an AFK orchestrator loop-end at Step 2.5b surfacing.
- **Frequency**: every loop-end where Step 2.5b queues a question that could be answered by the user doing the work themselves in-session. High ratio when retro-flagged MUST_SPLIT files accumulate, when briefing rotation is overdue, or when small docs edits queue up.
- **Severity**: low — friction-add at the one explicit user-interaction surface. Not a correctness defect.
- **Analytics**: count of Step 2.5b option-sets that include vs omit a "do it interactively now" option. Ratio close to 0 indicates the AFK-bias is universal.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit `packages/itil/skills/work-problems/SKILL.md` Step 2.5b prose for option-shape guidance — does it explicitly enumerate "do it interactively now" as a valid option for user-answerable items the user could resolve in-session?
- [ ] Decide whether the fix is (a) SKILL.md amendment listing "do it now (interactive)" as a required option-class for Step 2.5b, (b) orchestrator runtime detection that the user is interactive (via the AskUserQuestion surface firing), or (c) per-question shape guidance enumerating when each option-class applies.
- [ ] Sibling sweep: do other AskUserQuestion-using skills (manage-problem, work-problem, manage-rfc, run-retro) have the same AFK-biased option-shape pattern? Capture each sibling instance into this ticket if so.
- [ ] Behavioural bats: AskUserQuestion options for user-answerable items at loop-end MUST include at least one "interactive now" option when the work is doable in-session.

## Dependencies

- **Blocks**: (none — this is option-set framing, not control-flow)
- **Blocked by**: (none)
- **Composes with**: P132 (agents over-ask interactively — same mode-misclassification class), P175 (over-narrows scope-pin — same fixed-mode-assumption class), P185 (capture-problem derive-first — same anti-pattern at SKILL surface), P186 (VQ age heuristic — same proxy-for-evidence anti-pattern at render surface), P187 (orchestrator halts with recommendation — same halt-instead-of-act anti-pattern at control-flow surface)

## Related

- **P132** — agents over-ask interactively (verifying).
- **P175** — agent over-narrows scope-pin (open).
- **P185** — `/wr-itil:capture-problem` derive-first classifier (verifying — iter 2 fix released this session).
- **P186** — VQ `Likely verified?` heuristic (open).
- **P187** — orchestrator halts with recommendation instead of auto-dispatching unblock (open).
- **`packages/itil/skills/work-problems/SKILL.md`** — primary fix surface (Step 2.5b option-shape contract).
- **memory `feedback_act_on_obvious_decisions.md`** — act on observable evidence, not on assumed prior state.
- **memory `feedback_capture_on_correction.md`** — drove the capture of this ticket (P078 correction-signal pattern fired on the user's "you're not being very smart" correction).

(captured via /wr-itil:capture-problem; expand at next investigation)
