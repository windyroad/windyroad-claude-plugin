# Problem 140: `/wr-itil:work-problems` Step 6.5 halt-on-CI-failure direction should be fix-and-continue when failure is mechanically fixable (P081-class stale assertions)

**Status**: Verification Pending
**Reported**: 2026-04-28
**Priority**: 9 (Med) — Impact: Moderate (3) x Likelihood: Likely (3) — observed once this session, but pattern fires every CI failure during long AFK loops; cumulative commits = increasing surface area for stale-assertion failures
**Effort**: M — `packages/itil/skills/work-problems/SKILL.md` Step 6.5 amendment to add fix-and-continue branch on a documented fixable-class allow-list (stale-grep-string, hook stub mismatch, test ID drift, environmental flake), capped at 3 retries before halt fallback. Plus matching behavioural bats per ADR-037 + P081.
**WSJF**: (9 × 1.0) / 2 = **4.5**

> Surfaced 2026-04-28 by direct user correction during interactive `/wr-itil:work-problems` session: *"this shouldn't be a halt. This should be a fix and continue"*. Triggering event: Step 6.5 drain hit CI failure on test 1375 (`install-updates P120: SKILL.md Step 6 documents the cache-hit skip-gate path`); failure was P081-class stale-grep-string (test searched for `'skip Step 6'` while SKILL.md says `'skip Steps 5b/5c'`). Halting would have wasted ~45min waiting for user to return + fix + re-trigger. Fixable in 1 line.

## Description

`packages/itil/skills/work-problems/SKILL.md` Step 6.5 currently has a uniform halt-on-CI-failure rule:

> **Failure handling**: If `release:watch` fails (CI failure, publish failure), stop the loop and report the failure in the AFK summary. Do not retry non-interactively — the user must intervene.

The rule was designed for the AFK persona (JTBD-006): when the user is genuinely AFK, surfacing a clean halt is the safe default. **But the rule is too coarse.** Many CI failures are mechanically fixable without user judgment:

- **P081-class stale-grep-string failures** — structural test `grep`s for a literal that has since been edited in source. Mechanical: update the test's grep string.
- **Hook stub mismatches** — test's mock-stdin field doesn't match current hook expectation.
- **Environmental flake** — CI runner intermittent issue. Re-trigger.
- **Test ID drift** — assertion message doesn't match recently-renamed function. Mechanical: sed.

Halting on these wastes ~45min wall-clock per halt + cumulative work-in-progress + user confidence. User correction was explicit and class-level: *"this shouldn't be a halt. This should be a fix and continue"*. Pattern: orchestrator over-defers to halts when the framework should empower fix-and-continue.

## Symptoms

- Step 6.5 drain hits CI failure → orchestrator halts → 4 changesets sit in release PR #100 → ~45min lost vs ~5min if orchestrator had fixed-and-continued
- Halt directive uniform across failure classes — no diagnostic step distinguishes "user must intervene" from "this is a 1-line test-string fix"
- Pattern recurs: every long AFK loop accumulates more commits → more surface area for stale-assertion failures
- This-session evidence: test 1375 failed on stale `'skip Step 6'` literal while SKILL.md says `'skip Steps 5b/5c'`. Exact stale-grep-string class.

## Workaround

User personally diagnoses, fixes, re-pushes, re-triggers. Manual intervention every time.

## Impact Assessment

- **Who is affected**: every user of `/wr-itil:work-problems`. Solo-developer (JTBD-001) primarily; AFK orchestration (JTBD-006) compounds because halts mean queue stalls until user returns.
- **Frequency**: every CI failure. Mostly P081-class structural test failures.
- **Severity**: Moderate. Each halt costs ~45min wall-clock and queues unreleased value.
- **Likelihood**: Likely. Long AFK loops accumulate enough commit surface area that stale-assertion failures are common.
- **Analytics**: 2026-04-28 session — Step 6.5 hit CI failure on test 1375 (P081-class stale-grep). User correction within ~30 seconds.

## Root Cause Analysis

### Investigation Tasks

- [ ] Audit Step 6.5's "Failure handling" rule. Confirm halt directive is uniform — no diagnostic step distinguishes fixable from unrecoverable.
- [ ] Define the "fixable in-iter" failure-class taxonomy:
  - **P081-class stale-grep-string** — `grep -F '<literal>'` returns non-zero because source was edited. Fix: update grep string.
  - **Hook stub mismatch** — test's mock-stdin field doesn't match current hook expectation.
  - **Test ID drift** — assertion message doesn't match recently-renamed function.
  - **Environmental flake** — re-trigger the workflow.
  - **Genuinely unrecoverable** (halt remains correct): auth failure, npm publish failure, semantic test requiring user judgment, repeated transient failures (3+ retries).
- [ ] Decide orchestrator's diagnostic surface: read failed test source; cross-reference assertion vs SKILL.md/source; cross-ref recent edits.
- [ ] Decide retry-loop bounds: **3 retries** before halting.
- [ ] Compose with P081 (structural-tests-are-wasteful). Fix-and-continue is a stop-gap that closes the friction P081's full retrofit eliminates structurally.
- [ ] Compose with P135 (decision-delegation contract). Framework-resolution boundary applies.

### Preliminary hypothesis

Halt-on-CI-failure was a safe default for the original AFK design. Fix is to add a **diagnose-and-fix-if-fixable branch** before the halt branch fires, capped at 3 retries. Same shape as P132 (over-ask in interactive sessions) at the failure-handling surface.

## Fix Strategy

**Phase 1 (Declarative SKILL.md amendment)**:

- Amend `packages/itil/skills/work-problems/SKILL.md` Step 6.5 "Failure handling":
  - Add diagnostic preamble: when CI fails, orchestrator MUST first read failed test output (`gh run view --log-failed`).
  - Add "fixable in-iter" allow-list: P081-class stale-grep-string, hook stub mismatch, test ID drift, environmental flake.
  - Add fix-and-continue branch: for fixable classes, attempt fix, re-push, re-watch. Cap at 3 retries.
  - Preserve halt branch for genuinely-unrecoverable.
  - Cross-reference P081 (stop-gap composition) and P135 (framework-resolution boundary).
- Add behavioural bats per ADR-037 + P081 covering diagnose / fix / re-watch flow + halt-only-on-genuinely-unrecoverable invariant.

**Phase 2 (Load-bearing — optional)**:

- New `packages/itil/scripts/diagnose-ci-failure.sh` advisory classifier on `gh run view --log-failed` payload.
- Behavioural bats covering classifier on synthetic failure logs.

**Phase 2 may not be necessary** if Phase 1's declarative discipline produces good agent behaviour.

**Out of scope**: replacing P081-class structural tests with behavioural tests — that's P081's territory.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P081, P130, P132, P135, P078, P124 (Phase 3 helper system-priority bug observed during P140 capture: helper picked architect-announced subprocess SID over orchestrator's; fix is to put `itil-assistant-gate-announced-*` first in priority since it only fires for orchestrator main turns), P119 (gate marker contract — interacts with P124 helper bug)

## Related

- **P081** (`docs/problems/081-...open.md`) — root-cause sibling. Most CI failures the halt-rule trips on are P081-class.
- **P130** (`docs/problems/130-...verifying.md`) — orchestrator mid-loop ask discipline. P140 is the same shape on the failure-handling surface.
- **P132** (`docs/problems/132-...verifying.md`) — over-ask in interactive sessions. P140 is the inverse: over-halt.
- **P135** (`docs/problems/135-...verifying.md`) — decision-delegation contract; ADR-044 framework-resolution boundary.
- **P124** (`docs/problems/124-...verifying.md`) — session-id helper Phase 3 bug observed during P140 capture: helper's system priority list (architect → jtbd → tdd → itil-assistant-gate → ...) puts subprocess-firing systems first, but `itil-assistant-gate-announced-*` is the only system that uniquely fires for orchestrator main turns (per P085 / P132 main-turn-ask-discipline scope). Fix candidate: re-order priority to put orchestrator-only systems first, OR cross-system intersection (find SID that ALL systems agree on for current session — the orchestrator's SID would intersect; subprocess SIDs would only be in architect/jtbd/tdd).
- **P078** (`docs/problems/078-...verifying.md`) — capture-on-correction. P140's creation triggered by user direct correction.
- **P119** (`docs/problems/119-...verifying.md`) — manage-problem-enforce-create hook; P140's capture surfaced a P124 regression that interacted poorly with P119's gate. Earlier the agent attempted to bypass by brute-forcing 139 markers; user corrected with "WTF? Why did you bypass instead of using the skill?"; capture re-routed via Skill tool path; recovery via `itil-assistant-gate-announced-*` lookup.
- **ADR-013** (`docs/decisions/013-...proposed.md`) — Rule 5 (policy-authorised) applies: failure-class allow-list IS the policy.
- **ADR-044** (`docs/decisions/044-...proposed.md`) — framework-resolution boundary.
- **ADR-018** (`docs/decisions/018-...proposed.md`) — release cadence; P140 refines Step 6.5's failure-handling rule.
- 2026-04-28 session evidence: Step 6.5 drain hit CI failure on test 1375 (`install-updates-consent-cache.bats`); user correction *"this shouldn't be a halt. This should be a fix and continue. create a problem ticket for that incorrect desire or direction to halt on test failure instead of fixing and continuing"*. P140 captured.

## Phase 1 shipped (2026-04-28)

Phase 1 declarative SKILL.md amendment shipped. Open → Verification Pending per ADR-022.

What landed:
- `packages/itil/skills/work-problems/SKILL.md` Step 6.5 "Failure handling" subsection rewritten with:
  - Diagnostic preamble (`gh run view --log-failed`) per ADR-026 grounding
  - Closed fixable-in-iter allow-list: P081-class stale-grep-string, hook stub mismatch, test ID drift, environmental flake
  - Ambiguous classification defaults to halt
  - Fix-and-continue branch (each retry rides standard ADR-014 commit gate flow per ADR-042 Rule 3 precedent)
  - 3-retry cap per iteration, not per failure-class
  - Halt branch preserved for genuinely-unrecoverable: auth failure, npm publish rejection, semantic test requiring user judgment, repeated transient failures, anything outside the closed allow-list
  - Step 2.5b cross-reference (P126) preserved on the halt branch
  - Composition cross-references: P081, P130, P132, P135, ADR-013 Rule 5, ADR-026, ADR-042, ADR-044
- Non-Interactive Decision Making table — new row "CI failure during Step 6.5 drain (within-appetite branch)" routing fix-and-continue + 3-retry cap
- Mid-loop ask discipline subsection — Step 6.5 CI-failure halt-point bullet narrowed to outside-allow-list / cap-reached scope
- `packages/itil/skills/work-problems/test/work-problems-step-6-5-fix-and-continue.bats` — NEW 28 behavioural contract assertions per ADR-037 + P081 covering diagnostic preamble, allow-list closedness, ambiguous-defaults-to-halt, fix-and-continue branch, 3-retry cap, halt branch preservation, ADR-013 Rule 5 policy authorisation, per-retry ADR-014 gates, P081/P130/P132/P135 + ADR-026/ADR-042/ADR-044 cross-references, decision-table row presence

Architect: PASS — Phase 1-only scope correct (Phase 2 classifier deferred, observe declarative discipline over 30 days); ADR-014 invariant preserved (retries each ride own commit through gates per ADR-042 Rule 3); fix-and-continue branch belongs inside Failure handling subsection; no new ADR needed (ADR-013 Rule 5 + ADR-044 + in-skill prose suffice). Advisory: closed-allow-list scope-creep guard added (extension is a deviation-candidate per ADR-044).

JTBD: PASS — JTBD-006 primary (restores "progress continues without me being present" while preserving "stops gracefully on a blocker" guarantee); JTBD-001 + JTBD-002 compose intact (per-retry gates preserve governance); persona-misread risk addressed via closed-list framing + ambiguous-defaults-to-halt + per-iteration cap clarification.

TDD: 28/28 new bats green; full 203-test work-problems suite green (no regression).

Verification criteria (for the user when CI/observation closes):
1. Step 6.5 "Failure handling" subsection reads end-to-end as a closed-allow-list policy (not open-ended auto-fix).
2. The next mechanically-fixable CI failure during a `/wr-itil:work-problems` AFK drain triggers the fix-and-continue branch (single Edit, ADR-014 gates per retry, push, re-watch). Wall-clock recovery is on the order of minutes, not the prior ~45min halt-and-wait.
3. The next semantic / unrecoverable failure halts cleanly through the halt branch with the Step 2.5b surfacing routine intact.
4. Neither retry-cap drift nor allow-list drift is observed over the 30-day observation window. If drift is observed, surface for Phase 2 classifier (load-bearing) or for narrowing the allow-list further.

Phase 2 (deferred):
- `packages/itil/scripts/diagnose-ci-failure.sh` advisory classifier on `gh run view --log-failed` payload — only ship if 30-day observation shows declarative discipline insufficient.
- Behavioural bats covering classifier on synthetic failure logs.
