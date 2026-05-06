# Problem 170: Problem tickets strain as fixes decompose into multiple coordinated changes — need an RFC framework that ties all changes back to problems (and unifies technical with user/business problems)

**Status**: Open
**Reported**: 2026-05-04
**Priority**: 8 (Medium) — Impact: 2 (Minor) x Likelihood: 4 (Likely) — re-rated 2026-05-05 (was 3 (Low) deferred); strain pattern N=4 in single session = Likely; impact is dev-tooling / framework-integrity slow-burn (not npm publish disruption) = Minor
**Effort**: XL — re-rated 2026-05-05 (was M deferred); Phase 1 alone is XL (2 new skills, type-tag schema migration with capture-problem AskUserQuestion update + I2 behavioural test, P168 retrospective RFC migration, behavioural bats coverage, held-changeset window) + ADR-060 amendments before code
**WSJF**: 1.0 — (8 × 1.0) / 8
**Type**: technical

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

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems. **Done 2026-05-05**: Priority 3 → 8 (Medium); Effort M → XL. See header.
- [x] Architect review of ADR-060 (proposed → accepted): validate design space, considered-alternatives rejection rationale, Phase 1 scope, confirmation + reassessment criteria. Surface design gaps before implementation work begins. **Done 2026-05-05** via `wr-architect:agent`. Verdict **AMEND** — 14 findings (2 critical: I1 enforcement contradictory, I2 needs load-bearing test). See `## Review Findings (2026-05-05)`.
- [x] JTBD review of ADR-060: validate JTBD-001 / JTBD-008 / JTBD-101 framing; identify any persona-jobs missed; assess whether a new JTBD ("decompose-fix-into-coordinated-changes" or similar) is needed for the persona-job-to-be-done that the RFC framework explicitly serves. **Done 2026-05-05** via `wr-jtbd:agent`. Verdict **AMEND with 1 critical block** — JTBD-008 phantom anchor (does not exist in `docs/jtbd/`). See `## Review Findings (2026-05-05)`.
- [ ] Reproduction of strain pattern: confirm the N=4 examples (P168 / P159 / P051 / P169) are accurately characterised; sweep `docs/problems/` for additional instances; if base rate is higher than estimated, the strain pattern has been costing more than session-surfacing implies.
- [ ] Base-rate investigation: count multi-commit problem tickets over last 90 days; count sibling-tree captures (parent → workstream child); count tickets with explicit "Phase N" language in body. Validates the urgency rating.
- [ ] Adopter-impact investigation: any adopter currently consuming the Windy Road problem-management model that has independently surfaced the strain pattern? (Search GitHub Discussions / issues across adopter repos for "phase" / "RFC" / "multi-commit problem" mentions.) If yes, framework adoption is a customer-facing concern, not just an internal one.

## Review Findings (2026-05-05)

Both `wr-architect:agent` and `wr-jtbd:agent` returned **AMEND** verdicts on ADR-060 (proposed). Findings consolidated below; the full review prose is preserved in this session's transcript. ADR-060 must carry the load-bearing amendments below before moving `proposed → accepted` and before any Phase 1 implementation begins.

### Architect verdict: AMEND (14 findings, 2 critical)

**Critical (block acceptance)**:

1. **I1 enforcement contradictory** — Decision Outcome (line 83) says "hard-block at capture-rfc, advisory-with-escalation at manage-rfc lifecycle transitions"; Confirmation item 2 (line 122) echoes the advisory escalation. ADR-051's load-bearing-from-the-start posture is incompatible with advisory-with-escalation at the manage-rfc surface — the composite reads as "load-bearing where convenient." Resolve to one shape: **hard everywhere** (recommended) or **two-phase load-bearing with a bounded escape at irreversible transitions** (e.g. hard-block at `accepted → in-progress`, advisory only at `→ closed`).

2. **I2 needs load-bearing behavioural test, not prose prohibition** — I2 (uniform problem ontology) is stated as load-bearing, but Phase 1 introduces the `type` tag and Phase 3 (out-of-scope) explicitly contemplates capture-flow differentiation by type-tag. Without a behavioural test asserting capture-problem / manage-problem / work-problems / review-problems exhibit identical control-flow shape regardless of `type`, "differs slightly at capture" leaks into "differs at lifecycle" leaks into "differs at WSJF" by graceful drift. Add to Confirmation: a behavioural test asserting no skill carries a branch keyed on `type`. Reject Phase 3 type-conditional capture-flow differentiation in Out-of-Scope; any UX differentiation must be JTBD-trace-conditional or nullable-field-conditional, not type-conditional.

**Amend (must close before acceptance)**:

3. **Resolve 3 of 4 deferred decisions in-ADR** (P170 lines 80–83 list four "deferred to Phase 1 architect review" decisions; three should resolve now to unblock Phase 1 implementer + close the inverse-P078 trap):
   - **RFC filename grammar** = `RFC-<NNN>` (matches `ADR-<NNN>` form; `R<NNN>` collides with `docs/risks/`; bare `<NNN>` collides with problem IDs).
   - **WSJF placement** = RFC-level for Phase 1; story-level deferred to Phase 2 with story-mapping infrastructure (story-level WSJF without stories is structurally impossible; the reassessment criterion "WSJF granularity friction compared to what `/wr-itil:work-problems` Step 3 actually selects" needs a baseline to measure against).
   - **AskUserQuestion authority classes** for capture-rfc / manage-rfc per ADR-044 taxonomy: capture-rfc = direction-setting (problem trace) + taste (title / scope summary) + silent-mechanical (ID allocation, file write, frontmatter). Spell out per inverse-P078 / P132 — defensive over-asking accumulates when the contract isn't named.
   - Story-mapping directory layout legitimately stays deferred — depends on Phase 2 work and no Phase 1 surface touches it.

4. **RFC-vs-ADR boundary needs gloss** — at "RFC may reference ≥ 1 ADRs (decisions made during execution)" risk: if every coordination decision spawns an ADR, RFC-internal decomposition pollutes `docs/decisions/`. Recommended one-line addition to Decision Outcome: *"An RFC's internal decomposition (story breakdown, phase ordering) does not create ADRs by default; ADRs created during RFC execution capture decisions with scope outside the RFC."*

5. **Confirmation item 5 ("no semantic loss") not measurable** — sharpen to six concrete clauses (a)-(f) per architect detailed finding 5: every commit referenced under RFC-001's commit list; Smoke-Test Findings map to RFC-001 verification entries; deferred Commit 3' named under RFC-001's deferred-scope OR captured as follow-up RFC stub OR explicitly listed in P168's continuing scope; P168 lifecycle state preserved (`verifying`); ADR-059 references propagate; no information that was retrievable from P168 pre-migration is unretrievable post-migration via the RFC-001 + P168 pair.

6. **Reassessment criterion ">20% trace-violation rate" needs measurement mechanism** — capture-rfc hard-block emits no telemetry by default. Either: (a) extend Phase 1 item 2 to emit a structured deny log entry to `logs/rfc-capture-denials.jsonl`; or (b) rephrase the reassessment criterion to a measurable proxy ("RFCs that trace to a freshly-captured problem (≤24h prior) exceed 20% of total RFCs" — surfaces the "capture problem just to satisfy gate" anti-pattern without requiring deny logs).

7. **Decision Drivers list missing 3 ADRs** — add **ADR-010** (amended skill-granularity — capture-rfc + manage-rfc are two skills, not one), **ADR-013** (governance interaction — manifest / discoverability), **ADR-019** (next-ID compute — RFC ID allocation must compose with existing convention). ADR-018 + ADR-024 are weaker signals; add only if they constrain Phase 1 surfaces.

8. **ADR-014 commit-grain composition needs explicit text** — RFCs span multiple ADR-014-grain commits by design. Add subsection naming: (a) commit messages reference RFC-NNN via trailer convention (specify trailer name); (b) one commit advances at most one RFC; (c) one RFC = N × ADR-014-grain commits, ordered.

9. **Phase 1 missing commit-message RFC trailer convention + hook recognition** — the auto-maintained `## RFCs` reverse-trace section (Confirmation item 3) implicitly requires either commit-message parsing or registration at lifecycle transitions. Make the choice explicit at Phase 1 design time. **Add Phase 1 item 12: commit-message RFC trailer convention + hook recognition.**

10. **Split Phase 1 item 8 (type-tag schema migration)** into 8a (schema added to frontmatter spec, no migration), 8b (existing tickets bulk one-shot migrate to default `type: technical`), 8c (capture-problem AskUserQuestion adds type prompt), 8d (I2 behavioural test ships at the same time as the tag — load-bearing-from-the-start enforcement). Without 8d, item 8 ships I2 in name only.

11. **Mark Phase 1 item 9 (P168 retro migration) as dogfood pass, not framework deliverable** — re-number under a separate "Phase 1 dogfood pass" heading so held-changeset graduation criteria apply only to the framework, not the dogfood evidence.

12. **Held-changeset window atomicity for RFC-shaped changesets** — Phase 1 item 11 says held window per ADR-042 / P162. ADR-042 doesn't specify whether RFC-shaped held windows graduate atomically (entire commit chain) or per-commit. Spell out: *"RFC-shaped held changesets graduate atomically — the entire RFC-001 commit chain either ships or doesn't. ADR-042's auto-apply is paused until RFC-001 reaches `closed` status."*

13. **Phase 1 / Phase 2 boundary at risk from "story" terminology bleed** — when implementer hits P168's commit-decomposition mid-Phase-1 dogfood, they will feel pressure to name the commits "stories" prematurely. Reserve "story" for Phase 2's INVEST-shaped + JTBD-anchored shape; introduce a Phase 1 placeholder noun (`task` or `step`) for ordered work-items inside an RFC.

14. **Forward-dogfood requirement closes bootstrap circularity** — RFC-001 = P168 retro migration demonstrates the framework can *represent* a known multi-commit decomposition, not that it *produces* such decompositions in forward use. Add to reassessment / graduation: *"Framework validates only on forward dogfood — at least one RFC must be captured before its first commit and run to closure under the framework before adopter release. Retroactive migration (RFC-001) demonstrates representability, not framework correctness."*

**Optional (architect's call)**: add **Option G** (GitHub Discussions / Issues+Projects as RFC home) to Considered Options with rejection rationale (docs-driven monorepo with RFCs as first-class versioned artefacts; routing through GitHub Discussions creates a second source of truth and breaks gate-enforceability on I1). Mention `changesets`/`@changesets/cli` rejection in same option (per-package version-bump metadata is not coordination metadata). Sibling alternative for "Notion-style external tool" folds into Option G.

### JTBD verdict: AMEND with 1 critical block (8 findings)

**Critical (block acceptance)**:

1. **JTBD-008 phantom anchor** — ADR-060 lines 32 + 146 cite `JTBD-008 (Evolve the Framework)` as "meta-driver"; this JTBD does **not exist** in `docs/jtbd/`. Solo-developer index runs JTBD-001 → JTBD-007. P170 line 139 also references JTBD-008. Hallucinated ID. Two clean shapes:
   - **(A) Drop the anchor** (recommended): the meta-architectural concern (self-recursive framework evolution) is more naturally captured as an ADR-040-class invariant than a persona-anchored job. Remove JTBD-008 from ADR-060 + this ticket.
   - **(B) Promote it**: draft `docs/jtbd/solo-developer/JTBD-008-evolve-framework.proposed.md` BEFORE ADR-060 moves accepted. Job-statement candidate: *"When the framework I'm using to manage problems hits its own scaling limits, I want the framework's evolution path to compose with its own primitives, so my framework-improvement work rides the same WSJF / lifecycle / capture flow as everything else."*

**Amend (must close before acceptance)**:

2. **JTBD-001 framing overclaims** — JTBD-001 is about *per-edit hook enforcement* (every edit reviewed against policy, no manual step, <60s reviews). RFC framework adds NEW multi-commit-coordination governance. ADR-060 line 31 currently treats JTBD-001 as if it already captures multi-commit work. Amend: *"RFC framework **extends** JTBD-001's scope from per-edit governance to multi-commit coordinated-change governance. (JTBD-001 will need amendment to add a multi-commit-coordination outcome before this ADR moves accepted, or sibling JTBD per finding 5.)"* + add to JTBD-001 § Desired Outcomes: *"Multi-commit coordinated changes are governed at the change-set level, not just per-edit."*

3. **JTBD-101 friction-add risk unacknowledged** — JTBD-101 anchors on *"clear template, clear patterns, scale up to complexity"*. For atomic-fix adopters, RFC ceremony introduces friction without proportional value (their fixes were never multi-commit). Capture-problem AskUserQuestion type-prompt is the load-bearing surface. Amend ADR-060 line 30 to acknowledge bifurcation: primary fit for complex multi-commit adopters; for atomic-fix adopters, **type-tag prompt is friction-add** at capture-problem time. Add to JTBD-101 § Persona Constraints: *"Plugin / framework ceremony must scale down to atomic-change adopters, not only up to complex multi-commit adopters."*

4. **Three persona-jobs materially affected and unmentioned** — add to ADR-060 § Decision Drivers:
   - **JTBD-006 (Progress the Backlog While I'm Away)** — AFK orchestrator selects by WSJF. Phase 1's deferred WSJF placement is a JTBD-006 risk. Phase 1 confirmation should include *"work-problems iter still selects from `docs/problems/` correctly when RFC layer exists"* until WSJF placement lands. (Architect finding 3 resolves WSJF placement = RFC-level Phase 1; this confirms protection.)
   - **JTBD-301 (Report a Problem Without Pre-Classifying It)** — plugin-user persona has explicit *no-pre-classification* constraint. Type-tag prompt MUST fire on maintainer-side `/wr-itil:capture-problem` only; **never** on plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml`. Maintainer triage assigns type during `/wr-itil:manage-problem` intake.
   - **JTBD-201 (Restore Service Fast with an Audit Trail)** — incident → problem handoff. Incident-driven problems default to `type: technical` (no type prompt during incident handoff); RFC trace-to-problem invariant composes naturally with incident-driven problems.

5. **NEW JTBD candidate: `decompose-fix-into-coordinated-changes`** — per P170 investigation task #3 explicit ask. JTBD lens says **yes**, draft a new JTBD before ADR-060 moves accepted. Distinct from JTBD-001 (per-edit) / JTBD-006 (AFK selection) / JTBD-101 (plugin-extension shape). Proposed slot: **JTBD-008** (if Option A above is taken — i.e. the slot vacated by dropping the phantom anchor) OR **JTBD-009** (if Option B is taken). Persona: solo-developer (Tom) primary, tech-lead secondary. Draft job statement: *"When my fix to a problem decomposes into multiple coordinated changes (a refactor across packages, a phased migration, a framework evolution), I want the work to be scoped, time-boxed, and traced to its driving problem at a level above individual commits, so each sub-workstream competes for WSJF attention as a first-class entity rather than hiding inside a parent ticket's body."*

**Nitpick (consider, defer-acceptable)**:

6. **I2 clarifier**: I2 holds at *mechanism level* (skills/lifecycle/WSJF persona-agnostic) but is silent on *attached metadata* (user/business problems may carry persona-anchoring metadata that technical problems do not). Add one-line: *"I2 makes mechanism uniform. Asymmetry, if any, lives in the schema's optional fields, not in the workflow."*

7. **Phase 4 JTBD-unification category-error risk** — JTBD job statements are persona-anchored by construction; problem tickets are not always persona-anchored. Phase 4 must answer: does every user-business problem ticket carry a `persona:` frontmatter field? Add to future-direction text.

8. **RFCs should trace to a JTBD when driving problem is `type: user-business`** — Phase 1 deferred; Phase 2 story-mapping work decides whether JTBD trace lives at RFC level, story level, or both. Add deferred note to Phase 1.

### Adopter-impact assessment for Phase 1 graduation (JTBD lens)

- **JTBD-101 atomic-fix adopters**: friction-add. Type-tag prompt fires on every problem capture; `--problem` flag enforcement on capture-rfc; auto-maintained `## RFCs` section adds noise to atomic-fix tickets. Held-changeset graduation criteria + 20% violation-rate reassessment are the right gates.
- **JTBD-101 multi-commit-coordination adopters**: value-add. The persona ADR-060 was written for; structured replacement for sibling-tree workaround / multi-phase Fix Strategy bodies / scope drift.
- **JTBD-301 plugin-user**: silent if type-tag prompt is correctly scoped to maintainer-side capture-problem. **Held-window must verify this scoping** — leak to user-side intake breaks JTBD-301.
- **JTBD-006 AFK orchestrator**: protected by WSJF-placement-resolution = RFC-level Phase 1 (architect finding 3).

### Recommended Phase 1 graduation gates (in addition to ADR-060 § Confirmation)

1. Verify type-tag prompt fires on maintainer-side `/wr-itil:capture-problem` only — never on plugin-user-side intake or upstream-classifier paths.
2. Verify `/wr-itil:work-problems iter` still selects from `docs/problems/` correctly during the bootstrap window where RFCs exist but story-level WSJF is unresolved (JTBD-006 protection).
3. Track `--problem` flag denial rate during dogfood; if >20% by Phase 1 closure, trigger reassessment immediately rather than waiting for adopter signal.

### Net-net actionable list before ADR-060 moves `proposed → accepted`

1. Resolve I1 enforcement contradiction (architect finding 1).
2. Add I2 behavioural test to Confirmation; reject Phase 3 type-conditional capture-flow differentiation (architect finding 2).
3. Resolve RFC ID grammar = `RFC-<NNN>`; WSJF placement = RFC-level Phase 1; AskUserQuestion authority classes for capture-rfc + manage-rfc (architect finding 3).
4. Add RFC-internal-coordination-doesn't-spawn-ADR gloss (architect finding 4).
5. Sharpen "no semantic loss" to six concrete clauses (architect finding 5).
6. Add measurement mechanism for trace-violation rate (architect finding 6).
7. Add ADR-010 / ADR-013 / ADR-019 to Decision Drivers (architect finding 7).
8. Add commit-grain composition subsection (architect finding 8).
9. Add Phase 1 item 12 — commit-message RFC trailer convention + hook recognition (architect finding 9).
10. Split Phase 1 item 8 into 8a/8b/8c/8d (architect finding 10).
11. Mark Phase 1 item 9 as dogfood pass (architect finding 11).
12. Spell out RFC-shaped held-window atomicity (architect finding 12).
13. Reserve "story" for Phase 2; introduce `task`/`step` placeholder for Phase 1 (architect finding 13).
14. Add forward-dogfood requirement (architect finding 14).
15. ~~**Decide JTBD-008 fate**: Option A (drop) or Option B (draft) — JTBD finding 1 critical block.~~ **Resolved 2026-05-05** (per `docs/plans/170-rfc-framework-story-map.md` B3.T1): user direction = **Option A (drop the phantom anchor)**. JTBD-008 references removed from ADR-060 in commit `e646c17`; P170 ## Related section updated (line 254). The slot is now free for the new JTBD (item 19).
16. Amend JTBD-001 framing + add multi-commit-coordination outcome to JTBD-001 (JTBD finding 2).
17. Acknowledge JTBD-101 atomic-fix friction in ADR-060 + amend JTBD-101 Persona Constraints (JTBD finding 3).
18. Add JTBD-006 / JTBD-201 / JTBD-301 to ADR-060 Decision Drivers (JTBD finding 4).
19. ~~**Decide new JTBD fate**: draft JTBD-008 (`decompose-coordinated-changes`) per JTBD finding 5 if Option A above is taken (frees the slot); otherwise JTBD-009 if Option B is taken.~~ **Resolved 2026-05-05**: per item 15 outcome (Option A — drop), the new JTBD `decompose-fix-into-coordinated-changes` claims the freed slot **JTBD-008**. Drafting deferred to Slice 2 of `docs/plans/170-rfc-framework-story-map.md` (B3.T3) — slot is reserved; no orphan ID gap for future readers.
20. (Nitpick) I2 clarifier; (nitpick) Phase 4 category-error caveat; (nitpick) RFC-to-JTBD trace deferred note (JTBD findings 6-8).
21. (Optional) Add Option G to Considered Options (architect optional).

## Implementation Tasks (workaround section — until RFC framework arrives)

**Meta-recursive bootstrap acknowledgement**: P170 is the first concrete instance of the strain pattern that surfaced as a captured ticket — yet P170's own implementation work needs an RFC framework that doesn't exist yet. Until Phase 1 ships, this section is the workaround: implementation tasks live here in the problem-ticket body (the very anti-pattern P170 names), tagged explicitly so they're not mistaken for RCA work. Once the RFC framework lands (Phase 1), these tasks migrate to a Phase-1 RFC traced to P170, and this section gets replaced with a forward pointer.

**Decisions discharged by ADR-060** (status: proposed):

- ✓ 4-tier hierarchy (Problem → ADR → RFC → Story).
- ✓ I1 trace-to-problem invariant + I2 uniform-problem-ontology invariant.
- ✓ RFC vs ADR boundary (ADR = how we decided; RFC = what we're shipping).
- ✓ Backwards-compat path: P168 retrospectively migrates to RFC-001 as Phase 1 dogfood; P159 / P051 / P169 grandfathered unless cost-of-migration is reassessed at later phase boundaries.
- ✓ JTBD unification roadmap (Phase 4 deferred; sequencing recorded as direction).
- ✓ RFC lifecycle states (`proposed` / `accepted` / `in-progress` / `verifying` / `closed`).

**Decisions resolved by architect review 2026-05-05** (in-ADR amendment recommended; see `## Review Findings (2026-05-05)` finding 3):

- ✓ **RFC filename prefix grammar** = `RFC-<NNN>` (matches `ADR-<NNN>` form; no collision with `docs/risks/R<NNN>`; bare `<NNN>` would collide with problem IDs).
- ✓ **WSJF placement** = RFC-level for Phase 1 (story-level deferred to Phase 2 with story-mapping infrastructure; story-level WSJF without stories is structurally impossible).
- ✓ **AskUserQuestion authority classes** for capture-rfc / manage-rfc per ADR-044 taxonomy: capture-rfc = direction-setting (problem trace) + taste (title / scope summary) + silent-mechanical (ID allocation, file write, frontmatter). Per inverse-P078 / P132, spell out so SKILL implementation is constrained.

**Decisions still deferred to Phase 1 implementation**:

- ⌛ Story-mapping directory layout (`docs/rfcs/<RFC-NNN>/stories/` vs embedded vs separate `docs/stories/`) — depends on Phase 2 story-mapping work; no Phase 1 surface touches it.

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

- **Story map (planning artefact)**: `docs/plans/170-rfc-framework-story-map.md` — Patton-style user story map decomposing P170/ADR-060 Phase 1 work into 6 slices anchored to JTBD-001 (extended scope). Created 2026-05-05 under user direction "continue with expanded scope, but plan it out properly". jtbd-review verdict PASS with 3 nitpick amendments applied. Slice 1 ("ADR-060 ready for accept") is the this-session candidate.
- ADR-014 (commit grain — RFCs decompose into ADR-014-grain commits)
- ADR-032 (governance-skill aside-invocation pattern — capture-rfc + manage-rfc would follow the same shape)
- ADR-042 (held-area + auto-apply — RFCs ride held-changeset windows naturally)
- ADR-051 (load-bearing-from-the-start — applies to RFC-introducing controls themselves)
- ADR-052 (behavioural tests — RFC stories carry behavioural acceptance)
- ADR-059 (consume-catalog + bootstrap-from-reports — first multi-commit ADR landed under the strain pattern this ticket addresses)
- JTBD-001 (enforce-governance — extended scope per ADR-060 amendment 2026-05-05), JTBD-101 (plugin-developer — bifurcation acknowledged per ADR-060 amendment 2026-05-05), JTBD-006 (work-backlog-afk), JTBD-201 (restore-service-fast), JTBD-301 (report-without-pre-classifying) — JTBD-008 reference dropped 2026-05-05 (phantom anchor — does not exist; per JTBD-review finding 1)
- P168 / P169 (substantive design + operationalisation pair — first explicit Problem→workstream-decomposition example session-surfaced)
- P159 (Phase 1 shipped, Phase 2-3 deferred — second-most-pressing example of the pattern)
- P051 (6 improve shapes — third-most-pressing example)
- User direction recorded 2026-05-04: *"Capture the actual problem as P170. The ADR captures how we decide to solve it (and considered alternatives). All RFCs MUST be tied to a problem. We go beyond ITIL in this way. We consider technical problems and inherent user/business problems in the same way. In fact, even JTBD describes problems that we somehow (in the future) need to unify with the problem management framework."*
- Jeff Patton, *User Story Mapping* (O'Reilly, 2014) — backbone/ribs/slices canonical reference
- ITIL 4 Foundation: Change Enablement practice (RFC lifecycle), Service Request Management practice (request shape), Problem Management practice (root-cause shape) — informs but does not constrain (we extend per user direction)
