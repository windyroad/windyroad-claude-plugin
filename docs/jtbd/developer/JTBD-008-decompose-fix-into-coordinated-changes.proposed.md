---
status: proposed
job-id: decompose-fix-into-coordinated-changes
persona: developer
secondary-persona: tech-lead
date-created: 2026-05-05
human-oversight: confirmed
oversight-date: 2026-05-26
---

# JTBD-008: Decompose a Fix Into Coordinated Changes

## Job Statement

When my fix to a problem decomposes into multiple coordinated changes (a refactor across packages, a phased migration, a framework evolution), I want the work to be scoped, time-boxed, and traced to its driving problem at a level above individual commits, so each sub-workstream competes for WSJF attention as a first-class entity rather than hiding inside a parent ticket's body.

## Desired Outcomes

- **Capture-time scoping** — when a problem's fix is too large for atomic-commit shape, the framework offers a structured way to scope the work as a Request for Change (RFC) traced to the driving problem. The decomposition decision happens at capture time, not as drift mid-flight.
- **Trace invariant** — every RFC traces back to a problem (no orphan RFCs). The trace is gate-enforced at capture time, not advisory. WSJF prioritisation works uniformly across the framework because every change is solving some problem.
- **Time-boxing** — each RFC carries a bounded scope; mid-flight scope expansion triggers a structured re-evaluation (`AskUserQuestion` deviation-approval per ADR-044 category 2) rather than silent body-drift.
- **First-class sub-workstream entities** — phased work is ordered explicitly (Phase 1 → 2 → …); deferred phases stay visible as first-class entities competing for WSJF attention rather than buried as TODO bullets in a parent ticket's body.
- **Every fix goes through an RFC — no atomic-fix exemption** — single-commit and multi-commit fixes alike are scoped as an RFC traced to the driving problem (per ADR-071: every problem is fixed only via an RFC, unconditionally — no carve-out, no effort threshold, no lighter path). An atomic fix is the **same** RFC as any other (its `stories:` array is simply empty when the work is not decomposed into stories); it is NOT a thin or scaled-down variant. The framework scales the multi-commit *coordination* surface (stories / story maps) **up** when the work needs it; it never scales the RFC itself **down**.
- **Composes with the existing problem framework** — RFC lifecycle mirrors problem lifecycle states (`proposed` / `accepted` / `in-progress` / `verifying` / `closed`); same WSJF formula; same capture-then-manage skill split (lightweight aside + heavyweight intake per ADR-032).

## Persona Constraints

- Solo developer using AI agents to investigate, fix, and ship work end-to-end. Multi-commit coordinated changes are the **exception**, not the norm — but every fix, atomic or coordinated, goes through an RFC (ADR-071). The framework surfaces the multi-commit *coordination* ceremony (stories / story maps) only when the work shape genuinely needs it; it does NOT scale the RFC itself down or exempt atomic shapes. There are no short cuts (user direction 2026-05-26, P311).
- **The new framework must visibly compose with JTBD-001 (per-edit governance) and JTBD-006 (AFK orchestrator selection) without rebuilding either.** JTBD-001 handles per-edit governance and (per its 2026-05-05 amendment) multi-commit coordinated-change governance at the change-set level; JTBD-006 handles AFK orchestration of WSJF-ranked work. JTBD-008 is the **capture-time and scoping** surface — it handles the act of decomposing (when do I split? how do I scope? how do I sequence?) and trace-to-problem invariant enforcement. Once decomposed, JTBD-001 governs the resulting commits and JTBD-006 selects them; JTBD-008 does not re-host either of those concerns.
- Strain surfaces first in the developer persona but composes naturally with tech-lead multi-team coordination needs (audit-trail, hand-off, parallel workstreams). Tech-lead persona is the secondary anchor.
- The framework must not introduce a parallel hierarchy that drifts from the problem-management primitives — RFCs sit alongside problems, never replace them. Problem-tier persona/JTBD anchoring is best-effort capture-time via the optional `**JTBD**:` + `**Persona**:` body fields per ADR-060 Phase 4 (as amended by P287 2026-06-02 — the historical `type: user-business` discriminator was retired as redundant with RFC/Story persona-anchoring).

## Current Solutions

- **Multi-phase fixes ride one problem ticket with a multi-section Fix Strategy** — works for 2-3 commit decompositions (P168 model); strains beyond. Ticket body becomes a moving target rather than a stable problem-statement-plus-RCA.
- **Sibling problem tickets capture explicitly-deferred phases** — works (P169 as P168 follow-up) but loses parent-child trace; future re-derivation of "what work was needed for X" requires graph traversal across tickets.
- **Workstream-shaped problem tickets accepted with a note** (P169 with "this is task-shaped" callout) — defers the structural fix.

None of these compose well with WSJF prioritisation when phases need to compete for attention as first-class entities.

## Related decisions

- **ADR-060** — Problem-RFC-Story framework with mandatory problem-trace and unified problem ontology. The decision that introduces the RFC layer JTBD-008 is anchored to.
- **JTBD-001** — Enforce Governance Without Slowing Down. JTBD-001 § Desired Outcomes was amended 2026-05-05 (P170 / ADR-060) to cover multi-commit coordinated-change governance at the change-set level. JTBD-008 composes by handling the **capture-time decomposition** surface; JTBD-001 handles the **lifecycle-time governance** of the resulting work.
- **JTBD-006** — Progress the Backlog While I'm Away. AFK orchestrator selects by WSJF; ADR-060 Phase 1 resolves WSJF placement at RFC-level so JTBD-006 selection from `docs/problems/` continues to work during the bootstrap window. JTBD-008 protects JTBD-006 by surfacing decomposition signals at capture time rather than letting work-shape drift hide multi-phase scope from the orchestrator's selection input.
- **JTBD-101** — Extend the Suite with New Plugins. Atomic-fix-adopter constraint. Per ADR-071 the RFC trace has **no opt-out**: atomic-fix shapes go through the same RFC as any fix. Only the multi-commit *coordination* surface (stories / story maps) is conditional on the work decomposing; the RFC trace itself is unconditional.
- **JTBD-201** — Restore Service Fast with an Audit Trail. Incident-driven problems compose naturally with RFC trace-to-problem invariant; tech-lead persona inherits JTBD-008 for incident-aftermath multi-commit fixes.

## Related problems

- **P170** (`docs/problems/170-...open.md`) — driver problem ticket. Captures the strain pattern (N=4 examples session-surfaced: P168 / P159 / P051 / P169) and the user direction defining the non-ITIL extensions.
- **P168** (`docs/problems/168-...verifying.md`) — first surfaced multi-commit decomposition. Slated for retroactive migration to RFC-001 in Slice 4 of the P170 story map.
- **P159** — Phase 1 shipped, Phase 2-3 deferred. Second-most-pressing example.
- **P051** — 6 improve shapes; third-most-pressing example.
- **P169** (`docs/problems/169-...open.md`) — first explicitly task-shaped ticket. The capture that surfaced the strain.

## Methodology source

- Jeff Patton, *User Story Mapping* (O'Reilly, 2014) — backbone/ribs/slices canonical reference for capture-time work decomposition. Applied at RFC level in ADR-060 Phase 2; applied at this JTBD's capture-time-scoping outcome.
- ITIL 4 Foundation, Change Enablement practice — RFC lifecycle conventions. The framework adopts the lifecycle mirror but rejects ITIL's split between Service Request and Problem (per ADR-060 invariant 2).
