---
status: proposed
rfc-id: p346-backlog-flow-control-multi-phase
reported: 2026-05-31
decision-makers: [Tom Howard]
problems: [P346]
adrs: [ADR-079, ADR-032, ADR-022, ADR-014, ADR-052, ADR-026, ADR-071]
jtbd: [JTBD-001, JTBD-006, JTBD-101, JTBD-201]
stories: []
---

# RFC-013: P346 backlog flow control multi-phase

**Status**: proposed
**Reported**: 2026-05-31
**Problems**: P346
**ADRs**: ADR-079 (Phases 1+2 evidence-based relevance-close pass), ADR-032 (Phase 3 5th invocation pattern — fresh-context-subagent-as-decision-arbiter), ADR-022, ADR-014, ADR-052, ADR-026, ADR-071
**JTBD**: JTBD-001, JTBD-006, JTBD-101, JTBD-201

## Summary

P346 is the master ticket for the framework's backlog-flow-control mechanisms. The repository accumulates problem tickets faster than it closes them (47 days in: 102 Open + 40 Known Error + 116 Verifying; +2.82/day Active trajectory with no zero ETA), driven by automatic, cheap inflow (P078 capture-on-correction, P342 retro auto-capture, ADR-062 inbound discovery, agent-observed mid-iter friction) against effortful, expensive outflow.

This RFC retroactively traces the three-phase P346 fix work to satisfy ADR-071's unconditional Problem→RFC fix-time trace. Phases 1+2 shipped before RFC-013 was authored (2026-05-31 iters 4+5, governed by ADR-079); Phase 3 (this iter) lands the inflow-discipline subagent governed by ADR-032's 5th-pattern amendment. The decomposition + traces below cover all three phases as one logical fix of one master problem (per ADR-070, RFCs hold scope + decomposition + traces only — substantive decisions home in ADRs).

## Driving problem trace

- **P346** (`docs/problems/open/346-review-problems-no-path-to-close-no-longer-relevant-tickets-evidence-based.md`) — Open. The master ticket carries the full multi-phase scope, user direction (verbatim 2026-05-31), and acceptance evidence. Phase 1+2 deliverables address the outflow gap (`/wr-itil:review-problems` Step 4.6 + `evaluate-relevance.sh` 5 evidence shapes); Phase 3 deliverables address the inflow gap (capture-time hang-off-check subagent on `/wr-itil:capture-problem` + `/wr-itil:manage-problem` Step 2).

## Scope

In scope:

- **Phase 1** (shipped 2026-05-31 iter 4, `@windyroad/itil@0.40.0`) — evidence-based relevance-close pass (single shape: file-no-longer-exists) per ADR-079.
- **Phase 2** (shipped 2026-05-31 iter 5) — 4 more evidence shapes (ADR-shipped-with-`human-oversight: confirmed`, named-skill-or-feature-exists, self-marker-in-body, driver-child-ticket-closed) + Phase 1 false-positive fixes (state-suffix detection, sibling-file detection, rename detection via `git log --follow`). ADR-079 amended.
- **Phase 3** (this iter) — capture-time hang-off-check subagent per ADR-032 5th-pattern amendment. Mechanical pre-filter (≤5 candidates) on `/wr-itil:capture-problem` Step 2 + `/wr-itil:manage-problem` Step 2; fresh-context `wr-itil:hang-off-check` subagent dispatched on non-empty filtered set; structured verdict (`HANG_OFF: P<NNN>` or `PROCEED_NEW`) drives the SKILL deterministically. AFK safe-default (ambiguous-multi-parent → `PROCEED_NEW`). Maintainer-side firewall (JTBD-301 — plugin-user-side intake unchanged).

Out of scope (deferred to follow-up tickets):

- Verifying-ticket aging surface (P334/P336-class evidence-close for Verifying tickets exercised repeatedly without regression).
- Auto-rate the deferred Priority/Effort placeholders on captured tickets (currently deferred to `/wr-itil:review-problems` WSJF re-rank).
- Inflow-discipline extensions to story / story-map capture (parallel ADR-060 surfaces; ship under separate tickets when demand emerges).

## Tasks

Ordered slice decomposition (one coherent purpose per commit per ADR-014). Phase 1+2 already shipped; this RFC records them for the trace. Phase 3 commits ship under this iter.

### Phase 1 — relevance-close pass (DONE)

- [x] Slice 1a — ADR-079 capture
- [x] Slice 1b — `evaluate-relevance.sh` script + `wr-itil-evaluate-relevance` shim
- [x] Slice 1c — 18 bats fixtures GREEN
- [x] Slice 1d — `/wr-itil:review-problems` SKILL.md Step 4.6 + `/wr-itil:manage-problem` lifecycle extension
- [x] Slice 1e — `@windyroad/itil@0.40.0` released

### Phase 2 — evidence shape expansion (DONE)

- [x] Slice 2a — ADR-079 amendment with Phase 2 evidence shapes (commit `6980e13`)
- [x] Slice 2b — `evaluate-relevance.sh` extended with 4 shapes + Phase 1 false-positive fixes (commit `b160eb8`)
- [x] Slice 2c — bats extended to 33/33 GREEN
- [x] Slice 2d — SKILL.md Step 4.6 + manage-problem lifecycle sync to 5 shapes (commit `3bdd1d7`)
- [x] Slice 2e — `@windyroad/itil` minor + patch changesets queued

### Phase 3 — capture-time hang-off discipline (THIS RFC)

- [ ] Slice 3a — ADR-032 amendment with 5th invocation pattern + RFC-013 itself
- [ ] Slice 3b — `packages/itil/agents/hang-off-check.md` subagent + `packages/itil/agents/test/hang-off-check.bats` (3 fixtures) + `plugin.json` registration
- [ ] Slice 3c — `/wr-itil:capture-problem` Step 2 + `/wr-itil:manage-problem` Step 2 amendments
- [ ] Slice 3d — `@windyroad/itil` minor changeset
- [ ] Slice 3e — P346 master ticket Open → Verifying via close-on-evidence

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Confirmation criteria

Discharges ADR-079's Confirmation + ADR-032's amendment Cross-reference contract:

- Phases 1+2: `evaluate-relevance.bats` GREEN (33 fixtures); smoke test against active backlog showed conservative outflow.
- Phase 3: `hang-off-check.bats` GREEN (3 fixtures); the canonical regression fixture (P347's description + candidate set containing P346 → `HANG_OFF: P346`) passes.
- `/wr-itil:capture-problem` + `/wr-itil:manage-problem` Step 2 prose carries the mechanical pre-filter + dispatch contract + JTBD-301 firewall + AFK safe-default language.
- P346 master ticket transitions to Verifying with Phase 3 boxes ticked in the Investigation Tasks checklist.

## Reassessment

Revisit if:

- The hang-off-check subagent's `HANG_OFF` verdict rate is too high (wrongly absorbing distinct new tickets into parents) — signal: maintainers manually un-folding captured tickets in `/wr-itil:review-problems`. Mitigation: tune the mechanical pre-filter's signal strictness.
- The hang-off-check subagent's `PROCEED_NEW` verdict rate is too high in the face of obvious hang-off candidates (the safe-default collapsing too often) — signal: `/wr-itil:review-problems` continues to surface manually-mergeable duplicates after Phase 3 ships. Mitigation: raise the candidate-cap from 5 OR tighten the pre-filter to surface more bodies.
- Phase 1+2 outflow + Phase 3 inflow combined do not bend the +2.82/day Active trajectory — signal: the open-problems-tracker dashboard shows continued monotonic growth 30 days after Phase 3 ships. Mitigation: revisit the full taxonomy (Verifying-ticket aging surface, additional outflow paths).

## Related

- P346 (driving problem; master ticket — multi-phase scope authored there, not duplicated per ADR-070).
- P347 (closed as duplicate-of-P346; canonical regression case for Phase 3 hang-off-check bats fixture).
- ADR-079 (Phases 1+2 governing decision).
- ADR-032 (Phase 3 governing decision — 5th invocation pattern).
- ADR-022, ADR-014, ADR-052, ADR-026, ADR-071 (cross-cutting framework decisions).
- JTBD-001, JTBD-006, JTBD-101, JTBD-201 (persona-anchored jobs served).

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)
