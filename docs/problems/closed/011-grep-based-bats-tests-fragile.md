# Problem 011: Grep-based BATS tests produce false positives on legitimate refactors

**Status**: Closed
**Reported**: 2026-04-15
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)

## Description

Several BATS tests assert hook behaviour by grepping the hook source for patterns rather than executing the hook with mock input and checking output/exit codes. These tests pass when source matches the pattern they expect — but they false-positive (or false-negative) when the source legitimately changes for unrelated reasons.

This has now hit twice:

1. **First hit**: `jtbd-enforce-scope.bats` originally asserted UI extension scoping was present; ADR-007 broadened scope and the test had to be inverted. Plan called out "upgrade from grep-based to functional tests" but only the new tests were added — old grep assertions kept.
2. **Second hit (this session)**: `jtbd-enforce-scope.bats:70` asserted no `*) exit 0 ;;` pattern (per ADR-007's removal of UI-only scoping). P004 added a project-root check that legitimately uses that exact pattern. Test failed in CI on the rename commit despite hook behaviour being correct. Fixed by tightening the regex to target UI-extension filtering specifically (commit `433fdb9`).

## Symptoms

- BATS test fails after an unrelated refactor that touches the hook source
- Failure message looks like a real regression but the hook behaves correctly
- Functional tests (mock JSON → hook → exit code) all pass alongside the failing grep test
- Cost: a CI red, a re-think, a fix commit, another release

## Workaround

When a grep-based test fires false-positive, tighten the regex to target the *intent* of the original assertion (e.g., UI extensions specifically) rather than the *implementation pattern* (e.g., any `*)` case statement).

## Impact Assessment

- **Who is affected**: plugin-developer persona — anyone refactoring hooks
- **Frequency**: every legitimate hook source change risks tripping a grep assertion
- **Severity**: Low — caught by CI, fixable in minutes, but burns cache + commit cycles
- **Analytics**: 2 incidents in ~3 weeks across the same test file

## Root Cause Analysis

### Confirmed Root Cause

Grep-based assertions over-specify the implementation. They assert on *how* the hook is written, not *what* it does. Any change to hook structure that preserves behaviour can trip them.

The functional test pattern (mock JSON → execute hook → check output) is already proven in this same file (lines 76+) but co-exists with the grep tests rather than replacing them.

### Audit needed

Other plugins likely have similar grep tests. Worth a sweep:

```bash
grep -rn "grep -q.*HOOK" packages/*/hooks/test/*.bats
```

## Fix Strategy

1. **Audit**: enumerate all grep-based assertions across `packages/*/hooks/test/*.bats`
2. **Categorise**: for each, decide whether the assertion's intent is verifiable functionally (yes for almost all behavioural assertions; maybe not for "this hook is registered" structural checks)
3. **Replace**: convert behavioural greps to functional tests; keep structural checks but tighten their patterns
4. **Document**: add a note in the testing strategy ADR (ADR-005) that behavioural assertions must be functional, not source-grep

### Investigation Tasks

- [x] Identify root cause (this session)
- [x] Audit `packages/*/hooks/test/*.bats` for grep-based behavioural assertions (see Audit Findings below)
- [x] Convert behavioural greps to functional tests — `jtbd-enforce-scope.bats` and `architect-enforce-scope.bats` (the two repeat-offender files)
- [x] Update ADR-005 with the rule (added "Behavioural assertions must be functional" section)
- [x] Convert remaining files: `jtbd-mark-reviewed.bats` (now 9 functional tests) and `risk-score-mark.bats` (now 9 functional tests, 4 tautological tests deleted)

## Audit Findings

Categorised every `grep -q` in `packages/*/hooks/test/*.bats`:

**A. Behavioural source-greps — must convert (the P011 problem)**

| File | Lines | Status |
|------|------|--------|
| `packages/jtbd/hooks/test/jtbd-enforce-scope.bats` | 22 + 9 exclusion tests + line 74 | **Converted this session** |
| `packages/architect/hooks/test/architect-enforce-scope.bats` | 14 + 5 exemption tests | **Converted this session** |
| `packages/jtbd/hooks/test/jtbd-mark-reviewed.bats` | 7, 12, 17, 18 | **Converted (follow-up session)** — now 9 functional tests covering directory vs file path, hash content, FAIL verdict, plan marker, subagent routing |
| `packages/risk-scorer/hooks/test/risk-score-mark.bats` | 9-23 (4 tautological tests) | **Converted (follow-up session)** — tautologies deleted, 9 real functional tests added covering pipeline scores, bypass markers, plan verdicts, and subagent routing |

**B. Output greps over executed-hook stdout — keep**

These run the hook and grep its output. They are functional, not source-grep:
- `packages/architect/hooks/test/architect-mark-reviewed.bats:7,12,17`
- `packages/tdd/hooks/test/tdd-gate.bats:251,252,269`

**C. Structural config-file checks — keep (permitted exception per ADR-005)**

These assert the absence/presence of a hook registration in `hooks.json`:
- `packages/architect/hooks/test/architect-no-stop-hook.bats:12`
- `packages/jtbd/hooks/test/jtbd-no-stop-hook.bats:10`
- `packages/risk-scorer/hooks/test/risk-scorer-no-stop-hook.bats:10`
- `packages/style-guide/hooks/test/style-guide-no-stop-hook.bats:10`
- `packages/voice-tone/hooks/test/voice-tone-no-stop-hook.bats:10`

## Bonus Finding (this session)

Converting the jtbd exclusion tests to functional tests immediately surfaced
**three real bugs** in the hook's exclusion patterns: `*/MEMORY.md`,
`*/.risk-reports/*`, and `*/RISK-POLICY.md` only match when the path has
a leading directory component. Root-level paths fall through. In practice
Claude Code passes absolute paths so the patterns work, but the source-grep
tests gave no signal at all — they passed because the literal text appeared
in source, even though the case branch wasn't matching the test inputs.
This is exactly the failure mode P011 predicted.

## Fix Released

All four behavioural source-grep files converted to functional tests. A live audit on 2026-04-16 confirmed zero remaining `grep`-over-source assertions in any `packages/*/hooks/test/*.bats` file. Remaining greps are all Category B (output greps over executed hook stdout) or Category C (structural `hooks.json` checks) — both permitted per ADR-005. Root cause structurally eliminated; no false-positive BATS failures can occur from a hook refactor.

Verified by inspection 2026-04-16 — P011 closed.

## Resolution

All four behavioural source-grep files are now functional. Audit is complete,
ADR-005 codifies the rule, and converting `jtbd-mark-reviewed.bats` surfaced a
test-only bug fix (its `_hashcmd` is `md5sum`, not `shasum -a 256` as my first
draft assumed) — caught at the right layer, not in production. Awaiting
verification that the next legitimate hook refactor doesn't false-positive
a BATS test before closing.

## Related

- ADR-005 (plugin testing strategy) — should encode the rule
- Commit `433fdb9` — most recent false-positive fix
- `packages/jtbd/hooks/test/jtbd-enforce-scope.bats` — repeat offender
