# Problem 314: Rework the fix-time RFC-trace gate — wrong lifecycle placement (ADR-072) + hard-block should be auto-create (ADR-073), per corrected Known Error semantics

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 8 (Medium) — Impact: 4 x Likelihood: 2 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: L (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

The `/wr-architect:review-decisions` drain of ADR-072 + ADR-073 (the F1/F4 extractions from RFC-005, created this session) surfaced **two user rejections** that together require reworking the fix-time RFC-trace gate design. Both ADRs were left **unoversighted** (no marker written); this ticket scopes the rework.

### Correction 1 — Known Error semantics (rejects ADR-072's gate placement)

User correction 2026-05-26 (verbatim): *"You've got the process wrong. A problem becomes a known error when we have a documented workaround and root cause. Once it's known error then we can propose a fix which would result in an RFC."*

Corrected lifecycle semantics:
- A problem reaches **Known Error** on **root cause identified + documented workaround** — NOT on "fix strategy known / work is real" (the wrong framing ADR-072 + RFC-005 F1 used).
- The **fix is proposed AFTER Known Error**, and proposing the fix is what **produces the RFC**.

Therefore the RFC-trace gate **must not** fire at the `Open → Known Error` transition (a problem reaches Known Error with no fix and no RFC yet). It must fire **when a fix is proposed / fix work commences on a Known Error**. ADR-072's chosen placement (`Open → Known Error`) is wrong; RFC-005 F1's three options were evaluated against a wrong model.

### Correction 2 — auto-create, not hard-block (rejects ADR-073), everywhere

User correction 2026-05-26 (verbatim): *"No, it's supposed to create the RFC if it's missing"* + scope answer *"Everywhere the gate fires"*.

ADR-073 chose **hard-block + skip-to-next** (orchestrator) on the ADR-044-cat-1 rationale that RFC scope is direction-setting and must stay with the user. The user reverses this: a missing RFC for a mandatory-RFC fix (ADR-071) should be **auto-created** (a problem-traced RFC — its scope IS the fix it traces, so auto-creating it is instantiating the mandatory vehicle, not inventing direction), **at every fix-time surface** — the AFK orchestrator dispatch AND the interactive `/wr-itil:manage-problem` + commit-hook gate. A missing RFC is never a block; the framework always creates it.

## Symptoms

- ADR-072 (`docs/decisions/072-...proposed.md`) records a gate placement (`Open → Known Error`) built on a wrong Known Error model.
- ADR-073 (`docs/decisions/073-...proposed.md`) records a hard-block stance the user reversed to auto-create-everywhere.
- ADR-060 invariant **I13** (added this session) encodes both errors: "trace-to-RFC at fix-time … before the `Open → Known Error` transition … hard-block … orchestrator hard-blocks per ADR-073."
- RFC-005 F1/F3/F4/F5 + B2–B10 task decomposition all assume the `Open → Known Error` placement + hard-block enforcement.

## Workaround

The I13 enforcement code (RFC-005 B2–B10) has not shipped yet — it rides the held-changeset window — so no live behaviour is wrong; only the recorded design is. Rework before that enforcement is built.

## Impact Assessment

- **Who is affected**: the (not-yet-built) fix-time gate; any future implementation of RFC-005 B2–B10 would build the wrong placement + wrong behaviour.
- **Frequency**: one-shot design rework (blocks correct I13 implementation).
- **Severity**: Moderate — recorded-design error in accepted-framework territory (ADR-060 I13); high drift cost if implemented as-is.

## Confirmed design (2026-05-26 — user-ratified via /wr-architect:review-decisions)

The substantive decisions are now human-confirmed (the P315 lesson applied — confirm substance before building):

- **Lifecycle (corrected)**: `Open → Known Error → Verifying → Closed`. "Fix Released" is NOT a separate state — releasing the fix IS the `Known Error → Verifying` transition (ADR-022). (User: *"there's no difference between fixed released and verifying"*.)
- **Known Error** = root cause identified + documented workaround. No fix, no RFC yet.
- **Gate placement (ADR-072 corrected)**: the RFC is created/required at the **propose-fix step on a Known Error** — a `/wr-itil:manage-problem` propose-fix action — NOT at `Open → Known Error` and NOT a new lifecycle state. The RFC is the fix-proposal artifact. (User confirmed Option A.)
- **Gate behaviour (ADR-073 corrected)**: when the propose-fix gate fires with no RFC, **auto-create a problem-traced RFC** (skeleton tracing the problem; scope = the fix; composes with ADR-070 no-decisions + ADR-071 every-fix-via-RFC) — NOT hard-block. **Everywhere the gate fires** (interactive `/wr-itil:manage-problem` AND the AFK `/wr-itil:work-problems` orchestrator). (User confirmed auto-create + "everywhere".)
- **ADR-044 note**: this overrides the ADR-073-original cat-1 rationale (RFC scope is direction-setting → user must author). User direction: auto-creating a problem-traced RFC is instantiating the mandatory vehicle (scope = the fix), not inventing direction.

## Resolution — design rework complete (2026-05-26)

The **design** rework is done (committed this session); the gate **implementation** remains RFC-005's B-tasks (held-changeset window).

- **ADR-072** rewritten + `git mv` to `072-rfc-required-at-fix-proposal-on-a-known-error` — placement = propose-fix step on a Known Error (conforms to ADR-022); born-confirmed (user-ratified substance).
- **ADR-073** rewritten + `git mv` to `073-fix-time-gate-auto-creates-missing-rfc` — auto-create a problem-traced skeleton RFC everywhere the gate fires; born-confirmed; includes the ADR-044 cat-1 reclassification (auto-creating the ADR-071-mandated vehicle is framework-mediated, not direction-setting; no `amends:`).
- **ADR-060 I13** rewritten (propose-fix placement + auto-create-everywhere), plus the frontmatter `amendment-driver` + the "Amendment 2026-05-26 (ADR-070/071)" blockquote corrected.
- **RFC-005** mechanism prose corrected throughout (Summary/Scope/B-tasks: propose-fix gate + auto-create, not Open→Known-Error hard-block).
- **RFC-006** (verifying): forward-pointer note added (its records are as-shipped; P314 + the rewritten ADRs are the current design).
- Architect PASS on the rework (pre-edit review of the user-ratified design); ADR-052 rejected-alternatives lint clean across the corpus.

**Remaining (not this ticket — RFC-005 scope):** build the propose-fix gate + auto-create mechanism (RFC-005 B2–B10), which rides the held-changeset window. This ticket's design-rework is complete.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] **Open design question — exact gate placement**: where does "a fix is proposed / fix work commences on a Known Error" sit in the `Open → Known Error → Verifying → Closed` lifecycle? Options to weigh: (a) a new `Known Error → In Progress (fixing)` transition the gate fires on; (b) the first fix commit referencing a Known Error problem; (c) a "fix proposed" marker/action in manage-problem. The original F1 "Known Error → Fix Released" was rejected as too-late under the WRONG model — re-evaluate under the corrected model (the RFC must exist before fix work, not at fix-release).
- [ ] **Auto-create design**: when the gate fires with no RFC, auto-create a problem-traced RFC (skeleton tracing the problem; scope = the fix). Confirm composition with ADR-070 (RFCs hold no decisions — a skeleton is fine) + ADR-071 (every fix via RFC) + whether the auto-created RFC needs any user touch.
- [ ] Rework artifacts: rewrite/supersede ADR-072 (placement) + ADR-073 (auto-create everywhere) — both are `proposed` + unoversighted + unimplemented, so in-place rewrite is likely cheaper than formal supersede; rewrite ADR-060 I13; adjust RFC-005 F1/F3/F4/F5 + B-tasks. Route through the architect + JTBD gates.

## Dependencies

- **Blocks**: correct implementation of RFC-005 B2–B10 (the I13 enforcement code).
- **Composes with**: ADR-070/071 (parent decisions — unchanged), ADR-060 I13 (rewrite target), RFC-005 (adjust), RFC-006 (the implementation RFC — this is its follow-on correction), ADR-044 (the cat-1 rationale ADR-073 leaned on, now overridden by user direction), P251/P310.

## Related

- **ADR-072 / ADR-073** — rejected at the 2026-05-26 `/wr-architect:review-decisions` drain; left unoversighted; superseded/rewritten by this rework.
- **RFC-006** — the ADR-070/071 implementation RFC; this is the corrective follow-on (the gate design it carried via ADR-072/073 + I13 was wrong).
- captured via /wr-architect:review-decisions Reject/supersede path, 2026-05-26.
