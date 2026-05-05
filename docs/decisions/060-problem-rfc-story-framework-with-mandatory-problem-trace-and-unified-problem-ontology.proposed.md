---
status: "proposed"
date: 2026-05-04
decision-makers: [Tom Howard]
consulted: []
informed: [Windy Road plugin users, adopter maintainers]
reassessment-date: 2026-08-04
---

# Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology

## Context and Problem Statement

P170 (driver) captures a structural problem with the existing `docs/problems/` framework: problem tickets strain as fixes decompose into multiple coordinated changes. The 1:1 problem-to-fix mapping that worked when changes were atomic has broken down at N≥4 surfaced examples in current session — P168 (3 commits + deferred Commit 3'), P159 (Phase 1 shipped + Phase 2-3 deferred), P051 (6 improve shapes), P169 (explicitly Phase 1 + Phase 2). The structural drift surfaced concretely with P169, captured 2026-05-04, which was largely a workstream description rather than a problem statement (user observation: *"P169 is not really a problem ticket. It's more of a task masquerading in the problem ticket structure."*).

When fixes decompose like this, the problem-ticket structure carries load it wasn't designed for: it accumulates "Fix Strategy" sections that mutate as work progresses; "Investigation Tasks" turn into multi-phase work plans; the ticket body becomes a moving target rather than a stable problem-statement-plus-RCA. Lifecycle states (`Open` / `Known Error` / `Verifying` / `Closed`) lack natural placeholders for "Phase 1 closed, Phase 2 in flight". Sibling-ticket-trees workaround (P168 → P169) loses parent-child trace. WSJF prioritisation can't see sub-work-items as first-class entities competing for attention.

The classic ITIL answer is **Request for Change (RFC)** — a controlled, scoped, time-boxed change ticket that owns the work to fix a problem. Multiple RFCs can trace to one problem when the fix is large enough to need decomposition. **Jeff Patton's User Story Mapping** (O'Reilly, 2014) is the candidate vehicle for breaking an RFC into stories: backbone (the spine of the user journey) + ribs (the sub-flows) + slices (time-ordered MVP / version-2 / version-N).

User direction 2026-05-04 names two non-ITIL extensions that this ADR codifies:

1. **All RFCs MUST trace to a problem** (no orphan RFCs). ITIL allows RFCs from non-problem sources (continuous improvement, opportunity, regulatory mandate); this project treats every change as solving some problem — even a feature build is a customer's problem.
2. **Technical problems and user/business problems are treated identically.** ITIL's Service Strategy / Service Request Management splits "Service Request" from "Problem"; this project collapses them. A bug, a missing feature, a UX gap, an adopter pain point, a future JTBD job — all are problems.

User direction also names a future direction: **unify JTBD job statements with the problem framework** so a JTBD-NNN job description IS a problem ticket of class "user/business" — same WSJF, same RFC decomposition, same lifecycle. This ADR records the direction; implementation phases beyond Phase 1 stay out of scope.

## Decision Drivers

- **P170** — driver ticket. Captures the structural strain with N=4 concrete examples and the user direction defining the non-ITIL extensions.
- **JTBD-101 (Plugin Developer)** — primary fit. Adopters consume the Windy Road problem-management framework as a model; the framework must scale with project complexity to preserve the value proposition.
- **JTBD-001 (Enforce Governance Without Slowing Down)** — RFC framework IS governance scaffolding for multi-commit coordinated changes. The trace-to-problem invariant makes WSJF prioritisation work uniformly.
- **JTBD-008 (Evolve the Framework)** — meta-driver. The framework itself accumulates problems (P170 is one); evolution must compose with the problem-management primitives that drive the rest of the project.
- **ADR-014 (Governance skills commit their own work)** — RFCs decompose into ADR-014-grain commits. RFC owns the scope; commits ride the existing single-purpose grain.
- **ADR-022 (Problem lifecycle conventions)** — RFC lifecycle mirrors problem lifecycle states for symmetry, with RFC-specific naming to distinguish.
- **ADR-032 (Governance-skill aside-invocation pattern)** — `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc` follow the same lightweight + heavyweight skill split that capture-problem + manage-problem already established.
- **ADR-038 (Progressive disclosure)** — RFC SKILL files ship SKILL.md (runtime) + REFERENCE.md (deep context).
- **ADR-042 (Held-changeset auto-apply)** — RFCs are exactly the surface that should ride held-changeset dogfood windows; the framework integrates with held-area graduation criteria (P162).
- **ADR-044 (Decision delegation contract)** — RFC creation is a direction-setting authority; capture-rfc must use AskUserQuestion for genuine design choices and silent-proceed for mechanical stages (per inverse-P078 / P132).
- **ADR-051 (Load-bearing-from-the-start for drift class)** — the trace-to-problem invariant is a drift class; gate enforcement should be load-bearing at capture-rfc time, not advisory-then-escalate.
- **ADR-052 (Behavioural-tests default)** — capture-rfc + manage-rfc skills land with behavioural bats coverage.
- **ADR-053 (Plugin maturity taxonomy)** — RFC framework ships with maturity tag; initial maturity matches this ADR's `proposed` status.
- **ADR-059 (Pipeline consume-catalog and bootstrap-from-reports)** — the most recent ADR to ship under the strain pattern (3-commit decomposition, Commit 3' deferred); first candidate for retroactive migration to RFC shape during Phase 1 dogfood.
- **User direction recorded 2026-05-04** verbatim: *"Capture the actual problem as P170. The ADR captures how we decide to solve it (and considered alternatives). All RFCs MUST be tied to a problem. We go beyond ITIL in this way. We consider technical problems and inherent user/business problems in the same way. In fact, even JTBD describes problems that we somehow (in the future) need to unify with the problem management framework."*
- **Jeff Patton, *User Story Mapping*** (O'Reilly, 2014) — backbone/ribs/slices canonical reference for story decomposition.

## Considered Options

### Option A — Continue with multi-phase Fix Strategy embedded in problem ticket bodies (the status quo)

**Rejected.** Doesn't compose with WSJF prioritisation at sub-work granularity (sub-work items hide inside parent ticket and don't compete for `/wr-itil:work-problems` selection). Already strained at N=4 examples and ramping with project complexity. Forces sibling-ticket-trees as workaround (P168 → P169) which loses parent-child trace and accumulates ticket sprawl. Problem ticket bodies become moving targets rather than stable problem-statement-plus-RCA artefacts.

### Option B — Sub-directory split per phase (e.g. `docs/problems/<NNN>/phases/<phase-N>.md`)

**Rejected.** Filename conventions become complex (`168/phases/2-bootstrap.in-progress.md`?). Doesn't generalize to user/business problems (a JTBD-class problem isn't naturally "phase-decomposed"). Loses ID-based linking (`P168` becomes ambiguous — is it the parent problem or a specific phase?). Solves the multi-phase strain but doesn't address the broader RFC pattern (scoping, story mapping, JTBD trace, etc.).

### Option C — Type-field-only on problem frontmatter (`type: technical` / `type: user-business`)

**Rejected.** Insufficient — type-tag distinguishes classification but doesn't decompose work. Doesn't address the multi-phase strain at all. Worth incorporating as a sub-decision within the chosen RFC framework (Phase 3 work), but not sufficient on its own.

### Option D — Lift ITIL Change Advisory Board (CAB) framework whole

**Rejected.** Too heavy for solo / small-team workflow (CAB roles, weekly meetings, formal approval ceremony). ITIL allows non-problem RFCs (continuous improvement, regulatory mandate, opportunity-driven) — directly violates user-stated **invariant 1**. ITIL splits Service Request from Problem in Service Request Management practice — directly violates user-stated **invariant 2**. Audit / approval ceremony doesn't match the AFK-loop autonomous-work model the project depends on.

### Option E — Story-mapping without an RFC layer (stories directly under problem)

**Rejected.** Loses the scope-boundary that RFC provides. Stories become the only multi-commit decomposition surface; can't capture coordination above story level (multiple stories that ship together as one feature, multiple stories that ride a shared dogfood window, etc.). Patton's model explicitly places stories below a scope artefact (the backbone-and-ribs structure presupposes a defined product / feature scope which the RFC provides). Loses the "this is a coordinated change with explicit scope and acceptance" semantics that ITIL RFCs encode.

### Option F — RFC framework with Problem→ADR→RFC→Story hierarchy and the two non-ITIL invariants (CHOSEN)

**Selected.** Captures the multi-phase decomposition strain. Composes with WSJF (RFC-level + story-level ranking; phasing decision deferred to Phase 1 architect review). Composes with held-changeset dogfood (RFCs ride held windows; ADR-042 graduation criteria apply at RFC level). Preserves the trace-to-problem invariant (gate-enforced at capture-rfc time). Treats technical and user/business problems uniformly. Future-proofs the JTBD unification direction (JTBD-jobs become a problem class; existing problem-management skills compose without rebuild).

## Decision Outcome

Introduce a four-tier hierarchy:

1. **Problem** (existing) — *what hurts*. Lifecycle: `Open` / `Known Error` / `Verifying` / `Closed` / `Parked`. Per existing `docs/problems/` shape. **New**: type-tag added to frontmatter (`type: technical` | `type: user-business`); both treated identically by WSJF, capture skill, and lifecycle (invariant 2).
2. **ADR** (existing) — *how we decided to solve it*. Status: `proposed` / `accepted` / `superseded`. Per existing `docs/decisions/` shape. May reference ≥ 0 problems; may underpin ≥ 0 RFCs (decisions can predate or be independent of execution).
3. **RFC** (new) — *what we're shipping to solve it*. Status: `proposed` / `accepted` / `in-progress` / `verifying` / `closed`. New `docs/rfcs/` directory. **Invariant 1**: MUST trace to ≥ 1 problem (gate-enforced at capture-rfc + manage-rfc). May reference ≥ 1 ADRs (ADRs ride alongside RFCs as decisions made during execution).
4. **Story** (new) — INVEST-shaped work item inside an RFC. Story-mapping directory layout TBD at Phase 1 architect review (candidates: `docs/rfcs/<RFC-NNN>/stories/`, embedded section in RFC body, or separate `docs/stories/` with bidirectional trace). Each story JTBD-anchored where applicable.

**Mandatory invariants** (load-bearing, gate-enforced):

- **I1 (trace-to-problem)**: every RFC traces to ≥ 1 problem; orphan RFCs are prohibited. Gate-enforced at `capture-rfc` time (hard-block) and at `manage-rfc` lifecycle transitions (advisory-with-escalation per ADR-051's load-bearing-from-the-start clause). Reverse trace is auto-maintained on each problem ticket (RFC list section refreshed per P094 / P062 contract pattern).
- **I2 (uniform problem ontology)**: technical and user/business problems use the same WSJF formula, the same capture skill, the same lifecycle transitions, the same RFC decomposition path. Type-tag is a classification facet, not a workflow split.

**Future direction** (recorded; implementation deferred):

- **JTBD unification (Phase 4)**: JTBD job statements in `docs/jtbd/` describe user/business problems and are kin to problem tickets of class `user-business`. Phase 4 work unifies the directories so a JTBD-NNN job description becomes a first-class problem ticket. Existing problem-management skills (capture, manage, transition, work, review) compose without rebuild because invariant I2 already requires uniform handling.

## Scope (Phase 1 — this ADR's bounded first shipment)

Phase 1 lands the minimum viable RFC framework so it can dogfood on this very ADR's implementation:

1. **`docs/rfcs/` directory** with `README.md` (lifecycle index analogous to `docs/problems/README.md`).
2. **`/wr-itil:capture-rfc` skill** — lightweight aside-invocation per ADR-032; mandatory `--problem P<NNN>` flag (gate-enforced at I1).
3. **`/wr-itil:manage-rfc` skill** — heavyweight intake + lifecycle management; AskUserQuestion for design choices; mechanical stages for status transitions (per P132 / inverse-P078).
4. **RFC frontmatter shape** — at minimum: `status`, `problems: [P<NNN>, ...]`, `adrs: [ADR-NNN, ...]`, `reported`, `decision-makers`. Story shape TBD.
5. **`packages/itil/scripts/reconcile-rfcs.sh`** — diagnose-only mechanical drift detector for `docs/rfcs/README.md` (mirrors `reconcile-readme.sh`).
6. **`packages/itil/bin/wr-itil-reconcile-rfcs`** — `$PATH` shim per ADR-049.
7. **Behavioural bats coverage** for capture-rfc, manage-rfc, reconcile-rfcs per ADR-052.
8. **Type-tag introduction on problem frontmatter** — schema migration (existing tickets default to `type: technical`; capture-problem AskUserQuestion gains the type prompt for I2).
9. **First retrospective RFC migration** — convert P168 retroactively to `RFC-001-pipeline-consume-catalog-and-bootstrap` traced to P168, referencing ADR-059. This is the dogfood pass that validates the framework on a known multi-commit decomposition.
10. **`docs/problems/<NNN>-...md` body section addition** — auto-maintained `## RFCs` section listing traced RFCs (refresh contract analogous to P094 README refresh).
11. **`docs/changesets-holding/`** — Phase 1 ships under a held window per ADR-042 / P162 graduation criteria; dogfood evidence accumulates before adopter release.

Phase 1 is itself a multi-commit coordinated change of exactly the shape this ADR addresses. The bootstrap meta-recursion is acknowledged: Phase 1 ships under the existing problem-management framework (last "without-RFC" change), and at the same time produces the first RFC dogfood instance.

## Out of Scope

- **Story mapping (Phase 2)**: backbone/ribs/slices template, INVEST checks, story-to-RFC trace, story status lifecycle, WSJF placement (RFC-level vs story-level ranking decision). Deferred until Phase 1 dogfood evidence informs the design.
- **Type-as-workflow-split (rejected)**: type-tag is classification only, never a workflow split. Phase 3 work clarifies UX surfaces (capture flow may differ slightly for user/business problems, e.g. JTBD trace prompt) but lifecycle and WSJF stay identical per I2.
- **JTBD unification (Phase 4)**: deferred. Recorded as future direction. Implementation depth requires migration scripts and possible deprecation of `docs/jtbd/` directory; not viable until story-mapping (Phase 2) lands and informs the JTBD-as-problem composition shape.
- **Retroactive migration of P168 / P159 / P051 / P169** beyond the Phase 1 dogfood pass: P159 / P051 / P169 stay under the existing framework as grandfathered tickets unless cost-of-migration is reassessed at the Phase 1 / Phase 2 / Phase 3 boundary.
- **ITIL CAB ceremony**: rejected per Option D. Approval / audit ceremony does not enter the framework.
- **Non-problem RFCs**: rejected per I1. RFCs without a problem trace are prohibited; if the change can't name a problem, the work creates a problem ticket first (continuous-improvement RFCs, opportunity RFCs, regulatory RFCs all become problem tickets first under I2's uniform ontology — including upstream-regulatory mandates).

## Confirmation

This ADR's contract holds when:

1. `/wr-itil:capture-rfc` invoked without `--problem` flag halts with directive (gate-enforced I1).
2. `/wr-itil:manage-rfc` lifecycle transitions emit advisory-with-escalation when problem trace is missing or stale (load-bearing I1 enforcement).
3. `docs/problems/<NNN>-...md` `## RFCs` section auto-maintains the reverse trace; `reconcile-readme.sh` extends to detect drift.
4. `capture-problem` AskUserQuestion includes the type-tag prompt (I2 surface); both `technical` and `user-business` ride the same WSJF, lifecycle, skill set.
5. P168 retrospectively migrated to `RFC-001` traces correctly; ADR-059 references propagate as the underpinning ADR; the migration produces no semantic loss.
6. Phase 1 ships under held-changeset dogfood per ADR-042 / P162; graduation criteria evaluated via counterfactual risk assessment (delay-risk vs release-risk).
7. Behavioural bats per ADR-052 cover capture-rfc, manage-rfc, reconcile-rfcs surfaces; no structural grep on SKILL.md / ADR content (P081).

## Reassessment Criteria

Re-evaluate this decision when any of:

- **Adopter trace failure**: an adopter reports the framework as unusable / heavyweight / mismatched-to-their-workflow at capture-rfc time. Suggests the RFC layer adds friction the framework's own metric (problem-management cost) doesn't justify.
- **WSJF granularity friction**: RFC-level WSJF or story-level WSJF systematically miscalibrates compared to what `/wr-itil:work-problems` Step 3 actually selects. Suggests the WSJF placement decision (deferred to Phase 1 architect review) needs revisiting.
- **JTBD unification readiness**: Phase 2 story mapping ships and reveals a clear path to unify JTBD jobs with problems (e.g., JTBD descriptions naturally decompose into stories under the RFC framework without semantic translation). Triggers Phase 4 work.
- **Trace-to-problem violation rate**: capture-rfc gate fires denials at a rate exceeding 20% of attempts. Suggests either the invariant is wrong (some legitimate RFCs don't have problems), or the capture-rfc UX over-prompts. Investigate root cause; consider amending I1 to allow problem-creation-from-rfc (user creates RFC, framework offers to create a placeholder problem ticket).
- **Type-tag drift**: `technical` vs `user-business` classifications drift over time (tickets get retroactively reclassified, tag is ambiguous, contributors disagree). Suggests the type-tag is the wrong primitive; consider per-ticket faceted tagging or removing the tag.
- **Story shape collapse**: Phase 2 architect review concludes story-level decomposition is unnecessary or that backbone/ribs/slices doesn't fit the project. Triggers Phase 2 redesign.
- **Held-window cost**: RFC-shaped held-changeset dogfood windows accumulate beyond P162's counterfactual-risk graduation criteria. Suggests RFC scopes are too large; consider sub-RFC decomposition.

## Related

- **P170** (driver) — `docs/problems/170-problem-tickets-strain-as-fixes-decompose-into-multiple-coordinated-changes-need-rfc-framework.open.md`.
- **P168 / P159 / P051 / P169** — concrete examples of the strain pattern this ADR addresses.
- **P162** — held-changeset graduation criteria (RFCs compose with).
- **JTBD-001 / JTBD-008 / JTBD-101** — primary persona-jobs served.
- **ADR-014** — commit grain (RFCs decompose into ADR-014-grain commits).
- **ADR-022** — problem lifecycle conventions (RFC lifecycle mirrors).
- **ADR-032** — aside-invocation pattern (capture-rfc + manage-rfc follow).
- **ADR-038** — progressive disclosure (RFC skills ship SKILL + REFERENCE).
- **ADR-042** — auto-apply / held-changeset graduation (RFCs ride held windows).
- **ADR-044** — decision delegation (capture-rfc AskUserQuestion shape).
- **ADR-049** — `$PATH` bin shims (`wr-itil-reconcile-rfcs`).
- **ADR-051** — load-bearing-from-the-start (I1 gate enforcement).
- **ADR-052** — behavioural-tests default.
- **ADR-053** — plugin maturity taxonomy.
- **ADR-059** — most recent ADR shipped under the strain pattern; first retrospective RFC candidate.
- Jeff Patton, *User Story Mapping*, O'Reilly Media, 2014 — backbone/ribs/slices canonical reference.
- ITIL 4 Foundation — Change Enablement, Service Request Management, Problem Management practices (informs but does not constrain; we extend per user direction).
