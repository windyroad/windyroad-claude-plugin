# Problem 218: manage-problem SKILL.md doesn't explain how to obtain the actual session UUID for the P119 marker

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`/wr-itil:manage-problem` Step 2 tells the agent to write the per-session create-gate marker at `/tmp/manage-problem-grep-${SESSION_ID}` so the P119 PreToolUse hook allows new ticket Writes. The SKILL.md offers a portable suggestion using `${CLAUDE_SESSION_ID}` but `CLAUDE_SESSION_ID` is not exported in agent contexts today. Agents commonly use the wrong SID and the marker doesn't match what the hook checks for.

**In-session reproduction this monorepo (2026-05-15)**: same bug surfaced — the `get_current_session_id` helper returns one SID while the PreToolUse hook's JSON-stdin SID is different (runtime-marker contents). Manual dual-touch unblocked the Write. See P197 / P198 commit messages.

## Workaround

Read the runtime-marker file (`/tmp/itil-runtime-sid-<user>-<hash>.current`) for the JSON-stdin SID the hook will use, and seed the marker under THAT SID (not the helper-fast-path SID).

## Impact Assessment

- **Severity**: Moderate — every new-ticket creation in non-standard sessions can hit this; recoverable with workaround.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Update SKILL.md Step 2 prose to document the canonical SID-derivation pattern (read runtime-marker file from `runtime-sid.sh` helper).
- [ ] Possibly unify `get_current_session_id` to ALWAYS read from runtime-marker first (already does per P142 but the helper fallback can return a different SID).
- [ ] Behavioural test asserting marker landing under the SID the hook will use.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/77
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Sibling**: P119 (create-gate hook); P142 (runtime-sid marker); P197 + P198 (in-session reproduction).
