# Problem 342: Iter retros queue their own observations as `outstanding-questions.jsonl` entries for user-direction triage instead of auto-ticketing — same trust-boundary as `/wr-retrospective:run-retro` Step 4a

**Status**: Open
**Reported**: 2026-05-31
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next `/wr-itil:review-problems`; HIGH in practice — retros are the system designed to mechanically observe recurring patterns; routing those observations through user-direction triage instead of mechanical-ticket capture inverts the trust-boundary the run-retro skill already encodes)

**Origin**: internal
**Effort**: M (deferred — re-rate at next `/wr-itil:review-problems`; iter-prompt body amendment in `/wr-itil:work-problems` + cross-skill alignment in `/wr-retrospective:run-retro` Step 4b stage classification + possibly behavioural bats coverage on the auto-ticket path)
**Type**: technical

## Description

Surfaced 2026-05-31 by direct user observation (screenshot annotation during session 9 AFK exchange, immediately after iter 1's retro commit `e49a72e`):

> *"The retro's own observations about iter 12 + iter 7 are queued in outstanding-questions.jsonl for user-direction triage rather than auto-ticketed — same trust-boundary as Step 4a."*

Iter subprocesses run `/wr-retrospective:run-retro` before emitting `ITERATION_SUMMARY` per P086. The retro surfaces observations (cross-iter friction patterns, recurring hook misbehaviour, framework-improvement candidates, ticket-worthy defects discovered during the iter). Per the current iter prompt + `ITERATION_SUMMARY` schema, those observations get routed into `outstanding_questions: [...]` in the summary and accumulated to `.afk-run-state/outstanding-questions.jsonl` for orchestrator-level Step 2.5/2.5b surface.

The structural error: the retro is MECHANICAL OBSERVATION. It is precisely the system designed to detect recurring class-of-behaviour and surface them as ticketable artefacts. When a retro observes a defect (e.g. "iter 12 hit hook misbehaviour", "iter 7 surfaced a contract gap"), the right routing is **auto-capture via `/wr-itil:capture-problem`** — same trust-boundary as `/wr-retrospective:run-retro` Step 4a (verification close-on-evidence), which mechanically closes verifications based on observed evidence without user triage.

Instead, the iter retro defers the routing to user-direction triage: the observation is queued, the user reads it later, the user must decide whether to ticket it. The user direction surfaces the trust-boundary inversion: *retros that observe ticketable patterns should ticket them, not queue them*.

## Symptoms

- Iter retro surfaces a concrete ticketable observation (recurring class-of-behaviour, framework-gap, hook-bug, SKILL-contract drift) → routed to `outstanding_questions` queue → accumulates in `.afk-run-state/outstanding-questions.jsonl` → user must manually triage → user manually invokes `/wr-itil:capture-problem`.
- The observation may be **mechanically auto-ticketable** (the retro already has the symptoms, the failure mode, the iter exemplar) — yet the queue defers to user judgment.
- Across an AFK loop of N iters, N retros may accumulate observations that should have been N tickets; instead they pile up in the queue file.
- Cross-iter pattern detection — when iter 5 + iter 7 + iter 12 all observe a sibling class — is doubly deferred: each observation is queued individually instead of triggering a single class-of-behaviour ticket with all three iters as evidence.

## Workaround

User explicitly directs: route the retro observation to `/wr-itil:capture-problem`, not to `outstanding_questions`. Until iter prompt + run-retro Step 4b classification enforces this, the orchestrator (or the user post-session) must remember to triage the queue and lift mechanically-ticketable entries into tickets.

## Impact Assessment

- **Who is affected**: every user invoking `/wr-itil:work-problems` whose AFK loops generate retro observations that should be tickets.
- **Frequency**: every iter that surfaces a concrete ticketable observation in retro (the typical-case for any iter that hits friction, drift, or recurring pattern).
- **Severity**: HIGH in practice — retros are the trust-boundary the run-retro skill encodes as MECHANICAL. Routing their output through user-direction triage instead of mechanical-ticket capture undoes the trust-boundary the parent skill ships.
- **Analytics**: in-session evidence — iter 1 retro (commit `e49a72e`) included cross-iter observations about iter 12 + iter 7 in its retro body, which the user observed are exactly the class that should ticket, not queue.

## Root Cause Analysis

`/wr-retrospective:run-retro` Step 4a (verification close-on-evidence) carries the trust-boundary contract: when the retro mechanically observes a verification has met its evidence floor, the retro closes the verification — no user triage. This is the mechanical-stage carve-out applied at the retro surface (per ADR-044 + CLAUDE.md MANDATORY rules on mechanical-stage carve-outs).

Step 4b (problem-ticket capture from retro observations) has the symmetric pattern but is NOT applied consistently in the iter-retro path. The iter's prompt body (in `/wr-itil:work-problems` Step 5) directs the iter to route retro observations through `outstanding_questions` instead of `/wr-itil:capture-problem`. The iter is also told "no capture-* siblings mid-loop" — this rule was intended to prevent the iter from capturing tickets DURING work (P078-class spam), but it OVER-APPLIES to retro observations which ARE the legitimate capture surface.

The required structural shape:

1. **Iter retro observations classification**:
   - **Recurring class-of-behaviour observation** (sibling iters hit same pattern; SKILL-contract drift; hook misbehaviour; framework-gap): **auto-ticket via `/wr-itil:capture-problem`** in the iter's main turn (mechanical-stage carve-out per `/wr-retrospective:run-retro` Step 4a precedent).
   - **Direction-setting observation** (genuine user-judgment-bound question — design choice, deviation-approval, framework boundary): route to `outstanding_questions` for Step 2.5/2.5b surface.
   - **Ambiguous** (retro can't distinguish): default to auto-ticket; the ticket lifecycle will surface direction-setting questions through the standard `/wr-itil:manage-problem` flow.

2. **`/wr-itil:work-problems` iter-prompt body amendment**:
   - Strike "No `capture-*` siblings mid-loop" for retro observations — those ARE the legitimate capture surface
   - Add: "Retro observations of recurring class-of-behaviour MUST route to `/wr-itil:capture-problem` (mechanical-stage carve-out per run-retro Step 4a precedent); only direction-setting observations route to `outstanding_questions`."

3. **`/wr-retrospective:run-retro` Step 4b alignment**:
   - Mirror the iter-prompt's classification in run-retro Step 4b stage prose so the same trust-boundary applies whether retro fires in iter context OR standalone in main turn.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems`
- [ ] Amend `/wr-itil:work-problems` SKILL.md Step 5 iter-prompt body: relax the `no-capture-*-siblings-mid-loop` rule for retro-surfaced observations; direct retro to auto-ticket recurring class-of-behaviour observations via `/wr-itil:capture-problem`; route direction-setting observations to `outstanding_questions` only.
- [ ] Amend `/wr-retrospective:run-retro` SKILL.md Step 4b stage classification to enforce the mechanical-auto-ticket vs direction-setting-queue split per the same trust-boundary as Step 4a.
- [ ] Behavioural bats: assert work-problems SKILL.md carries the retro-auto-ticket exception to the no-capture-* rule; assert run-retro SKILL.md Step 4b carves out the mechanical-stage path.
- [ ] Cross-reference and possibly amend the `ITERATION_SUMMARY.outstanding_questions` schema: retros that emit OBSERVATIONS should not all funnel through that field; direction-setting subset only.
- [ ] Decide whether the auto-ticket path needs explicit policy authorisation (ADR-013 Rule 5 silent-proceed) given it fires `/wr-itil:capture-problem` from an iter context — likely yes; cite the precedent in the iter-prompt amendment.
- [ ] Sibling capture: P341 (work-problems must surface outstanding questions + run retro before ALL_DONE).
- [ ] Cross-check against the existing `.afk-run-state/outstanding-questions.jsonl` in this session for entries that should have been tickets; lift opportunistically during the next interactive session.

## Dependencies

- **Blocks**: trust-boundary integrity for iter-retro observations. Until the auto-ticket carve-out is in place, retros generate observations that pile up in the queue file instead of becoming durable WSJF-ranked backlog.
- **Blocked by**: (none — fix is bounded to SKILL.md amendments in two SKILLs + schema adjustment + bats coverage).
- **Composes with**: P341 (sibling — work-problems must surface outstanding questions + run retro before ALL_DONE), `/wr-retrospective:run-retro` Step 4a (mechanical-close trust-boundary precedent), ADR-044 (decision-delegation; the auto-ticket path is the framework-resolved mechanical-stage carve-out), CLAUDE.md MANDATORY P078 (capture-on-correction; this ticket's class is closely related but distinct — P078 is user-correction → offer capture; this ticket is retro-observation → auto-capture without user-direction round-trip).

## Related

(captured via direct user direction 2026-05-31 during session 9 AFK exchange after iter 1's retro commit `e49a72e` surfaced cross-iter observations that should have been tickets)

- **P341** — sibling-class capture; work-problems must surface outstanding questions + run retro before ALL_DONE.
- **P086** — retro-on-exit at iter subprocess level; this ticket's amendment locus is within the same iter-retro surface.
- **P078** — capture-on-correction (CLAUDE.md MANDATORY); same family of "capture instead of queue" rules but distinct trigger (correction vs retro-observation).
- **ADR-044** — decision-delegation contract; the mechanical-stage carve-out applied here mirrors the standard pattern.
- **ADR-013** — Rule 5 silent-proceed; the auto-ticket path is policy-authorised.
- `packages/itil/skills/work-problems/SKILL.md` Step 5 — iter-prompt body amendment locus.
- `packages/retrospective/skills/run-retro/SKILL.md` Step 4b — mechanical-stage classification amendment locus.
- `packages/itil/skills/work-problems/test/*.bats` + `packages/retrospective/skills/run-retro/test/*.bats` — behavioural-coverage loci.
