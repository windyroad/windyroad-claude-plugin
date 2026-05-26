---
status: verifying
rfc-id: adr-070-071-decision-homing-and-unconditional-rfc-first
reported: 2026-05-26
decision-makers: [Tom Howard]
problems: [P310, P251]
adrs: [ADR-070, ADR-071, ADR-072, ADR-073, ADR-060, ADR-068, ADR-052]
jtbd: [JTBD-008, JTBD-101]
stories: []
---

# RFC-006: Implement ADR-070 + ADR-071 — re-home RFC decisions to ADRs and make RFC-first unconditional

**Status**: verifying
**Reported**: 2026-05-26
**Problems**: P310, P251
**ADRs**: ADR-070 (RFCs hold no independent decisions), ADR-071 (every fix goes through an RFC), ADR-072 (RFC required at fix-proposal on a Known Error — rewritten per P314), ADR-073 (fix-time gate auto-creates a missing RFC, everywhere — rewritten per P314), ADR-060 (parent framework — amended), ADR-068 (JTBD oversight re-confirm flow), ADR-052 (behavioural-test enforcement surface)
**JTBD**: JTBD-008 (decompose-fix-into-coordinated-changes — carve-out struck), JTBD-101 (extend-suite — atomic-fix-adopter carve-out struck)

> **Follow-up correction (P314, 2026-05-26).** After RFC-006 shipped, the `/wr-architect:review-decisions` oversight drain **rejected** ADR-072 + ADR-073 as recorded here: the original gate placement (`Open → Known Error`) was built on a wrong Known Error model, and the hard-block stance should be auto-create. Both ADRs were **rewritten** (RFC required at the propose-fix step on a Known Error; a missing RFC is auto-created everywhere) and ADR-060's I13 was corrected to match. The records below reflect RFC-006's **as-shipped** state; see **P314** + the rewritten ADR-072/073 for the current design. (The decision-homing + de-carve-out work — RFC-006's actual deliverable — stands; only the gate's placement/behaviour was corrected.)

## Summary

Implement the two ratified, born-confirmed sibling decisions ADR-070 (RFCs hold no independent decisions) and ADR-071 (every fix goes through an RFC — no atomic-fix carve-out, no effort threshold). The work re-homes RFC-005's genuine decisions out to the ADR ledger (so they enter the ADR-066 oversight net), repudiates the disavowed atomic-fix carve-out, strikes the JTBD-008/JTBD-101 carve-out language entirely (every fix goes through the **same** RFC — no thin / scaled-down / minimal-ceremony path), amends ADR-060's permissive line-97 clause + adds the unconditional fix-time I13 invariant, ships the ADR-052 enforcement test, and retro-fits an RFC for P260 so its held `@windyroad/itil` changeset can release under the new unconditional gate. This RFC dogfoods ADR-071: the decision-homing fix itself goes through an RFC.

## Driving problem trace

- **P310** (`docs/problems/open/310-rfcs-carry-independent-decisions-invisible-to-adr-066-oversight.md`) — RFCs carry independent decisions invisible to the ADR-066 human-oversight net. The atomic-fix carve-out reached RFC-005 `accepted` (F2/F7/I13) with no human ratification because the oversight detector greps only `docs/decisions/`. This RFC's decision-homing slices (1, 6) + the ADR-052 enforcement test (5) close the blind spot. ADR-070 is the governing decision.
- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without an RFC. This RFC's gate slice (4) + the carve-out repudiation (2) + the P260 retro-fit (7) make Problem→RFC unconditional at fix-time. ADR-071 is the governing decision.

## Scope

RFC-006 discharges ADR-070's and ADR-071's Confirmation criteria. It holds **no independent decisions of its own** (per ADR-070) — every choice was ratified in ADR-070/071 or re-homed to ADR-072/073; this RFC carries only scope, decomposition, and traces.

In scope:

- **Decision-homing (ADR-070).** Extract RFC-005's genuine decisions (the facets that recorded "alternatives rejected") into the ADR ledger; reduce RFC-005 to scope + decomposition + traces. F1 → ADR-072, F4 → ADR-073 (shipped in slice 1a). F2 (atomic-fix carve-out) is repudiated by ADR-071, struck not extracted. F3 (`rfcs:` problem-frontmatter schema), F5 (PreToolUse hook surface — application of ADR-051), F6 (story-map composition deferral — scope boundary), F7 (I13 invariant text — the ADR-060 amendment) remain RFC-resident decomposition.
- **Carve-out repudiation (ADR-071).** Strike the atomic-fix carve-out in JTBD-008 + JTBD-101 entirely — every fix goes through the **same** RFC, with no thin / scaled-down / minimal-ceremony path; routed through the ADR-068 oversight re-confirm flow.
- **Framework amendment.** Delete ADR-060 line-97's permissive half (RFC-internal decisions skip ADR capture); retain + reframe its protective half (pure sequencing is not an ADR); add the unconditional fix-time I13 invariant.
- **Enforcement surface.** Strip the "Considered Options / Alternatives Rejected" section from the RFC template + capture-rfc + manage-rfc; ship the ADR-052 behavioural lint (no RFC body carries a rejected-alternatives block without a matching `adrs:` reference).
- **Backfill.** Retro-fit an RFC for P260 so its held `@windyroad/itil` changeset releases under the new unconditional gate.

Out of scope (deferred, per F6 boundary): composing story-map presence into the fix-time gate (transitively assured by ADR-060 I7/I8; revisit if RFC-003 ships and dogfood evidence shows a gap). The structural I13 hook + `/wr-itil:manage-problem`/`work-problems` enforcement code is named in the task decomposition but ships under the same held-changeset window as the rest of the RFC framework per ADR-042.

## Tasks

Ordered slice decomposition (one coherent purpose per commit per ADR-014; each carries a `Refs: RFC-006` trailer).

- [x] **Slice 1a** — Record ADR-072 (fix-time gate placement, from F1) + ADR-073 (orchestrator dispatch hard-block, from F4). Born proposed, no oversight marker. (`b30d08f`)
- [x] **Slice 1b** — Retrofit RFC-005 to scope + decomposition + traces: strike the embedded F1–F7 Decision/Rationale blocks + the "Considered Options / Alternatives Rejected" section; F2 carve-out struck; F1→ADR-072 / F4→ADR-073 references; de-carve-out the B1–B10 task list; ADR-070/071/072/073 added to `adrs:` frontmatter. (`49c25f4`)
- [x] **Slice 2** — Amend JTBD-008 (born-confirm) + JTBD-101 (clear-and-reconfirm) to strike the atomic-fix carve-out entirely (every fix goes through the **same** RFC — no thin / scaled-down path), via the ADR-068 oversight-confirm flow. (`8d8da90`)
- [x] **Slice 3** — Strike the atomic-fix carve-out framing from capture-rfc + manage-rfc; add explicit no-"Considered Options" guidance per ADR-070; align `docs/rfcs/README.md`. (`0c8976f`, `38edcdb`)
- [x] **Slice 4 + 6** — Amend ADR-060: delete line-97's permissive half + retain/reframe the protective half (slice 6); add the unconditional fix-time I13 invariant (slice 4); `prior-amendments:` + amendment subsection updated. (`065f76b`)
- [x] **Slice 5** — Ship the ADR-052 behavioural lint `check-rfc-rejected-alternatives.sh` + behavioural bats (8 green, incl. a real-corpus dogfood). (`8aa3176`)
- [x] **Slice 7** — Retro-fit RFC-007 tracing P260 (undecomposed fix, `stories: []`) so its held `@windyroad/itil` Option-C changeset releases under the new unconditional gate. (`df7630f`)
- [x] **Correction (P311)** — Mid-flight user correction: strike the unauthorized "thin RFC / scale-down / minimal-ceremony" softening the agent had introduced; captured as P311; corrective sweep across ADR-071/072, RFC-005/006. (`4671755`, `bd42dad`)
- [x] **Finalize** — Advance RFC-006 → verifying; `@windyroad/itil` changesets queued (RFC-skills alignment + ADR-052 lint); `docs/rfcs/README.md` refreshed; push + release.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

- `56ea8ad` — capture RFC-006 skeleton.
- `cb83066` — RFC-006 accepted (scope + 7-slice decomposition).
- `b30d08f` — slice 1a: record ADR-072 + ADR-073.
- `49c25f4` — slice 1b: retrofit RFC-005.
- `bd42dad` — P311 corrective sweep (strike thin-RFC/scale-down softening).
- `8d8da90` — slice 2: strike carve-out from JTBD-008 + JTBD-101.
- `38edcdb` — align docs/rfcs/README.md to ADR-070/071.
- `0c8976f` — slice 3: strike carve-out framing from RFC skills.
- `065f76b` — slices 4+6: amend ADR-060 (line-97 + I13).
- `8aa3176` — slice 5: ADR-052 behavioural lint.
- `df7630f` — slice 7: capture RFC-007 (P260 retro-fit).

## Verification

All seven slices shipped (commits above); the corrective P311 sweep removed the unauthorized softening. ADR-070/071 Confirmation criteria discharged:

- **ADR-070**: RFC-005's F1/F4 decisions re-homed to ADR-072/073; RFC-005 reduced to scope + decomposition + traces; the "Considered Options / Alternatives Rejected" section dropped from the template + skills; the ADR-052 behavioural lint (`check-rfc-rejected-alternatives.sh`, 8 bats green) asserts no RFC body carries a rejected-alternatives block without a matching `adrs:` reference (real corpus clean across 7 RFCs); ADR-060 line-97 permissive half deleted.
- **ADR-071**: unconditional fix-time I13 invariant added to ADR-060 (no carve-out, no effort threshold, no override); JTBD-008/JTBD-101 carve-out struck via the ADR-068 flow; P260's pre-existing fix retro-fitted under RFC-007.

**Release marker**: the `@windyroad/itil` release carrying `wr-itil-adr-070-071-rfc-skills.md` + `wr-itil-rfc-no-rejected-alternatives-lint.md` (+ the P260 Option-C changeset). **User-side verification**: the dropped carve-out + the lint are observable in the published `@windyroad/itil`; the I13 gate (structural hook + skill enforcement) ships under RFC-005's B2–B10 held-changeset chain, separately verified when that chain graduates.

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
