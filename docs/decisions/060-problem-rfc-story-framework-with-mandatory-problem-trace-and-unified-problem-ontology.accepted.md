---
status: "accepted"
date: 2026-05-04
accepted-date: 2026-05-05
decision-makers: [Tom Howard]
consulted: [wr-architect:agent (initial review + re-review 2026-05-05), wr-jtbd:agent (initial review + re-review 2026-05-05)]
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
- **JTBD-001 (Enforce Governance Without Slowing Down)** — RFC framework **extends** JTBD-001's scope from per-edit governance to multi-commit coordinated-change governance. The trace-to-problem invariant makes WSJF prioritisation work uniformly. (JTBD-001 § Desired Outcomes amended alongside this ADR landing to add the multi-commit-coordination outcome per JTBD-review finding 2.)
- **JTBD-101 (Extend the Suite with New Plugins)** — primary fit for complex adopters whose projects exhibit the multi-commit decomposition pattern. **For atomic-fix-shaped adopters, RFC ceremony introduces friction without proportional value; the type-tag prompt at capture-problem time is the load-bearing surface where this friction materialises.** Phase 1 dogfood evidence and the >20% trace-violation-rate reassessment criterion gate whether the framework graduates from held-area to adopters as-is or with adopter-side opt-out. (JTBD-101 § Persona Constraints amended alongside this ADR landing per JTBD-review finding 3.)
- **JTBD-006 (Progress the Backlog While I'm Away)** — AFK orchestrator selects by WSJF. Phase 1's resolution of WSJF placement = RFC-level (per "Decisions resolved" below) protects the AFK orchestrator's selection from `docs/problems/` during the bootstrap window. Phase 1 confirmation includes *"work-problems iter still selects from `docs/problems/` correctly when RFC layer exists"*.
- **JTBD-201 (Restore Service Fast with an Audit Trail)** — incident → problem handoff. Incident-driven problems default to `type: technical` (no type prompt during incident handoff per JTBD-201 § Outcomes preservation); RFC trace-to-problem invariant composes naturally with incident-driven problems.
- **JTBD-301 (Report a Problem Without Pre-Classifying It)** — plugin-user persona's no-pre-classification constraint. Type-tag prompt fires on maintainer-side `/wr-itil:capture-problem` only; plugin-user-side intake (GitHub issue templates) MUST NOT add a type-tag selector. Maintainer triage assigns type during `/wr-itil:manage-problem` intake, not at user-report time.
- **ADR-010 (amended skill-granularity)** — `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc` are two skills, not one. Skill-granularity decision is directly load-bearing on whether this is two skills or one with subcommands; per `feedback_skill_subcommand_discoverability.md` user memory, separate skills wins.
- **ADR-013 (governance interaction)** — skill manifest / governance-skill discoverability is load-bearing on how capture-rfc / manage-rfc surface in adopter installs.
- **ADR-014 (Governance skills commit their own work)** — RFCs decompose into ADR-014-grain commits. RFC owns the scope; commits ride the existing single-purpose grain. See "Commit-grain composition" subsection in Decision Outcome below for the full RFC ↔ commit mapping rule.
- **ADR-019 (next-ID compute)** — directly load-bearing on RFC ID allocation in capture-rfc. The RFC numbering scheme (`RFC-<NNN>`) + `reconcile-rfcs.sh` must compose with the existing ID-compute convention used by capture-problem and create-adr.
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
3. **RFC** (new) — *what we're shipping to solve it*. Status: `proposed` / `accepted` / `in-progress` / `verifying` / `closed`. New `docs/rfcs/` directory with naming grammar **`RFC-<NNN>`** (matches `ADR-<NNN>` form; no collision with `docs/risks/R<NNN>` or problem `<NNN>` IDs). **Invariant 1**: MUST trace to ≥ 1 problem (gate-enforced at capture-rfc + manage-rfc — see "I1 enforcement" below). May reference ≥ 1 ADRs (ADRs ride alongside RFCs as decisions made during execution). **An RFC's internal decomposition (story breakdown, phase ordering, task sequencing) does NOT create ADRs by default; ADRs created during RFC execution capture decisions with scope outside the RFC's own boundary.** This protects against ADR-sprawl when story-mapping (Phase 2) lands.
4. **Story** (new, **Phase 2**) — INVEST-shaped + JTBD-anchored work item inside an RFC. Phase 1 explicitly does NOT introduce stories; it introduces RFC-internal **tasks** (or **steps**) — ordered work-items inside an RFC body, no INVEST/JTBD requirements. The "task"/"step" terminology is reserved for Phase 1; "story" is reserved for Phase 2 work that ships INVEST-shape + JTBD-trace gates. This split prevents Phase-2-bleed during Phase 1 dogfood when implementer hits P168's commit-decomposition mid-flight.

**Type-tag schema (Phase 1 introduction)**:

- Field name: `type`
- Values: `technical` (default) | `user-business`
- Frontmatter location: header field block in body (`**Type**: <value>`), placed after the `**WSJF**:` line, matching the existing `**Status**` / `**Reported**` / `**Priority**` / `**Effort**` / `**WSJF**` body-bullet convention. (RFC tickets use YAML frontmatter; problem tickets use body-field bullets — the inconsistency is grandfathered, not addressed by this ADR. Spec text corrected 2026-05-06 in iter 2 of P170 Slice 4 — the original "YAML frontmatter, after existing fields" wording was inaccurate to the actual `docs/problems/*.md` schema.)
- Migration: existing tickets bulk-migrate to `type: technical` (one-shot, no per-ticket judgement). Capture-problem `AskUserQuestion` adds a type prompt for new problems (maintainer-side only — JTBD-301 protection: NEVER on plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml`).
- I2 enforcement: see "Mandatory invariants" below.

**Mandatory invariants** (load-bearing, gate-enforced):

- **I1 (trace-to-problem)**: every RFC traces to ≥ 1 problem; orphan RFCs are prohibited. **Hard-block at `capture-rfc`** (no `--problem` flag = capture refuses; no escape). **Bounded escape at `manage-rfc` lifecycle transitions** (per ADR-051 load-bearing-from-the-start, with the bounded-escape carve-out): hard-block on transitions to irreversible states (`accepted → in-progress`, ` → verifying`); advisory-with-escalation only at `→ closed` (allows closure of an RFC whose driving problem reaches `Closed` or `Parked` without a still-open problem trace, but the closure must record the trace history). Reverse trace auto-maintained on each problem ticket (RFC list section refreshed per P094 / P062 contract pattern).
- **I2 (uniform problem ontology)**: technical and user/business problems use the same WSJF formula, the same capture skill, the same lifecycle transitions, the same RFC decomposition path. Type-tag is a classification facet, not a workflow split. **Enforcement is load-bearing**: a behavioural test (per ADR-052) asserts capture-problem / manage-problem / work-problems / review-problems exhibit identical control-flow shape regardless of `type` value — no skill carries a branch keyed on `type`. **Clarifier** (per JTBD-review nitpick 6): I2 makes mechanism uniform (same skills, same WSJF, same lifecycle). It does NOT homogenise problem-attached metadata — user/business problems may carry persona-anchoring metadata (JTBD trace, persona-impact field) that technical problems do not. The asymmetry, if any, lives in optional schema fields, not in workflow.

**Decisions resolved in this ADR** (per architect-review finding 3 — three of P170's four "deferred to Phase 1 architect review" decisions resolve in-ADR; the fourth legitimately stays deferred):

- **RFC filename grammar**: `RFC-<NNN>` — three-digit zero-padded ID matching `ADR-<NNN>` form. Avoids collision with `R<NNN>` (risks register), bare `<NNN>` (problem IDs).
- **WSJF placement**: **RFC-level for Phase 1**. Story-level WSJF is structurally impossible without story-mapping infrastructure (Phase 2). RFC-level WSJF composes with `/wr-itil:work-problems` Step 3 selection by adding RFC entries alongside problem entries in the WSJF Rankings table; tie-break ladder extends Status to include RFC statuses (open/known-error/RFC-equivalents).
- **AskUserQuestion authority classes for capture-rfc / manage-rfc** (per ADR-044 taxonomy + inverse-P078 / P132): capture-rfc uses **direction-setting** (problem trace name) + **taste** (title / scope summary text) + **silent-mechanical** (ID allocation, file write, frontmatter). Manage-rfc uses **direction-setting** (lifecycle-transition triggers when ambiguous) + **deviation-approval** (scope expansion mid-RFC) + **silent-mechanical** (status renames, README refresh). No `AskUserQuestion` fires for mechanical stages.
- **Story-mapping directory layout** — legitimately deferred to Phase 2. Depends on story-mapping infrastructure that Phase 1 does not ship.

**Commit-grain composition** (per architect-review finding 8, composes with ADR-014):

- **Mapping**: one RFC = N × ADR-014-grain commits, ordered. Phase 1 dogfood (RFC-001 retro on P168) is itself a 3-commit chain; Phase 1's own implementation is a multi-commit chain.
- **One commit advances at most one RFC**. If a single commit attempts to advance two RFCs, the commit is mis-scoped; split. (Coordination decisions across multiple RFCs go in a separate commit on a meta-RFC OR in an ADR if the scope is outside any single RFC.)
- **Commit-message RFC trailer**: commits that advance an RFC carry a `Refs: RFC-<NNN>` trailer (exact form decided in Phase 1 architect call alongside the hook recognition step — see Phase 1 item 12). Reverse-trace `## RFCs` section on problem tickets is driven off the trailer parsing.

**Future direction** (recorded; implementation deferred):

- **JTBD unification (Phase 4)**: JTBD job statements in `docs/jtbd/` describe user/business problems and are kin to problem tickets of class `user-business`. Phase 4 work unifies the directories so a JTBD-NNN job description becomes a first-class problem ticket. Existing problem-management skills (capture, manage, transition, work, review) compose without rebuild because invariant I2 already requires uniform handling. **Phase 4 risk** (per JTBD-review nitpick 7): JTBD job statements are persona-anchored by construction; problem tickets are not always persona-anchored. Unification must preserve persona-anchoring as a first-class facet of user-business problems, not collapse it into the body. Phase 4 design must answer: does every user-business problem ticket carry a `persona:` frontmatter field, or is persona-anchoring optional?

## Scope (Phase 1 — this ADR's bounded first shipment)

Phase 1 lands the minimum viable RFC framework so it can dogfood on this very ADR's implementation. **Framework deliverables**:

1. **`docs/rfcs/` directory** with `README.md` (lifecycle index analogous to `docs/problems/README.md`).
2. **`/wr-itil:capture-rfc` skill** — lightweight aside-invocation per ADR-032; mandatory `--problem P<NNN>` flag (hard-block I1 enforcement; deny emits structured log entry to `logs/rfc-capture-denials.jsonl` for the trace-violation-rate reassessment criterion below).
3. **`/wr-itil:manage-rfc` skill** — heavyweight intake + lifecycle management; AskUserQuestion authority classes per ADR-044 (named in "Decisions resolved" above); mechanical stages for status transitions (per P132 / inverse-P078).
4. **RFC frontmatter shape** — at minimum: `status`, `problems: [P<NNN>, ...]`, `adrs: [ADR-NNN, ...]`, `jtbd: [JTBD-NNN, ...]` (optional Phase 1; required Phase 2+ when driving problem is `type: user-business`), `reported`, `decision-makers`.
5. **`packages/itil/scripts/reconcile-rfcs.sh`** — diagnose-only mechanical drift detector for `docs/rfcs/README.md` (mirrors `reconcile-readme.sh`).
6. **`packages/itil/bin/wr-itil-reconcile-rfcs`** — `$PATH` shim per ADR-049.
7. **Behavioural bats coverage** for capture-rfc, manage-rfc, reconcile-rfcs per ADR-052 (no structural grep on SKILL.md / agent.md content per P081).
8. **Type-tag introduction on problem frontmatter** — split into 4 sub-items per architect-review finding 10 to ensure load-bearing I2 ships at the same time as the tag (not later by graceful drift):
   - **8a**: type-tag schema added to frontmatter spec (no migration; `type: technical | user-business`; default `technical`).
   - **8b**: existing tickets bulk one-shot migrate to default `type: technical` (script-driven; no per-ticket judgement).
   - **8c**: `/wr-itil:capture-problem` `AskUserQuestion` adds type prompt — **maintainer-side only**. JTBD-301 protection: NEVER on plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` or upstream-classifier paths.
   - **8d**: I2 behavioural test ships at the same time as the tag — asserts capture-problem / manage-problem / work-problems / review-problems exhibit identical control-flow shape regardless of `type` value. Without 8d, the type-tag ships I2 in name only.
10. **`docs/problems/<NNN>-...md` body section addition** — auto-maintained `## RFCs` section listing traced RFCs (refresh contract analogous to P094 README refresh).
11. **`docs/changesets-holding/`** — Phase 1 ships under a held window per ADR-042 / P162 graduation criteria; dogfood evidence accumulates before adopter release. **Atomicity** (per architect-review finding 12): RFC-shaped held changesets graduate **atomically** — the entire RFC-001 commit chain either ships or doesn't. ADR-042 auto-apply is paused until RFC-001 reaches `closed` status.
12. **Commit-message RFC trailer convention + hook recognition** (per architect-review finding 9): commits that advance an RFC carry a `Refs: RFC-<NNN>` trailer; a hook (per ADR-038 progressive disclosure surface) recognises the trailer and feeds the reverse-trace refresh on the driving problem ticket. Closes the mechanism gap on Confirmation criterion 3.

**Phase 1 dogfood pass** (per architect-review finding 11 — separated from framework deliverables; held-changeset graduation criteria apply to deliverables, not to dogfood evidence):

9. **First retrospective RFC migration** — convert P168 retroactively to `RFC-001-pipeline-consume-catalog-and-bootstrap` traced to P168, referencing ADR-059. This is the dogfood pass that validates the framework on a known multi-commit decomposition. Per architect-review finding 14, retroactive migration demonstrates **representability**, not framework correctness; **forward-dogfood** (a NEW RFC captured before its first commit and run to closure) is a separate gate before Phase 1 graduates from held-changeset to adopters — see Reassessment Criteria below.

Phase 1 is itself a multi-commit coordinated change of exactly the shape this ADR addresses. The bootstrap meta-recursion is acknowledged: Phase 1 ships under the existing problem-management framework (last "without-RFC" change), and at the same time produces the first RFC dogfood instance.

## Out of Scope

- **Story mapping (Phase 2)**: backbone/ribs/slices template, INVEST checks, story-to-RFC trace, story status lifecycle, **story-level WSJF placement**. RFC-level WSJF placement IS in scope (resolved in "Decisions resolved" subsection above; deferred sub-decision is story-level only). Phase 2 deferred until Phase 1 dogfood evidence informs the design. Phase 1 uses **task** / **step** terminology for ordered work-items inside an RFC body (per architect-review finding 13 — reserves "story" for Phase 2's INVEST-shaped + JTBD-anchored shape).
- **Type-as-workflow-split (rejected, load-bearing)**: type-tag is classification only, never a workflow split. **Phase 3 type-conditional capture-flow differentiation is rejected** (per architect-review finding 2): any UX differentiation must be JTBD-trace-conditional or nullable-field-conditional, never type-conditional. The I2 behavioural test (Phase 1 item 8d) enforces this at the lifecycle / WSJF / skill-set surfaces; Phase 3 design must respect the same prohibition at the UX surface.
- **JTBD unification (Phase 4)**: deferred. Recorded as future direction. Implementation depth requires migration scripts and possible deprecation of `docs/jtbd/` directory; not viable until story-mapping (Phase 2) lands and informs the JTBD-as-problem composition shape. **Phase 4 design must answer**: does every user-business problem ticket carry a `persona:` frontmatter field, or is persona-anchoring optional? Persona-anchoring is JTBD-essential and problem-optional — the unification cannot collapse one into the other (per JTBD-review nitpick 7).
- **External RFC homes** (per architect-review optional Option G — folded here rather than re-opening Considered Options): GitHub Discussions / Issues+Projects / Notion-style external tools / `changesets`-style per-package version-bump metadata as RFC home. **Rejected**: this is a docs-driven monorepo where RFCs are first-class versioned artefacts under `docs/rfcs/`; routing through any external tool creates a second source of truth and breaks gate-enforceability on I1. `changesets` specifically is per-package publish-axis metadata, not coordination-axis metadata — wrong granularity.
- **Retroactive migration of P168 / P159 / P051 / P169** beyond the Phase 1 dogfood pass: P159 / P051 / P169 stay under the existing framework as grandfathered tickets unless cost-of-migration is reassessed at the Phase 1 / Phase 2 / Phase 3 boundary.
- **ITIL CAB ceremony**: rejected per Option D. Approval / audit ceremony does not enter the framework.
- **Non-problem RFCs**: rejected per I1. RFCs without a problem trace are prohibited; if the change can't name a problem, the work creates a problem ticket first (continuous-improvement RFCs, opportunity RFCs, regulatory RFCs all become problem tickets first under I2's uniform ontology — including upstream-regulatory mandates).

## Confirmation

This ADR's contract holds when:

1. `/wr-itil:capture-rfc` invoked without `--problem` flag halts with directive (hard-block I1 enforcement; deny emits structured log entry to `logs/rfc-capture-denials.jsonl` for the trace-violation-rate reassessment criterion).
2. `/wr-itil:manage-rfc` lifecycle transitions to irreversible states (`accepted → in-progress`, `→ verifying`) hard-block on missing problem trace; `→ closed` emits advisory-with-escalation only when the driving problem reaches `Closed` or `Parked` AND no still-open problem trace exists (per "I1 enforcement" in Decision Outcome — bounded escape only at irreversible-end transitions, hard-block elsewhere).
3. `docs/problems/<NNN>-...md` `## RFCs` section auto-maintains the reverse trace; the trace mechanism is **commit-message RFC trailer parsing** (per Phase 1 item 12); `reconcile-rfcs.sh` extends to detect drift.
4. `capture-problem` AskUserQuestion includes the type-tag prompt **on the maintainer-side surface only** — JTBD-301 protection: the prompt MUST NOT fire on plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` or upstream-classifier paths. Both `technical` and `user-business` ride the same WSJF, lifecycle, skill set.
5. P168 retrospectively migrated to `RFC-001` traces correctly; ADR-059 references propagate as the underpinning ADR; the migration produces **no semantic loss**, defined as the conjunction of six concrete clauses (per architect-review finding 5):
    - (a) every commit referenced in P168's Fix Strategy (`ab73328`, `af5447c`, `8edaf7b`) is referenced under RFC-001's commit list;
    - (b) every Smoke-Test Finding sub-section in P168 maps to an RFC-001 verification entry;
    - (c) deferred Commit 3' is named under RFC-001's deferred-scope section AND is captured as a follow-up RFC stub OR explicitly listed in P168's continuing scope;
    - (d) P168 lifecycle state is preserved (`verifying`);
    - (e) ADR-059 references propagate as the underpinning trace;
    - (f) no information that was retrievable from P168 pre-migration is unretrievable post-migration via the RFC-001 + P168 pair (round-trip retrievability).
6. Phase 1 ships under held-changeset dogfood per ADR-042 / P162; graduation criteria evaluated via counterfactual risk assessment (delay-risk vs release-risk); RFC-shaped held changesets graduate **atomically** — entire RFC-001 commit chain or nothing (per architect-review finding 12); ADR-042 auto-apply paused until RFC-001 reaches `closed`.
7. Behavioural bats per ADR-052 cover capture-rfc, manage-rfc, reconcile-rfcs surfaces; no structural grep on SKILL.md / ADR content (P081).
8. **I2 load-bearing enforcement** (per architect-review finding 2): a behavioural test asserts capture-problem / manage-problem / work-problems / review-problems / transition-problem(s) exhibit identical control-flow shape regardless of `type` value — no skill carries a branch keyed on `type`. The test ships in the same iteration as the type-tag introduction (Phase 1 item 8d), not later.
9. **Forward-dogfood gate** (per architect-review finding 14, also a Reassessment trigger): Phase 1 does NOT graduate from held-changeset window until at least one RFC has been captured **before its first commit** and run to closure under the framework. RFC-001 (P168 retro) demonstrates representability; the forward-dogfood RFC demonstrates correctness. Both gates must close before adopter release.

## Reassessment Criteria

Re-evaluate this decision when any of:

- **Adopter trace failure**: an adopter reports the framework as unusable / heavyweight / mismatched-to-their-workflow at capture-rfc time. Suggests the RFC layer adds friction the framework's own metric (problem-management cost) doesn't justify.
- **WSJF granularity friction**: RFC-level WSJF (Phase 1 default) or story-level WSJF (Phase 2) systematically miscalibrates compared to what `/wr-itil:work-problems` Step 3 actually selects. Suggests the WSJF placement decision needs revisiting at the next phase boundary.
- **JTBD unification readiness**: Phase 2 story mapping ships and reveals a clear path to unify JTBD jobs with problems (e.g., JTBD descriptions naturally decompose into stories under the RFC framework without semantic translation). Triggers Phase 4 work.
- **Trace-to-problem violation rate** (per architect-review finding 6 — measurement mechanism named): capture-rfc gate fires denials at a rate exceeding 20% of attempts, measured from the structured deny log at `logs/rfc-capture-denials.jsonl` (Phase 1 item 2). Alternative measurable proxy: RFCs that trace to a freshly-captured problem (≤24h prior) exceed 20% of total RFCs over a rolling 30-day window. Either threshold suggests either the invariant is wrong (some legitimate RFCs don't have problems), or the capture-rfc UX over-prompts. Investigate root cause; consider amending I1 to allow problem-creation-from-rfc (user creates RFC, framework offers to create a placeholder problem ticket).
- **Forward-dogfood pending** (per architect-review finding 14 + Confirmation criterion 9): if Phase 1 graduation pressure builds (delay-risk > release-risk per ADR-042 / P162) before a forward-captured RFC has run to closure, the explicit retreat is to graduate after Slice 4 with this reassessment criterion firing, NOT to skip the forward-dogfood gate. Triggers re-evaluation of held-window graduation criteria.
- **JTBD-001 amendment drift** (per JTBD-review nitpick 2 — narrower and earlier than "Adopter trace failure"): adopters report the multi-commit-coordination governance outcome added to JTBD-001 § Desired Outcomes feels heavyweight or doesn't compose with their atomic-fix workflow. Triggers JTBD-001 reassessment at the persona-constraint level before failures cascade to capture-rfc denials.
- **JTBD-101 amendment drift** (per JTBD-review nitpick 2): atomic-fix adopters report the scaling-down-friction Persona Constraint added to JTBD-101 isn't being respected by the framework — type-tag prompt fires too aggressively, or `## RFCs` reverse-trace adds noise to atomic-fix problem tickets. Triggers JTBD-101 reassessment.
- **Type-tag drift**: `technical` vs `user-business` classifications drift over time (tickets get retroactively reclassified, tag is ambiguous, contributors disagree). Suggests the type-tag is the wrong primitive; consider per-ticket faceted tagging or removing the tag.
- **Story shape collapse**: Phase 2 architect review concludes story-level decomposition is unnecessary or that backbone/ribs/slices doesn't fit the project. Triggers Phase 2 redesign.
- **Held-window cost**: RFC-shaped held-changeset dogfood windows accumulate beyond P162's counterfactual-risk graduation criteria. Suggests RFC scopes are too large; consider sub-RFC decomposition.

## Related

- **P170** (driver) — `docs/problems/170-problem-tickets-strain-as-fixes-decompose-into-multiple-coordinated-changes-need-rfc-framework.open.md`.
- **P168 / P159 / P051 / P169** — concrete examples of the strain pattern this ADR addresses.
- **P162** — held-changeset graduation criteria (RFCs compose with).
- **JTBD-001** (extended scope per JTBD-review finding 2) / **JTBD-101** (with bifurcation acknowledgement per JTBD-review finding 3) — primary persona-jobs served.
- **JTBD-006 / JTBD-201 / JTBD-301** — secondary persona-jobs (AFK orchestrator protection / incident handoff / plugin-user no-pre-classify).
- **ADR-010** (amended skill-granularity — capture-rfc + manage-rfc are two skills).
- **ADR-013** (governance interaction — manifest / discoverability for capture-rfc + manage-rfc).
- **ADR-014** — commit grain (RFCs decompose into ADR-014-grain commits; see "Commit-grain composition" subsection).
- **ADR-019** — next-ID compute (RFC ID allocation must compose with existing convention).
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
