# Problem 002: JTBD Gate Blocks Creation of Its Own Policy File

**Status**: Closed
**Reported**: 2026-04-14
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Almost Certain (5) when first installing

## Description

The JTBD enforce hook (`jtbd-enforce-edit.sh`) blocks writing `docs/JOBS_TO_BE_DONE.md` when the file doesn't exist, because the gate checks `[ ! -f "docs/JOBS_TO_BE_DONE.md" ]` and blocks all edits. This creates a chicken-and-egg: you can't create the file because the gate requires the file to exist first.

## Symptoms

- Running `/wr-jtbd:update-guide` correctly drafts the document but the Write tool is blocked
- Error: "BLOCKED: Cannot edit 'JOBS_TO_BE_DONE.md' because docs/JOBS_TO_BE_DONE.md does not exist"
- The hook tells you to "Run /wr-jtbd:update-guide" — which is exactly what you're doing

## Workaround

Use `bash cat >` to write the file directly, bypassing the hook system. Or temporarily uninstall the JTBD plugin, create the file, then reinstall.

## Impact Assessment

- **Who is affected**: Every new user of the JTBD plugin on first install
- **Frequency**: Once per project (first-time creation of JOBS_TO_BE_DONE.md)
- **Severity**: High — completely blocks the intended workflow
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed Root Cause

The enforce hook at line 68-72 of `jtbd-enforce-edit.sh` blocks ALL edits when `docs/JOBS_TO_BE_DONE.md` doesn't exist. The exclusion list (lines 41-66) did not include the policy file itself (`docs/JOBS_TO_BE_DONE.md`) or its companion (`docs/PRODUCT_DISCOVERY.md`).

This bug was introduced by ADR-007, which broadened the JTBD gate from UI-only files to all project files. Before ADR-007, `.md` files didn't match the UI extension filter (`*.html|*.jsx|*.tsx|etc`), so the gate never fired for `.md` writes.

### Related Plugins

Voice-tone and style-guide have the same `! -f` pattern (line 47 in both enforce hooks), but they are NOT affected because they still use the UI-only file extension filter. `.md` files don't match `*.html|*.jsx|*.tsx|etc`, so the policy file write passes through. If those plugins are ever broadened like JTBD was, they will hit the same bug.

### Investigation Tasks

- [x] Confirm root cause in `jtbd-enforce-edit.sh`
- [x] Check if voice-tone and style-guide have the same bug (not affected due to UI-only scope)
- [x] Add exemption for the policy file itself
- [x] Create reproduction test (`jtbd-enforce-scope.bats` tests 10-11)
- [x] Release and verify fix in production — released in @windyroad/jtbd@0.2.1, verified 2026-04-15 by deleting JTBD docs and confirming the JTBD gate no longer blocks recreation (only the architect gate fired, tracked separately as P009)

## Fix Strategy

Add `docs/JOBS_TO_BE_DONE.md` and `docs/PRODUCT_DISCOVERY.md` to the case exclusion list in `jtbd-enforce-edit.sh`, matching the pattern used for other excluded files (`*/docs/BRIEFING.md|docs/BRIEFING.md`).

## Related

- `packages/jtbd/hooks/jtbd-enforce-edit.sh` — the blocking hook (fixed)
- `packages/jtbd/hooks/test/jtbd-enforce-scope.bats` — reproduction tests (tests 10-11)
- ADR-007 — broadened JTBD to all project files, introducing this bug
