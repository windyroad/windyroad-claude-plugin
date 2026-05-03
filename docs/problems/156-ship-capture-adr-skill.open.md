# Problem 156: Ship `/wr-architect:capture-adr` skill — lightweight aside-invocation surface for ADR capture during foreground work

**Status**: Open
**Reported**: 2026-05-03
**Priority**: 12 (High) — Impact: Significant (3) x Likelihood: Almost certain (4)
**Effort**: M — new skill SKILL.md + REFERENCE.md per ADR-038 progressive-disclosure pattern; bin shim per ADR-049; behavioural bats per ADR-052; compose with `wr-architect:create-adr` (the heavyweight canonical path) so capture-adr produces a `.proposed.md` with skeleton sections deferred for later canonical review.

**WSJF**: (12 × 1.0) / 2 = **6.0**

> Surfaced 2026-05-03 by user direction post-AFK-loop-restart: split P014 (ADR-032 master tracker) into its three planned children. P156 is the second child — the `/wr-architect:capture-adr` skill that iter-12's outstanding_questions named as a foreground-iter requirement. Sibling to P155 (capture-problem) and P157 (pending-questions-surface hook). Iter 12's plan named P154/P155/P156; P154 was taken by P137 npm-pack-detector follow-up; children renumber to P155/P156/P157.

## Description

The current ADR-creation surface is `/wr-architect:create-adr` — the heavyweight canonical path that walks through Considered Options (≥2 options required per MADR 4.0), Decision Drivers, Decision Outcome, Consequences, Confirmation, More Information, and Reassessment Triggers. Full flow ~10-15 turns and burns substantial context.

This is correct for canonical decision-making. But it's wrong for the **aside-invocation** use case — when a foreground work session generates a decision worth recording but the agent / user can't afford the full ceremony. The need surfaces:

- Mid-AFK-iter design decisions (e.g. iter 17 P137 chose Option C namespace-prefix + Option B permalinks; iter 18 P033 Phase 1b inline shape; iter 19 P033 Phase 2a back-channel write contract). Each decision was substantial enough to warrant an ADR; iter 19 actually shipped ADR-056 inline because the decision was load-bearing for Phase 2a.
- User-driven design decisions during conversational work (e.g. user direction during P088 settled options (a)/(b)/(c) but the settlement was buried in P088's ticket body rather than codified in an ADR).
- Architect review delegations that yield a verdict-with-rationale (PASS-WITH-NOTES, ISSUES-FOUND, etc.). The verdict + rationale together IS often a decision worth recording. Currently the verdicts vanish into commit messages.

A lightweight `/wr-architect:capture-adr` skill provides:

1. **Skeleton ADR file** — writes `docs/decisions/<NNN>-<kebab-title>.proposed.md` with required sections present but flagged "(deferred to canonical review)" for the heavy lifting (Considered Options, Consequences). The MUST-have skeleton includes Title, Status, Context (1-line), Decision (1-line), and a "Rationale (deferred)" placeholder.
2. **Defer the ≥2-options requirement** — capture-adr writes a single-option skeleton and flags it for follow-up canonical review (`/wr-architect:create-adr` invoked on the same `<NNN>` ID later expands to MADR-compliant shape).
3. **No architect-review handoff inline** — capture-adr is for capture; the architect agent reviews the ADR later via the standard delegation when canonical review fires.
4. **Compose with P155 (capture-problem)** — when an iter surfaces both a problem AND a related decision, the user can fire capture-problem + capture-adr in sequence without 20-30 turns of overhead.
5. **Compose with P157 (pending-questions-surface hook)** — captured ADRs that surface design questions for the user can have those questions queued via the same `outstanding_questions` schema.

## Symptoms

- Mid-AFK-iter design decisions get captured INSIDE the ADR-056 / ADR-057 etc. ad-hoc-shaped — sometimes well, sometimes underspecified. Iter 19's ADR-056 was substantial; iter 17's ADR-055 was substantial; iter 18's no-new-ADR work could have used an ADR-shaped record but didn't get one.
- Architect review verdicts (PASS-WITH-NOTES, ISSUES-FOUND) land in commit message bodies. Future readers grep commit history for the verdict but lose the rationale.
- User-driven design conversations resolve options (a)/(b)/(c) but the settlement only lives in the problem ticket's RCA section.

## Workaround

Currently: `/wr-architect:create-adr` is the only path. Workaround = use the heavyweight skill.

Sub-workarounds:
- Inline-write the ADR via Edit/Write tool, skipping the skill. Bypasses the architect-review hand-off + ADR-014 commit grain. Brittle.
- Capture as a problem ticket with a "Decision" section. Conflates problems with decisions; muddies WSJF ranking.
- Defer to retro file. Loses the ADR-shape audit trail.

## Impact Assessment

- **Who is affected**: Solo-developer (foreground design decisions) + plugin-developer (sibling-finding architectural decisions) + AFK orchestrator (mid-iter design captures).
- **Frequency**: Every multi-phase fix this session generated an ADR (049/051/052/053/054/055/056/057). At ~1 ADR per 2-3 iters, capture-adr would be invoked frequently.
- **Severity**: Significant — decisions not captured drift; future iters reinvent the same design space.
- **Likelihood**: Almost certain — known gap, no controls in place.
- **Analytics**: This session shipped 6 cluster ADRs (049/051/052/053/054/055) + 2 implementation ADRs (056/057 if/when codified). Each could have been captured first-aside then expanded canonically; instead each was created inline through `/wr-architect:create-adr` (the canonical path) burning ~10-15 turns each.

## Root Cause Analysis

### Preliminary Hypothesis

ADR-032 names capture-adr as a deferred slice. P088 settled the user-direction-scoped decision: capture-adr is shippable with self-contained payload shape (distinct from capture-retro which has the context-marshalling problem).

Fix shape — sibling to P155 capture-problem:

1. **New skill at `packages/architect/skills/capture-adr/SKILL.md`** — minimal contract:
   - Step 0: parse Title + 1-line Context + 1-line Decision (from invocation args or AskUserQuestion if missing).
   - Step 1: compute next ADR ID via local + origin-max lookup.
   - Step 2: skeleton-fill the MADR template (Title / Status: proposed / Context / Decision / Rationale (deferred)) + flag Considered Options + Consequences + Confirmation + More Information + Reassessment Triggers as "(deferred to /wr-architect:create-adr canonical review)".
   - Step 3: write the file.
   - Step 4: minimal commit (no architect-review handoff inline; defer to canonical review).
   - Step 5: report.
2. **REFERENCE.md** — progressive-disclosure pattern.
3. **Behavioural bats** per ADR-052 — assert: skeleton-fill produces well-formed `.proposed.md`; deferred-flag prose present; canonical review path documented.
4. **Compose with `/wr-architect:create-adr`** — when the user later invokes create-adr on the same `<NNN>` ID, it detects the existing capture-adr skeleton and expands it canonically (vs. writing a new ADR).

### Investigation Tasks

- [ ] Architect review — confirm skeleton shape preserves MADR conformance even in deferred state (i.e. a capture-adr skeleton is a valid ADR-stub that doesn't violate MADR validation).
- [ ] JTBD review.
- [ ] Implement: SKILL.md + REFERENCE.md + bin shim + behavioural bats.
- [ ] Wire into create-adr's "expand existing skeleton" path.

## Dependencies

- **Blocks**: (none directly — but plugin-developer ADR throughput improves)
- **Blocked by**: (none — ADR-032 design landed; ADR-038 / 049 / 052 patterns already shipped)
- **Composes with**: P155 (sibling — capture-problem); P157 (sibling — pending-questions-surface hook); P014 (parent — ADR-032 master); ADR-038 (progressive-disclosure); ADR-049 (bin shim); ADR-052 (bats); MADR 4.0 conformance

## Related

- P014 (`docs/problems/014-...open.md`) — parent / master tracker.
- P155 (sibling — capture-problem skill).
- P157 (sibling — pending-questions-surface hook).
- ADR-032 (governance skill invocation patterns) — capture-adr is the foreground-aside variant.
- ADR-038 (progressive-disclosure) — SKILL.md + REFERENCE.md split.
- ADR-049 (plugin-script resolution) — bin shim shape.
- ADR-052 (behavioural-tests-default) — bats fixture shape.
- P088 — settled the user-direction-scoped decision; capture-adr is shippable.
