# Problem 170: Problem tickets strain as fixes decompose into multiple coordinated changes — need an RFC framework that ties all changes back to problems (and unifies technical with user/business problems)

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `docs/problems/` framework was designed when each problem mapped 1:1 to a fix — one ticket, one commit (or a tight handful), one closure. As the project has matured, that mapping no longer holds. Recent examples:

- **P168** decomposed into 3 commits (ADR-059 design + Commit 1 ab73328 + Commit 2 af5447c + Commit 3 8edaf7b) plus a deferred Commit 3' under Phase 2.
- **P159** shipped Phase 1 (load-bearing commit-hook) but explicitly deferred Phase 2-3 (12-README prose-weaving + auto-fix orchestration), each of which is a separate body of work needing its own architect/JTBD/test scope.
- **P051** has 6 separate "improve" shapes (improve-skill / improve-agent / improve-hook / improve-rule / improve-template / improve-prompt) each potentially a multi-commit workstream.
- **P169** (newly captured) is itself "Phase 1 scorer-side, Phase 2 bootstrap-side" — explicitly two coordinated workstreams under one ticket.

When fixes decompose like this, the problem-ticket structure starts carrying load it wasn't designed for: it accumulates "Fix Strategy" sections that mutate as work progresses; "Investigation Tasks" turn into multi-phase work plans; the ticket body becomes a moving target rather than a stable problem-statement-plus-RCA. The structural drift surfaced concretely when P169 was authored — the ticket was largely a workstream description ("Phase 1 updates pipeline.md…", "Phase 2 ships starter catalogue…") rather than a problem statement. User observation 2026-05-04: *"P169 is not really a problem ticket. It's more of a task masquerading in the problem ticket structure."*

The classic ITIL answer is **Request for Change (RFC)** — a controlled, scoped, time-boxed change ticket that owns the work to fix a problem. Multiple RFCs can trace to one problem when the fix is large enough to need decomposition (typical for refactors, multi-package coordination, phased migrations). User direction 2026-05-04 names two non-ITIL extensions:

1. **All RFCs MUST trace to a problem** (no orphan RFCs). ITIL allows RFCs to come from non-problem sources (continuous improvement, opportunity, regulatory mandate); Windy Road's framework treats every change as solving some problem — even a feature build is a customer's problem. The trace-to-problem invariant makes WSJF prioritisation work uniformly across the project.

2. **Technical problems and user/business problems are treated identically** in the framework. ITIL's Service Strategy / Demand Management splits "Service Request" from "Problem"; this project collapses them. A bug, a missing feature, a UX gap, an adopter's pain point, a future JTBD job — all are problems. The /wr-itil:capture-problem and /wr-itil:manage-problem skills already accept user/business problems alongside technical bugs (P078 capture-on-correction explicitly anchors on user-experience signal). Future direction: unify JTBD job statements with the problem framework so that a JTBD-001 (enforce governance) jobs-to-be-done description IS a problem ticket of class "user/business" — same WSJF, same RFC decomposition, same lifecycle.

**Story decomposition via Jeff Patton's User Story Mapping** is the candidate vehicle for breaking an RFC into stories. Backbone (the spine of the user journey) + ribs (the sub-flows) + slices (the time-ordered MVP / version-2 / version-N slices). RFC owns the scope; stories are the INVEST-shaped work items inside it; each story is JTBD-anchored where applicable (which job does this story serve?). ADRs continue to capture decisions — an RFC may reference one or more ADRs (the ADR is the "how we decided", the RFC is the "what we're shipping").

## Symptoms

- Problem tickets accumulate multi-phase Fix Strategy sections that drift from "what's the problem" to "how are we executing" — `docs/problems/168-...verifying.md` is the canonical example (3-commit Fix Strategy with Smoke-Test Finding sub-sections).
- New tickets are captured that are largely workstream descriptions rather than problem statements — P169 is the first explicitly-flagged instance.
- The lifecycle states (`Open` / `Known Error` / `Verifying` / `Closed`) don't have natural placeholders for "Phase 1 closed, Phase 2 in flight" — the workaround is to capture Phase 2 as a sibling problem (e.g. P169 sibling to P168) but this loses the parent-child trace structure.
- Deferred sub-work loses visibility — P159's deferred Phase 2-3 work sits in the ADR-051 "Out of scope" section but isn't WSJF-ranked as standalone items.
- ADR-014 single-commit-grain plus held-changeset dogfood + ADR-042 graduation criteria already imply RFC-shaped change management (multi-commit coordinated change with explicit reinstate trigger), but the framework isn't named or formalized.
- JTBD job statements in `docs/jtbd/` describe user/business problems but live in a parallel hierarchy from `docs/problems/` — the unification gap is observable but not closed.

## Workaround

Currently:
- **Multi-phase fixes ride one problem ticket with a multi-section Fix Strategy** (P168 model). Works for 2-3 commit decompositions; strains beyond that.
- **Sibling problem tickets capture explicitly-deferred phases** (P169 as P168 follow-up). Works but loses parent-child trace; future re-derivation of "what work was needed for X" requires graph traversal across tickets.
- **Workstream-shaped problem tickets are accepted with a note** (P169 with "this is task-shaped" callout). Defers the structural fix.

None of these workarounds compose well with WSJF prioritisation when the project grows. /wr-itil:work-problems iter loops select by WSJF; if Phase 2 is a sub-work-item, it should compete for WSJF attention as a first-class entity, not hide inside a parent ticket's body.

## Impact Assessment

- **Who is affected**: (deferred to investigation) — primary: project maintainer (cost of structural drift); secondary: every adopter trying to consume the Windy Road problem-management framework as a model (adopters inherit the same scaling pain).
- **Frequency**: (deferred to investigation) — likely Possible to Likely; surfaced N=4 times in current session (P168 / P159 / P051 / P169) and ramping with project complexity.
- **Severity**: (deferred to investigation) — likely Moderate; not blocking ship, but compounding toil.
- **Analytics**: (deferred to investigation) — tickets in `docs/problems/` with multi-phase Fix Strategy sections OR explicit "Phase N" language; ratio of sibling-ticket-trees to standalone tickets.

## Root Cause Analysis

### Investigation Tasks

These are genuine RCA tasks — validating the proposed framing, surfacing additional examples, confirming base rate. The decision-shaped and implementation-shaped tasks that previously lived here have moved to **Implementation Tasks** below (per user observation 2026-05-04: implementation tasks were masquerading as investigation tasks — the very strain pattern this ticket addresses).

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Architect review of ADR-060 (proposed → accepted): validate design space, considered-alternatives rejection rationale, Phase 1 scope, confirmation + reassessment criteria. Surface design gaps before implementation work begins.
- [ ] JTBD review of ADR-060: validate JTBD-001 / JTBD-008 / JTBD-101 framing; identify any persona-jobs missed; assess whether a new JTBD ("decompose-fix-into-coordinated-changes" or similar) is needed for the persona-job-to-be-done that the RFC framework explicitly serves.
- [ ] Reproduction of strain pattern: confirm the N=4 examples (P168 / P159 / P051 / P169) are accurately characterised; sweep `docs/problems/` for additional instances; if base rate is higher than estimated, the strain pattern has been costing more than session-surfacing implies.
- [ ] Base-rate investigation: count multi-commit problem tickets over last 90 days; count sibling-tree captures (parent → workstream child); count tickets with explicit "Phase N" language in body. Validates the urgency rating.
- [ ] Adopter-impact investigation: any adopter currently consuming the Windy Road problem-management model that has independently surfaced the strain pattern? (Search GitHub Discussions / issues across adopter repos for "phase" / "RFC" / "multi-commit problem" mentions.) If yes, framework adoption is a customer-facing concern, not just an internal one.

## Implementation Tasks (workaround section — until RFC framework arrives)

**Meta-recursive bootstrap acknowledgement**: P170 is the first concrete instance of the strain pattern that surfaced as a captured ticket — yet P170's own implementation work needs an RFC framework that doesn't exist yet. Until Phase 1 ships, this section is the workaround: implementation tasks live here in the problem-ticket body (the very anti-pattern P170 names), tagged explicitly so they're not mistaken for RCA work. Once the RFC framework lands (Phase 1), these tasks migrate to a Phase-1 RFC traced to P170, and this section gets replaced with a forward pointer.

**Decisions discharged by ADR-060** (status: proposed):

- ✓ 4-tier hierarchy (Problem → ADR → RFC → Story).
- ✓ I1 trace-to-problem invariant + I2 uniform-problem-ontology invariant.
- ✓ RFC vs ADR boundary (ADR = how we decided; RFC = what we're shipping).
- ✓ Backwards-compat path: P168 retrospectively migrates to RFC-001 as Phase 1 dogfood; P159 / P051 / P169 grandfathered unless cost-of-migration is reassessed at later phase boundaries.
- ✓ JTBD unification roadmap (Phase 4 deferred; sequencing recorded as direction).
- ✓ RFC lifecycle states (`proposed` / `accepted` / `in-progress` / `verifying` / `closed`).

**Decisions deferred to Phase 1 architect review** (open during implementation):

- ⌛ RFC filename prefix grammar (clashes with `docs/risks/R<NNN>` shape — `RFC<NNN>` or `C<NNN>` candidates pending architect call).
- ⌛ Story-mapping directory layout (`docs/rfcs/<RFC-NNN>/stories/` vs embedded vs separate `docs/stories/`).
- ⌛ WSJF placement (RFC-level vs story-level vs both).
- ⌛ AskUserQuestion shape for `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc` (which decisions are direction-setting vs framework-mediated mechanical per ADR-044).

**Phase 1 implementation tasks** (per ADR-060 § Scope, ride a held-changeset dogfood window per ADR-042 / P162):

- [ ] Scaffold `docs/rfcs/` directory + `README.md` index.
- [ ] Build `/wr-itil:capture-rfc` skill (lightweight aside per ADR-032; mandatory `--problem P<NNN>` flag, gate-enforced at I1).
- [ ] Build `/wr-itil:manage-rfc` skill (heavyweight intake + lifecycle management).
- [ ] Define RFC frontmatter shape (`status`, `problems`, `adrs`, `reported`, `decision-makers`).
- [ ] Build `packages/itil/scripts/reconcile-rfcs.sh` (diagnose-only mechanical drift detector for `docs/rfcs/README.md`).
- [ ] Build `packages/itil/bin/wr-itil-reconcile-rfcs` `$PATH` shim per ADR-049.
- [ ] Behavioural bats coverage per ADR-052 for capture-rfc, manage-rfc, reconcile-rfcs.
- [ ] Type-tag introduction on problem frontmatter (`type: technical` | `type: user-business`); existing tickets default to `technical`; capture-problem AskUserQuestion gains the type prompt.
- [ ] Auto-maintained `## RFCs` section on problem tickets (refresh contract analogous to P094).
- [ ] Retrospective migration of P168 to RFC-001 (first dogfood pass; validates framework on a known multi-commit decomposition).
- [ ] Held-changeset graduation evaluation per ADR-042 / P162 counterfactual risk assessment.

**Phase 2 implementation** (deferred until Phase 1 dogfood evidence informs design):

- [ ] Story-mapping templates (backbone / ribs / slices per Patton).
- [ ] `/wr-itil:capture-story` or `/wr-itil:map-stories <RFC>` skill.
- [ ] INVEST checks on story shape.
- [ ] JTBD trace gate on stories (story names the job-to-be-done it serves).
- [ ] Story-to-RFC trace surface; story lifecycle state.
- [ ] WSJF refresh integration if story-level ranking selected.

**Phase 3 implementation** (deferred):

- [ ] Beyond-type-tag user/business problem UX (e.g. JTBD trace prompt at capture-problem time when type=`user-business`).

**Phase 4 implementation** (deferred):

- [ ] JTBD-as-problem unification — migration scripts; possible deprecation of `docs/jtbd/` if redundant under unified ontology.

**Cross-phase work**:

- [ ] Dogfood pass per phase: convert existing live tickets through the new framework; verify lifecycle transitions; check WSJF behaviour; confirm capture skills compose without redundant ceremony.
- [ ] Stress-test: run a multi-phase ticket (P168), a feature-shaped ticket (P162), and an observation-only ticket (P161) through the new shape end-to-end; check the framework distinguishes them without artificial scaffolding.

When Phase 1 ships, replace this entire section with a forward pointer to `RFC-NNN-rfc-framework-phase-1-bootstrap` (or equivalent ID). Phases 2-4 then track as separate RFCs traced back to P170.

## Dependencies

- **Blocks**: (none directly — but the longer this is deferred, the more retroactive migration cost accumulates as P168/P159/P051/P169-style multi-phase tickets pile up)
- **Blocked by**: (none — the design space is well-scoped and the user direction is clear)
- **Composes with**: P014 (ADR-032 governance-skill-aside-invocation; capture-rfc / manage-rfc would be siblings to capture-problem / manage-problem under that pattern), P051 (improve shapes — many of those would naturally become RFCs), P078 (capture-on-correction; corrections may surface RFC-shaped work, not just problem-shaped), P033 (persistent risk register — RFC framework should compose with risk-scoring at the RFC level, not just commit/push/release), P162 (dogfood-graduation criteria — RFCs are exactly the surface that should ride held-changeset dogfood windows), P169 (this ticket's first concrete victim — once RFC framework lands, P169 retroactively becomes an RFC traced to P168 + this ticket).

## Related

(captured via /wr-itil:capture-problem; expand at next investigation)

- ADR-014 (commit grain — RFCs decompose into ADR-014-grain commits)
- ADR-032 (governance-skill aside-invocation pattern — capture-rfc + manage-rfc would follow the same shape)
- ADR-042 (held-area + auto-apply — RFCs ride held-changeset windows naturally)
- ADR-051 (load-bearing-from-the-start — applies to RFC-introducing controls themselves)
- ADR-052 (behavioural tests — RFC stories carry behavioural acceptance)
- ADR-059 (consume-catalog + bootstrap-from-reports — first multi-commit ADR landed under the strain pattern this ticket addresses)
- JTBD-001 (enforce-governance), JTBD-008 (evolve-framework), JTBD-101 (plugin-developer)
- P168 / P169 (substantive design + operationalisation pair — first explicit Problem→workstream-decomposition example session-surfaced)
- P159 (Phase 1 shipped, Phase 2-3 deferred — second-most-pressing example of the pattern)
- P051 (6 improve shapes — third-most-pressing example)
- User direction recorded 2026-05-04: *"Capture the actual problem as P170. The ADR captures how we decide to solve it (and considered alternatives). All RFCs MUST be tied to a problem. We go beyond ITIL in this way. We consider technical problems and inherent user/business problems in the same way. In fact, even JTBD describes problems that we somehow (in the future) need to unify with the problem management framework."*
- Jeff Patton, *User Story Mapping* (O'Reilly, 2014) — backbone/ribs/slices canonical reference
- ITIL 4 Foundation: Change Enablement practice (RFC lifecycle), Service Request Management practice (request shape), Problem Management practice (root-cause shape) — informs but does not constrain (we extend per user direction)
