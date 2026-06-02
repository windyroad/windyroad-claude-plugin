# Problem 319: Full `bats --recursive` suite hangs locally on architect-detect-scope.bats — no timeout, wedges the whole run

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Running the full `npm test` suite (`bats --recursive packages/*/hooks/test/ packages/*/skills/*/test/ ...`) locally **hung indefinitely** on `packages/architect/hooks/test/architect-detect-scope.bats` (test `detect-3a scope text mentions problem files exemption (P029)`). The run wedged ~40 min with no progress and no error before manual `pkill -f bats-core`.

The first full run of the session (background `bphfm6l80`) completed (exit 0, reached test 2402); the re-run (`bubxtlil8`) hung on architect-detect-scope. So it is **intermittent / environmental** (a subprocess the test spawns occasionally never returns), not a deterministic failure. Origin CI ("Run hook tests") passed the same test in the same session — so it is a LOCAL flake, not a real test failure.

**Cost this session**: the hang looked like a stall ("Looks stuck" — user), wasted ~40 min wall-clock, and forced a fallback to running targeted suites instead of the full sweep. A hanging full-suite run is worse than a failing one — it gives no signal and blocks the verify-before-push step.

## Symptoms

- `bats --recursive ...` stops emitting after a test in `architect-detect-scope.bats`; `ps` shows `bats-exec-test ... architect-detect-scope.bats test_detect-3a...` alive but idle for tens of minutes.
- Killing the run requires `pkill -f bats-core` / `pkill -f architect-detect-scope`.
- The same test passes on origin CI and in isolated runs.

## Workaround

Run targeted suites (the specific affected `.bats` files) instead of the full `bats --recursive` sweep; or add a per-test timeout. Avoid relying on the full local sweep as the pre-push verify gate.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Reproduce: run `architect-detect-scope.bats` in isolation in a loop to find the intermittent hang; identify the subprocess that doesn't return (likely a `claude`/agent/`gh`/network call or a `read` without stdin redirect in a test fixture).
- [ ] Fix at source (redirect stdin / add `timeout` wrapper to the offending command in the fixture), OR add a suite-level per-test timeout (`bats --timeout` or a wrapper) so a wedged test fails fast instead of hanging the whole run.
- [ ] Consider a `npm test` wrapper that applies a global timeout + names the wedged file.

## Dependencies

- **Composes with**: the verify-before-push discipline (a hanging suite defeats it).

## Related

- captured via /wr-retrospective:run-retro Step 2b pipeline-instability scan (Repeat-work / Skill-contract friction), 2026-05-27. Witnessed during the RFC-009 full-suite verification (background runs bphfm6l80 completed / bubxtlil8 hung).
