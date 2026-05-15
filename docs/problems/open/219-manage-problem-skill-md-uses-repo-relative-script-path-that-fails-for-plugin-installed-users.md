# Problem 219: manage-problem SKILL.md uses repo-relative script path that fails for plugin-installed users

**Status**: Open
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

`/wr-itil:manage-problem` Step 0 instructs the agent to run `bash packages/itil/scripts/reconcile-readme.sh docs/problems`. That path is the plugin's own development repo layout. For plugin-installed projects (the common case), the script lives under `~/.claude/plugins/cache/windyroad/...` and the repo-relative path fails with `bash: ... No such file or directory`.

## Workaround

Use the $PATH-resolved shim (ADR-049): `wr-itil-reconcile-readme docs/problems`.

## Impact Assessment

- **Severity**: High — every plugin-installed adopter hits this on the first manage-problem invocation.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Audit all SKILL.md files for repo-relative script paths; replace with $PATH-resolved shims per ADR-049.
- [ ] Behavioural test asserting plugin-installed project context resolves all script dependencies.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/76
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil. Sibling of P209/#85.
