# Problem 251: RFC-first trace invariant not enforced — fixes start without RFC, story map, or JTBD trace

**Status**: Open
**Reported**: 2026-05-17
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**JTBD**: JTBD-008
**Persona**: solo-developer

## Description

We have a RFC process and fixes for each problem MUST be captured through a RFC (instead of as task list), PRIOR to the work on fixing it commencing, but I'm not seeing that happening. Instead problems have task lists and no RFC and most importantly, no user story mapping or tracing to JTBD.

JTBD-008 names "Trace invariant — every RFC traces back to a problem (no orphan RFCs). The trace is gate-enforced at capture time, not advisory" as a desired outcome. The current framework enforces RFC→Problem trace at RFC capture time per ADR-060 I1 invariant. But the inverse direction — Problem→RFC trace at fix-time — is NOT enforced. Agents (and AFK orchestrator iters) routinely start fix work on a problem ticket using a task-list inline in the ticket body (`## Root Cause Analysis` / `### Investigation Tasks` / `### Fix Strategy`) without first authoring an RFC, without a story map, and without a JTBD trace on the underlying problem.

JTBD-008 § Desired Outcomes also names "The decomposition decision happens at capture time, not as drift mid-flight." The current behaviour treats decomposition as drift — task lists accrete in the problem body as fix work uncovers scope, rather than the agent stopping to scope an RFC + story map + JTBD trace before commencing.

## Symptoms

(deferred to investigation)

Initial observations:

- Most `Open` and `Known Error` tickets in `docs/problems/` carry `## Root Cause Analysis` → `### Investigation Tasks` and `## Fix Strategy` sections with checkbox task lists, NOT an RFC reference in the `## Dependencies` or `## Related` section.
- `/wr-itil:work-problems` orchestrator iter prompts dispatch the iter against the highest-WSJF problem ticket directly via `/wr-itil:manage-problem`, with no step that checks "does this problem have an associated RFC?" before commencing fix work.
- `/wr-itil:manage-problem` SKILL.md does not gate Step 7 (transition Open → Known Error → Fix Released) on the presence of a linked RFC + story map + JTBD trace.
- The problem-ticket template (per `/wr-itil:capture-problem` + `/wr-itil:manage-problem`) has no `**RFC**:` frontmatter field on problems classified `type: user-business` — even though ADR-060 Phase 4 made JTBD trace required on user-business problems, the RFC trace was not made symmetric.
- Recent fix-shipped tickets (search the `closed/` and `verifying/` subdirectories) show fix commits landing without an `RFC-<NNN>` cross-reference in either commit message or ticket body — confirming the gap is observable, not theoretical.

## Workaround

(deferred to investigation)

Possible interim workarounds (to validate):

- Author RFC-first for any multi-slice problem (Effort ≥ L); accept atomic-fix problems (Effort ≤ M) commencing without RFC ceremony per JTBD-008 § Persona Constraints "Atomic-fix shapes pay no ceremony".
- Manual cross-check during `/wr-itil:review-problems` Step 4a / 4b to flag tickets that have started fix work without RFC trace.

## Impact Assessment

- **Who is affected**: solo-developer persona (primary anchor of JTBD-008), tech-lead persona (secondary). AFK orchestrator iters most acutely — they cannot pause to author an RFC; they default to the task-list-inline shape.
- **Frequency**: high — observable across most Open / Known Error / fix-shipped tickets.
- **Severity**: (deferred to investigation) — degrades JTBD-008 outcomes but does not break atomic shipping; ranking-and-prioritization decisions decouple from user-anchored sequencing because the JTBD trace and story-map sequencing are missing.
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — likely candidates: (1) `/wr-itil:manage-problem` Step 7 transition does not require RFC trace; (2) AFK orchestrator iter prompts do not enforce RFC-first on dispatch; (3) ticket template carries `### Investigation Tasks` + `### Fix Strategy` sections, encoding the "task list in ticket body" anti-pattern as the default shape; (4) ADR-060 Phase 3 / Phase 4 may have shipped one direction of the trace invariant (RFC→Problem) without the symmetric direction (Problem→RFC at fix-time).
- [ ] Identify which lifecycle transition should require the RFC trace — Open → Known Error (when fix strategy is known)? Open → In Progress (a new state)? Known Error → Fix Released (when commit lands)?
- [ ] Identify the atomic-fix carve-out shape — Effort ≤ M may not need RFC ceremony per JTBD-008 § Persona Constraints, but the carve-out should be explicit at the gate.
- [ ] Survey current Open / Known Error tickets — how many would need retroactive RFC authoring? Cost-of-retrofit informs the scope of the fix.
- [ ] Create reproduction test — likely an `i7-rfc-trace-at-fix-time` behavioural bats test asserting `/wr-itil:work-problems` Step 5 dispatch refuses to dispatch a fix iter on an RFC-less problem above the Effort carve-out.

## Dependencies

- **Blocks**: (none — observation ticket; fix design TBD)
- **Blocked by**: (none)
- **Composes with**: [[P170]] (RFC framework parent), [[P196]] (agent reports RFC-document completion as fix-shipped — premature-completion class), [[P189]] (agent invents deferred framing — different surface of "skip the contract" class-of-behaviour)

## Related

- **JTBD-008** (`docs/jtbd/solo-developer/JTBD-008-decompose-fix-into-coordinated-changes.proposed.md`) — Desired Outcomes "Trace invariant" + "Capture-time scoping" both speak directly to this problem. This ticket is the load-bearing symptom that JTBD-008 outcomes are not being delivered at the fix-time surface.
- **ADR-060** (`docs/decisions/060-...accepted.md`) — Phase 3 + Phase 4 in-scope amendment 2026-05-13 shipped I1 (RFC→Problem trace at capture), I6 (Story→Problem trace at capture), I9 (Story→JTBD trace at capture), I12 (JTBD trace required on user-business problems). The symmetric Problem→RFC trace at fix-time is NOT in the I-series — this ticket names that gap.
- **P170** (`docs/problems/known-error/170-problem-tickets-strain-as-fixes-decompose-into-multiple-coordinated-changes-need-rfc-framework.md`) — parent / RFC framework driver. P170 Phase 2 shipped the framework; this ticket reports a Phase 3 / Phase 4 enforcement gap.
- **P196** (`docs/problems/open/196-agent-reports-rfc-document-completion-as-fix-shipped-premature-completion-on-multi-slice-rfcs.md`) — sibling; agents complete RFC docs without shipping the slices. This ticket is the inverse — agents skip the RFC entirely.
- **P189** (`docs/problems/open/189-...md`) — sibling; agent invents "deferred" framing on tracked phases without user direction. Same class-of-behaviour at a different SKILL surface (`/wr-itil:work-problems` / `/wr-itil:manage-problem` vs ADR-060 phase tracking).
- (captured via /wr-itil:capture-problem; expand at next investigation)

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-005 | accepted | RFC-first trace invariant not enforced at fix-time |
| RFC-006 | verifying | Implement ADR-070 + ADR-071 — re-home RFC decisions to ADRs and make RFC-first unconditional |
