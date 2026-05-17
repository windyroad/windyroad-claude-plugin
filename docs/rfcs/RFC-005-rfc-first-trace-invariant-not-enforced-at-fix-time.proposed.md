---
status: proposed
rfc-id: rfc-first-trace-invariant-not-enforced-at-fix-time
reported: 2026-05-17
decision-makers: [Tom Howard]
problems: [P251]
adrs: [ADR-060]
jtbd: [JTBD-008]
stories: []
---

# RFC-005: RFC-first trace invariant not enforced at fix-time

**Status**: proposed
**Reported**: 2026-05-17
**Problems**: P251
**ADRs**: ADR-060 (extends I-series with new symmetric-direction invariant)
**JTBD**: JTBD-008 (primary anchor — decompose-fix-into-coordinated-changes)

## Summary

ADR-060 I1 enforces the RFC→Problem trace at RFC capture time. The inverse direction — Problem→RFC trace at fix-time — is NOT enforced. Problems routinely accrete inline `## Root Cause Analysis` → `### Investigation Tasks` → `## Fix Strategy` checklists as fix work uncovers scope, rather than the agent stopping to scope an RFC + story map + JTBD trace before commencing. P251 captures the gap; JTBD-008 § "Trace invariant" + "Capture-time scoping" Desired Outcomes name the contract this RFC closes.

Scope: design and implement the symmetric Problem→RFC trace gate at the fix-time lifecycle surfaces. Include the atomic-fix carve-out per JTBD-008 § Persona Constraints ("Atomic-fix shapes pay no ceremony") — Effort ≤ M may proceed without RFC ceremony; Effort ≥ L requires RFC trace before fix work commences.

## Driving problem trace

- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without RFC, story map, or JTBD trace. Captured 2026-05-17 via user correction during /wr-itil:work-problems orchestrator main turn. Status: Open. JTBD trace: JTBD-008. Persona: solo-developer.

## Scope

(deferred — populate at /wr-itil:manage-rfc accepted transition)

Anticipated scope facets (to be ratified at the proposed → accepted gate):

1. **Lifecycle gate placement** — which transitions enforce the Problem→RFC trace check? Candidates:
   - Open → Known Error (when fix strategy is known) — earliest enforcement; matches the moment "fix is now real work" semantically
   - Known Error → Fix Released (commit lands) — latest enforcement; matches the moment "work shipped"
   - New "Open → In Progress" state — explicit semantic for "work commenced"; introduces a new lifecycle state
2. **Atomic-fix carve-out shape** — Effort ≤ M may not need RFC ceremony per JTBD-008 § Persona Constraints. The carve-out boundary needs:
   - Effort threshold (M vs L; per WSJF divisor 2 vs 4)
   - Override hatch for genuinely-multi-commit M-effort work
   - Atomic-fix-adopter friction guard per JTBD-101 (RFC ceremony stays opt-in for atomic shapes)
3. **Problem-ticket template extension** — add `**RFC**:` frontmatter field. Cardinality:
   - 0..N RFCs per problem (mirrors ADR-060 RFC `problems:` cardinality on the symmetric direction)
   - Nullable for atomic fixes within the carve-out
   - Required for user-business problems above the carve-out (composes with the I12 invariant — user-business already requires JTBD trace)
4. **Iter dispatch refusal at /wr-itil:work-problems Step 5** — orchestrator refuses to dispatch a fix iter on an RFC-less problem above the carve-out. Refusal options:
   - Hard-block (loop halts; user must capture RFC first; matches ADR-060 I1 hard-block precedent at the symmetric surface)
   - Soft-route (orchestrator auto-invokes /wr-itil:capture-rfc inline; matches ADR-013 Rule 6 fail-safe + ADR-044 silent-framework)
5. **Hook vs SKILL prose enforcement** — load-bearing-from-the-start per ADR-051 mandates a structural hook. Candidate hook: PreToolUse:Bash gate on `git commit` whose staged set includes ticket-state-transition with no RFC trace in the problem body's `**RFC**:` field. Sibling shape to P165 README-refresh-discipline hook.
6. **Story-map composition** — JTBD-008 outcomes also name "user story mapping" + sequencing. The RFC framework's Phase 2 (capture-story / list-stories per RFC-003) ships the story-tier; this RFC may compose with that work as a downstream dependency. Open question: does the trace gate also require story-map at fix-time, or is RFC-trace sufficient?
7. **New I-series invariant** — formalise as I13 (next sequential after ADR-060's I1-I12): "Every problem fix above the atomic carve-out MUST trace to a Proposed/Accepted/In-Progress RFC before lifecycle transition."

## Tasks

- [ ] (deferred — populate at /wr-itil:manage-rfc accepted transition)

Anticipated decomposition (to be ratified at the proposed → accepted gate):

- **B1** Architect + JTBD reviews of the seven scope facets → resolved direction set
- **B2** Author the new I13 invariant amendment to ADR-060 (composes existing I-series)
- **B3** Extend problem-ticket template + capture-problem + manage-problem SKILL surfaces with `**RFC**:` frontmatter field
- **B4** Ship the structural hook (sibling to P165 readme-refresh-discipline) per ADR-051 load-bearing-from-the-start
- **B5** Update /wr-itil:work-problems Step 5 iter dispatch logic with the carve-out check
- **B6** Update /wr-itil:manage-problem Step 7 lifecycle transition pre-flight with the trace check
- **B7** Behavioural bats coverage per ADR-052 (behavioural-tests-default) — fixture asserting iter dispatch refuses RFC-less problem above carve-out, accepts within carve-out
- **B8** Retro migration sweep — survey current Open / Known Error tickets; identify tickets above carve-out that would need retroactive RFC authoring; cost-of-retrofit informs the rollout shape

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12; lands in Slice 3 task B5.T9)

## Related

- **P251** — driving problem ticket; captured 2026-05-17 via user correction.
- **JTBD-008** — primary anchor; "Trace invariant" + "Capture-time scoping" + "First-class sub-workstream entities" Desired Outcomes all speak directly.
- **ADR-060** — parent framework. This RFC extends the I-series to the symmetric direction. ADR-060 Phase 1 ships RFC→Problem trace; this RFC ships Problem→RFC trace at fix-time.
- **ADR-051** — load-bearing-from-the-start; mandates structural hook over prose-only contract.
- **ADR-052** — behavioural-tests-default; B7 task contract.
- **JTBD-101** — atomic-fix-adopter friction guard; informs the atomic-fix carve-out shape.
- **JTBD-006** — work-backlog-AFK; the carve-out boundary affects AFK orchestrator dispatch latency.
- **JTBD-001** — enforce-governance; the structural hook composes with the existing per-edit governance band.
- **P196** — sibling; agents complete RFC docs without shipping the slices (different premature-completion failure mode; same RFC framework surface).
- **P189** — sibling; agent invents "deferred" framing on tracked phases (same class-of-behaviour at a different SKILL surface).
- **P165** — sibling structural hook shape; PreToolUse:Bash gate on staged ticket surfaces.

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)
