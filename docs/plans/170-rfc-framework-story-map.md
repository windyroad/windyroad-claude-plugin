---
status: draft
date-created: 2026-05-05
driver-problem: P170
driving-adr: ADR-060
methodology: Patton, "User Story Mapping" (O'Reilly, 2014)
primary-jtbd: JTBD-001 (with extended scope per JTBD-review finding 2)
secondary-jtbd:
  - JTBD-NNN (to-be-drafted: `decompose-fix-into-coordinated-changes`; slot decided in Slice 1)
  - JTBD-006 (AFK orchestration — protected during bootstrap)
  - JTBD-101 (plugin-developer — adopter consume gate)
  - JTBD-301 (plugin-user — type-prompt scope guard)
jtbd-review: 2026-05-05 PASS with 3 nitpick amendments applied
---

# Story Map: RFC Framework (P170 / ADR-060) — Phase 1 bootstrap

## Purpose

Plan the work to land ADR-060's Phase 1 RFC framework using Jeff Patton's user story mapping methodology — backbone activities + tasks + slices. The map decomposes the work into shippable units, anchors each to a JTBD, names the gates between slices, and surfaces the cross-cutting concerns (held-changeset window, architect re-reviews, AskUserQuestion fires, TDD discipline) that govern the whole.

## Methodology note — bootstrap one-off (JTBD-101 friction-add pre-emption)

This 13-task Slice 1 (and the file itself in `docs/plans/`) is the **bootstrap one-off**. Once Phase 1 ships and `docs/rfcs/` is populated, future multi-phase work will decompose under `docs/rfcs/<RFC-NNN>/` with story sub-decomposition once Phase 2 lands. Adopters consuming the Windy Road problem-management framework as a model (JTBD-101 secondary persona) should NOT interpret the Slice-1 granularity here as the recommended discipline for atomic or near-atomic fixes — those continue to use the lightweight `/wr-itil:capture-problem` aside-invocation surface (P155), and never need a parallel `docs/plans/` artefact. This file's existence is purely the meta-recursive artefact required to plan the framework that will replace this filing pattern.

## Bootstrap acknowledgement (meta-recursion)

This file is itself an instance of the work-shape ADR-060's RFC framework is designed to manage: a multi-phase coordinated change traced to a problem (P170) and a design decision (ADR-060). Patton's story-mapping is named in ADR-060 § Decision Outcome as the Phase 2 vehicle for breaking RFCs into stories. Applying it here, *before* the framework's Phase 1 ships, is the load-bearing-from-the-start move (ADR-051): we plan with the methodology even though the in-tree primitives that will mechanise it (RFC artefacts, story-mapping templates, `/wr-itil:capture-rfc`, `/wr-itil:manage-rfc`) don't yet exist.

When Phase 1 ships (Slices 2-3), this file is a candidate for retroactive migration into RFC-001's body OR retention as a sibling planning artefact under `docs/plans/`. The decision is itself a Slice 1 deliverable (deferred to end of Slice 1 architect re-review).

## Primary JTBD anchor: JTBD-001 (extended scope)

JTBD-001 ("Enforce Governance Without Slowing Down") today captures **per-edit governance** — every edit reviewed against policy, no manual trigger, <60s reviews. The RFC framework extends JTBD-001's scope to **multi-commit coordinated-change governance** — same automatic-enforcement spirit, applied at the change-set level, not just the per-edit level. Slice 1 amends JTBD-001 § Desired Outcomes to add the multi-commit-coordination outcome (per JTBD-review finding 2).

After Slice 1, the JTBD landscape will also include a more-precise anchor (a new JTBD covering `decompose-fix-into-coordinated-changes` — slot is JTBD-008 if the phantom anchor is dropped, JTBD-009 if it is filled). JTBD-001 remains the universal anchor for the framework's governance-enforcement value; the new JTBD becomes the precise anchor for the framework's coordinated-change-decomposition value. Both are valid traces.

## Backbone (left-to-right user journey)

The journey runs from **"P170 captured (Open)"** to **"Adopters consume the framework: complex multi-commit adopters use it; atomic-fix adopters retain low friction"**.

| # | Backbone activity | Status | Slice |
|---|-------------------|--------|-------|
| B1 | Capture the problem | done (P170 captured 2026-05-04) | — |
| B2 | Validate the design | in progress (architect+JTBD reviews done; amendments pending) | Slice 1 |
| B3 | Resolve JTBD anchoring | pending (JTBD-008 phantom decision; new JTBD draft) | Slice 1 + Slice 2 |
| B4 | Accept the design (ADR-060 proposed → accepted) | pending | Slice 1 |
| B5 | Build the bare RFC scaffold | pending | Slice 2 + Slice 3 |
| B6 | Dogfood RFC-001 retroactively on P168 | pending (retro validation — representability) | Slice 4 |
| B7 | Migrate problem tickets to type-tag schema | pending (Phase 1 item 8a-8d split per architect finding 10) | Slice 1 (8a) + Slice 4 (8b-8d) |
| B8 | Validate forward dogfood | pending (architect finding 14 — close bootstrap circularity) | Slice 5 |
| B9 | Graduate Phase 1 from held-changeset window | pending (ADR-042 / P162 counterfactual risk) | Slice 6 |
| B10 | Adopters consume the framework | pending (JTBD-101 outcome; >20% denial rate triggers reassessment) | Slice 6 |

## Tasks (under each backbone activity)

Tasks are listed top-to-bottom in approximate execution order. Each carries its slice membership in `[]`.

### B2 — Validate the design

- B2.T1 `[S1]` Apply 14 architect amendments to ADR-060 (findings 1-14 per `## Review Findings (2026-05-05)` in P170)
- B2.T2 `[S1]` Apply 8 JTBD amendments to ADR-060 (findings 1-8 per same)
- B2.T3 `[S1, optional]` Add Option G (GitHub Discussions / Issues+Projects as RFC home) to ADR-060 § Considered Options with rejection rationale (architect's optional)

### B3 — Resolve JTBD anchoring

- B3.T1 `[S1]` Decide JTBD-008 fate — drop phantom OR draft (direction-setting `AskUserQuestion` fires)
- B3.T2 `[S1]` Apply B3.T1 outcome — drop: remove JTBD-008 from ADR-060 + P170; draft: write `docs/jtbd/solo-developer/JTBD-008-evolve-framework.proposed.md`
- B3.T3 `[S2]` Draft new JTBD `decompose-fix-into-coordinated-changes` — slot JTBD-008 (if B3.T1 drop) OR JTBD-009 (if B3.T1 draft).
  - **Persona-constraint guidance** (per JTBD-review nitpick amendment 3): the new JTBD's Persona Constraints section MUST name *"the new framework must visibly compose with JTBD-001 (per-edit governance) and JTBD-006 (AFK orchestrator selection) without rebuilding either"* — this locks in the architecture-driver constraint that anchored the whole story map.
- B3.T4 `[S1]` Update JTBD-001 § Desired Outcomes — add multi-commit-coordination outcome (JTBD-review finding 2)
- B3.T5 `[S1]` Update JTBD-101 § Persona Constraints — add atomic-fix-adopter scaling concern (JTBD-review finding 3)
- B3.T6 `[S1]` Add JTBD-006 / JTBD-201 / JTBD-301 to ADR-060 § Decision Drivers (JTBD-review finding 4)

### B4 — Accept the design

- B4.T1 `[S1]` `git mv docs/decisions/060-...proposed.md → .accepted.md`
- B4.T2 `[S1]` Update ADR-060 frontmatter `status: proposed` → `status: accepted` (P057 staging-trap re-stage discipline applies)
- B4.T3 `[S1]` Architect re-review confirming all amendments applied (final gate before commit)
- B4.T4 `[S1]` Commit + release-queue drain per ADR-018 cadence (single ADR commit; no changeset queued because docs-only)

### B5 — Build the bare RFC scaffold

- B5.T1 `[S2]` Create `docs/rfcs/` directory + `README.md` (lifecycle index analogous to `docs/problems/README.md`)
- B5.T2 `[S2]` RFC frontmatter shape spec — at minimum: `status`, `problems: [P<NNN>, ...]`, `adrs: [ADR-NNN, ...]`, `jtbd: [JTBD-NNN, ...]` (optional; required when driving problem is `type: user-business`), `reported`, `decision-makers`
- B5.T3 `[S2]` Build `/wr-itil:capture-rfc` skill skeleton — lightweight aside per ADR-032; mandatory `--problem P<NNN>` flag (gate-enforced at I1, hard-block per architect finding 1)
- B5.T4 `[S2]` Build `/wr-itil:manage-rfc` skill skeleton — heavyweight intake + lifecycle management; AskUserQuestion authority classes per ADR-044 (architect finding 3)
- B5.T5 `[S2]` Behavioural bats coverage for capture-rfc + manage-rfc per ADR-052 (no structural grep on SKILL.md content per P081)
- B5.T6 `[S3]` `packages/itil/scripts/reconcile-rfcs.sh` — diagnose-only mechanical drift detector for `docs/rfcs/README.md` (mirrors `reconcile-readme.sh`)
- B5.T7 `[S3]` `packages/itil/bin/wr-itil-reconcile-rfcs` — `$PATH` shim per ADR-049 naming grammar
- B5.T8 `[S3]` Auto-maintained `## RFCs` section on problem tickets — refresh contract analogous to P094 README refresh; trigger: any RFC traces this problem ID
- B5.T9 `[S3]` Commit-message RFC trailer convention (`Refs: RFC-<NNN>` or similar — exact form decided in Slice 3 architect call) + hook recognition (architect finding 9 — closes Confirmation item 3 mechanism gap)

### B6 — Dogfood RFC-001 retroactively on P168

- B6.T1 `[S4]` Author RFC-001 frontmatter referencing P168 (driver problem) + ADR-059 (underpinning ADR)
- B6.T2 `[S4]` Migrate P168 multi-commit history into RFC-001's commit list — Commits 1 (`ab73328`), 2 (`af5447c`), 3 (`8edaf7b`); deferred Commit 3' named under RFC-001 § Deferred Scope OR captured as RFC-NNN follow-up stub
- B6.T3 `[S4]` Verify "no semantic loss" per the six concrete clauses (architect finding 5 sharpening — every commit referenced; Smoke-Test Findings map to RFC-001 verification entries; deferred Commit 3' explicit; P168 lifecycle preserved at `.verifying.md`; ADR-059 references propagate; round-trip retrievability holds)
- B6.T4 `[S4]` Confirm P168 lifecycle stays at `.verifying.md` — no re-transition (P076 carve-out: verifying upstream contributes 0 to transitive effort)

### B7 — Migrate problem tickets to type-tag schema (split per architect finding 10)

- B7.T1 `[S1]` Item 8a — type-tag schema added to frontmatter spec (no migration; `type: technical | user-business`; default `technical`)
- B7.T2 `[S4]` Item 8b — existing tickets bulk one-shot migrate to default `type: technical` (script-driven; no per-ticket judgement)
- B7.T3 `[S4]` Item 8c — `/wr-itil:capture-problem` AskUserQuestion adds type prompt (maintainer-side only — JTBD-301 protection per JTBD-review finding 4b; never on plugin-user-side `.github/ISSUE_TEMPLATE/problem-report.yml`)
- B7.T4 `[S4]` Item 8d — I2 behavioural test ships at the same time as the tag (architect finding 2): asserts capture-problem / manage-problem / work-problems / review-problems exhibit identical control-flow shape regardless of `type`

### B8 — Validate forward dogfood

- B8.T1 `[S5]` Identify a candidate forward RFC from current problem queue (multi-commit shape) — `AskUserQuestion` fires (taste authority per ADR-044)
- B8.T2 `[S5]` Capture the candidate as RFC-002 BEFORE any commits land — `/wr-itil:capture-rfc --problem P<NNN>`; problem trace; story map authored
- B8.T3 `[S5]` Run RFC-002 to closure under the framework — ADR-022-mirror lifecycle: `proposed → accepted → in-progress → verifying → closed`
- B8.T4 `[S5]` Validates framework correctness per architect finding 14 — RFC-001 demonstrates representability; RFC-002 demonstrates forward correctness; held-window graduation criteria can fire only after this

### B9 — Graduate Phase 1 from held-changeset window

- B9.T1 `[S6]` Counterfactual risk assessment per ADR-042 / P162 — delay-risk vs release-risk; held-window atomicity per architect finding 12 (entire RFC-001 chain or nothing)
- B9.T2 `[S6]` Reinstate held changesets to `.changeset/`
- B9.T3 `[S6]` Release queue drain via `npm run push:watch` + `npm run release:watch` (or via `/wr-risk-scorer:assess-release` skill per ADR-018)

### B10 — Adopters consume the framework

- B10.T1 `[S6]` `/install-updates` picks up new RFC framework skills in adopter projects
- B10.T2 `[S6]` Verify adopter friction per JTBD-101 atomic-fix-adopter caveat (held-window dogfood evidence; if friction signals during dogfood, reassess before adopter release)
- B10.T3 `[S6]` Track `--problem` flag denial rate over 30 days post-adoption; if >20%, trigger ADR-060 reassessment (architect finding 6 — measurable proxy via "RFCs trace to a freshly-captured problem (≤24h prior)" if deny-log instrumentation isn't ready)

## Slices (time-ordered releases)

Each slice is a candidate held-changeset window per ADR-042 / P162. Graduation between slices is gated on the slice's exit criteria PLUS architect re-review where named.

### Slice 1 — ADR-060 ready for accept (this-session candidate)

**Goal**: ADR-060 amendments applied; JTBD landscape cleaned; ADR-060 moves `proposed → accepted`.

**Tasks**: B2.T1, B2.T2, B2.T3 (optional), B3.T1 (`AskUserQuestion` fires), B3.T2, B3.T4, B3.T5, B3.T6, B4.T1, B4.T2, B4.T3, B4.T4, B7.T1.

**Effort**: M (single ADR file edit + JTBD file edits + ADR rename + commit + drain). Bounded session-sized.

**Exit criteria**:
- ADR-060 in `.accepted.md` with all 14 architect + 8 JTBD amendments applied
- JTBD-008 phantom resolved per B3.T1 user direction (drop or draft)
- JTBD-001 § Desired Outcomes amended; JTBD-101 § Persona Constraints amended
- ADR-060 § Decision Drivers includes ADR-010, ADR-013, ADR-019, JTBD-006, JTBD-201, JTBD-301
- type-tag schema added to problem frontmatter spec (no migration yet — that's Slice 4)
- Architect re-review PASSES on the amended file (B4.T3)
- Commit landed; release-queue drained if non-empty

**Deferred / out-of-slice**: framework code (capture-rfc / manage-rfc / reconcile-rfcs / bin shim / bats / `## RFCs` section / commit-message trailer) — Slices 2-3.

**`AskUserQuestion` fires**: B3.T1 (JTBD-008 fate — direction-setting per ADR-044 category 1).

### Slice 2 — Bare framework artefacts

**Goal**: minimum viable RFC framework — directory + skills + bats — without dogfood validation.

**Tasks**: B3.T3 (draft new JTBD per Slice 1 outcome), B5.T1, B5.T2, B5.T3, B5.T4, B5.T5.

**Effort**: L–XL. Multi-day. Held-changeset window per ADR-042 / P162 begins here (Slice 1 was docs-only; Slice 2 is the first to ship code).

**Exit criteria**:
- `docs/rfcs/` + `README.md` exist with lifecycle index
- `/wr-itil:capture-rfc` + `/wr-itil:manage-rfc` skills exist with skeleton + behavioural bats green
- New JTBD drafted (slot decided in Slice 1)
- Held-changeset accumulating; not yet released to adopters

### Slice 3 — Complete the bare framework + reverse-trace + commit-grain composition

**Goal**: framework feature-complete for atomic operation; reverse-trace + commit-message composition land.

**Tasks**: B5.T6 (reconcile-rfcs.sh), B5.T7 (bin shim), B5.T8 (`## RFCs` section refresh contract), B5.T9 (commit-message RFC trailer + hook).

**Effort**: L. Multi-day; rides Slice 2's held-changeset window (still pre-graduation).

**Exit criteria**:
- Reverse-trace `## RFCs` section auto-maintained on problem tickets via P094-analogue
- Commit-message RFC trailer recognized by hook
- reconcile-rfcs script + `$PATH` bin shim exist with bats coverage
- ADR-060 Confirmation items 1, 2, 3, 4, 7 PASS

### Slice 4 — Retro dogfood + type-tag full migration

**Goal**: validate framework on known multi-commit decomposition (P168 → RFC-001); complete type-tag migration with I2 enforcement.

**Tasks**: B6.T1, B6.T2, B6.T3, B6.T4, B7.T2, B7.T3, B7.T4.

**Effort**: L. Multi-day; still on held-changeset window.

**Exit criteria**:
- RFC-001 written, traces P168 + ADR-059, "no semantic loss" verified per six concrete clauses
- All existing problem tickets carry `type: technical`
- capture-problem AskUserQuestion includes type prompt (maintainer-side only)
- I2 behavioural test green
- ADR-060 Confirmation items 5 + 6 PASS

**Architect re-review fires** at end of slice (dogfood evidence review).

### Slice 5 — Forward dogfood

**Goal**: validate framework correctness on a NEW multi-commit RFC captured before its first commit.

**Tasks**: B8.T1, B8.T2, B8.T3, B8.T4.

**Effort**: variable — depends on the chosen forward RFC's scope. Candidate selection (B8.T1) is itself a sub-decision.

**Exit criteria**:
- One forward RFC captured before commit-1, run to closure under the framework
- Architect finding 14 (forward-dogfood requirement) closed
- Held-changeset graduation evidence sufficient for counterfactual risk assessment

**`AskUserQuestion` fires**: B8.T1 (forward RFC candidate — taste per ADR-044 category 5).
**Architect re-review fires** at end of slice (forward-dogfood verdict; gate to Slice 6).

### Slice 6 — Graduate to adopters

**Goal**: framework reaches adopter projects; friction-vs-value evidence accumulates.

**Tasks**: B9.T1, B9.T2, B9.T3, B10.T1, B10.T2, B10.T3.

**Effort**: M. Mostly mechanical (release drain + monitoring).

**Exit criteria**:
- Held-changeset graduated per ADR-042 / P162 counterfactual risk
- Released on npm; adopters consume via `/install-updates`
- 30-day `--problem` flag denial rate measured; if >20%, ADR-060 reassessment triggers
- ADR-060 reassessment criteria evaluated; framework either holds or amends
- **JTBD-001 § Desired Outcomes amendment (Slice 1 B3.T4) drift signal** — if adopters report multi-commit-coordination governance feels heavyweight, trigger JTBD-001 reassessment (per JTBD-review nitpick amendment 2).
- **JTBD-101 § Persona Constraints amendment (Slice 1 B3.T5) drift signal** — if atomic-fix adopters report scaling-down friction, trigger JTBD-101 reassessment (per JTBD-review nitpick amendment 2). The JTBD-amendment-drift signal is narrower and earlier than the trace-failure signal in ADR-060 § Reassessment Criteria — it fires at the persona-constraint level before failures cascade to the gate level.

## Cross-cutting concerns

- **Held-changeset window** spans Slices 2-5 inclusive. Atomicity per architect finding 12: graduate the entire chain or nothing. Auto-apply paused per ADR-042 until RFC-001 reaches `closed`.
- **`AskUserQuestion` fires** at: B3.T1 (JTBD-008 fate, direction-setting), B8.T1 (forward RFC candidate, taste). All other decisions are framework-mediated mechanical or policy-authorised silent-proceed per ADR-044 + CLAUDE.md P132.
- **Architect / JTBD re-reviews fire** at: end of Slice 1 (final ADR gate before accept), end of Slice 4 (dogfood evidence review), end of Slice 5 (forward-dogfood verdict; final gate to graduate).
- **Commit-grain discipline (architect finding 8)** governs all slices: one commit advances at most one RFC; one RFC = N × ADR-014-grain commits, ordered. Commit messages reference RFC-NNN via the trailer convention landed in Slice 3.
- **TDD discipline (ADR-052)**: every code-bearing task carries a behavioural bats fixture before commit. Slices 2, 3, 4 all gate on bats green. No structural grep on SKILL.md / agent.md content per P081.
- **Risk-scorer pipeline gate (ADR-014, ADR-015)** fires on every commit. Slices 2-5 land under held-changeset per ADR-042 — the held-area's documented reinstate trigger is the graduation gate, not arbitrary calendar guards (P162).

## Risks

- **R1: JTBD-008 fate ambiguity** — Slice 1 cannot complete without user direction at B3.T1. If the user is unavailable for an extended period, Slice 1 stalls. Mitigation: B3.T1 is the only direction-setting question in Slice 1; everything else is mechanical. Slice 1 progresses as far as the question, then halts gracefully.
- **R2: WSJF placement deferred to Phase 2** — though architect resolved RFC-level for Phase 1, story-level WSJF remains a Phase 2 deferred decision (architect finding 3 last bullet). JTBD-006 protection during Slices 2-5 depends on RFC-level WSJF being sufficient for AFK orchestrator selection. If story-level granularity becomes needed mid-Phase-1, scope expands. Mitigation: confirm at end of Slice 4 that `/wr-itil:work-problems iter` still selects from `docs/problems/` correctly with RFC layer present.
- **R3: Held-window cost overrun** — Slices 2-5 accumulate held-changeset cost. If P162 graduation criteria fire early (delay-risk > release-risk), the held-window may need to graduate before Slice 5's forward-dogfood completes — potentially shipping a framework that hasn't validated forward correctness. Mitigation: architect finding 14 explicitly guards against this; if pressure builds, retreat to "graduate after Slice 4 with explicit reassessment-criterion firing on forward-dogfood-pending" rather than skip Slice 5.
- **R4: Adopter friction at Slice 6** — JTBD-101 atomic-fix-adopter friction may surface in dogfood; if `--problem` flag denial rate spikes >20% during dogfood, triggers ADR-060 reassessment before adopter release. Mitigation: Slice 4 + Slice 5 dogfood gives early signal.
- **R5: Bootstrap circularity (architect finding 14)** — RFC-001 is retro on P168; demonstrates representability not correctness. Slice 5 (forward dogfood) closes this; if Slice 5 is skipped or short-circuited, framework correctness is unproven. Mitigation: hard-block Slice 6 graduation on Slice 5 completion (architect re-review at end of Slice 5 enforces).
- **R6: Type-tag I2 drift (architect finding 2)** — without B7.T4 (I2 behavioural test) shipping at the same time as the tag (B7.T2 + B7.T3), type-tag becomes a workflow-split surface by graceful drift. Mitigation: Slice 4 ships all four sub-items together (8a + 8b + 8c + 8d); 8a alone in Slice 1 is intentional (schema only, no migration).

## Dependencies

- **Blocks**: P168 retro migration (B6.T1-T4) is gated by Slices 1+2+3 completion; can't migrate without the framework existing.
- **Blocked by**: nothing external. Slice 1 has no blocking external upstream.
- **Composes with**: P162 (held-changeset graduation criteria — Slices 2-5 all ride this), P078 (capture-on-correction surface — composes with capture-rfc as another aside-invocation), P051 (improve shapes — many become RFCs naturally; not migrated in Phase 1), P014 (master tracker for ADR-032 aside-invocation pattern — capture-rfc + manage-rfc are siblings to capture-problem + manage-problem under that pattern), P033 (persistent risk register — RFC framework should compose with risk-scoring at RFC level, not just commit/push/release; deferred to post-Phase-1).

## Related

- **P170** — driver problem ticket (`docs/problems/170-problem-tickets-strain-as-fixes-decompose-into-multiple-coordinated-changes-need-rfc-framework.open.md`)
- **ADR-060** — design decision (`docs/decisions/060-problem-rfc-story-framework-with-mandatory-problem-trace-and-unified-problem-ontology.proposed.md`; AMEND verdicts pending application in Slice 1)
- **JTBD-001** — primary anchor (extended scope per JTBD-review finding 2; amended in Slice 1 B3.T4)
- **JTBD-006 / JTBD-101 / JTBD-201 / JTBD-301** — secondary anchors per JTBD-review finding 4 (added to ADR-060 Decision Drivers in Slice 1 B3.T6)
- Patton, *User Story Mapping*, O'Reilly, 2014 — methodology source
- ADR-022 (problem lifecycle — RFC lifecycle mirrors), ADR-032 (aside-invocation), ADR-038 (progressive disclosure), ADR-042 (held-changeset auto-apply), ADR-044 (decision-delegation contract), ADR-051 (load-bearing-from-the-start), ADR-052 (behavioural-tests), ADR-053 (plugin maturity)
- P162 — held-changeset graduation criteria
- P168 — retro-migration target (Slice 4)
