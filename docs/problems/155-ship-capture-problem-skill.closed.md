# Problem 155: Ship `/wr-itil:capture-problem` skill — lightweight aside-invocation surface for problem capture during foreground work

**Status**: Closed (verified 2026-05-05)
**Reported**: 2026-05-03
**Priority**: 12 (High) — Impact: Significant (3) x Likelihood: Almost certain (4)
**Effort**: M — new skill SKILL.md + REFERENCE.md per ADR-038 progressive-disclosure pattern; bin shim per ADR-049; behavioural bats per ADR-052; integrate with manage-problem Step 2 create-gate (P119) so capture-problem writes the marker correctly without re-running the full Step 2 grep when the user is mid-capture (capture-problem is the lightweight aside that defers full duplicate-check to a follow-up review).

**WSJF**: (12 × 1.0) / 2 = **6.0**
**Type**: technical

> Surfaced 2026-05-03 by user direction post-AFK-loop-restart: split P014 (ADR-032 master tracker) into its three planned children. P155 is the first child — the `/wr-itil:capture-problem` skill that iter-12's outstanding_questions named as a foreground-iter requirement. Sibling to P156 (capture-adr) and P157 (pending-questions-surface hook). Iter 12's plan named P154/P155/P156 for the three children; P154 was taken by the P137 npm-pack-detector follow-up captured 2026-05-03 mid-iter-20, so the children renumber to P155/P156/P157.

## Description

The current problem-capture surface is `/wr-itil:manage-problem <description>` — a heavyweight skill that fires Step 0 README reconciliation preflight, Step 2 duplicate-grep, Step 3 next-ID computation, Step 4 information-gathering, Step 4b multi-concern check, Step 5 ticket-file write, Step 5 P094 README refresh, and Step 11 commit gate. The full flow is ~10 turns of agent work and burns substantial context.

This is correct for new-problem creation as the canonical path. But it's wrong for the **aside-invocation** use case — when the user (or agent mid-iter) wants to capture an observation quickly during foreground work without disrupting the current task. The need surfaces repeatedly:

- Mid-AFK-iter sibling-findings (e.g. iter 20's "itil's package.json files array missing scripts/" note that became P140 R1) — the iter authoring context can't afford a 10-turn manage-problem detour, so the finding gets recorded in `notes` field of `ITERATION_SUMMARY` and post-processed by the orchestrator main turn.
- User-initiated rapid captures during retros, code reviews, or correction conversations — the user has a fresh observation, wants it on the backlog, and shouldn't have to wait for a full manage-problem ceremony.
- AFK orchestrator main turn captures — same shape as iter sibling-findings but from the orchestrator surface (the user's mid-loop interjections in this very session — P151 / P152 — were these).

A lightweight `/wr-itil:capture-problem` skill provides:

1. **Minimal duplicate-check** — quick keyword grep with conservative threshold; defer full duplicate analysis to a follow-up `/wr-itil:review-problems` invocation. Rationale: capture-time false-positives (creating a duplicate that gets merged later) are cheaper than capture-time false-negatives (losing the observation entirely).
2. **Skeleton ticket file** — writes `docs/problems/<NNN>-<title>.open.md` with required sections (Description, Symptoms, Workaround, Impact Assessment, Root Cause Analysis stub, Dependencies stub, Related stub) but doesn't ask the user to fill them all out. Mark sections "(deferred to investigation)" so later work picks up cleanly.
3. **No README refresh inline** — the captured ticket gets indexed on next `/wr-itil:review-problems` invocation per the existing P094 contract. Saves 1-2 turns per capture.
4. **Single commit per capture** — one ticket file + one minimal commit per ADR-014 grain. No batch-of-three multi-concern split overhead unless the user explicitly invokes that.
5. **Composes with manage-problem Step 2 create-gate (P119)** — capture-problem writes the marker correctly so the subsequent Write doesn't hit P119 deny.

## Symptoms

- Mid-AFK-iter the agent observes a sibling-finding worthy of a ticket but cannot afford the full manage-problem ceremony. Workaround: bury the observation in `notes` field, hope the orchestrator main turn captures it later. Outcome: 50%+ of sibling-findings never make it to tickets (P078 driver — "observations could very easily be lost if I was in a rush").
- User mid-conversation says "btw, this is broken too — capture it" and the agent either (a) fires manage-problem and burns 10 turns, breaking conversational flow, or (b) defers to retro summary which is itself a P078 anti-pattern (P148 driver).
- The orchestrator main turn during AFK loop captures user-driven mid-loop tickets (P151, P152, P154 in this session). Each capture took 5-15 minutes wall-clock through manage-problem. Total session capture overhead: ~30-45 minutes across 3 captures.

## Workaround

Currently: `/wr-itil:manage-problem <description>` is the only path. Workaround = use the heavyweight skill.

Sub-workarounds for the mid-iter sibling-finding case:
- Record in retro file `Tickets Deferred` section (introduced by P148 fix). Effective for AFK iters but not for user-driven rapid captures (which don't run a retro).
- Write the observation to BRIEFING.md or a topic file in `docs/briefing/`. Bypasses the manage-problem flow but loses the WSJF-rankable structure. Not a real ticket.
- Tell the user "remember this observation" in a chat reply. Brittle; observation gets lost on context compaction.

None reliable. Capture skill is the source-side fix.

## Impact Assessment

- **Who is affected**: All three personas mid-foreground-work — solo-developer (rapid capture during foreground), plugin-developer (sibling-finding during plugin work), AFK orchestrator (mid-iter capture by orchestrator main turn). Plugin-user persona unaffected (capture-problem is internal tooling).
- **Frequency**: Continuous. Every AFK loop session hits this; every user-driven correction conversation hits this; every retro that surfaces observations hits this.
- **Severity**: Significant — observations not captured cost 1-2 weeks of WSJF-rankable backlog signal per session. Per RISK-POLICY Impact-3 ("...some observations missed, no data corruption, recoverable...") — the observations are eventually re-encountered if the underlying issue keeps recurring, but the audit trail of when/who/why is lost.
- **Likelihood**: Almost certain — known gap, no controls in place. P078 + P148 are sibling tickets in the same family.
- **Analytics**: This very session — 3 user-driven captures (P151, P152, P154) + multiple iter sibling-findings (iter 20 broken-shim leading to P140 R1; iter 14's 3-instance pattern; iter 15's similar; iter 17's). Without capture-problem, ~50% of sibling-findings never reach the backlog.

## Root Cause Analysis

### Preliminary Hypothesis

ADR-032 (governance skill invocation patterns) names capture-problem as a deferred slice. P088 settled the user-direction-scoped (a)/(b)/(c) decision: capture-retro is deferred (context-marshalling problem), but capture-problem and capture-adr retain self-contained payload shape and are shippable.

The fix shape:

1. **New skill at `packages/itil/skills/capture-problem/SKILL.md`** — minimal contract:
   - Step 0: README reconciliation preflight (same as manage-problem; ~1 turn).
   - Step 1: parse description (same as manage-problem).
   - Step 2: minimal-grep duplicate check (3-keyword cap; conservative).
   - Step 2.5: write the create-gate marker per P119.
   - Step 3: compute next ID (same as manage-problem).
   - Step 4: skeleton-fill the ticket template (defer-flag empty sections).
   - Step 5: write the file.
   - Step 6: minimal commit (no README refresh inline; defer to next /wr-itil:review-problems).
   - Step 7: report.
2. **REFERENCE.md** — per ADR-038 progressive-disclosure pattern (sibling to install-updates' SKILL.md+REFERENCE.md split per ADR-098 / ADR-038).
3. **Behavioural bats** per ADR-052 — assert: skeleton-fill produces well-formed ticket; minimal-grep doesn't hard-fail on no-matches; create-gate marker writes correctly; commit message uses convention `docs(problems): capture P<NNN> <title>`.
4. **Compose with P135's `outstanding_questions` queue** — when the user surfaces an observation via capture-problem from inside an AFK loop main turn, the capture skill should still respect the iter-boundary contract: the orchestrator's between-iter aggregation queue file (`.afk-run-state/outstanding-questions.jsonl`) is the right surface for accumulated direction questions, but capture-problem is for tickets-worthy observations. They're distinct.

### Investigation Tasks

- [ ] Architect review — confirm minimal-grep shape (3-keyword cap, conservative) doesn't surface too many false-positive duplicates that disrupt the lightweight flow.
- [ ] JTBD review.
- [ ] Implement: SKILL.md + REFERENCE.md + bin shim + behavioural bats per ADR-005.
- [ ] Wire into manage-problem create-gate (P119) so the marker handoff is clean.
- [ ] Behavioural smoke test: run capture-problem against this very ticket's description-shape and confirm correct skeleton-fill.
- [ ] Document the invocation pattern in install-updates SKILL.md or BRIEFING.md so users know when to use capture-problem vs manage-problem.

## Dependencies

- **Blocks**: P078 (capture-on-correction OFFER pattern — closes when capture-problem ships); P148 (Tickets Deferred retro section becomes legacy when capture-problem ships)
- **Blocked by**: (none — ADR-032 design landed; P119 + P124 + P142 + ADR-049 + ADR-052 + ADR-038 all already shipped or designed)
- **Composes with**: P156 (sibling — capture-adr skill); P157 (sibling — pending-questions-surface hook); P014 (parent — ADR-032 master tracker); P135 (outstanding_questions schema this skill respects); ADR-038 (progressive-disclosure pattern); ADR-049 (bin shim resolution); ADR-052 (behavioural-tests-default)

## Related

- P014 (`docs/problems/014-aside-invocation-for-governance-skills.open.md`) — parent / master tracker for ADR-032 children.
- P156 (sibling — capture-adr).
- P157 (sibling — pending-questions-surface hook).
- P078 (`docs/problems/078-...verifying.md`) — capture-on-correction OFFER; depends on capture-problem.
- P148 (`docs/problems/148-...verifying.md`) — Tickets Deferred retro section; would simplify when capture-problem ships.
- ADR-032 (governance skill invocation patterns) — capture-problem is the foreground-aside variant per ADR-032.
- ADR-038 (progressive-disclosure pattern) — SKILL.md + REFERENCE.md split shape.
- ADR-049 (plugin-script resolution via bin/-on-PATH) — bin shim shape for the new skill.
- ADR-052 (behavioural-tests-default for skill testing) — bats fixture shape.
- P088 (`docs/problems/088-...verifying.md`) — settled the user-direction-scoped decision: capture-problem + capture-adr are shippable; capture-retro is deferred (context-marshalling problem).

## Fix Released

Shipped 2026-05-03 in this commit (AFK iter 2 of `/wr-itil:work-problems`). Awaiting user verification.

**Artefacts shipped**:

- `packages/itil/skills/capture-problem/SKILL.md` — runtime contract (~150 lines, ADR-038 progressive-disclosure budget). Steps 0-7: reconciliation preflight; description parse; minimal-grep + create-gate marker; next-ID; skeleton-fill template (deferred-placeholder pattern); Write; commit; report.
- `packages/itil/skills/capture-problem/REFERENCE.md` — rationale, edge cases, contract trade-offs, ADR cross-references.
- `packages/itil/skills/capture-problem/test/capture-problem.bats` — 14 behavioural fixtures per ADR-052: P119 create-gate composition (3 tests), next-ID formula (2 tests), title-only conservative duplicate-grep (2 tests), skeleton-fill template (1 test), allowed-tools surface (3 tests), deferred-README-refresh contract (1 test), existence/wiring (2 tests). All 14 green.
- `docs/decisions/032-governance-skill-invocation-patterns.proposed.md` — appended **"Foreground-lightweight-capture variant (P155 amendment, 2026-05-03)"** section between Observable-output contract (line 199) and Scope (line 201). Names the new variant alongside the deferred background-capture variant; documents the deferred-README-refresh contract; pin variant-selection precedence (foreground-lightweight is LEAD post-P155).

**Architectural review verdict (this session)**: PASS — three substantive issues from initial review resolved (ADR-032 amendment, ADR-031 path layout matches on-disk flat reality, deferred-README-refresh contract documented inline in the amendment). JTBD review: PASS (JTBD-001, JTBD-006, JTBD-101 all served; no persona-scope mismatches; plugin-user out of scope).

**Behavioural-test verification**:

```
$ npx bats packages/itil/skills/capture-problem/test/capture-problem.bats
1..14
ok 1..14 — all green
```

**Verification path for the user**: invoke `/wr-itil:capture-problem <description>` against a real observation. Expected outcome: ~3-4 turn skeleton-filled ticket lands at `docs/problems/<NNN>-<title>.open.md`, single commit `docs(problems): capture P<NNN> <title>`, README is NOT touched, trailing pointer surfaces "Run /wr-itil:review-problems next to fold P<NNN> into the WSJF rankings". Then run `/wr-itil:review-problems` to fold the captured ticket into the WSJF table and re-rate the deferred placeholders.

Recovery path if the close action was wrong: `/wr-itil:transition-problem 155 known-error` flips back to Known Error for further work.
