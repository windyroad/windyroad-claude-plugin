---
status: accepted
rfc-id: adr-070-071-decision-homing-and-unconditional-rfc-first
reported: 2026-05-26
decision-makers: [Tom Howard]
problems: [P310, P251]
adrs: [ADR-070, ADR-071, ADR-072, ADR-073, ADR-060, ADR-068, ADR-052]
jtbd: [JTBD-008, JTBD-101]
stories: []
---

# RFC-006: Implement ADR-070 + ADR-071 — re-home RFC decisions to ADRs and make RFC-first unconditional

**Status**: accepted
**Reported**: 2026-05-26
**Problems**: P310, P251
**ADRs**: ADR-070 (RFCs hold no independent decisions), ADR-071 (every fix goes through an RFC), ADR-072 (fix-time gate placement), ADR-073 (orchestrator dispatch hard-block), ADR-060 (parent framework — amended), ADR-068 (JTBD oversight re-confirm flow), ADR-052 (behavioural-test enforcement surface)
**JTBD**: JTBD-008 (decompose-fix-into-coordinated-changes — carve-out reframed), JTBD-101 (extend-suite — atomic-fix-adopter friction guard reframed)

## Summary

Implement the two ratified, born-confirmed sibling decisions ADR-070 (RFCs hold no independent decisions) and ADR-071 (every fix goes through an RFC — no atomic-fix carve-out, no effort threshold). The work re-homes RFC-005's genuine decisions out to the ADR ledger (so they enter the ADR-066 oversight net), repudiates the disavowed atomic-fix carve-out, reframes the JTBD-008/JTBD-101 carve-out language into the thin-RFC minimal-ceremony path, amends ADR-060's permissive line-97 clause + adds the unconditional fix-time I13 invariant, ships the ADR-052 enforcement test, and retro-fits a thin RFC for P260 so its held `@windyroad/itil` changeset can release under the new unconditional gate. This RFC dogfoods ADR-071: the decision-homing fix itself goes through an RFC.

## Driving problem trace

- **P310** (`docs/problems/open/310-rfcs-carry-independent-decisions-invisible-to-adr-066-oversight.md`) — RFCs carry independent decisions invisible to the ADR-066 human-oversight net. The atomic-fix carve-out reached RFC-005 `accepted` (F2/F7/I13) with no human ratification because the oversight detector greps only `docs/decisions/`. This RFC's decision-homing slices (1, 6) + the ADR-052 enforcement test (5) close the blind spot. ADR-070 is the governing decision.
- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without an RFC. This RFC's gate slice (4) + the carve-out repudiation (2) + the P260 retro-fit (7) make Problem→RFC unconditional at fix-time. ADR-071 is the governing decision.

## Scope

RFC-006 discharges ADR-070's and ADR-071's Confirmation criteria. It holds **no independent decisions of its own** (per ADR-070) — every choice was ratified in ADR-070/071 or re-homed to ADR-072/073; this RFC carries only scope, decomposition, and traces.

In scope:

- **Decision-homing (ADR-070).** Extract RFC-005's genuine decisions (the facets that recorded "alternatives rejected") into the ADR ledger; reduce RFC-005 to scope + decomposition + traces. F1 → ADR-072, F4 → ADR-073 (shipped in slice 1a). F2 (atomic-fix carve-out) is repudiated by ADR-071, struck not extracted. F3 (`rfcs:` problem-frontmatter schema), F5 (PreToolUse hook surface — application of ADR-051), F6 (story-map composition deferral — scope boundary), F7 (I13 invariant text — the ADR-060 amendment) remain RFC-resident decomposition.
- **Carve-out repudiation (ADR-071).** Strike/reframe the atomic-fix carve-out in JTBD-008 + JTBD-101 into the thin-RFC (empty `stories: []`) minimal-ceremony path, routed through the ADR-068 oversight re-confirm flow.
- **Framework amendment.** Delete ADR-060 line-97's permissive half (RFC-internal decisions skip ADR capture); retain + reframe its protective half (pure sequencing is not an ADR); add the unconditional fix-time I13 invariant.
- **Enforcement surface.** Strip the "Considered Options / Alternatives Rejected" section from the RFC template + capture-rfc + manage-rfc; ship the ADR-052 behavioural lint (no RFC body carries a rejected-alternatives block without a matching `adrs:` reference).
- **Backfill.** Retro-fit a thin RFC for P260 so its held `@windyroad/itil` changeset releases under the new unconditional gate.

Out of scope (deferred, per F6 boundary): composing story-map presence into the fix-time gate (transitively assured by ADR-060 I7/I8; revisit if RFC-003 ships and dogfood evidence shows a gap). The structural I13 hook + `/wr-itil:manage-problem`/`work-problems` enforcement code is named in the task decomposition but ships under the same held-changeset window as the rest of the RFC framework per ADR-042.

## Tasks

Ordered slice decomposition (one coherent purpose per commit per ADR-014; each carries a `Refs: RFC-006` trailer).

- [x] **Slice 1a** — Record ADR-072 (fix-time gate placement, from F1) + ADR-073 (orchestrator dispatch hard-block, from F4). Born proposed, no oversight marker. (commit `b30d08f`)
- [ ] **Slice 1b** — Retrofit RFC-005: strike the embedded F1–F7 Decision/Rationale blocks + the "Considered Options / Alternatives Rejected" section; F2 carve-out struck; F1→ADR-072 / F4→ADR-073 references; de-carve-out the B1–B10 task list; add ADR-070/071/072/073 to `adrs:` frontmatter.
- [ ] **Slice 2** — Amend JTBD-008 (lines 21/26/44 — born-confirm) + JTBD-101 (line 30 — clear-and-reconfirm) to reframe the atomic-fix carve-out into the thin-RFC minimal-ceremony path. Route through the ADR-068 oversight-confirm flow.
- [ ] **Slice 3** — Drop the "Considered Options / Alternatives Rejected" section from the RFC body-structure template (`docs/rfcs/README.md`) + capture-rfc + manage-rfc; add explicit negative guidance per ADR-070 (contested choices reference governing ADRs).
- [ ] **Slice 4 + 6** — Amend ADR-060: delete line-97's permissive half + retain/reframe the protective half (slice 6); add the unconditional fix-time I13 invariant (slice 4); append the `2026-05-26` `prior-amendments:` entry. Mirror the line-97 fix in `docs/rfcs/README.md` line-57 `adrs` field semantics.
- [ ] **Slice 5** — Ship the ADR-052 behavioural lint: a checker script + bats asserting no RFC body in `docs/rfcs/` carries a rejected-alternatives block without a matching `adrs:` reference (artefact-state behavioural over the corpus + synthetic fixtures).
- [ ] **Slice 7** — Retro-fit a thin RFC (`stories: []`) tracing P260 so its held `@windyroad/itil` Option-C changeset releases under the new unconditional gate.
- [ ] **Finalize** — Advance RFC-006 → verifying; author the `@windyroad/itil` changeset for the skill/test/script surface changes; refresh `docs/rfcs/README.md`.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

- `b30d08f` — slice 1a: record ADR-072 + ADR-073.

## Verification

(populated at the `in-progress → verifying` transition once all slices land — release marker for the `@windyroad/itil` changeset, the ADR-052 bats green, the P260 changeset released, and the ADR-070/071 Confirmation criteria discharged.)

## Related

- **ADR-070 / ADR-071** — the ratified parent decisions this RFC implements; RFC-006 closing discharges their Confirmation criteria.
- **ADR-072 / ADR-073** — the decisions re-homed from RFC-005 under this RFC (slice 1a).
- **ADR-060** — parent framework; amended (line 97 + I13) under slices 4 + 6. Stays `accepted`.
- **ADR-068** — JTBD/persona oversight marker; governs the slice-2 JTBD re-confirm flow.
- **ADR-052** — behavioural-tests-default; the slice-5 enforcement surface.
- **ADR-066** — human-oversight marker + review-decisions drain; the net ADR-072/073 enter as born-proposed-unmarked.
- **RFC-005** — carries the disavowed carve-out (F2/F7/I13); retrofitted under slice 1b.
- **P310 / P251** — driving problems.
- **JTBD-008 / JTBD-101** — anchor the carve-out; reframed under slice 2.
