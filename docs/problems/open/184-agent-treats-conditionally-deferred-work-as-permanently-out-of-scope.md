# Problem 184: Agent treats conditionally-deferred work (deferred-pending-X-graduation) as permanently out of scope — prematurely transitions parent ticket when X graduates

**Status**: Open
**Reported**: 2026-05-12
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Surfaced 2026-05-12 during the P170 Phase 1 transition. The agent read "Phase 2 SHIP deferred to post-Phase-1-graduation" (a CONDITIONAL deferral — "this becomes in-scope once Phase 1 graduates") as equivalent to "Phase 2 permanently deferred / explicitly out of scope" and moved P170 from Known Error → Verification Pending after Phase 1 shipped, missing that the deferral was conditional on a dependency that had just lifted. The user caught this only because they asked an orthogonal question ("where do RFCs manage user story maps?") that surfaced the agent's response stating Phase 2 was deferred — exposing the misreading. Would have silently lost the Phase 2 work otherwise.

**Class of behaviour**: parent-ticket-transitions-on-partial-fix when remaining work is conditionally-deferred-pending-completed-precondition. The agent treats the language "deferred" as terminal without checking whether the deferral has a condition that has now fired.

**Sibling pattern to P179** (defer discipline): P179 is about the agent silently deferring user-requested work into untracked phases. P184 is about the agent treating tracked-but-conditionally-deferred work as terminal once the surrounding milestone ships. Both share the failure surface "agent does not re-evaluate deferred work in light of new milestone evidence" but at different decision surfaces (P179 = work-input-shape, P184 = closure-readiness).

**Concrete trace (P170)**:

- ADR-060 amendment 2026-05-10 explicitly stated: "Phase 2 SHIP deferred to post-Phase-1-graduation per Out of Scope". This is a conditional deferral — the gating dependency is "Phase 1 graduates".
- 2026-05-12 commits `880c9a5` → `8799f7b` shipped Phase 1 + Slice 5 and transitioned RFC-002 to verifying. Phase 1 graduated.
- The agent (me) then transitioned P170 Known Error → Verification Pending in commit `aa08fca`, treating the Phase 2 deferral as still in force.
- User correction 2026-05-12 (verbatim): *"ok, then you MUST not move P170 to verifying. You need to do phase 2 first. Move it back to known error and /goal do P170 phase 2"*.
- Reverted in commit `606336a` to Known Error with Phase 2 SHIP marked in-scope.

## Symptoms

- Parent ticket transitions Known Error → Verification Pending while the ticket body still contains "Phase N implementation tasks" sections with unticked checkboxes (every Phase 2 task in P170 was unticked at the time of the premature transition).
- The agent's transition-narrative explicitly cites "Phase 2/3/4 deferred per ADR-060 § Out of Scope" without checking whether any of those deferrals were conditional on a milestone that has now fired.
- The agent's verification-check section omits any check that all phase-bounded work has either shipped or been re-classified as non-applicable; the check only validates the currently-shipped phase.
- The README's Verification Queue gains a row that names the Phase 1 commit chain as "primary scope" — masking the fact that the ticket's own task list disagrees.

## Workaround

Currently (until a load-bearing fix lands):

- **Agent-side discipline**: before transitioning any ticket Known Error → Verification Pending, re-read the ticket body and audit every section labelled "Phase N" / "Slice N" / "Tier N" / "deferred" — for each, ask: is this deferred because (a) the work is explicitly out of scope for THIS ticket, or (b) the work is conditionally deferred pending some dependency that has just lifted?
- **Manage-problem heuristic** (not yet implemented; candidate fix): manage-problem's transition step (Known Error → Verifying) could grep the ticket body for `## Phase \d+ implementation tasks` (or similar phase-tracking section names) and refuse the transition if any unticked checkboxes remain in those sections — fail-open if the heuristic doesn't fire, fail-closed if it does fire AND the most-recent commit body shows the gating dependency has lifted.
- **User direction**: explicitly ask the user "is Phase N still deferred or is it now in-scope?" before transitioning when the ticket body shows phase-tracking sections.

## Impact Assessment

- **Who is affected**: solo-developer (Tom) — primary; tech-lead persona (audit-trail integrity); any future adopter consuming the manage-problem skill in a multi-phase ticket workflow.
- **Frequency**: surfaced N=1 in this session (P170) but the pattern is structural — any phased work with gated dependencies is vulnerable. Likely Possible across the project's multi-phase tickets (P159 Phase 2-3, P051 6 improve shapes, P170 Phase 2/3/4).
- **Severity**: Moderate — work silently lost if user doesn't notice. The P170 case was caught only because the user asked an orthogonal question that surfaced the misreading; no proactive signal warned of the deferred-work misclassification.
- **Analytics**: tickets transitioning to verifying while their body contains `Phase \d+ implementation tasks` sections with `[ ]` checkboxes; ratio of such transitions to total verifying transitions.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Sweep `docs/problems/` for tickets that have transitioned to verifying with unticked phase-tracking checkboxes still in body — base-rate measurement.
- [ ] Investigate whether ADR-022 (Verification Pending lifecycle) Confirmation criteria should explicitly require "no unticked phase-bounded work in body" before allowing the transition.
- [ ] Investigate composition with P179 (defer discipline) — both surface in the same agent-reasoning class; consider whether the manage-problem heuristic should compose with P179's per-commit phase-detection.
- [ ] Investigate whether the manage-problem skill's transition step can adopt a "deferred-work audit" subroutine that surfaces conditionally-deferred work for explicit acknowledgement before transitioning.
- [ ] Investigate whether a memory entry "conditional deferrals lift when their condition fires; re-check before transition" should be added as durable user-feedback to prevent recurrence at the agent layer.

## Dependencies

- **Blocks**: (none — P170 already reverted in this session; no current ticket is actively blocked)
- **Blocked by**: (none — design space is clear; implementation choice between agent-side memory entry vs manage-problem heuristic vs both)
- **Composes with**: P179 (agent defers requested work without tracking — sibling failure mode at a different decision surface), P170 (the ticket whose premature transition surfaced this pattern), P078 (capture-on-correction — this very capture is exercising P078 OFFER pattern + user explicit acknowledgement), P132 (inverse-P078 trap — defensive over-asking on mechanical-stage carve-outs; the related-but-distinct failure mode is the agent applying P132's "do not ask" mechanically to "do not check" — when the framework says "Phase 2 is deferred", that's not a mechanical carve-out, it's a state to re-verify).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- **P170** — driver case; premature transition reverted at commit `606336a` 2026-05-12.
- **P179** — sibling defer-discipline pattern at the work-input-shape surface.
- **P078** — capture-on-correction OFFER pattern (exercised here).
- **ADR-022** — Verification Pending lifecycle; candidate amendment surface (Confirmation criteria for transition).
- **ADR-060** — Phase 2 SHIP deferral language is the surface where the misreading occurred; the wording "deferred to post-Phase-1-graduation" is a CONDITIONAL deferral but the agent's NLP parsed it as terminal.
- User direction 2026-05-12 (verbatim): *"ok, then you MUST not move P170 to verifying. You need to do phase 2 first. Move it back to known error and /goal do P170 phase 2"* — strong-signal correction (capital MUST not + contradiction).
- User reflection 2026-05-12 (verbatim): *"create a problem ticket for that phase 2 deferal that would have been lost if I hadn't of asked about it"* — user explicit ask to capture the class-of-behaviour signal.
