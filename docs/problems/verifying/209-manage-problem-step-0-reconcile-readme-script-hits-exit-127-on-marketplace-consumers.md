# Problem 209: manage-problem Step 0 reconcile-readme.sh hits exit 127 on marketplace consumers; script only resolves via repo-relative path

**Status**: Verification Pending
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Fix Released

Fixed by `148d189` "plugin-bundled scripts via bin/-on-PATH (closes P151)" — `manage-problem` Step 0 now invokes the `wr-itil-reconcile-readme` bin shim (on PATH for plugin-installed users) instead of the repo-relative script path, eliminating the exit-127 on marketplace consumers. Released in `@windyroad/itil`. Verify: a marketplace-installed adopter's Step 0 reconcile resolves without `command not found`.

## Description

Adopters installing `@windyroad/itil` via the Claude Code marketplace cache see `manage-problem` Step 0 exit 127 (`command not found`) because the SKILL prose uses a repo-relative path (`packages/itil/scripts/reconcile-readme.sh`) that resolves only in the source repo. Marketplace consumers carry the script under their own cache tree but the SKILL prose doesn't know about it.

ADR-049 prescribes the `$PATH`-resolved shim pattern (`wr-itil-reconcile-readme`) which is the documented fix. The SKILL prose was updated in subsequent versions but the marketplace cache may carry the old version with the repo-relative path.

## Workaround

Adopters must either (a) clone the source repo to get the script at its expected path, OR (b) install a newer version of `@windyroad/itil` that uses the `$PATH`-resolved shim.

## Impact Assessment

- **Who is affected**: every marketplace adopter on an older `@windyroad/itil` version that hasn't migrated to the shim.
- **Frequency**: every `/wr-itil:manage-problem` invocation in such adopters.
- **Severity**: High — hard-fail on a load-bearing skill step; adopters can't run review or transition without manual workaround.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Verify current `@windyroad/itil` version uses `wr-itil-reconcile-readme` shim (per ADR-049) — if not, audit and fix.
- [ ] Audit other SKILL.md files for repo-relative script-path references (sibling pattern).
- [ ] Document the marketplace-adopter testing path: install via `npm install --global @windyroad/itil` against a separate adopter project; verify all SKILL invocations resolve their script dependencies.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/85
- **Pipeline classification**: JTBD-aligned (JTBD-101/JTBD-302 — marketplace adopter trust contract); safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Sibling**: ADR-049 ($PATH-resolved shim pattern).
