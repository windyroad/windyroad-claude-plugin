# Problem 222: manage-problem skill should auto-commit ticket file changes

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `wr-itil:manage-problem` skill (and its `update-ticket` sub-flow) writes the problem-ticket markdown file but explicitly does not commit. The note says "the user will commit when ready." In practice this means after every `/problem` invocation the file sits unstaged until the maintainer remembers to commit, breaking the AFK promise that ticket lifecycle changes are durable.

Note: ADR-014 (governance skills commit their own work) was accepted AFTER this report was filed. The current `/wr-itil:manage-problem` Step 11 + `/wr-itil:capture-problem` Step 6 DO commit per ADR-014. This ticket may already be largely resolved by ADR-014's acceptance; verify and close as duplicate / resolved if so.

## Workaround

ADR-014's acceptance closed this gap for new-ticket-creation + transitions. Audit any update-ticket flow that hasn't yet adopted ADR-014.

## Impact Assessment

- **Severity**: Low (already largely resolved by ADR-014).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Verify all manage-problem update-ticket flows commit per ADR-014; close as resolved if so, OR identify remaining gaps and fix.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/61
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Likely resolved by**: ADR-014.
