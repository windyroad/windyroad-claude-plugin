---
"@windyroad/architect": patch
"@windyroad/jtbd": patch
---

P170 / ADR-060 Phase 1 Slice 5 B8.T3 — RFC-002 T1: dual-pattern hook glob widening for `docs/problems/` migration

`packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` gain a sibling exemption pattern (`docs/problems/*/*.md` + `*/docs/problems/*/*.md`) alongside the existing flat-layout pattern (`docs/problems/*.md` + `*/docs/problems/*.md`). The dual-pattern shape is forward-compatible: the new pattern matches zero files today (the per-state subdirs do not exist yet); the existing pattern continues to exempt the current flat-layout ticket files.

**Why this is the first sub-task of RFC-002**:

ADR-031 § Hook exemption glob contract notes that the flat-layout pattern matches zero files post-migration (shell `*` does not cross `/`), so any subsequent commit that migrates ticket files would immediately trigger architect+jtbd edit-gate denials on its own transition bookkeeping (`git mv` + Edit + re-stage on a ticket file). ADR-031 originally required hook update + migration in ONE big landing commit to bridge this gap.

ADR-014 single-purpose grain dominates that single-shot framing. T1 lands the dual-pattern as a separate ADR-014-grain commit BEFORE the migration; T6 (post-migration cleanup) drops the flat-layout half once T5's bulk migration verifies. The dual-pattern window spans T1 → T6 and bounds the transient layout-coexistence exposure flagged in JTBD-001 amendment-drift (per ADR-060 Reassessment criterion).

**No current behaviour changes**:

- Flat-layout ticket-edits continue to skip the architect+jtbd gate (existing pattern matches).
- Per-state subdir ticket-edits (none today) would also skip the architect+jtbd gate (new pattern would match if such files existed).
- All other file paths continue to enter the gate as before.

**ADR-014 single-purpose grain check**: the commit changes one logical thing — the exemption-glob shape on the two enforce-edit hooks — across two package boundaries that share the same exemption contract. Per ADR-014 § "single-purpose" guidance, "one logical change across multiple files" satisfies the grain when the files share the contract being changed.

**JTBD impact**:
- **JTBD-001** (governance without slowing down) — neutral now; enables the directory-skimmability win when T5 ships.
- **JTBD-101** (atomic-fix-adopter friction guard) — neutral; no new gate, no new prompt; dual-pattern preserves existing adopter behaviour.
- **JTBD-006** (AFK orchestrator) — neutral; the hooks remain idempotent.
- **JTBD-201** (tech-lead audit trail) — neutral now; enables the directory-as-audit-trail win when T5 ships.
- **JTBD-301** (plugin-user no-pre-classification) — untouched.

**Held-changeset window scope**:

This entry lands under the ADR-060 § Confirmation criterion 6 atomicity contract — held alongside the Slice 4 entries (`wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md` + `wr-itil-p170-slice-4-b7-capture-problem-type-prompt.md`) and the Slice 2-3 entries (`wr-itil-p170-rfc-framework-phase-1.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3.md` + `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md`). The full chain graduates atomically per architect finding 12 once RFC-001 reaches `closed` post-Slice-5 forward-dogfood (which RFC-002 itself drives to closure).

**Out of scope (deferred to subsequent T-tasks)**:

- T2: dual-tolerant SKILL.md glob updates across `manage-problem`, `work-problems`, `manage-incident`, `report-upstream`, `run-retro` (plus forward audit on `capture-rfc` + `manage-rfc` per architect advisory 2026-05-07).
- T3: bats fixture audit + dual-tolerant assertions.
- T4: `docs/problems/README.md` generation logic dual-tolerant.
- T5: bulk migration commit (rename + ADR-031 proposed→accepted + ADR-022 / ADR-016 / ADR-024 amendments).
- T6: drop dual-pattern compatibility post-verification.
- T7-T11: Slice B adopter auto-migration (shared routine, manage-problem + work-problems integration, bats, ADR-014 commit-gate marker).

Refs: RFC-002
