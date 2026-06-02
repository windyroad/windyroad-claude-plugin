# Problem 193: `risk-gate.bats:163` "Band B with no hash file" test fails non-deterministically at the 5s/5s TTL boundary

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Med) — Impact: 2 (Minor — test flakiness, not production correctness) x Likelihood: 2 (Possible — fires when load delays push elapsed past 5s) (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)

## Description

`packages/risk-scorer/hooks/test/risk-gate.bats` test #14 ("Band B with no hash file: passes but does NOT slide (no invariance proof)") fails intermittently with:

> Expected gate to allow but it denied: Risk score expired (5s old, TTL 5s).

Test setup at risk-gate.bats:157-166:
```bash
@test "Band B with no hash file: passes but does NOT slide (no invariance proof)" {
  printf '3' > "$SCORE_FILE"
  _backdate "$SCORE_FILE" 3
  rm -f "$HASH_FILE"
  BEFORE_MTIME=$(_mtime "$SCORE_FILE")
  sleep 1
  assert_gate_allows "$TEST_SESSION" "commit"
  ...
}
```

The test backdates the score file by 3 seconds, sleeps 1 second, then calls the gate (TTL default 5 seconds in test). Total elapsed at assertion time is approximately 4-5 seconds. The gate's TTL check is `age < TTL` (strict less-than), so elapsed exactly equals 5 triggers the expired-branch.

Whether the test passes or fails depends on:
- Wall-clock precision: `_backdate "$SCORE_FILE" 3` sets mtime to `now - 3s`; if the gate's `now` is read slightly later, elapsed can hit 5s.
- System load: under loaded CI or local-machine load, the 1-second sleep + intervening fork/exec overhead can push elapsed past 5s before the gate samples `now`.

## Symptoms

- `not ok 14 Band B with no hash file: passes but does NOT slide (no invariance proof)` appears intermittently in full-suite bats runs.
- Reproducible by running the test under load (e.g. while a parallel build is consuming CPU).
- Does NOT reproduce in isolation under low system load — the test passes when run as a single bats invocation on a quiet machine.

## Workaround

None at present — the test is flaky in CI but the suite re-runs typically resolve it. Manual retry of `npx bats hooks/test/risk-gate.bats` usually passes.

## Impact Assessment

- **Who is affected**: plugin-developer (JTBD-101) running the test suite; AFK orchestrator if it gates iteration progress on bats green.
- **Frequency**: intermittent; observed at least once in the 2026-05-15 P038 session under normal session load.
- **Severity**: Minor — false negative in test, not a production-path bug. The 5s TTL is a test-only constant; production TTL is 3600s and not subject to this boundary issue.
- **Analytics**: deferred to investigation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Confirm reproduction: run the test under controlled load and measure elapsed-at-assertion vs the configured TTL.
- [ ] Decide between (a) widening the test TTL so the assertion has slack (e.g. TTL=10s, sleep 1 — elapsed 4-5s well below 10s), or (b) tightening the test's elapsed budget (e.g. backdate 2s, sleep 1, elapsed 3-4s well below 5s), or (c) making the gate's TTL check `age <= TTL` (allow-at-boundary) — but this changes the production contract and is the wrong fix for a test flake.
- [ ] Apply the chosen fix; verify the test passes 100/100 in a loop.
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.

### Preliminary Hypothesis

The test is right at the TTL boundary by design (it's testing Band B = `TTL/2 <= age < TTL`). Under load, the actual elapsed exceeds the upper bound. The fix is option (b) — tighten the elapsed budget so the assertion has more headroom — or option (a) widening TTL. Both are test-only changes that preserve the production gate semantics.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P090 (gate marker hard-cap; related TTL contract), P107 (TTL extension; same band-of-TTL family)

## Related

- `packages/risk-scorer/hooks/test/risk-gate.bats:157-166` — the flaky test.
- `packages/risk-scorer/hooks/risk-score-commit-gate.sh` — the gate under test.
- Captured by `/wr-retrospective:run-retro` Step 4b Stage 1 + user direction "don't defer the stage 1 ticketing" (2026-05-15).

**Recurrence 2026-05-28 — broke main CI on an unrelated docs-only commit (likelihood under-rated).** CI run `26549501237` (Quality Gates, push of commit `ec6cf9e`, a docs-only retro-artifact commit touching only `docs/problems/` + `docs/retros/`) failed with `not ok 572 Band B with no hash file: passes but does NOT slide (no invariance proof)` (`risk-gate.bats` assert_gate_allows line 55 / test line 178). The commit could not possibly affect `risk-score-commit-gate.sh` behaviour — this is the flake firing under CI-runner timing (CI runners are slower, so the push-elapsed more readily crosses the 5s boundary). Two implications: (1) the **Likelihood is higher than "2 Possible"** — it demonstrably reds main CI on commits with zero risk-gate relevance, so under CI load it's closer to Likely; (2) **it produces false-red on main** for any committer, eroding the green-CI signal. Bumps the case for the Effort-S deterministic-clock fix (inject the TTL clock / use a fixed fake-time rather than wall-clock elapsed). Re-rate up at next /wr-itil:review-problems.
