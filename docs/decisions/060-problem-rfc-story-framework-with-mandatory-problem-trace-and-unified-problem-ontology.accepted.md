---
status: "accepted"
human-oversight: confirmed
oversight-date: 2026-05-26
date: 2026-05-04
accepted-date: 2026-05-05
amended: 2026-05-26
amendment-driver: ADR-070-071-implementation-per-RFC-006 (line-97 permissive clause DELETED per ADR-070 — RFCs hold no independent decisions, every choice among ≥2 viable options is an ADR; + new unconditional invariant I13 — RFC required at fix-time per ADR-071, every fix via RFC with no carve-out and no effort threshold; gate placement per ADR-072 (RFC required at fix-proposal on a Known Error — rewritten per P314), auto-create missing RFC everywhere per ADR-073 (rewritten per P314); the atomic-fix carve-out is disavowed. Architect + JTBD PASS; human-oversight retained — the user ratified ADR-070/071 directly. See "Amendment 2026-05-26 (ADR-070/071)" in Decision Outcome.)
prior-amendments: [2026-05-26 (P283 prong-2 human-oversight canonical-spine clarification — execution spine is Problem (fix) → RFC → user story map(s) → user stories, ADRs riding alongside as decisions referencing problems/RFCs rather than a linear spine tier; the numbered tiers remain the node-type catalogue), 2026-05-13 (P170 Phase 3+4 in-scope reversion — JTBD-trace-conditional UX + persona/jtbd frontmatter + I12 invariant), 2026-05-12 (Phase 2 Slice 0 — HTML encoding for story-maps), 2026-05-10 (Phase 2 design accepted, ship deferred)]
decision-makers: [Tom Howard]
consulted: [wr-architect:agent (initial review + re-review 2026-05-05 + amendment review 2026-05-10 + Phase 2 HTML encoding review 2026-05-12 + Phase 3 + Phase 4 design review 2026-05-13), wr-jtbd:agent (initial review + re-review 2026-05-05 + Phase 2 HTML encoding review 2026-05-12 + Phase 4 design review 2026-05-13)]
informed: [Windy Road plugin users, adopter maintainers]
reassessment-date: 2026-08-04
---

# Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology

> **Amendment 2026-05-13 (Phase 3 + Phase 4 in-scope reversion)**: User direction 2026-05-13: *"release and then implement phase 3 and phase 4. I never deferred those phases."* Phase 1 (RFC tier) + Phase 2 (story tier) framework code shipped 2026-05-12; Phase 3 (JTBD-trace-conditional UX + story-level WSJF) and Phase 4 (`persona:` + `jtbd:` frontmatter; one-way parallel-existence reverse-trace to `docs/jtbd/`) are the remaining in-scope phases. Prior "deferred" framing in ADR-060 Out-of-Scope + P170 implementation-task blocks was agent-authored without a user-deferral citation; reversion captured at [[P189]] (sibling to [[P184]] transition-surface + [[P179]] untracked-phase-defer). **New invariant I12** — JTBD-as-source-of-truth for persona-anchored unmet need: JTBDs MAY exist with zero `## Related problems`; `type: user-business` problem tickets MUST cite ≥1 JTBD ID (`jtbd:` frontmatter array, hard-block at capture-problem when type resolves to user-business and array is empty). **Extended I2 behavioural test** — asserts no control-flow branch on `persona:` field presence (additive to existing `type`-value uniformity assertion). Architect verdict AMEND 2026-05-13 (5 findings A1-A5 all closed). JTBD verdict PASS 2026-05-13 (7 findings F1-F7 all closed in this amendment). See "Phase 3 + Phase 4 in-scope amendment (2026-05-13)" subsection in Decision Outcome.

> **Amendment 2026-05-12 (Phase 2 Slice 0 — HTML encoding for story-maps)**: User direction 2026-05-12: encode `docs/story-maps/` artefacts as HTML rather than markdown — Patton's whole point is that the 2D spatial backbone × ribs × slices layout *is* the meaning; markdown linearises that away. Individual stories + RFCs + problems + decisions stay markdown (each is a 1D card, not a 2D grid). HTML carries `data-story-id` / `data-rfc` / `data-jtbd` / `data-status` attributes for deterministic agent parsing; structure-only HTML5 + minimal embedded `<style>` for grid layout; no inline `style=""` on data-bearing elements. Phase 2 commit-grain gains an encoding-scaffold sub-slice between scaffold and ADR-019 extension. ADR-019 collision-guard extends to `*.html` for `docs/story-maps/`. Hook exemption globs (architect-enforce-edit.sh / jtbd-enforce-edit.sh / risk-policy-enforce-edit.sh / style-guide-enforce-edit.sh / voice-tone-enforce-edit.sh) extend to `docs/story-maps/**/*.html` in the same slice that ships the first HTML map. JTBD-302 (not JTBD-007 — prior-amendment typo) carries the README-currency rule for `docs/story-maps/README.md`. Architect verdict AMEND 2026-05-12 (7 findings; all closed in this amendment). JTBD verdict PASS 2026-05-12 (2 non-blocking notes applied). See "Phase 2 encoding amendment (2026-05-12)" subsection in Decision Outcome.

> **Amendment 2026-05-10**: Phase 2 design (user story maps + individual stories) is accepted; framework code remains deferred. User direction (3-message refinement mid-P170 Slice 5 work) collapsed the original Phase 2 / Phase 2.5 split into a single Phase 2 ship — stories are first-class artefacts from the start so RFCs can reference them by ID for the working-the-problem traversal (Problem → Fix Strategy RFCs → RFC's ordered `stories:` array → next-actionable story). Spec corrections ride this amendment per architect-review verdict (8 amendments + 3 nitpicks applied). See "Story Map + Story design (Phase 2 deliverables)" subsection in Decision Outcome.

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
- **ADR-069 (Load-bearing-from-the-start for drift class; carried forward from superseded ADR-051)** — the trace-to-problem invariant is a drift class; gate enforcement should be load-bearing at capture-rfc time, not advisory-then-escalate.
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

> **Amendment 2026-05-26 — canonical execution spine (human-oversight correction, P283 prong 2).** The **canonical execution spine** of a fix runs: **Problem (fix) → RFC → user story map(s) → user stories**. ADRs are **not** a linear tier in that spine — they ride *alongside* it as decisions that reference ≥ 0 problems and underpin ≥ 0 RFCs (a decision can predate, follow, or be independent of any single fix's execution). The numbered "four-tier hierarchy" below is the ontology's **node-type catalogue** (the four kinds of artefact and their lifecycles), not the linear flow; it lists ADR as a node type for completeness. Where the catalogue's ordering reads as a linear Problem→ADR→RFC→Story spine, defer to this amendment: the execution spine threads Problem→RFC→**story map(s)**→stories, and story maps are a first-class organising tier between an RFC and its stories (per the Phase 2 story-map encoding, prior-amendment 2026-05-12). This correction was recorded as a human-oversight confirmation during the P283 prong-2 `/wr-architect:review-decisions` drain; it sharpens the description toward what the tier bodies already assert (tier 2: "decisions can predate or be independent of execution"; tier 3: "ADRs ride alongside RFCs"), and does not change any decision outcome.

> **Amendment 2026-05-26 (ADR-070/071) — RFCs hold no independent decisions + every fix via RFC.** Two ratified sibling decisions amend this ADR. **ADR-070** (RFCs hold no independent decisions): line 97's permissive half ("ADRs created during RFC execution capture decisions with scope outside the RFC's own boundary") is **deleted**; every choice among ≥ 2 viable options is recorded as an ADR (under the ADR-064 confirm gate + ADR-066 oversight net), and only pure sequencing/breakdown of *already-decided* work stays in the RFC. This closes the P310 blind spot — decisions living in `docs/rfcs/` were invisible to the ADR-066 detector (which greps only `docs/decisions/`). **ADR-071** (every fix goes through an RFC): new unconditional invariant **I13** (in Mandatory invariants above) requires the RFC at the **propose-fix step on a Known Error** — **no carve-out, no effort threshold, no `--rfc-deferred` override** (the atomic-fix carve-out originally proposed as RFC-005 F2 was disavowed by the user: *"No. Same RFC. Not scaled down. No short cuts."*). Gate placement per ADR-072 (RFC required at fix-proposal on a Known Error, conforming to ADR-022); auto-create a missing RFC everywhere per ADR-073. (**Both ADR-072/073 were rewritten 2026-05-26 per P314** — the original `Open → Known Error` placement + hard-block stance were rejected at the `/wr-architect:review-decisions` oversight drain: the placement was built on a wrong Known Error model, and a missing RFC is auto-created, not blocked.) The implementation RFC is **RFC-006**. ADR-060 stays `accepted`; `human-oversight: confirmed` retained — the user ratified ADR-070/071 directly.

Introduce a four-tier hierarchy (**node-type catalogue** — see the canonical execution spine in the 2026-05-26 amendment above; this is the artefact-kind catalogue, not the linear fix-flow):

1. **Problem** (existing) — *what hurts*. Lifecycle: `Open` / `Known Error` / `Verifying` / `Closed` / `Parked`. Per existing `docs/problems/` shape. **New**: type-tag added to frontmatter (`type: technical` | `type: user-business`); both treated identically by WSJF, capture skill, and lifecycle (invariant 2).
2. **ADR** (existing) — *how we decided to solve it*. Status: `proposed` / `accepted` / `superseded`. Per existing `docs/decisions/` shape. May reference ≥ 0 problems; may underpin ≥ 0 RFCs (decisions can predate or be independent of execution).
3. **RFC** (new) — *what we're shipping to solve it*. Status: `proposed` / `accepted` / `in-progress` / `verifying` / `closed`. New `docs/rfcs/` directory with naming grammar **`RFC-<NNN>`** (matches `ADR-<NNN>` form; no collision with `docs/risks/R<NNN>` or problem `<NNN>` IDs). **Invariant 1**: MUST trace to ≥ 1 problem (gate-enforced at capture-rfc + manage-rfc — see "I1 enforcement" below). May reference ≥ 1 ADRs (ADRs ride alongside RFCs as decisions made during execution). **An RFC holds no independent decisions (per ADR-070): every choice among ≥ 2 viable options is recorded as an ADR (inheriting the ADR-064 confirm gate + ADR-066 oversight marker). Only pure sequencing/breakdown of *already-decided* work (story breakdown, phase ordering, task sequencing) stays in the RFC and does NOT create an ADR.** This keeps every genuine decision under the ADR-066 oversight net (closing the P310 blind spot) while protecting against ADR-sprawl on pure sequencing. (Amended 2026-05-26 per ADR-070 — the prior permissive clause "ADRs created during RFC execution capture decisions with scope outside the RFC's own boundary" is deleted; it let RFC-internal decisions escape ADR capture, which is exactly the drift ADR-070 closes.)
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
- **I13 (RFC required at fix-proposal — unconditional)** *(added 2026-05-26 per ADR-071 / RFC-006; **rewritten 2026-05-26 per P314** — the original placed this at `Open → Known Error` with a hard-block, built on a wrong Known Error model + reversed by the user)*: every problem is fixed only via an RFC — **no carve-out, no effort threshold, no exemption** (per ADR-071; the atomic-fix carve-out originally proposed as RFC-005 F2 is disavowed). The RFC is required at the **propose-fix step on a Known Error** (gate placement per ADR-072), conforming to ADR-022's Known Error semantics (`Known Error` = root cause + documented workaround; the fix is *proposed* after, which produces the RFC; fix-release IS the `Known Error → Verifying` transition). It is **NOT** required at `Open → Known Error` (a problem reaches Known Error with no fix and no RFC) and there is **no new lifecycle state**. When a fix is proposed on a Known Error with no RFC trace, the framework **auto-creates a problem-traced skeleton RFC** (scope = the fix; no decisions per ADR-070) rather than blocking — **everywhere the gate fires**: the interactive `/wr-itil:manage-problem` propose-fix surface AND the AFK `/wr-itil:work-problems` orchestrator (per ADR-073; auto-creating the ADR-071-mandated vehicle is framework-mediated, not cat-1 direction-setting). Problem-ticket frontmatter carries `rfcs: [RFC-<NNN>, ...]` (cardinality `0..N`: empty until a fix is proposed; ≥ 1 once a fix is proposed/auto-created). Symmetric to I1's RFC→Problem direction. The propose-fix gate + auto-create mechanism ship under RFC-005's (corrected) task decomposition (held-changeset window per ADR-042). **Enforcement is load-bearing**: a behavioural test (per ADR-052) asserts the RFC is required/auto-created at fix-proposal (not at `Open → Known Error`) at every effort level (S/M/L/XL).

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

**Story Map + Story design (Phase 2 deliverables — DESIGN accepted in this amendment 2026-05-10 per user direction; SHIP deferred to Phase 2 framework code per Out of Scope)**:

User direction 2026-05-10 (3-message interactive refinement mid-P170 Slice 5 work) promoted story-map AND story DESIGN from "deferred entirely to Phase 2 / 2.5" to "design accepted now, ship deferred together". Driver: the existing bootstrap planning artefact at `docs/plans/170-rfc-framework-story-map.md` exposed load-bearing properties (own lifecycle, multi-RFC trace, multi-JTBD trace) the original Phase 2 deferral didn't articulate. User's third refinement (verbatim): *"the Problem, when it's a known error and has a proposed fix, should link to 1 or more RFCs. Each of those RFCs should reference specific stories in a user story map, so when we work the problem, we know what to implement and in what order"* — this collapsed the original Phase 2 ↔ Phase 2.5 split (story-maps-now / individual-stories-later) into a single Phase 2 ship: **stories are first-class from the start**.

**Working-the-problem traversal** (the load-bearing data flow this design serves):

```
Problem (known-error + ## Fix Strategy section)
   │ "fix proposed via RFC-NNN, RFC-NNN"
   ▼
RFC-NNN (## Stories section)
   │ "implement STORY-NNN, STORY-NNN, STORY-NNN in this order"
   ▼
STORY-NNN (acceptance-criteria + INVEST shape)
   │ "ship the story; mark done; advance to next"
```

Working a problem reads its Fix Strategy → finds linked RFCs → reads each RFC's ordered story list → implements stories in order. The story map is the BACKBONE/RIBS/SLICES shape that organises stories visually + by user-journey context; an RFC's `stories` list is the ORDERED EXECUTION sequence (which may be a subset of the map's stories, or span across maps).

**Hierarchy position**: Story maps and individual stories are **ORTHOGONAL** to the Problem→ADR→RFC chain — they are work-decomposition artefacts that DO NOT own RFCs or get owned by RFCs. The traversal is by reference: RFCs reference specific stories (by STORY-NNN ID); stories may appear in multiple story maps (the maps are organisational lenses on the story corpus). Many-to-many across all three pairs: many problems ↔ many RFCs; many RFCs ↔ many stories; many stories ↔ many story maps.

**No WSJF on story maps** (I5 invariant — see below): maps are planning artefacts, not work items. WSJF stays on problems and RFCs (Phase 1); story-level WSJF is a Phase 3 deferred decision per Reassessment Criterion (d) below — gated on use evidence. Avoids double-ranking the same work via two artefacts; protects `/wr-itil:work-problems` Step 3 selection from competing surfaces.

**Naming + location**:

- File: `docs/story-maps/<state>/STORY-MAP-NNN-<slug>.md` — per-state subdir layout per ADR-031, matching the post-RFC-002 problem-ticket layout from the start (no flat→subdir migration needed; first artefact tier born in the new layout).
- ID grammar: `STORY-MAP-NNN` — three-digit zero-padded ID, parallel to `ADR-NNN` / `RFC-NNN` / problem `<NNN>`. Same `max(local, origin) + 1` allocation per ADR-019.
- README: `docs/story-maps/README.md` — rendered index analogous to `docs/problems/README.md` (sections per lifecycle state; `## Currently in-progress` surfaces active maps).

**Lifecycle states**:

| Status | Subdir | Meaning | Entry criteria |
|--------|--------|---------|----------------|
| `draft` | `docs/story-maps/draft/` | Backbone/ribs/slices being authored; not yet ready to execute | Captured via `/wr-itil:capture-story-map`; ≥1 problem trace + ≥1 JTBD trace |
| `accepted` | `docs/story-maps/accepted/` | Design done; slices ready to execute; traced RFCs may not yet exist (a map can scope work that pre-dates its RFCs) | Architect review PASS on backbone/ribs structure; user direction-pin via `/wr-itil:manage-story-map <NNN> accepted` |
| `in-progress` | `docs/story-maps/in-progress/` | At least one traced RFC has reached `accepted` or beyond; slices being shipped | Auto-transition when first traced RFC moves to `accepted` |
| `completed` | `docs/story-maps/completed/` | All traced RFCs have reached `closed`; all slices shipped (or explicitly cancelled with reason captured in the map body) | Auto-transition when all traced RFCs reach `closed` |
| `archived` | `docs/story-maps/archived/` | Completed >30 days ago AND all traced RFCs cleared from active queue | Housekeeping pass; reversible via `git mv` back to `completed` if user disagrees |

NO `verifying` state — story maps are planning artefacts, not user-facing fixes. (RFC-level verification fires per ADR-022; the map's `completed` transition rolls up.)
NO `superseded` state distinct from `archived` — superseded maps move directly to `archived` with a forward-pointer in the map body (`## Superseded by STORY-MAP-NNN`); explicit `superseded` state would add a sixth lifecycle state without distinct semantics.

**Frontmatter schema**:

```yaml
---
status: draft | accepted | in-progress | completed | archived
date-created: YYYY-MM-DD
date-accepted: YYYY-MM-DD     # required when status >= accepted
date-completed: YYYY-MM-DD    # required when status == completed
methodology: Patton, "User Story Mapping" (O'Reilly, 2014)
problems: [P<NNN>, P<NNN>, ...]        # ≥1 driver problems; I3 invariant (see below)
rfcs: [RFC-<NNN>, RFC-<NNN>, ...]      # 0..N traced RFCs (may be empty at draft; populated as design firms up)
adrs: [ADR-<NNN>, ...]                 # 0..N referenced ADRs (optional — ADRs that scoped the map's design)
jtbd: [JTBD-<NNN>, JTBD-<NNN>, ...]    # ≥1 jobs the map serves; I4 invariant (see below)
decision-makers: [<git config user.name>]
---
```

The flat `problems` / `rfcs` / `jtbd` arrays mirror RFC frontmatter precedent and replace the existing bootstrap map's scalar `driver-problem` / `driving-adr` / split `primary-jtbd` + `secondary-jtbd` shape (which assumed 1:1 trace and contradicts the multi-RFC / multi-JTBD design accepted here).

**Mandatory invariants** (load-bearing, gate-enforced — mirror RFC's I1/I2 pattern):

- **I3 (trace-to-problem)**: every story map traces to ≥ 1 problem; orphan maps prohibited. Hard-block at `/wr-itil:capture-story-map` (no problem trace = capture refuses; same `if there's no problem, capture one first` surface routing as RFC's I1).
- **I4 (trace-to-JTBD)**: every story map traces to ≥ 1 JTBD; maps without a stated job served are prohibited. Justification: story-map purpose IS to organise work around user value (Patton's central thesis); a map with no JTBD trace is structurally meaningless. Hard-block at `/wr-itil:capture-story-map`. Distinguishes story maps from RFCs (where JTBD trace is OPTIONAL per current Phase 1 frontmatter) — the strict-JTBD invariant is what makes story maps Patton-shaped rather than just "RFC bundles".
- **I5 (no WSJF leak)**: story maps MUST NOT carry a WSJF field, MUST NOT participate in WSJF ranking, MUST NOT appear in `/wr-itil:work-problems` Step 3 selection. Behavioural test (per ADR-052) asserts no skill / orchestrator reads or writes WSJF on story maps. Composes with I2 (uniform problem ontology) — same test pattern, different artefact tier.

**Stories as first-class artefacts** (collapsed Phase 2.5 INTO Phase 2 per user direction 2026-05-10 refinement):

The original Phase 2 / Phase 2.5 split (story-maps-now / individual-stories-later) was the wrong cleavage. The user's working-the-problem traversal requires individual stories to exist as first-class artefacts FROM the start so RFCs can reference them by ID. Phase 2 now ships story maps AND stories together; "Phase 2.5" no longer exists as a separate phase tier.

**Story naming + location**:

- File: `docs/stories/<state>/STORY-NNN-<slug>.md` — per-state subdir layout per ADR-031, matching post-RFC-002 problem-ticket layout.
- ID grammar: `STORY-NNN` — three-digit zero-padded ID, parallel to `ADR-NNN` / `RFC-NNN` / `STORY-MAP-NNN` / problem `<NNN>`. Same `max(local, origin) + 1` allocation per ADR-019.
- README: `docs/stories/README.md` — rendered index analogous to the other tier READMEs.

**Story lifecycle states**:

| Status | Subdir | Meaning | Entry criteria |
|--------|--------|---------|----------------|
| `draft` | `docs/stories/draft/` | Story being written; acceptance criteria not yet INVEST-shaped | Captured via `/wr-itil:capture-story` |
| `accepted` | `docs/stories/accepted/` | INVEST-shaped (Independent / Negotiable / Valuable / Estimable / Small / Testable); ready to implement | INVEST behavioural test PASS via `/wr-itil:manage-story <NNN> accepted`; ≥1 problem trace + ≥1 JTBD trace + ≥1 RFC trace |
| `in-progress` | `docs/stories/in-progress/` | Implementation underway | Auto-transition when first commit references the story (commit-message `Implements: STORY-NNN` trailer) |
| `done` | `docs/stories/done/` | Implementation shipped + acceptance criteria verified | Auto-transition when story's referencing RFC reaches `closed` AND acceptance criteria checkboxes all ticked |
| `archived` | `docs/stories/archived/` | Done >30 days ago AND containing story-map(s) reach `archived` | Housekeeping pass; reversible |

NO `verifying` state — story acceptance is criterion-driven (acceptance-criteria checkboxes), not separate-verification-driven. RFC-level verification per ADR-022 catches the broader user-verification surface.

**Story frontmatter schema**:

```yaml
---
status: draft | accepted | in-progress | done | archived
date-created: YYYY-MM-DD
date-accepted: YYYY-MM-DD     # required when status >= accepted
date-done: YYYY-MM-DD         # required when status == done
problems: [P<NNN>, ...]                # ≥1 — problems this story serves; I6 invariant
rfcs: [RFC-<NNN>, ...]                 # ≥1 — RFCs that reference this story; I7 invariant
story-maps: [STORY-MAP-<NNN>, ...]     # ≥1 — maps that include this story; I8 invariant
jtbd: [JTBD-<NNN>, ...]                # ≥1 — jobs the story serves; I9 invariant
acceptance-criteria-count: <N>         # mechanical — count of `- [ ]` / `- [x]` lines in body
estimated-effort: S | M | L | XL       # INVEST "Estimable" — set at accepted transition
---

# STORY-NNN: <Title>

## User-value statement
As a <persona>, I want <capability>, so that <outcome>.

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] ...

## Implementation notes
<technical context, gotchas, links to relevant code>

## Related
<problems / RFCs / story-maps / JTBD cross-refs (auto-maintained reverse-trace)>
```

**Story invariants** (load-bearing, gate-enforced):

- **I6 (trace-to-problem)**: every story traces to ≥ 1 problem. Hard-block at `/wr-itil:capture-story`. Mirrors RFC's I1 / story-map's I3.
- **I7 (trace-to-RFC)**: every story traces to ≥ 1 RFC. Hard-block at `/wr-itil:manage-story <NNN> accepted` (allows draft stories to exist before their RFC reference firms up; blocks acceptance without one). Stories without RFC references are work-in-search-of-a-coordinated-change — exactly the inverse of P179's "untracked phase" failure.
- **I8 (trace-to-story-map)**: every story traces to ≥ 1 story map. Hard-block at `/wr-itil:manage-story <NNN> accepted`. Stories that exist only as RFC references but never appear in a map lose the user-journey context that motivates story shape.
- **I9 (trace-to-JTBD)**: every story traces to ≥ 1 JTBD. Same justification as story-map I4 — stories are by-definition organised around user value.
- **I10 (INVEST shape)**: at acceptance, the story body MUST satisfy INVEST behaviourally — ≥1 acceptance criterion (Testable); explicit user-value statement (Valuable); no `Blocked by` references to other unaccepted stories (Independent); estimated-effort field set (Estimable); story scope SHOULD be S or M (Small) — L or XL stories are flagged as **decomposition candidates** rather than blocked at acceptance (per architect-amendment-2026-05-10 nitpick N3 — XL stories aren't necessarily violations of "Small" and may be the right granularity for some bounded work). Behavioural test enforces presence of the criteria + value statement + estimated-effort field; flags L/XL as decomposition candidates without blocking.
- **I11 (no WSJF leak — Phase 2)**: stories MUST NOT carry a WSJF field in Phase 2. Story-level WSJF is a Phase 3 deferred decision (gated on use evidence — does AFK orchestrator selection benefit from story-level granularity?). Behavioural test asserts.

**RFC frontmatter extension** (Phase 2 amendment to RFC frontmatter spec — required for the RFC→story reference):

```yaml
# Existing Phase 1 RFC frontmatter PLUS:
stories: [STORY-<NNN>, STORY-<NNN>, ...]   # 0..N stories this RFC implements; ORDERED (execution sequence)
```

The `stories:` field is **ordered** — array order IS the execution sequence per the user's traversal. **Cardinality is genuinely 0..N**: atomic RFCs that don't decompose into stories MAY ship with empty `stories: []` (composes with JTBD-101 atomic-fix-adopter friction guard — Reassessment Criterion (a) names exactly this signal class). `/wr-itil:manage-rfc <NNN> accepted` does NOT require the field to be populated; story-decomposed RFCs SHOULD populate it for the working-the-problem flow's per-story dispatch, but atomic RFCs with empty `stories: []` are legitimate and inherit the Phase 1 per-RFC iter dispatch (no per-story scoping). `/wr-itil:work-problem <NNN>` reads the linked RFC's `stories:` array; on empty, falls back to the Phase 1 per-RFC iter dispatch with no per-story decomposition.

**Reverse-trace surfaces** (auto-maintained, refresh contract analogous to RFC's `## RFCs` section per Phase 1 item 10):

- `## Story Maps` section on each problem ticket whose ID appears in any map's `problems:` array.
- `## Story Maps` section on each RFC whose ID appears in any map's `rfcs:` array.
- `## Story Maps` section on each JTBD file whose ID appears in any map's `jtbd:` array. **NEW reverse-trace surface** on JTBDs.
- `## Stories` section on each problem ticket whose ID appears in any story's `problems:` array.
- `## Stories` section on each RFC's body listing the RFC's `stories:` array IN ORDER (this is forward-trace from the RFC's frontmatter, rendered as a body section so working-the-problem reads it inline; auto-refreshed on RFC frontmatter edits).
- `## Stories` section on each JTBD file whose ID appears in any story's `jtbd:` array.
- `## RFCs` section on each story (showing which RFCs reference it).
- `## Story Maps` section on each story (showing which maps include it).
- **Generalised reverse-trace helpers** (4 polymorphic scripts taking a `<section-name>` argument — per architect-amendment-2026-05-10 A5 firing on the 3-JTBD-surface threshold):
  - `update-problem-references-section.sh <section-name>` — covers `## Story Maps`, `## Stories` on problem tickets (and absorbs the existing `update-problem-rfcs-section.sh` for `## RFCs` per the cleanup contract; existing single-purpose helper retained as a thin shim during the deprecation window per ADR-010 forwarder pattern).
  - `update-rfc-references-section.sh <section-name>` — covers `## Story Maps`, `## Stories` on RFCs (forward-trace from RFC frontmatter `stories:` for the Stories surface).
  - `update-jtbd-references-section.sh <section-name>` — covers `## RFCs`, `## Story Maps`, `## Stories` on JTBD files. **NEW reverse-trace surface tier** — JTBDs currently have no auto-maintained reverse-trace sections; this helper introduces the JTBD reverse-trace surface generally, with all three section names supported from the start per A5.
  - `update-story-references-section.sh <section-name>` — covers `## RFCs`, `## Story Maps` on story files.

The 4-helper generalisation closes the count-mismatch flagged at A2 (the prior 6/8 enumeration was a counting bug; the surface map is 8 reverse-trace surfaces collapsed to 4 polymorphic helpers). Behavioural bats per ADR-052 covers all 4 helpers with parameterised section-name input.

**Skills** (Phase 2 ship — design accepted, code deferred):

Story-map skills (4):
- **`/wr-itil:capture-story-map`** — lightweight aside per ADR-032. Mandatory leading argument: at least one problem trace, at least one JTBD trace. I3 + I4 hard-block. Status: `draft` on capture.
- **`/wr-itil:manage-story-map`** — heavyweight intake + lifecycle management. Backbone/ribs/slices authoring guidance; trace-gate enforcement; **slices reference story IDs** (not contain stories inline) once the story corpus exists.
- **`/wr-itil:reconcile-story-maps`** — diagnose-only README drift detector for `docs/story-maps/README.md`.
- **`/wr-itil:list-story-maps`** — read-only display.

Story skills (4 — NEW per the refinement):
- **`/wr-itil:capture-story`** — lightweight aside. Mandatory: ≥1 problem trace, ≥1 JTBD trace. RFC + story-map traces optional at capture (I7 / I8 enforce at accepted transition). Status: `draft`.
- **`/wr-itil:manage-story`** — heavyweight lifecycle. INVEST checks (I10) at accepted transition; trace-gate enforcement (I7 / I8 / I9); auto-transition draft→in-progress on first `Implements: STORY-NNN` trailer; auto-transition in-progress→done on RFC-closes + acceptance-criteria all-ticked.
- **`/wr-itil:reconcile-stories`** — diagnose-only README drift for `docs/stories/README.md`.
- **`/wr-itil:list-stories`** — read-only display, with optional `--rfc RFC-NNN` filter to surface a specific RFC's ordered story list.

Plus extension to existing `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc`: support `--stories STORY-NNN,STORY-NNN,...` argument; render `## Stories` body section from frontmatter `stories:` array.

Behavioural bats per ADR-052 for all 8 new skills + 6 reverse-trace helpers + I3-I11 invariant tests + RFC stories-frontmatter extension test.

**Working-the-problem flow** (the load-bearing data flow — what `/wr-itil:work-problem <NNN>` does post-Phase-2):

1. Read problem `P<NNN>`'s `## Fix Strategy` section. Extract referenced RFC IDs.
2. For each RFC, read its frontmatter `stories:` array (ordered).
   - If `stories:` is non-empty: pick the first story whose status is `accepted` or `in-progress` (skipping `done` stories that already shipped, skipping `draft` stories that aren't ready). Continue to step 3.
   - If `stories:` is empty (atomic RFC, JTBD-101 friction guard): fall back to Phase 1 per-RFC iter dispatch — read the RFC body's tasks/steps section directly; no per-story scoping. Skip to step 7's RFC-closure handling.
3. Read the picked story's body — user-value statement, acceptance criteria, implementation notes.
4. Implement the story. Each commit references it via `Refs: STORY-NNN` trailer (matches the existing `Refs: RFC-NNN` trailer pattern from ADR-060 line 111 + Phase 1 item 12 — single trailer vocabulary, single hook parses both, per architect-amendment-2026-05-10 nitpick N2).
5. Mark acceptance criteria checkboxes as work lands.
6. When all criteria ticked + linked RFC closes, story auto-transitions to `done`.
7. Pick next story from RFC's `stories:` array (or next task/step from RFC body for atomic-RFC fallback); repeat.

This replaces the current `/wr-itil:manage-problem`'s "Working a Problem (Known Error)" flow which says vaguely *"Read the root cause analysis and fix strategy. Implement the fix following the project's development workflow"* — Phase 2 makes "implement the fix" concretely traceable via stories (or via the atomic-RFC fallback for non-decomposed work).

**Composition with other artefacts**:

- Story maps and stories DO NOT own RFCs or get owned by RFCs (orthogonal per hierarchy decision above).
- Story maps reference STORIES BY ID (not contain stories inline). The map's backbone/ribs/slices structure is a layout of story-references; the stories themselves live as their own artefacts. A single story can appear in multiple maps (the maps are journey-context lenses on the story corpus).
- RFCs reference stories BY ID in an ORDERED frontmatter `stories:` array. The order IS the execution sequence. Working-the-problem reads it linearly.
- Story maps DO compose with held-changeset windows per ADR-042 — if a map's stories ride a held window, the map's `in-progress` status reflects that.
- Stories DO compose with `/wr-itil:work-problems` orchestrator selection — the orchestrator picks problems / RFCs as today (NOT story maps; I5: no WSJF on maps); within an RFC iteration, the iter dispatches the next-actionable story from the RFC's ordered `stories:` array.

**Bootstrap migration**:

The existing `docs/plans/170-rfc-framework-story-map.md` migrates to `docs/story-maps/in-progress/STORY-MAP-001-rfc-framework-phase-1-bootstrap.md` when Phase 2 framework code ships (NOT in this amendment commit; this amendment lands the design only). Frontmatter populated:

```yaml
status: in-progress
problems: [P170]
rfcs: [RFC-001, RFC-002]
jtbd: [JTBD-001, JTBD-008, JTBD-006, JTBD-101]
adrs: [ADR-060]
stories: [STORY-NNN, STORY-NNN, ...]    # Phase 2 ship: extract slices into individual stories
```

Status `in-progress` because Slice 5 (RFC-002 forward-dogfood) is underway. Same dogfood discipline as RFC-001 retro on P168 (architect finding 14 forward-dogfood requirement). The frontmatter migration is the dogfood test that the schema is implementable against a real planning artefact — if it can't represent the Phase 1 work, the design is wrong.

Concurrently with the STORY-MAP-001 migration, every existing slice in the bootstrap map (Slices 1-6 backbone + B1-B10 ribs + T1-T11 tasks) extracts to an individual `STORY-NNN-<slug>.md` file in the appropriate lifecycle subdir (Slices 1-3 done; Slices 4-5 in-progress; Slice 6 in-progress; T1-T5a done; T5b through T11 not-yet-started). RFC-001's frontmatter gains `stories: [...]` listing its slices in execution order; RFC-002's frontmatter gains `stories: [...]` listing T1-T11 + L2-L3 in execution order.

**Bootstrap I7/I8/I9/I10 retrofit + exemption** (per architect-amendment-2026-05-10 A4): bootstrap stories that ship in `done/` or `in-progress/` subdirs MUST have their I7/I8/I9/I10 gates retrofitted at migration time — RFC + story-map + JTBD references populated in frontmatter, and INVEST shape backfilled from slice descriptions. The migration script bypasses the `manage-story <NNN> accepted` runtime gate for these stories via a one-time **bootstrap exemption marker** (`<!-- bootstrap-exempt: STORY-MAP-001 migration per ADR-060 amendment 2026-05-10 -->` HTML comment inline with the frontmatter). This matches the ADR-053 Bootstrapping precedent (same pattern ADR-051 used for its hook bootstrap commit). Stories created post-Phase-2 ship through the gates normally — no exemption marker permitted on non-bootstrap captures (behavioural test asserts).

**Phase 2 framework code shipment** (8 skills + scaffold + 2 reconcile scripts + 2 bin shims + bats coverage + 4 generalised reverse-trace refresh helpers + RFC frontmatter `stories:` extension + working-the-problem flow rewrite + ADR-019 collision-guard extension) remains in Out of Scope per the existing entry; that entry is updated by this amendment to point at this design subsection.

**Phase 2 commit-grain decomposition** (per architect-amendment-2026-05-10 A3 + ADR-014 single-purpose grain — Phase 2 ship is itself a multi-commit chain; making the decomposition explicit prevents implementer reading "Phase 2 ship" as a single commit):

Phase 2 graduates as its own RFC under the framework Phase 1 produces (eat-our-own-dogfood at the meta-level). Recommended decomposition (illustrative; the actual decomposition lives in the Phase 2 RFC's `stories:` array):

1. **Scaffold** — `docs/story-maps/`, `docs/stories/` directory layouts + 5-state subdirs each + READMEs.
2. **ADR-019 collision-guard extension** — extend `packages/itil/scripts/check-id-collision.sh` (or equivalent) to enumerate `docs/story-maps/` + `docs/stories/` recursive trees per ADR-031 P056 `--name-only` + `-r` pattern. Either amend ADR-019 in place OR add a Phase 2 Confirmation criterion that capture-story-map + capture-story run the collision guard against `origin/<base>` before ID allocation.
3. **4 story-map skills** — one commit per skill per ADR-014 (capture-story-map; manage-story-map; reconcile-story-maps; list-story-maps).
4. **4 story skills** — one commit per skill per ADR-014 (capture-story; manage-story; reconcile-stories; list-stories).
5. **4 generalised reverse-trace helpers** — grouped by adjacent surface (likely 2 commits — problems+RFCs in one, JTBDs+stories in another).
6. **RFC frontmatter `stories:` extension + capture-rfc / manage-rfc updates** — one commit covering the schema extension + skill updates + behavioural test for the empty-stories fallback.
7. **Working-the-problem flow rewrite** — `/wr-itil:work-problem <NNN>` rewrite per the traversal above. Behavioural test asserting the traversal end-to-end.
8. **Bootstrap migration** — STORY-MAP-001 + extracted bootstrap stories. Per A4 below, the bootstrap migration carries an explicit I7/I8/I9/I10 retrofit + bootstrap-exemption marker per ADR-053 Bootstrapping precedent.

This decomposition makes the Phase 2 ship correctly grain-able into ADR-014 single-commit-per-bounded-sub-task; Phase 2 itself becomes RFC-NNN traced to P170 per the dogfood discipline (the framework's own next-graduation cycle eats its own outputs).

**Confirmation (Phase 2 — when framework code ships)**:

- `docs/story-maps/` and `docs/stories/` directories exist with the 5 lifecycle subdirs each.
- STORY-MAP-001 migrated from `docs/plans/170-rfc-framework-story-map.md` with the frontmatter above; frontmatter validates against the schema; reverse-trace `## Story Maps` sections appear on P170 / RFC-001 / RFC-002 / JTBD-001 / JTBD-008 / JTBD-006 / JTBD-101.
- Bootstrap stories STORY-001..STORY-N extracted from the original map's slices/tasks; frontmatter validates against the schema (with bootstrap-exemption marker on done/in-progress stories per A4); reverse-trace `## Stories` sections appear on P170, on the appropriate RFCs (referencing the stories in execution order), on STORY-MAP-001, and on JTBDs.
- All 8 skills (`capture-story-map` / `manage-story-map` / `reconcile-story-maps` / `list-story-maps` / `capture-story` / `manage-story` / `reconcile-stories` / `list-stories`) ship with green behavioural bats covering I3-I11 invariants. Behavioural test asserts that the bootstrap-exemption marker is permitted ONLY on bootstrap-migration stories; non-bootstrap captures with the marker fail.
- RFC frontmatter `stories:` extension shipped + capture-rfc / manage-rfc updated to populate it; `## Stories` body section auto-rendered from frontmatter. Behavioural test asserts the empty-stories fallback (atomic RFCs ship with empty `stories: []` and inherit Phase 1 per-RFC iter dispatch).
- ADR-019 collision-guard extension shipped — capture-story-map + capture-story run the collision guard against `origin/<base>` before ID allocation per the `max(local, origin) + 1` pattern. Behavioural test asserts that a same-tier collision on origin triggers the renumber.
- 4 generalised reverse-trace helpers (`update-problem-references-section.sh`, `update-rfc-references-section.sh`, `update-jtbd-references-section.sh`, `update-story-references-section.sh`) ship with parameterised `<section-name>` argument; behavioural bats covers each section name across each helper.
- `/wr-itil:work-problem <NNN>` rewritten to traverse Problem → Fix Strategy RFCs → RFC's `stories:` array → next-actionable story (per the working-the-problem flow above). Behavioural test asserts the traversal end-to-end on STORY-MAP-001 + RFC-001 + RFC-002 + their stories AND the empty-stories atomic-RFC fallback.
- `/wr-itil:work-problems` Step 3 selection unchanged (regression test asserts no story-map ID and no story ID appear in the orchestrator's selection output; story IDs surface only inside iter dispatch via the linked RFC's `stories:` array).
- Orchestrator iter prompts dispatch a SINGLE story per iteration when the targeted RFC has non-empty `stories:` (composability test — iter dispatched against an RFC reads the RFC's first not-yet-done story and scopes the iter to that story's acceptance criteria); falls back to per-RFC iter dispatch on empty `stories:`.

**Reassessment Criteria (Phase 2 design)**: revisit if (a) >20% of multi-commit RFC bundles ship without a story map AND without a `stories:` array on the RFC (signal: design provides too much ceremony for the value), (b) cross-RFC maps prove rare in practice (signal: many-to-many was over-design; collapse to one-to-many), (c) a second JTBD reverse-trace surface emerges (signal: extract reverse-trace helpers into a generalised `packages/itil/scripts/update-jtbd-references-section.sh` taking a section-name argument), (d) story-level WSJF demand surfaces from `/wr-itil:work-problems` orchestrator users (signal: promote I11 from "no WSJF leak" to "story-level WSJF as Phase 3 deliverable" with the same RFC-frontmatter-extension pattern).

### Phase 2 encoding amendment (2026-05-12)

User direction 2026-05-12 (after the prior session's premature P170 Verification Pending transition was reverted to surface Phase 2 as in-scope): **encode story-maps as HTML, keep everything else markdown.** Patton's 2D backbone × ribs × slices layout *is* the meaning; markdown linearises that away. Individual stories + RFCs + problems + decisions stay markdown — each is a 1D card / decision record / ticket, not a 2D grid, so markdown is the right tool. This amendment captures the encoding decision + the four cascading scope adjustments per architect re-review verdict AMEND 2026-05-12 (7 findings) + JTBD re-review verdict PASS 2026-05-12 (2 non-blocking notes).

#### Encoding choice for story-maps

**Chosen**: structure-only HTML5 + minimal embedded `<style>` block for grid layout + `data-*` attributes on `<a>`-card elements for machine readability. File extension: `.html`. Path: `docs/story-maps/<state>/STORY-MAP-NNN-<slug>.html`.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>STORY-MAP-NNN: <title></title>
  <meta name="story-map-id" content="STORY-MAP-NNN">
  <meta name="status" content="<draft|accepted|in-progress|completed|archived>">
  <meta name="problems" content="P<NNN>[,P<NNN>...]">
  <meta name="rfcs" content="RFC-<NNN>[,RFC-<NNN>...]">
  <meta name="jtbd" content="JTBD-<NNN>[,JTBD-<NNN>...]">
  <style>
    /* Grid layout for backbone × ribs × slices. Minimal embedded only;
       no inline style="" on data-bearing elements. */
    .backbone { display: grid; grid-template-columns: repeat(var(--cols), 1fr); gap: 1rem; }
    .rib { display: contents; }
    .slice { border: 1px solid #ccc; padding: 0.5rem; }
  </style>
</head>
<body>
  <h1>STORY-MAP-NNN: <title></h1>
  <section class="backbone" style="--cols: <N>">
    <header class="rib-header">
      <h2 data-rib="<rib-N-name>">Rib N</h2>
      <!-- ... -->
    </header>
    <div class="rib">
      <a class="slice" href="../../stories/<state>/STORY-NNN-<slug>.md"
         data-story-id="STORY-NNN"
         data-rfc="RFC-<NNN>"
         data-jtbd="JTBD-<NNN>"
         data-status="<draft|accepted|in-progress|done|archived>">
        Story title
      </a>
      <!-- more slices in this rib -->
    </div>
  </section>
</body>
</html>
```

**Considered alternatives**:

- **Option G — JSON-LD island** (`<script type="application/ld+json">` block carrying the trace graph). Rejected: split-source-of-truth between visual (HTML elements) and machine data (JSON island); reverse-trace helpers must parse both and reconcile drift between them.
- **Option H — YAML frontmatter in `<head>` `<meta>`** (a YAML block embedded in `<meta name="frontmatter">`). Rejected: re-introduces markdown frontmatter parser dependency for what is otherwise pure HTML; loses the structural advantage of co-locating data with the visual element.
- **Option I — Pure markdown with ASCII-art 2D grid** (the existing approach in `docs/plans/170-rfc-framework-story-map.md`). Rejected per user direction — drives the entire reason for HTML.
- **Option J — External tool format** (StoriesOnBoard XML / FeatureMap CSV / drawio). Rejected: introduces external-tool dependency; loses repo-grep + IDE-native-render properties.

`data-*` attributes (chosen) are the most idiomatic HTML for this surface: co-located with the visual element, parseable by `grep`/`xmllint --xpath`, and HTML5-compliant without parser dependency.

#### Prohibition: inline `style=""` on data-bearing elements

`<a class="slice">` and `<h2 class="rib-header">` and any element carrying `data-*` attributes MUST NOT carry inline `style=""` attributes. Rationale: keeps `grep`-as-lint deterministic (data-attribute extraction never matches a styling string); allows future project-wide stylesheet without breaking existing maps; protects against drift between presentation and semantic data. Embedded `<style>` blocks in `<head>` are permitted for layout-only rules keyed on classes; `--<custom-property>` variables for grid sizing are permitted as inline because they are layout-not-data.

Behavioural bats per ADR-052 asserts this prohibition: `grep -E '<[^>]+data-[a-z-]+="[^"]+"[^>]*style="' docs/story-maps/**/*.html` MUST return zero matches.

#### Reverse-trace helper polymorphism (architect finding 4)

The 4 generalised reverse-trace helpers (`update-problem-references-section.sh`, `update-rfc-references-section.sh`, `update-jtbd-references-section.sh`, `update-story-references-section.sh`) handle two input artefact shapes:

- **HTML maps** (story-map IDs): `grep` for `data-story-id="STORY-NNN"` / `<meta name="story-map-id" content="STORY-MAP-NNN">` / `<meta name="rfcs" content="...">` etc.
- **Markdown files with frontmatter** (story / RFC / problem / decision IDs): YAML frontmatter parse for `problems:`, `rfcs:`, `jtbd:`, `stories:` arrays.

The helper body dispatches on input-file extension (`.html` → HTML grep path; `.md` → frontmatter parse path) at the entry point, then the per-section render path is identical regardless of source-extraction method. Behavioural bats asserts NO per-section-name branching inside the helper body — the section-name is a positional argument, not a control-flow key. (Architect finding 4 confirmation criterion.)

#### Phase 2 commit-grain decomposition (revised — architect finding 3)

Updates the 8-commit decomposition in the prior 2026-05-10 amendment. Insert sub-slice 1.5 between Scaffold (sub-slice 1) and ADR-019 collision-guard (sub-slice 2). Renumbered:

1. Scaffold (`docs/story-maps/` + `docs/stories/` directories with 5 lifecycle subdirs each + READMEs anchored to JTBD-008 and JTBD-302 per the JTBD-currency-rule sibling pattern of ADR-051).
1.5. **NEW — Phase 2 Slice 0 encoding scaffold**: HTML story-map schema definition + 4 generalised reverse-trace helpers + hook exemption globs extension to `docs/story-maps/**/*.html` (architect finding 7 — hook gates fire on their own seed artefact otherwise; same slice that introduces the first HTML map). Lands alongside the ADR-060 amendment commit OR in the immediately-following commit (single-purpose grain per ADR-014).
2. ADR-019 collision-guard extension to `*.html` for `docs/story-maps/` enumeration (architect finding 7 — `max(local, origin) + 1` allocation misses HTML otherwise; STORY-MAP IDs collide silently).
3. 4 story-map skills — one commit per skill per ADR-014 (capture-story-map; manage-story-map; reconcile-story-maps; list-story-maps).
4. 4 story skills — one commit per skill per ADR-014 (capture-story; manage-story; reconcile-stories; list-stories).
5. (Reverse-trace helpers folded into sub-slice 1.5; this slot vacated.)
6. RFC frontmatter `stories:` extension + capture-rfc / manage-rfc updates — one commit covering the schema extension + skill updates + behavioural test for the empty-stories fallback.
7. Working-the-problem flow rewrite — `/wr-itil:work-problem <NNN>` rewrite per the traversal above. Behavioural test asserting the traversal end-to-end.
8. Bootstrap migration — STORY-MAP-001 (HTML) + extracted bootstrap stories (markdown) split into TWO commits per ADR-014 single-purpose grain + architect finding 3 lean: (8a) HTML scaffold + ADR-060 amendment land as the encoding-decision commit; (8b) story extraction + `stories:` populated on RFC-001/RFC-002 lands as the migration-application commit. Bootstrap stories carry I7/I8/I9/I10 retrofit + bootstrap-exemption marker per ADR-053 Bootstrapping precedent.

#### `docs/story-maps/README.md` index rendering (architect finding 7)

The README index renders one row per story-map. Helper `packages/itil/scripts/render-story-map-index.sh` parses each `<meta>` block from each HTML map (status, problems, rfcs, jtbd) plus the `<title>` element, emits a markdown table. Same advisory-exit-0 contract as the other reconcile helpers per ADR-040.

```bash
# Pseudo:
for map in docs/story-maps/*/*.html; do
  status=$(xmllint --xpath 'string(//meta[@name="status"]/@content)' "$map")
  problems=$(xmllint --xpath 'string(//meta[@name="problems"]/@content)' "$map")
  # ... emit markdown row
done
```

`xmllint` ships with macOS + GNU libxml2 on Linux; bash-only fallback (grep on `<meta>` lines) is the pure-shell alternative for adopters without libxml2. Document both paths in the helper.

#### JTBD-302 (not JTBD-007) — README-currency rule applies to `docs/story-maps/README.md`

Prior amendment incorrectly referenced JTBD-007 (Keep Plugins Current Across Projects) when the load-bearing JTBD for the README-currency rule is **JTBD-302 (Trust That the README Describes the Plugin I Just Installed)**. Per JTBD-review nitpick 1 (2026-05-12): `docs/story-maps/README.md` follows the ADR-051 sibling pattern — cites at least one current JTBD ID (JTBD-008 primary; JTBD-302 secondary); the helper-emits-markdown-table-from-data-attributes approach preserves the load-bearing-at-commit-time signal from JTBD-302 § 2026-05-04 amendment.

Replace prior amendment references to "JTBD-007" with "JTBD-302" in any Phase 2 documentation that ships during this amendment cycle.

#### Hook exemption globs (architect finding 7)

Five gate hooks currently exempt `docs/problems/*/*.md` from their respective edit gates:

- `packages/architect/hooks/architect-enforce-edit.sh`
- `packages/jtbd/hooks/jtbd-enforce-edit.sh`
- `packages/risk-scorer/hooks/risk-policy-enforce-edit.sh`
- `packages/style-guide/hooks/style-guide-enforce-edit.sh`
- `packages/voice-tone/hooks/voice-tone-enforce-edit.sh`

Each gate's exemption glob extends in sub-slice 1.5 (encoding scaffold) to also exempt:

- `docs/story-maps/**/*.html` — both flat and per-state subdir paths
- `docs/stories/**/*.md` — both flat and per-state subdir paths

P131 read-tolerance-not-write-permission still holds — these are `docs/` paths, agent write targets when invoked via the new capture/manage skills, not `.claude/`.

#### ADR-019 collision-guard extension (architect finding 7)

`packages/itil/scripts/check-id-collision.sh` (or equivalent ADR-019 surface) extends to enumerate:

- `docs/story-maps/` recursive — `.html` files matching `^STORY-MAP-[0-9]+-` filename pattern
- `docs/stories/` recursive — `.md` files matching `^STORY-[0-9]+-` filename pattern

Both lists feed the `max(local, origin) + 1` allocation per ADR-019. capture-story-map + capture-story MUST run the guard against `origin/<base>` before ID allocation. Behavioural test asserts that a same-tier collision on origin triggers the renumber.

### Phase 3 + Phase 4 in-scope amendment (2026-05-13)

User direction 2026-05-13 (post-Phase-2 SHIP, post-premature-Verifying revert): *"release and then implement phase 3 and phase 4. I never deferred those phases."* Phase 1 + Phase 2 framework code is live; Phase 3 + Phase 4 are the remaining in-scope phases. This amendment closes the agent-authored "deferred" framing that lived in `## Out of Scope` lines 535-537 and in P170's implementation-task blocks. Sibling capture [[P189]] names the class-of-behaviour at the ticket-body authoring surface (distinct from [[P184]] transition-surface and [[P179]] untracked-phase-defer).

**Reviews**: architect verdict AMEND 2026-05-13 (5 findings A1-A5 all closed in this amendment). JTBD verdict AMEND → PASS 2026-05-13 (7 findings F1-F7 all closed in this amendment text after iteration).

#### Phase 3 design (in-scope from 2026-05-13)

**P3.1 — JTBD-trace-conditional UX surface extends `/wr-itil:capture-problem` Step 1.5** (per architect finding A1). The Phase 3 capture-time JTBD-trace prompt fires from within the existing Step 1.5 dispatcher — NOT a sibling Step 1.6. Step 1.5's derive-first lexical-signal classifier (per [[P185]] derive-first refactor) extends to also resolve `jtbd_trace_value` ∈ {`absent`, `present-with-IDs`} via the same dispatch shape that already handles `type_value`. The JTBD-trace prompt fires only when **`jtbd_trace == absent` AND `type` resolved to `user-business` AND no persona is derivable from the (still-absent) cited JTBDs**. The prompt is keyed on `jtbd-trace-nullability` (nullable-field-conditional, permitted per ADR-060 line 536 — see Out of Scope) — NOT on `type` value (type-conditional, prohibited per I2). Type is an upstream-determined co-incident gate, not a control-flow key. JTBD-301 plugin-user firewall preserved: plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT carry the JTBD-trace prompt; maintainer-side `capture-problem` only. ADR-044 authority taxonomy: silent-framework (category 4) on unambiguous signal (description cites `JTBD-\d+` IDs); taste (category 5) fallback on ambiguous.

**P3.2 — Story-level WSJF is within-RFC tie-break ONLY** (per architect finding A2). Stories do NOT join `/wr-itil:work-problems` Step 3 selection. Story-WSJF resolves ties only within a single RFC's `stories:` array when execution-order is silent on which parallel-able story should fire first. Cross-RFC and cross-problem WSJF selection remains at the existing problem-level + RFC-level granularity. Protects JTBD-006 AFK orchestrator selection performance budget; preserves I5 no-WSJF-leak shape at the story-map tier; protects against the cross-surface ranking confusion this ADR's Decision Outcome already named. **Reassessment Criterion forward-look** (extends Reassessment item (d) into criterion (k) below): if story-level WSJF tie-break demand never materialises after N=4+ RFCs ship with multi-story `stories:` arrays, deprecate the field per JTBD-101 atomic-fix-friction guard.

#### Phase 4 design (in-scope from 2026-05-13)

**P4.1 — Parallel-existence with one-way reverse-trace** (per architect finding A4 + JTBD finding F2). `docs/jtbd/` and `docs/problems/` remain parallel directories post-Phase-4. Unification is via bi-directional reference, NOT directory merge: every `type: user-business` problem ticket carries `persona:` + `jtbd:` frontmatter fields citing at least one JTBD ID; every JTBD's `## Related problems` section reverse-traces user-business problems that cite it. The `update-jtbd-references-section.sh` helper landing in Phase 2 already supports this surface — Phase 4 extends it via a **lookup-table row addition** (NOT a new helper) per JTBD finding F5; reuses existing per-section timing budget so JTBD-006 orchestrator-loop performance is preserved. **NO bulk migration** of `docs/jtbd/` to `docs/problems/`; doing so would collapse persona-anchoring into the WSJF-mechanism tier and lose the inversely-coupled job-statement surface (per JTBD-review nitpick 7 preserved).

**New invariant I12 — JTBD-as-source-of-truth for persona-anchored unmet need** (load-bearing per JTBD finding F2): JTBDs MAY exist with zero `## Related problems` (a persona-anchored unmet need not yet captured as a concrete failure). `type: user-business` problem tickets MUST cite ≥1 JTBD ID — hard-block at `capture-problem` Step 1.5 when type resolves to `user-business` and `jtbd:` array is empty. This asymmetry is what makes parallel-existence semantically distinct from directory-merge: the JTBD tier is the persona-anchored upstream of the user-business problem tier, never the other way around. Confirmation criterion 9 below behaviourally enforces.

**P4.2 — `persona:` frontmatter shape: closed-enum-validated-at-commit-gate** (per architect finding A3 + JTBD finding F1). The `persona:` field is a **scalar** value (singular, not array) drawn from a closed enum: `solo-developer | tech-lead | plugin-developer | plugin-user`. Optional **scalar** `secondary-persona:` field with same enum vocabulary (preserves JTBD-008's existing frontmatter precedent — `secondary-persona: tech-lead`). **NO new persona enum value introduced under Phase 4**; the `plugin-developer` persona explicitly covers both build-the-suite AND triage-the-suite responsibilities (per JTBD finding F1). Validation fires at commit-gate via ADR-052 behavioural test — not at capture-time. Maintainer-side `/wr-itil:capture-problem` Step 1.5 extension MAY surface the persona prompt when type resolves to `user-business` AND no persona is derivable from cited JTBDs (per JTBD finding F4 — when the user has already named ≥1 JTBD ID, persona is auto-derived from the JTBDs' `persona:` and `secondary-persona:` frontmatter; no separate prompt fires). Plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` MUST NOT carry this prompt (JTBD-301 protection per JTBD finding F6).

**P4.3 — I2 invariant compatibility: nullable-field-conditional, NOT type-conditional** (per architect finding A5 + JTBD finding F6 clarifier). The `persona:` field's required-on-user-business presence is schema-validation at commit-gate; the Phase 1 I2 behavioural test (Phase 1 item 8d) extends to assert `capture-problem` / `manage-problem` / `work-problems` / `review-problems` / `transition-problem(s)` exhibit identical control-flow shape regardless of `type` value AND regardless of `persona:` field presence. **Maintainer-side / plugin-user-side asymmetry clarifier** (per JTBD finding F6): I2's control-flow uniformity applies to the maintainer-side `capture-problem` skill across `type` values. The plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml` is a SEPARATE intake surface NOT subject to I2 — never prompts for persona, JTBD, or type, regardless of report content. Maintainer triage during `/wr-itil:manage-problem` ingestion assigns those fields (per JTBD-301 no-pre-classification constraint).

**P4.4 — Cross-persona composition: backfill `secondary-persona:` on JTBD-001 + JTBD-002** (per JTBD finding F3 Option (a)). Backfill the `secondary-persona: tech-lead` frontmatter on `docs/jtbd/solo-developer/JTBD-001-...md` and `docs/jtbd/solo-developer/JTBD-002-...md` to match JTBD-008's existing precedent. Then the existing `docs/jtbd/README.md` cross-persona prose annotation (*"Jobs 001, 002, and 008 also serve this persona"*) becomes auto-derivable via the existing reverse-trace helper pattern, and problem-tier `secondary-persona:` mirrors JTBD-tier `secondary-persona:` 1:1. Land as a Phase 4 sub-task; behavioural bats asserts the README annotation is reproducible from JTBD frontmatter.

**P4.5 — Maintainer-triage job complement extension** (per JTBD finding F7 Option (b)). Extend JTBD-301 Desired Outcomes section to explicitly cover the maintainer-side complement of no-pre-classification: *"When a report lands, maintainer triage can assign persona + JTBD using the report's symptom signals without round-tripping back to the reporter."* Preserves JTBD-301 as the canonical no-pre-classification job; treats the maintainer side as the symmetric obligation. **NO new JTBD slot promoted under Phase 4**; defer to a follow-up JTBD only if the maintainer-triage job grows enough complexity post-Phase-4 to need its own desired-outcomes / persona constraints / current solutions structure.

#### Phase 3 + Phase 4 commit-grain decomposition

Phase 3 + Phase 4 ship as a multi-commit chain riding a held-changeset window per ADR-042 / P162 until graduation. Decomposition (one-purpose-per-commit per ADR-014):

1. **P3.1** — `capture-problem` Step 1.5 derive-first classifier extension for JTBD-trace-presence: new lexical-signal class covering `JTBD-\d+` ID citations; SKILL.md + behavioural bats.
2. **P3.2** — story-level WSJF tie-break key: `manage-story` SKILL.md extension to optionally write `wsjf:` into story frontmatter; `work-problems` Step 3 traversal unchanged (cross-RFC selection remains problem-level + RFC-level); behavioural bats asserts within-RFC tie-break behaviour.
3. **P4.4** — JTBD-001 + JTBD-002 `secondary-persona:` backfill (single commit; same shape as JTBD-008 precedent).
4. **P4.5** — JTBD-301 Desired Outcomes extension naming the maintainer-side complement.
5. **P4.1** — `update-jtbd-references-section.sh` lookup-table row addition for `## Related problems`; behavioural bats coverage of the new section type.
6. **P4.2 + P4.3 + I12** — `persona:` + `jtbd:` frontmatter shape on user-business problem tickets: schema spec; capture-problem Step 1.5 hard-block on I12; commit-gate validator (ADR-052 behavioural test) for persona enum + jtbd ID format; I2 test extension for `persona:` field-presence uniformity.

Each sub-slice carries paired behavioural bats per ADR-052. The held-changeset window stays paused per ADR-042 until Phase 3 + Phase 4 reach end-of-chain user verification.

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

- **Story mapping framework code (Phase 2)**: **COMPLETED 2026-05-12** — 8 skills + 2 reconcile scripts + 4 generalised reverse-trace helpers + RFC frontmatter `stories:` extension + working-the-problem flow rewrite + ADR-019 collision-guard extension. See "Phase 2 encoding amendment (2026-05-12)" subsection in Decision Outcome above for the shipped scope; awaiting full forward-dogfood verification per ADR-022 (gate held by P170 transition lifecycle). Phase 1 still uses **task** / **step** terminology for ordered work-items inside an RFC body when stories are not authored (per architect-review finding 13 — reserves "story" for Phase 2's INVEST-shaped + JTBD-anchored shape).
- **Type-as-workflow-split (rejected, load-bearing)**: type-tag is classification only, never a workflow split. **Type-conditional capture-flow differentiation is rejected** (per architect-review finding 2): any UX differentiation must be JTBD-trace-conditional or nullable-field-conditional, never type-conditional. The I2 behavioural test (Phase 1 item 8d) enforces this at the lifecycle / WSJF / skill-set surfaces; Phase 3 (in-scope from 2026-05-13 — see "Phase 3 + Phase 4 in-scope amendment (2026-05-13)" subsection in Decision Outcome above) respects the same prohibition at the UX surface via the nullable-field-conditional `jtbd-trace-nullability` keying.
- **Story-level WSJF placement (Phase 3)**: **IN-SCOPE 2026-05-13** per "Phase 3 + Phase 4 in-scope amendment (2026-05-13)" subsection in Decision Outcome above. Resolved as **within-RFC tie-break only** (P3.2); stories do NOT join `/wr-itil:work-problems` Step 3 cross-RFC / cross-problem selection. Reassessment Criterion (k) below tracks deprecation if tie-break demand never materialises.
- **JTBD unification (Phase 4)**: **IN-SCOPE 2026-05-13** per "Phase 3 + Phase 4 in-scope amendment (2026-05-13)" subsection in Decision Outcome above. Resolved as **parallel-existence with one-way reverse-trace** (P4.1) — `docs/jtbd/` and `docs/problems/` remain parallel directories; unification is via bi-directional reference + new I12 invariant (JTBD-as-source-of-truth for persona-anchored unmet need), NOT directory merge. The `persona:` frontmatter field is closed-enum-validated-at-commit-gate (P4.2); the I2 behavioural test extends to `persona:` field-presence uniformity (P4.3). Persona-anchoring stays JTBD-essential and problem-required-on-user-business (per JTBD-review nitpick 7 + new I12 invariant).
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
10. **I12 invariant — JTBD-as-source-of-truth for persona-anchored unmet need** (added 2026-05-13 amendment): a behavioural bats fixture asserts `/wr-itil:capture-problem` hard-blocks Write of a `.open.md` file with `type: user-business` AND empty `jtbd:` frontmatter array. Negative path: `type: technical` with empty `jtbd:` passes. JTBD files MAY exist with zero `## Related problems` (persona-anchored unmet need without yet-captured failure). Confirms the one-way coupling that distinguishes parallel-existence from directory-merge.
11. **Extended I2 — `persona:` field uniformity** (added 2026-05-13 amendment): the Phase 1 item 8d I2 behavioural test extends to assert capture-problem / manage-problem / work-problems / review-problems / transition-problem(s) exhibit identical control-flow shape regardless of `persona:` field presence (additive to the existing `type`-value uniformity assertion). The `persona:` field's required-on-user-business shape is schema-validation at commit-gate, NOT a control-flow key.

## Reassessment Criteria

Re-evaluate this decision when any of:

- **Adopter trace failure**: an adopter reports the framework as unusable / heavyweight / mismatched-to-their-workflow at capture-rfc time. Suggests the RFC layer adds friction the framework's own metric (problem-management cost) doesn't justify.
- **WSJF granularity friction**: RFC-level WSJF (Phase 1 default) or story-level WSJF (Phase 2) systematically miscalibrates compared to what `/wr-itil:work-problems` Step 3 actually selects. Suggests the WSJF placement decision needs revisiting at the next phase boundary.
- **JTBD unification readiness**: Phase 2 story mapping ships and reveals a clear path to unify JTBD jobs with problems (e.g., JTBD descriptions naturally decompose into stories under the RFC framework without semantic translation). Triggers Phase 4 work.
- **Trace-to-problem violation rate** (per architect-review finding 6 — measurement mechanism named): capture-rfc gate fires denials at a rate exceeding 20% of attempts, measured from the structured deny log at `logs/rfc-capture-denials.jsonl` (Phase 1 item 2). Alternative measurable proxy: RFCs that trace to a freshly-captured problem (≤24h prior) exceed 20% of total RFCs over a rolling 30-day window. Either threshold suggests either the invariant is wrong (some legitimate RFCs don't have problems), or the capture-rfc UX over-prompts. Investigate root cause; consider amending I1 to allow problem-creation-from-rfc (user creates RFC, framework offers to create a placeholder problem ticket).
- **Forward-dogfood pending** (per architect-review finding 14 + Confirmation criterion 9): if Phase 1 graduation pressure builds (delay-risk > release-risk per ADR-042 / P162) before a forward-captured RFC has run to closure, the explicit retreat is to graduate after Slice 4 with this reassessment criterion firing, NOT to skip the forward-dogfood gate. Triggers re-evaluation of held-window graduation criteria.
- **JTBD-001 amendment drift** (per JTBD-review nitpick 2 — narrower and earlier than "Adopter trace failure"): adopters report the multi-commit-coordination governance outcome added to JTBD-001 § Desired Outcomes feels heavyweight or doesn't compose with their atomic-fix workflow. Triggers JTBD-001 reassessment at the persona-constraint level before failures cascade to capture-rfc denials.
- **JTBD-101 amendment drift** (per JTBD-review nitpick 2): atomic-fix adopters report the scaling-down-friction Persona Constraint added to JTBD-101 isn't being respected by the framework — type-tag prompt fires too aggressively, or `## RFCs` reverse-trace adds noise to atomic-fix problem tickets. Triggers JTBD-101 reassessment.
- **(k) Story-level WSJF tie-break demand never materialises** (added 2026-05-13 amendment per architect finding A2 + P3.2 forward-look): after N=4+ RFCs ship with multi-story `stories:` arrays, if no within-RFC WSJF tie-break has fired (orchestrator never had to pick between two parallel-able stories), signal that the within-RFC tie-break key is dormant ceremony. Deprecate the `wsjf:` field on stories per JTBD-101 atomic-fix-friction guard.
- **(l) Phase 4 `persona:` field drift** (added 2026-05-13 amendment per architect finding N2): user-business problem tickets accumulate without `persona:` trace at rate >20% over a rolling 30-day window — signal that the maintainer-side `capture-problem` Step 1.5 extension is failing to prompt (P3.1 derive-first dispatch broken) OR that the closed-enum vocabulary is incomplete (a new persona is needed in `docs/jtbd/<persona>/`). Investigate root cause before expanding the enum (JTBD finding F1 already named `plugin-developer` as the dual-purpose build+triage persona).
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
- **ADR-069** — load-bearing-from-the-start (I1 gate enforcement; carried forward from superseded ADR-051).
- **ADR-052** — behavioural-tests default.
- **ADR-053** — plugin maturity taxonomy.
- **ADR-059** — most recent ADR shipped under the strain pattern; first retrospective RFC candidate.
- Jeff Patton, *User Story Mapping*, O'Reilly Media, 2014 — backbone/ribs/slices canonical reference.
- ITIL 4 Foundation — Change Enablement, Service Request Management, Problem Management practices (informs but does not constrain; we extend per user direction).
