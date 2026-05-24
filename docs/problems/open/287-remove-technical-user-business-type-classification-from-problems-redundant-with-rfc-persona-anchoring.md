# Problem 287: Remove the technical/user-business type classification from problems — redundant with RFC/Story persona-anchoring (amends ADR-060)

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 5 (Medium) — Impact: 2 (Minor — the `type: technical | user-business` tag adds a capture-time AskUserQuestion prompt + gate-enforced schema that the user has judged redundant; carrying redundant classification degrades the schema's clarity but does not break workflow) × Likelihood: 3 (Possible — the type prompt fires on every maintainer-side `/wr-itil:capture-problem`; the redundancy is exercised on every new problem)
**Effort**: M — ADR-060 amendment (in-place or supersede) + capture-problem type-prompt removal + bulk un-migration of `type:` fields + I2/Phase-4 reconciliation + behavioural-test update
**WSJF**: 5/2 = **2.5** (Open multiplier 1.0)
**Type**: technical

## Description

Surfaced during the P283 prong-2 ADR-oversight drain (`/wr-architect:review-decisions`, 2026-05-25). When ADR-060 (Problem→ADR→RFC→Story framework) was presented for human-oversight confirmation, the user **confirmed the four-tier framework but amended the problem-level type classification**:

> User direction 2026-05-25 (drain confirm): *"Correct, but no business/technical classification. If that's needed, then it should be a persona classification and that persona is either a customer, a staff user (eg a manager looking at reports) or a software delivery persona (they interact with the software for delivering the software)."*
>
> Clarification 2026-05-25: *"I think the classification is not needed because it's already on the RFC."*

**Decision**: drop the `type: technical | user-business` classification from problem tickets. The classification axis is **redundant at the problem tier** because persona/JTBD-anchoring already lives at the RFC and Story tiers (RFCs are JTBD-anchored; Stories are INVEST-shaped + JTBD-anchored per ADR-060). A problem is *what hurts*; the persona it hurts is captured when the problem is decomposed into an RFC/Story, not duplicated on the problem itself.

If a persona axis is ever wanted, it is **persona-based, not technical/user-business**: `customer` (end-user of the delivered software) | `staff-user` (internal user, e.g. a manager viewing reports) | `software-delivery` (interacts with the software to deliver software — devs/ops). But the primary direction is **remove, don't replace** — the RFC/Story tier already carries it.

ADR-060 is `accepted` and deeply implemented, so this amendment is its own unit of work (not a drain-batch quick edit). ADR-060 is **left unoversighted** until this rework lands and the amended decision is re-confirmed via the asking flow (per ADR-066 — a materially-amended decision clears/withholds the marker until re-confirmation).

## Symptoms

(deferred to investigation)

- `type:` tag woven through ADR-060: Problem-tier definition, the Type-tag schema section (`technical` default | `user-business`), invariant **I2** (uniform ontology — type is "a classification facet, not a workflow split"), **Phase 4** `persona:` + `jtbd:` frontmatter machinery + invariant **I12** (JTBD-as-source-of-truth), and the JTBD-201 (incident-default `type: technical`) / JTBD-301 (no plugin-user-side type selector) driver references.
- Live implementation surfaces carrying the tag: `/wr-itil:capture-problem` Step 1.5 type AskUserQuestion prompt; the one-shot bulk migration that set `type: technical` on existing tickets; the I2 behavioural test (asserts no control-flow branch on `type`); any `**Type**:` body-field on current tickets (this ticket included, per the live schema).

## Workaround

None needed — the redundant tag is inert (does not break workflow). It is a clarity/friction cost, not a defect.

## Root Cause Analysis

### Investigation Tasks

- [ ] Decide amendment shape for ADR-060: in-place amendment (the four-tier framework stands; only the type-tag sub-decision is removed) vs supersede. Likely in-place amendment with a dated "Amendment 2026-05-25 (type-tag removal)" note, recorded via the asking flow per ADR-066.
- [ ] Confirm what "it's already on the RFC" means precisely — verify the RFC/Story tier's JTBD-anchoring fully covers the persona signal the type-tag was approximating. Decide whether the optional persona enum (`customer`/`staff-user`/`software-delivery`) should be recorded anywhere or dropped entirely.
- [ ] Reconcile invariant I2: with the type-tag gone, I2's "type is a classification facet not a workflow split" clarifier needs rewording (the uniform-ontology invariant itself stands; its type-tag illustration goes).
- [ ] Reconcile Phase 4: the `persona:` + `jtbd:` frontmatter + I12 currently key off `type: user-business`. Decide how persona-anchoring of problems works without the type discriminator (e.g. presence of `jtbd:` array, or move persona-anchoring entirely to RFC/Story).
- [ ] capture-problem: remove the Step 1.5 type AskUserQuestion prompt (maintainer-side). Confirm plugin-user-side intake is unaffected (JTBD-301 already forbids a type selector there).
- [ ] Migration: strip `type:` body-fields from existing problem tickets (one-shot, reverse of the original bulk migration).
- [ ] Update the I2 behavioural test (drop the type-value-uniformity assertion; keep the no-type-branch assertion as a regression guard that nothing re-introduces a type branch).
- [ ] Re-confirm amended ADR-060 via `/wr-architect:review-decisions` (or create-adr amend flow) → write `human-oversight: confirmed`.

## Dependencies

- **Blocks**: ADR-060 human-oversight confirmation (held until this rework lands per ADR-066).
- **Blocked by**: none — investigation can begin immediately.
- **Composes with**: ADR-060 (the amendment target), ADR-066 (the oversight-marker contract that withheld ADR-060's marker), P170 (the RFC/Story framework implementation), the JTBD persona model (`docs/jtbd/` persona groupings).

## Related

(captured during the P283 prong-2 ADR-oversight drain, 2026-05-25)

- **ADR-060** (`docs/decisions/060-...accepted.md`) — amendment target; the four-tier framework is confirmed, the problem-level type-tag is removed.
- **ADR-066** (`docs/decisions/066-...proposed.md`) — the human-oversight marker; ADR-060 stays unoversighted until this rework re-confirms it.
- **P283** — the oversight-drain mechanism that surfaced this.
- **P248** — sibling WSJF-schema refinement (both touch problem-ticket frontmatter schema; coordinate migrations).
- `packages/itil/skills/capture-problem/` — the Step 1.5 type-prompt removal site.
- `docs/jtbd/` — persona groupings; the candidate home for any persona axis that survives.
