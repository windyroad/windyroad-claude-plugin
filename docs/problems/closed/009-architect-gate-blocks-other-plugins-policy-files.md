# Problem 009: Architect Gate Blocks Other Plugins' Policy Files

**Status**: Closed
**Reported**: 2026-04-15
**Priority**: 6 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)

## Description

The architect enforce hook (`architect-enforce-edit.sh`) fires on writes to other plugins' policy files (e.g., `docs/JOBS_TO_BE_DONE.md`, `docs/jtbd/*`, `docs/VOICE-AND-TONE.md`, `docs/STYLE-GUIDE.md`). These files are governed by their own plugins' decision records and enforce hooks — the architect has no jurisdiction over their content.

Each plugin already exempts its own policy file from its own gate (the P002 fix pattern). The architect gate should similarly exempt *all* plugin policy files.

## Symptoms

- Running `/wr-jtbd:update-guide` triggers architect review for every JTBD file write
- Running `/wr-voice-tone:update-guide` would do the same for `docs/VOICE-AND-TONE.md`
- Each write consumes the architect marker, requiring re-review for the next file

## Workaround

Delegate to wr-architect:agent before each plugin-policy-file write (wasteful but works).

## Impact Assessment

- **Who is affected**: Anyone running a plugin's update-guide skill
- **Frequency**: Every setup/regeneration of a plugin policy doc
- **Severity**: Medium — adds unnecessary review cycles; compounds with P001 (marker consumed quickly)
- **Analytics**: N/A

## Root Cause Analysis

### Preliminary Hypothesis

The architect enforce hook's exclusion list (`architect-enforce-edit.sh` lines 31-56) doesn't include other plugins' policy files. It already exempts architect-adjacent files (changesets, risk reports, problems, briefing) but not peer-plugin docs.

### Fix Strategy

Add exclusions for:
- `*/docs/JOBS_TO_BE_DONE.md|docs/JOBS_TO_BE_DONE.md`
- `*/docs/PRODUCT_DISCOVERY.md|docs/PRODUCT_DISCOVERY.md`
- `*/docs/jtbd/*|docs/jtbd/*`
- `*/docs/VOICE-AND-TONE.md|docs/VOICE-AND-TONE.md`
- `*/docs/STYLE-GUIDE.md|docs/STYLE-GUIDE.md`

### Investigation Tasks

- [x] Confirm root cause — architect exclusion list doesn't cover peer plugin docs
- [x] Add exclusions for all peer plugin policy files
- [x] Add BATS tests — `packages/architect/hooks/test/architect-enforce-scope.bats`
- [x] Fix implemented in 2026-04-15

## Fix

Added peer-plugin policy file exclusions to `architect-enforce-edit.sh` case block:
- `docs/JOBS_TO_BE_DONE.md`
- `docs/PRODUCT_DISCOVERY.md`
- `docs/jtbd/*`
- `docs/VOICE-AND-TONE.md`
- `docs/STYLE-GUIDE.md`

5 BATS tests added to verify each exclusion is present. All 104 tests pass.

## Related

- P001 — architect marker consumed quickly (compounds with this)
- P002 — same pattern applied within JTBD plugin (fixed)
- P004 — edit gates block non-project files (related scope issue)
- `packages/architect/hooks/architect-enforce-edit.sh` — the enforce hook
