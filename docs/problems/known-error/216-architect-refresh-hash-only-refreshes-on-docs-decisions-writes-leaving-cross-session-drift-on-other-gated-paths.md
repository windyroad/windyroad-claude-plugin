# Problem 216: architect-refresh-hash.sh only refreshes hash on docs/decisions/* writes, leaving cross-session drift on other gated paths

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `architect-refresh-hash.sh` PostToolUse hook only fires for Edit/Write tool calls whose path matches `*/docs/decisions/*|docs/decisions/*`. Edits to other gated paths (e.g. `.claude/skills/`, `.claude/agents/`, source files) do not refresh the stored hash, so any prior session's hash persists. When the next session attempts a gated edit, the hash check fires deny on drift that the prior session legitimately introduced.

## Workaround

Manual re-invocation of architect agent on each cross-session edit attempt.

## Impact Assessment

- **Severity**: Moderate — friction on cross-session gated paths; recoverable.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Broaden hook's path filter to all gated paths (mirror the architect-enforce-edit.sh path-match rules).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/79
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/architect.
