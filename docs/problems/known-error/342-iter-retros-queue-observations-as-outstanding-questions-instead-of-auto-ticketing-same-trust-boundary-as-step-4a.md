# Problem 342: Iter retros queue their own observations as `outstanding-questions.jsonl` entries for user-direction triage instead of auto-ticketing — same trust-boundary as `/wr-retrospective:run-retro` Step 4a

**Status**: Known Error
**Reported**: 2026-05-31
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next `/wr-itil:review-problems`; HIGH in practice — retros are the system designed to mechanically observe recurring patterns; routing those observations through user-direction triage instead of mechanical-ticket capture inverts the trust-boundary the run-retro skill already encodes)

**Origin**: internal
**Effort**: M (deferred — re-rate at next `/wr-itil:review-problems`; iter-prompt body amendment in `/wr-itil:work-problems` + cross-skill alignment in `/wr-retrospective:run-retro` Step 4b stage classification + possibly behavioural bats coverage on the auto-ticket path)

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
- [x] Amend `/wr-itil:work-problems` SKILL.md Step 5 iter-prompt body: relax the `no-capture-*-siblings-mid-loop` rule for retro-surfaced observations; direct retro to auto-ticket recurring class-of-behaviour observations via `/wr-itil:capture-problem`; route direction-setting observations to `outstanding_questions` only. — implemented session 9 iter 6 (2026-05-31).
- [x] Amend `/wr-retrospective:run-retro` SKILL.md Step 4b stage classification to enforce the mechanical-auto-ticket vs direction-setting-queue split per the same trust-boundary as Step 4a. — implemented session 9 iter 6 (new Step 4b Stage 1 sub-step 2 carries the classification taxonomy; Step 4b Stage 1 numbering renumbered to host the new step).
- [x] Behavioural bats: assert work-problems SKILL.md carries the retro-auto-ticket exception to the no-capture-* rule; assert run-retro SKILL.md Step 4b carves out the mechanical-stage path. — `packages/itil/skills/work-problems/test/work-problems-p342-retro-auto-ticket-carveout.bats` (10 fixtures) + `packages/retrospective/skills/run-retro/test/run-retro-step-4b-retro-auto-ticket-carveout.bats` (9 fixtures), all GREEN.
- [x] Cross-reference and possibly amend the `ITERATION_SUMMARY.outstanding_questions` schema: retros that emit OBSERVATIONS should not all funnel through that field; direction-setting subset only. — schema unchanged (the schema already carries category-typed entries); the routing discipline is captured in the iter-prompt taxonomy + run-retro Step 4b mirror, so the schema continues to host direction-setting subset only.
- [x] Decide whether the auto-ticket path needs explicit policy authorisation (ADR-013 Rule 5 silent-proceed) given it fires `/wr-itil:capture-problem` from an iter context — likely yes; cite the precedent in the iter-prompt amendment. — confirmed: iter-prompt body cites ADR-013 Rule 5 + ADR-044 framework-resolution boundary as the carve-out's authority; Step 4b mirror cites the same.
- [x] Sibling capture: P341 (work-problems must surface outstanding questions + run retro before ALL_DONE). — both shipped in same changeset.
- [ ] Cross-check against the existing `.afk-run-state/outstanding-questions.jsonl` in this session for entries that should have been tickets; lift opportunistically during the next interactive session. — deferred (session-specific queue triage is a manual user task on return; not gating).

## Fix Strategy

Implemented session 9 iter 6 (2026-05-31). Two-locus SKILL.md amendment + behavioural bats coverage + changeset queued via single batch per ADR-014 (rides same commit as P341).

**Loci:**
- `packages/itil/skills/work-problems/SKILL.md` Step 5 iter-prompt body — Constraint #3 amended to carve out `/wr-itil:capture-problem` on the retro path EXCEPT for retro-surfaced observations of recurring class-of-behaviour (mechanical-stage carve-out per run-retro Step 4a precedent); Constraint #4 retro-on-exit clause now carries the P342 classification taxonomy (recurring class-of-behaviour / SKILL-contract drift / hook misbehaviour / framework-gap → auto-ticket; direction-setting → outstanding_questions; ambiguous → default to auto-ticket).
- `packages/retrospective/skills/run-retro/SKILL.md` Step 4b Stage 1 — new sub-step 2 carries the symmetric mirror of the same classification taxonomy so the trust-boundary fires whether retro runs in iter context (work-problems Step 5) OR standalone in main turn (run-retro Step 4b). Existing Stage 1 numbering renumbered to host the new step (1 → P016 concern-boundary; 2 → P342 classification; 3 → manage-problem dispatch).
- `packages/itil/skills/work-problems/test/work-problems-p342-retro-auto-ticket-carveout.bats` — 10 behavioural fixtures.
- `packages/retrospective/skills/run-retro/test/run-retro-step-4b-retro-auto-ticket-carveout.bats` — 9 behavioural fixtures.

**Behavioural assertions covered (work-problems):**
- Iter-prompt body carves out capture-* for retro-surfaced observations.
- Iter-prompt directs retro to auto-ticket via /wr-itil:capture-problem.
- Iter-prompt cites Step 4a precedent for mechanical-stage carve-out.
- Iter-prompt classifies recurring class-of-behaviour as auto-ticket.
- Iter-prompt classifies direction-setting as outstanding_questions.
- Iter-prompt classifies ambiguous observations as default-to-auto-ticket.
- Iter-prompt cross-references run-retro Step 4b carve-out symmetry.
- P130 mid-loop AskUserQuestion ban preserved.

**Behavioural assertions covered (run-retro Step 4b mirror):**
- Names mechanical-auto-ticket vs direction-setting-queue split.
- Cites Step 4a precedent.
- Names recurring class-of-behaviour as auto-ticket route.
- Names direction-setting as outstanding_questions route.
- Names ambiguous default-to-auto-ticket asymmetry.
- Cross-references work-problems Step 5 iter-prompt symmetry.
- Cites ADR-044 + ADR-014.
- Cites P342.

**Composition:**
- Composes with run-retro Step 4a precedent (verification close-on-evidence mechanical-stage carve-out — same trust-boundary applied to a different surface).
- Composes with ADR-013 Rule 5 (policy-authorised silent proceed for capture-* on retro path).
- Composes with ADR-014 (capture-problem / manage-problem commits per ticket; run-retro does NOT commit auto-ticket creates).
- Composes with ADR-032 (foreground-spawns-N-background fanout pattern already documented for Stage 1 — P342 reinforces, does not contradict).
- Composes with ADR-044 (mechanical-stage carve-out framework-resolved authority).
- Composes with P130 (mid-loop AskUserQuestion ban unchanged — carve-out is for capture-* siblings on retro path only).
- Composes with P078 (capture-on-correction — distinct trigger; both end in capture but for different signals).
- Composes with P148 (Stage 1 anti-pattern guard preserved — auto-ticket IS the legitimate Stage 1 path; the carve-out doesn't add a new "Tickets Deferred" cause class).

Awaiting release ship via `.changeset/p341-p342-pre-all-done-gate-and-retro-auto-ticket-carveout.md` (`@windyroad/itil` minor + `@windyroad/retrospective` minor). On release, `Status` will auto-transition to `Verification Pending` per ADR-022.

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
