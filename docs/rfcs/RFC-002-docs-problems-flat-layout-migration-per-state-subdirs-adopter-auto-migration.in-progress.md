---
status: in-progress
rfc-id: docs-problems-flat-layout-migration-per-state-subdirs-adopter-auto-migration
reported: 2026-05-07
decision-makers: [Tom Howard]
problems: [P069]
adrs: [ADR-031]
jtbd: []
---

# RFC-002: docs/problems/ flat layout migration — per-state subdirs + adopter auto-migration

**Status**: in-progress
**Reported**: 2026-05-07
**Accepted**: 2026-05-07
**In-Progress**: 2026-05-07 (T1 commit — dual-pattern hook glob widening)
**Problems**: P069
**ADRs**: ADR-031
**JTBD**: (none directly anchored — P069 anchors JTBD-001 / JTBD-006 / JTBD-101 / JTBD-201; this RFC inherits transitively)
**WSJF**: 2.8125 — (15 × 1.5) / 8 — Severity 15 inherited from P069 × Status Multiplier 1.5 (in-progress) / Effort XL=8

## Summary

Migrate `docs/problems/<NNN>-<slug>.<status>.md` from the current flat layout to a per-state subdirectory structure (`docs/problems/<status>/<NNN>-<slug>.md`) so the directory becomes skimmable as the backlog grows past ~100 tickets. Compose with adopter auto-migration so plugin-developer projects (JTBD-101) consuming the windyroad ITIL framework receive an idempotent migration path on `/install-updates`. Multi-commit shape inherited from P069's L → XL re-rate after auto-migration scope addition (2026-04-20).

This RFC is the **forward-dogfood candidate** for ADR-060 Phase 1 Slice 5 per the story map at `docs/plans/170-rfc-framework-story-map.md`. Demonstrates framework correctness (architect finding 14 — captured BEFORE its first commit, run to closure under the framework). Closes the bootstrap-circularity gate.

## Driving problem trace

- **P069** (`docs/problems/069-docs-problems-flat-layout-is-unskimmable.open.md`, WSJF 1.875, Open, XL) — the flat layout is unskimmable (175+ tickets in one directory at time of capture); the per-state subdir migration must compose with adopter-tree migration so consumers don't manually re-scaffold their own `docs/problems/` trees. The L → XL re-rate on 2026-04-20 captured the auto-migration scope add — exactly the multi-commit decomposition shape this RFC framework is designed to manage.

## Scope

Two coordinated subscopes inherited from P069's L→XL re-rate (2026-04-20) and the 2026-04-21 user direction (migration triggered inside the README-refresh block):

### Slice A — In-repo per-state subdir migration (this monorepo only)

Migrate `docs/problems/<NNN>-<slug>.<status>.md` → `docs/problems/<status>/<NNN>-<slug>.md` in this monorepo. State encoded by directory; filename suffix dropped. Authoritative state signal collapses from three-way redundancy (filename suffix + directory + body `Status:`) to one source (directory) plus one in-file fallback (body `Status:`). Mechanical bulk `git mv` per ADR-031 § Migration plan items 1-9.

Updates ride alongside: SKILL.md glob patterns (`manage-problem`, `work-problems`, `manage-incident`, `report-upstream`, `run-retro`, plus a forward audit on `capture-rfc` + `manage-rfc` per architect advisory clarification 2026-05-07); architect + jtbd hook exemption globs; bats fixture path-references; `docs/problems/README.md` rendering rules; ADR-022 / ADR-016 / ADR-024 path references; `packages/risk-scorer/agents/wip.md` recursive glob.

### Slice B — Adopter auto-migration (downstream consumers of `@windyroad/itil`)

Adopter repos that install `@windyroad/itil` retain the flat layout from a prior version. After Slice A's SKILL.md updates, adopters see empty enumerations on every invocation (silent "nothing to do") — a user-visible defect. Per ADR-031 § Backward compatibility — adopter repos auto-migrate on first-run, both `manage-problem` AND `work-problems` MUST detect flat-layout presence on invocation and auto-migrate the adopter's `docs/problems/` before executing layout-dependent logic. Migration is `mkdir` + `git mv` + commit; fully reversible via `git revert`; AFK-safe per ADR-013 Rule 6.

Open execution-time questions resolved during this RFC (ADR-031 § Open execution-time questions): step-numbering under ADR-027 (lean: subagent's first substantive action); shared-routine distribution (lean: ADR-017 sync pattern, canonical source in `packages/shared/`); ADR-014 commit-gate treatment (lean: explicit `RISK_BYPASS: adr-031-migration` marker); novel distribution pattern (lean: YAGNI per ADR-031, captured here for reassessment).

### Out of scope

- Sixth lifecycle state (Reassessment Criterion of ADR-031 — outside RFC-002).
- Per-year / per-severity / per-plugin secondary grouping (Reassessment Criterion when ticket count per subdir exceeds ~50 — outside RFC-002).
- Heuristic-slug derivation for any pre-ADR-056 corpus (RFC-001 deferred Commit 3' territory).

## Tasks

ADR-014-grain bounded sub-tasks. Each is a single commit; one commit advances at most one task per ADR-060 architect finding 8.

### Slice A — In-repo migration

- [x] **T1 — Hook exemption glob widening (dual-pattern transitional)**: extend `packages/architect/hooks/architect-enforce-edit.sh` and `packages/jtbd/hooks/jtbd-enforce-edit.sh` to accept BOTH `docs/problems/*.md` AND `docs/problems/*/*.md` (with the `*/` path-prefix variant). Forward-compatible; changes no current behaviour. Pre-requisite for T5's bulk migration without bootstrap-blocked-edit risk. Held changeset bumps `@windyroad/architect` + `@windyroad/jtbd` (patch). **Shipped 2026-05-07** (T1 commit — `docs/changesets-holding/wr-architect-jtbd-rfc-002-t1-glob-widening.md`).
- [ ] **T2 — Dual-tolerant SKILL.md glob updates**: extend `packages/itil/skills/manage-problem/SKILL.md`, `work-problems/SKILL.md`, `manage-incident/SKILL.md`, `report-upstream/SKILL.md`, `packages/retrospective/skills/run-retro/SKILL.md` to enumerate both flat + per-state shapes. Includes architect advisory: forward audit on `capture-rfc` + `manage-rfc` SKILL.md for problem-ticket path references and update if found.
- [ ] **T3 — Bats fixture audit + dual-tolerant assertions**: convert literal `docs/problems/*.<state>.md` fixture paths in `packages/itil/skills/*/test/*.bats` and `packages/retrospective/skills/*/test/*.bats` to dual-tolerant assertions. Re-run suite to confirm non-zero match counts.
- [ ] **T4 — `docs/problems/README.md` generation logic**: update `packages/itil/scripts/reconcile-readme.sh` (and any caller-side rendering helper) to read from both flat AND per-state shapes during the migration window.
- [ ] **T5 — Bulk migration commit**: in this monorepo only, run the `git mv` migration of ~72 ticket files into `docs/problems/<state>/<NNN>-<slug>.md` (suffix dropped); flip ADR-031 `proposed → accepted`; amend ADR-022, ADR-016, ADR-024 in-place; update `packages/risk-scorer/agents/wip.md` recursive glob. Single-purpose grain (ADR-014) preserved — every edit is in service of the rename. Architect re-review fires here.
- [ ] **T6 — Drop dual-pattern compatibility**: remove the flat-layout half of every dual-tolerant glob added in T1-T4 once T5 verifies the monorepo migration is clean. Tighten back to ADR-031's prescribed single-pattern shape.

### Slice B — Adopter auto-migration

- [ ] **T7 — Shared migration routine** (`packages/shared/lib/`): pure-shell migration routine following ADR-017 sync pattern. Detects flat-layout presence (`compgen -G 'docs/problems/*.<state>.md'`), runs `mkdir` + `git mv` + writes a standalone commit (`docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)`). Idempotent; partial-migration-safe.
- [ ] **T8 — `manage-problem` integration**: wire the shared routine into manage-problem's pre-delegation point (per ADR-031 § Open execution-time questions resolution: subagent's first substantive action). Pure-shell pre-flight before any layout-dependent logic.
- [ ] **T9 — `work-problems` integration**: same wiring at `work-problems` Step 0 / pre-delegation, addressing the false-zero defect (Step 1 enumerates BEFORE delegating to manage-problem; flat-layout adopters never reach manage-problem's auto-migrate without this).
- [ ] **T10 — Behavioural bats coverage**: `packages/itil/skills/manage-problem/test/manage-problem-auto-migrate.bats` + `packages/itil/skills/work-problems/test/work-problems-auto-migrate.bats` simulate adopter flat-layout, assert first invocation migrates, subsequent invocations are no-ops, partial-migration-safe.
- [ ] **T11 — ADR-014 commit-gate marker**: implement the `RISK_BYPASS: adr-031-migration` marker recognition in the commit-gate hook so adopter auto-migration commits skip the full risk-score overhead while keeping audit-trail.

### Lifecycle transitions (mechanical, per manage-rfc Step 11 commit-conventions table)

- [ ] **L1 — `accepted → in-progress`**: rename rides with the T1 work commit per manage-rfc Step 11 ("usually folded into the first feat/fix/chore commit").
- [ ] **L2 — `in-progress → verifying`**: rename rides with the final task commit (T11). `## Verification` section drafted at that point.
- [ ] **L3 — `verifying → closed`**: standalone `docs(rfcs): close RFC-002` commit after user-side verification per ADR-022 / ADR-044 framework-resolved silent dispatch. Closes architect finding 14 bootstrap-circularity.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12; lands in Slice 3 task B5.T9)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)

- **P069** — driving problem ticket (WSJF 1.875, Open, XL, reported 2026-04-20)
- **P170** + **ADR-060** — RFC framework that owns this RFC's lifecycle; Slice 5 forward-dogfood validates framework correctness per architect finding 14
- **`docs/plans/170-rfc-framework-story-map.md`** Slice 5 (B8.T1-T4) — context that selected this candidate
- **JTBD-101** (plugin-developer adopter persona) — auto-migration scope serves this persona
- **JTBD-001** (extended scope, change-set-level governance) — multi-commit RFC governance is JTBD-001 territory; this RFC IS JTBD-001 dogfood
