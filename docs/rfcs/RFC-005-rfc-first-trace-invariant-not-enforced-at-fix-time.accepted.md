---
status: accepted
rfc-id: rfc-first-trace-invariant-not-enforced-at-fix-time
reported: 2026-05-17
decision-makers: [Tom Howard]
problems: [P251]
adrs: [ADR-071, ADR-072, ADR-073, ADR-070, ADR-060, ADR-022, ADR-051, ADR-052, ADR-042, ADR-044]
jtbd: [JTBD-008, JTBD-001, JTBD-006, JTBD-101]
stories: []
---

# RFC-005: RFC-first trace invariant not enforced at fix-time

**Status**: accepted
**Reported**: 2026-05-17
**Problems**: P251
**ADRs**: ADR-071 (unconditional RFC-first — the governing decision), ADR-072 (RFC required at the propose-fix step on a Known Error), ADR-073 (fix-time gate auto-creates a missing RFC, everywhere), ADR-070 (RFCs hold no independent decisions — why this RFC carries none), ADR-060 (parent framework; I13 invariant added under RFC-006), ADR-022 (Known Error lifecycle semantics the gate placement conforms to), ADR-051 (load-bearing structural enforcement), ADR-052 (behavioural-test coverage), ADR-042 (held-changeset graduation), ADR-044 (decision-delegation contract)
**JTBD**: JTBD-008 (primary — decompose-fix-into-coordinated-changes), JTBD-001 (governance composition), JTBD-006 (AFK orchestrator throughput), JTBD-101 (atomic-fix-adopter — the carve-out is removed; atomic fixes go through the same RFC per ADR-071)

> **Retrofitted 2026-05-26 under RFC-006 (ADR-070); gate design corrected 2026-05-26 per P314.** This RFC originally carried its own decisions (facets F1–F7) inline, plus a "Considered Options / Alternatives Rejected" section — exactly the P310 blind spot ADR-070 closes. It has been reduced to **scope + decomposition + traces**. The decisions it used to hold now live in the ADR ledger: gate placement → **ADR-072**, missing-RFC behaviour → **ADR-073**, RFC-first-is-unconditional → **ADR-071** (which **repudiated** the atomic-fix carve-out the original F2/F7/I13 carried). **ADR-072/073 were rewritten 2026-05-26 per P314** — the original `Open → Known Error` placement + hard-block stance were rejected at the `/wr-architect:review-decisions` oversight drain; this RFC's mechanism prose is corrected to match (propose-fix placement + auto-create-everywhere). RFC-005 ships only the **gate mechanism** (schema + enforcement + bats); it makes no decisions of its own.

## Summary

ADR-060 I1 enforces the RFC→Problem trace at RFC capture time. The inverse direction — Problem→RFC trace at fix-time — is NOT enforced (P251). Problems routinely accrete inline `## Root Cause Analysis` → `### Investigation Tasks` → `## Fix Strategy` checklists as fix work uncovers scope, rather than the fix being scoped as an RFC.

RFC-005 ships the **mechanism** that enforces the Problem→RFC trace at fix-time: the problem-ticket `rfcs:` frontmatter schema, the propose-fix gate + auto-create mechanism, the `/wr-itil:manage-problem` + `/wr-itil:work-problems` enforcement, and the behavioural coverage. The gate is **unconditional** — no atomic-fix carve-out, no effort threshold (per ADR-071). The RFC is required at the **propose-fix step on a Known Error** (per ADR-072, conforming to ADR-022's Known Error semantics); when a fix is proposed with no RFC, the framework **auto-creates a problem-traced skeleton RFC** rather than blocking, **everywhere the gate fires** (per ADR-073).

## Driving problem trace

- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without an RFC. Captured 2026-05-17 via user correction during `/wr-itil:work-problems`. JTBD trace: JTBD-008. Persona: solo-developer.

## Scope

RFC-005 extends ADR-060's I-series with the symmetric Problem→RFC trace at fix-time (the I13 invariant, in ADR-060, rewritten under P314). It ships the **enforcement mechanism only** — every choice among ≥2 viable options that this RFC used to embed is now an ADR (per ADR-070):

- **Gate placement** — the RFC is required at the **propose-fix step on a Known Error**, NOT at `Open → Known Error` (a problem reaches Known Error on root cause + documented workaround alone; the fix is proposed after, which produces the RFC — per ADR-022). No new lifecycle state. Decision: **ADR-072**.
- **Unconditional, no carve-out** — every problem fix traces to an RFC; there is no effort threshold and no override hatch. Decision: **ADR-071** (repudiates the original F2 carve-out). Atomic fixes go through the **same** RFC as any fix — no lighter, thin, or scaled-down path; the JTBD-101 atomic-fix-adopter carve-out is removed, not relocated.
- **Missing-RFC behaviour** — when a fix is proposed on a Known Error with no RFC trace, the framework **auto-creates a problem-traced skeleton RFC** (scope = the fix; no decisions per ADR-070) rather than blocking — **everywhere the gate fires**: the interactive `/wr-itil:manage-problem` propose-fix surface AND the AFK `/wr-itil:work-problems` orchestrator. Decision: **ADR-073**.
- **Load-bearing enforcement** — the propose-fix gate + auto-create ship as real mechanism on day one, not advisory prose. Application of **ADR-051** (load-bearing-from-the-start).
- **Story-map composition deferred** — I13 enforces the RFC trace only; story-map presence at fix-time is transitively assured by ADR-060 I7/I8 and is out of scope here. Scope boundary; revisit only if RFC-003 ships and dogfood evidence shows a gap.

Problem-ticket frontmatter gains `rfcs: [RFC-<NNN>, ...]` (cardinality `0..N`: empty until a fix is proposed on the Known Error; `≥ 1` once a fix is proposed/auto-created, unconditionally). The shape mirrors ADR-060 I1's RFC→Problem `problems:` array (symmetric bidirectional trace).

## Tasks

Ordered slice decomposition (one-purpose-per-commit per ADR-014). Slices land in a held-changeset window per ADR-042 / P162; the held window stays paused until B6 bats green + B8 dogfood close. The gate mechanism is **unconditional** throughout (no carve-out branch, no override hatch) and **auto-creates** a missing RFC rather than blocking.

- [x] **B1** — Add the I13 invariant (RFC required at fix-proposal) to ADR-060's Mandatory invariants. **Done under RFC-006 slice 4; corrected under P314** (propose-fix placement + auto-create-everywhere, conforming to ADR-022). The gate surface is the propose-fix step on a Known Error, NOT the `Open → Known Error` transition.
- [ ] **B2** — Extend problem-ticket frontmatter schema: add `rfcs: [RFC-<NNN>, ...]` (`0..N`). Update the problem-ticket template + `/wr-itil:capture-problem` to populate `rfcs: []` by default; update `/wr-itil:manage-problem` to append RFC references when a fix is proposed / decomposes.
- [ ] **B3** — Ship the I13 propose-fix gate + auto-create mechanism. When a fix is proposed on a Known Error and no RFC traces the problem, **auto-create a problem-traced skeleton RFC** (scope = the fix; ADR-070-compliant, no Considered-Options block) and proceed — **auto-create-and-proceed, NOT `permissionDecision: deny`** (per ADR-073), for every effort level. Surface is the propose-fix action (B4); a structural backstop (e.g. PreToolUse:Bash on the fix-commit) MAY assert the trace exists per ADR-051 but auto-creates rather than blocks.
- [ ] **B4** — Add/formalise the propose-fix action in `/wr-itil:manage-problem` (the surface ADR-072 places the gate at). On propose-fix for a Known Error: require an RFC trace; auto-create a problem-traced skeleton if missing (per ADR-073). No `--rfc-deferred` flag (carve-out repudiated).
- [ ] **B5** — Update `/wr-itil:work-problems` so that when it dispatches a fix on an RFC-less Known Error, it **auto-creates the problem-traced RFC then proceeds** (per ADR-073) — the loop is NOT skipped or blocked. Structured-log auto-create events for the ADR-073 reassessment criterion.
- [ ] **B6** — Behavioural bats per ADR-052 covering: (a) proposing a fix on an RFC-less Known Error **auto-creates** a problem-traced RFC at every effort level (S/M/L/XL — no carve-out, no block); (b) proposing a fix when an RFC already traces the problem is a no-op (no duplicate); (c) work-problems auto-creates-and-proceeds rather than skipping; (d) ADR-060 I2 uniformity — manage-problem / work-problems behaviour identical regardless of `type:` value.
- [ ] **B7** — Migration sweep: enumerate `docs/problems/` Known-Error tickets that have a proposed/in-flight fix but no RFC trace (no effort filter — the gate is unconditional). Produce a survey at `docs/audits/i13-rollout-survey-2026-05-17.md`. Informs B8 dogfood selection + the rollout-grandfathering decision.
- [ ] **B8** — Forward-dogfood: take a real Known-Error problem from the B7 survey, propose a fix on it under the I13 gate (auto-create fires), ship a fix slice, confirm the auto-created RFC is correct. Mirrors ADR-060 Phase 1 forward-dogfood. Document the evidence inline.
- [ ] **B9** — Wire the ADR-073 reassessment criterion (auto-created RFCs systematically under-scoped) into `/wr-retrospective:run-retro` Step 2b advisory signal collection. The auto-create event log becomes a retro input.
- [ ] **B10** — Held-changeset graduation: ADR-042 auto-apply paused for the RFC-005 commit chain until B6 bats green + B8 dogfood confirms auto-create fires correctly. Graduate atomically per ADR-060 architect finding 12.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

- **P251** — driving problem ticket; captured 2026-05-17 via user correction.
- **ADR-071** — every fix goes through an RFC (the unconditional governing decision; repudiated the F2 carve-out RFC-005 originally carried).
- **ADR-072 (RFC required at fix-proposal) / ADR-073 (auto-create missing RFC everywhere)** — the gate-placement + missing-RFC-behaviour decisions re-homed from RFC-005's F1/F4 under RFC-006 slice 1a; **rewritten 2026-05-26 per P314** (the original Open→Known-Error placement + hard-block were rejected at the oversight drain).
- **ADR-022** — Known Error lifecycle semantics (root cause + workaround; fix-release IS the `Known Error → Verifying` transition) the gate placement conforms to.
- **ADR-070** — RFCs hold no independent decisions (the reason this RFC was retrofitted to carry none).
- **RFC-006** — the implementation RFC that re-homed RFC-005's decisions and ships the I13 + ADR-060 line-97 amendment.
- **P314** — the rework ticket that corrected the gate placement + behaviour (this RFC's mechanism prose tracks it).
- **ADR-060** — parent framework. RFC-005 ships the symmetric Problem→RFC direction; the I13 invariant text lives in ADR-060.
- **ADR-051** — load-bearing-from-the-start; real mechanism over prose-only.
- **ADR-052** — behavioural-tests-default; B6 task contract.
- **JTBD-008** — primary anchor. **JTBD-101** — atomic-fix-adopter; the carve-out is removed (per ADR-071), atomic fixes go through the same RFC. **JTBD-006** — AFK orchestrator throughput (ADR-073 auto-create keeps the loop moving). **JTBD-001** — per-edit governance composition.
- **P165** — sibling structural hook shape; PreToolUse:Bash gate on staged ticket surfaces.
- **P196 / P189** — sibling premature-completion / fictional-defer failure modes at the RFC/SKILL surfaces.
