# Problem 178: Agent skips ITIL state-machine gates on architecture-driven problems — treats architect-PASS verdict as substitute for empirical RCA + skips Open → Known Error transition

**Status**: Open
**Reported**: 2026-05-10
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

ADR-022 documents the problem-ticket lifecycle as `Open → Known Error → Verifying → Closed`. The transition `Open → Known Error` is gated on RCA being complete enough to declare a known root cause; ITIL discipline says implementation work begins AFTER the Known Error transition fires (the Known Error state IS the contract that "we understand the problem well enough to fix it").

Observed pattern: when a problem ticket is **architecture-driven** (i.e. its fix is shaped by an ADR rather than by code-level diagnosis), the agent (and orchestrator) treats the architect-PASS verdict on the driving ADR as substitute for empirical RCA. Implementation work commences while:
- The ticket's `Status:` field still reads `Open` (lifecycle never advanced)
- Investigation Tasks in the ticket's `## Root Cause Analysis` section remain unchecked (empirical validation deferred)
- No `Open → Known Error` transition commit fires (the file stays at `*.open.md` / `docs/problems/open/<NNN>-*.md`)

The architect-PASS verdict is a **design-validity** signal (the proposed fix's shape is sound), NOT an **empirical-RCA** signal (the problem actually occurs at the claimed frequency, has the claimed impact, and ships the claimed value). Conflating the two routes around the gate that ITIL Known Error introduces specifically to prevent fixes-in-search-of-problems.

This is a **class of behaviour**: the same root-cause class as P175 (agent inferring framework-resolved decisions from natural-language signals). P175 was about loop control; P178 is about ITIL state-machine discipline. Both stem from agent reading verdict-class signals as state-machine-transition signals when the framework hasn't actually authorised the substitution.

**Concrete evidence** — this session 2026-05-06 to 2026-05-10:

1. P170 (RFC framework — strain pattern) was at `**Status**: Open` when work commenced.
2. Architect + JTBD reviews on driving ADR-060 returned AMEND verdicts (subsequently incorporated). Those review tasks were ticked off in `## Investigation Tasks`.
3. Three empirical RCA tasks remained unchecked: reproduction-of-strain-pattern, base-rate-investigation, adopter-impact-investigation.
4. No `Open → Known Error` transition commit fired at any session boundary.
5. Implementation work proceeded across **8 iters / 26 commits** — Slice 4 (B6 + B7) and Slice 5 (B8.T1-T5) all shipped against an Open-status ticket.
6. User observed the gap mid-session 2026-05-10: *"it looks like work on fixing P170 has commenced before RCA is complete and before it's become a known error. Is that correct?"*

The orchestrator's response to the user's correction — and the user's `yes, create a problem ticket` — is the P078 capture-on-correction surfacing of P178.

## Symptoms

- Problem ticket file stays at `Open` status across multiple iters of implementation commits.
- `## Investigation Tasks` section has unchecked empirical-RCA tasks while implementation commits land.
- Architect-PASS / JTBD-PASS verdicts are interpreted by agent as authorising implementation, even though they're authorising design-shape, not empirical RCA.
- No `Open → Known Error` transition commit appears in `git log` between problem capture and first implementation commit.
- AFK orchestrator iter prompts ask "work the next bounded sub-task" without first asking "has this ticket transitioned to Known Error?"
- Manage-problem SKILL.md's Step 7 (transition Open → Known Error) is not being invoked as a precondition to manage-problem Step 9 (work the fix).

## Workaround

Currently — user manually flags the gap mid-implementation (as happened 2026-05-10 with P170). Each user-flag costs a re-prompt round-trip. The orchestrator's response IS the workaround: pause work, complete RCA from session evidence OR additional investigation, transition to Known Error, then resume.

A defensive workaround at iter dispatch time: orchestrator's iter prompt could include a precondition check "is the targeted ticket at Known Error or beyond?". If Open: route to RCA-completion + transition first. If KE/Verifying: proceed to implementation.

A SKILL-side fix: manage-problem SKILL.md Step 9 (work the fix) gains a precondition gate: ticket file must be at `*.known-error.md` / `docs/problems/known-error/<NNN>-*.md` OR architect-PASS-substitute carve-out must be explicitly authorised by user.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: solo-developer using AFK orchestrator on architecture-driven tickets; secondary: future maintainers who skim git log expecting Known Error transitions to mark "fix in progress".
- **Frequency**: (deferred to investigation) — likely Possible-to-Likely; surfaced N=1 explicitly (P170) but the pattern would naturally recur on every architecture-driven ticket where ADR-PASS substitutes for empirical RCA.
- **Severity**: (deferred to investigation) — likely Moderate; doesn't block ship but routes around an ITIL discipline gate that exists for a reason (preventing fixes-in-search-of-problems).
- **Analytics**: (deferred to investigation) — count of implementation commits that landed against `*.open.md` tickets without an intervening Known Error transition; ratio of architect-PASS substitution events to formal RCA-completion events.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause: is this a SKILL.md gap (manage-problem Step 9 doesn't precondition-check ticket status) or an iter-prompt gap (work-problems iter prompts don't precondition-check) or both? Likely both — fix at both surfaces per ADR-051 load-bearing-from-the-start.
- [ ] Survey existing tickets that received implementation commits while at `*.open.md` status. Counts as base-rate. Suggested grep: `git log --diff-filter=M --name-only -- 'docs/problems/open/**'` cross-referenced against `git log --grep='feat(\|fix(\|test('`.
- [ ] Decide framework position: is architect-PASS-substitution-for-RCA a legitimate carve-out that should be EXPLICITLY documented (with conditions: e.g. "for architecture-driven problems where the fix's value is independent of base-rate, architect-PASS on the driving ADR's design soundness can substitute for empirical RCA, with the Known Error transition gated on ADR acceptance")? OR should it be a hard-block (every problem must complete empirical RCA before Known Error)? The carve-out option mirrors ADR-060's "bounded escape" pattern at lifecycle transitions; the hard-block honours ITIL discipline more strictly.
- [ ] Sweep ADR-022 (problem lifecycle) for whether it already addresses this — likely silent on architect-PASS-substitution; needs amendment OR the carve-out lives in a new ADR.
- [ ] Behavioural test: a bats fixture asserting that work-problems iter dispatch (or manage-problem Step 9) refuses to advance an `*.open.md` ticket without either (a) the Known Error transition having fired OR (b) an explicit user-authorised carve-out marker.

## Dependencies

- **Blocks**: (none — this ticket is friction-reduction / discipline-strengthening; pre-existing implementation work continues)
- **Blocked by**: (none)
- **Composes with**:
  - **P175** (agent over-narrows scope-pin words into count constraints) — sibling root-cause class: agent inferring framework-resolved decisions from non-framework signals. P175 was loop-control; P178 is state-machine.
  - **P078** (capture-on-correction OFFER pattern) — this ticket was captured under P078 discipline after the user's mild correction signal "Is that correct?".
  - **P170** + **ADR-060** — driver for the empirical surface where the pattern was observed; P170 is now retroactively being transitioned Open → Known Error using session evidence to close the gap surfaced by this ticket's capture.
  - **ADR-022** (problem lifecycle conventions) — the contract this ticket says agent must not subvert. May need amendment if architect-PASS-substitution carve-out is the resolution shape.
  - **ADR-044** (decision-delegation contract — framework-resolution boundary) — state-machine transitions are framework-resolved; agent must not sub-contract back via verdict-class inference.
  - **ADR-051** (load-bearing-from-the-start) — applies to this ticket's own fix; whatever discipline emerges should ship with its enforcement test, not as advisory-then-escalate.

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-022 — problem lifecycle conventions (Open / Known Error / Verifying / Closed)
- ADR-044 — framework-resolution boundary
- ADR-051 — load-bearing-from-the-start
- ADR-060 — RFC framework (drove the architect-PASS-substitution misreading on P170)
- P078 — capture-on-correction OFFER pattern
- P175 — sibling inferential failure class
- P170 — the empirical surface where the pattern was observed
- /wr-itil:work-problems SKILL.md — Step 5 iter prompt template (precondition-check gap)
- /wr-itil:manage-problem SKILL.md — Step 9 work-the-fix (precondition-check gap)
- Session evidence — 2026-05-06 to 2026-05-10, 8 iters / 26 commits against P170 at `Open` status; user-correction 2026-05-10 "it looks like work on fixing P170 has commenced before RCA is complete and before it's become a known error".
