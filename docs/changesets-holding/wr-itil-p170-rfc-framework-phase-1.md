---
"@windyroad/itil": minor
---

P170 / ADR-060: Problem-RFC-Story framework Phase 1 — capture-rfc + manage-rfc skills + P119 hook generalisation

The `@windyroad/itil` plugin gains the RFC tier of the Problem-RFC-Story framework introduced by ADR-060 (Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology, accepted 2026-05-05). Phase 1 ships the lightweight + heavyweight skill split for coordinated multi-commit changes traced to a driving problem.

**New skills**:

- **`/wr-itil:capture-rfc`** — lightweight aside-invocation per ADR-032. Mandatory leading problem-trace argument (`P<NNN>` or `P<NNN>,P<NNN>,...`); refuses without it (I1 hard-block per ADR-060 § Confirmation criterion 1; deny logged to `logs/rfc-capture-denials.jsonl` for the trace-violation-rate reassessment criterion). Bounded-escape carve-out for Closed/Verifying/Parked traces — load-bearing for Phase 1 dogfood (RFC-001 retro on P168 per ADR-060 Phase 1 item 9 + Confirmation criterion 5).

- **`/wr-itil:manage-rfc`** — heavyweight RFC intake + lifecycle management. RFC lifecycle states (`proposed → accepted → in-progress → verifying → closed`) mirror ADR-022 problem lifecycle. I1 enforcement at lifecycle transitions per ADR-060 § Decision Outcome line 97 + § Confirmation criteria 1+2: hard-block at irreversible transitions (`accepted → in-progress`, `→ verifying`); advisory-with-escalation only at `→ closed`.

**Hook generalisation** (per architect verdict on capture-rfc sub-decision a):

- `manage-problem-enforce-create.sh` extended to also gate `docs/rfcs/RFC-<NNN>-*.<status>.md` Writes with branched deny messages naming the right skill (capture-rfc for rfcs tier; manage-problem for problems tier). Sibling marker `/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}` (preserves audit-trail per-surface granularity). Existing problems-tier gating behaviour preserved 1:1 (18/18 prior tests still pass; 12 new RFC-tier tests added; 30 total).

**RFC tier scaffold** (this changeset's predecessor commits):

- `docs/rfcs/` directory + lifecycle index README (`adc53c8`) — documents the four-tier governance hierarchy (Problem / ADR / RFC / Story), I1 + I2 invariants, RFC filename grammar, frontmatter shape, body structure, commit-grain composition (`Refs: RFC-<NNN>` trailer per ADR-060 finding 8 + Phase 1 item 12).
- JTBD-008 (`decompose-fix-into-coordinated-changes`) drafted (`59de19a`) — primary persona-anchor for the capture-time decomposition surface this framework enables.

**ADR-060 Phase 1 status**: Phase 1 deliverables (items 1, 2, 3, 4, 8a, 11) shipped under this held-changeset window. Outstanding Phase 1 work (items 5, 6, 7, 9, 10, 12 — `reconcile-rfcs.sh` + `wr-itil-reconcile-rfcs` shim + behavioural bats + RFC-001 retro on P168 + auto-maintained `## RFCs` section on problem tickets + commit-message RFC trailer hook) lands in Slices 3 + 4 of `docs/plans/170-rfc-framework-story-map.md`.

**Composes with**: ADR-014 (single-commit grain — RFCs decompose into ADR-014-grain commits, ordered, one commit advances at most one RFC), ADR-022 (lifecycle suffix-based — RFC mirrors), ADR-032 (lightweight + heavyweight aside-invocation pattern), ADR-038 (progressive disclosure — SKILL.md + REFERENCE.md split deferred per ADR-054), ADR-042 (held-changeset auto-apply — this changeset rides the held window), ADR-049 (`wr-itil-reconcile-rfcs` shim grammar — Slice 3), ADR-051 (load-bearing-from-the-start — I1 hard-block ships behaviourally on day one), ADR-052 (behavioural-tests default — bats coverage shipped), P057 (staging trap), P062 (README refresh on transition), P094 (README refresh on conditional update), P118 (reconciliation contract), P119 (create-gate marker — generalised), P132 + inverse-P078 (mechanical-stage carve-outs), P134 (last-reviewed line discipline), P138 (tie-break ladder), P150 (VQ sort direction), P162 (held-changeset graduation criteria).
