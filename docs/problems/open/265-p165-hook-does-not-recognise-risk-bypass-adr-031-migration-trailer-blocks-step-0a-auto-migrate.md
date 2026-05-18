# Problem 265: P165 hook does not recognise `RISK_BYPASS: adr-031-migration` trailer — blocks Step 0a auto-migrate

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 8 (Medium) — Impact: 2 × Likelihood: 4
**Effort**: S (re-estimated 2026-05-18 — single hook file extension, reuse P268 helper pattern + 1 bats fixture)
**Type**: technical

## Description

`packages/itil/hooks/itil-readme-refresh-discipline.sh` (P165) gates `git commit` invocations on staged-ticket-without-README-refresh, with the only documented bypass being `BYPASS_README_REFRESH_GATE=1` env var. The hook does NOT recognise the `RISK_BYPASS: adr-031-migration` trailer that `packages/itil/lib/migrate-problems-layout.sh::migrate_problems_to_per_state_layout` writes into its standalone migration commit.

When `/wr-itil:work-problems` Step 0a (or `/wr-itil:manage-problem` Step 0a) auto-migrates a remaining flat-layout ticket file to the per-state subdir, the migration helper:

1. Runs `git mv docs/problems/253-...open.md docs/problems/open/253-....md` (staged rename).
2. Calls `git commit -m "docs(problems): auto-migrate ..." -m "RISK_BYPASS: adr-031-migration"`.

Step 2 is silently blocked by P165 because:
- The staged set contains a ticket-path (`docs/problems/open/253-....md` per the per-state subdir match).
- The staged set does NOT contain `docs/problems/README.md` (the rename doesn't change README content; the table references P253 by ID, not by path).
- The hook's detect helper has no awareness of commit-message trailers (it only reads `git diff --staged --name-only`).

Observed 2026-05-18 work-problems session 7 Step 0a invocation: one orphan flat-layout file (P253) was relocated to `docs/problems/open/`, then the migration commit silently failed. The orchestrator reverted the rename to restore a clean tree and proceeded.

Per ADR-031 § Backward Compatibility (line 124) the migration is intended as a **standalone commit** with the RISK_BYPASS trailer carrying the policy-authorisation. Per ADR-013 Rule 6 the migration is policy-authorised silent action — no AskUserQuestion, no extra refresh.

**Fix**: extend `packages/itil/hooks/lib/readme-refresh-detect.sh::detect_readme_refresh_required` to recognise the commit-message trailer pattern via the `tool_input.command` (already extracted by the hook for the `git commit` substring check). When the command string contains the trailer `RISK_BYPASS: adr-031-migration` (or any other registered RISK_BYPASS token from an allow-list), return 0 (allow) silently. Allow-list keeps the bypass scope narrow — generic `RISK_BYPASS:` would over-permit; named trailers stay auditable.

Sibling hooks (P125 staging-trap, P141 changeset-discipline) may carry the same gap; sweep all PreToolUse:Bash gates for trailer-awareness.

## Symptoms

(deferred to investigation)

## Workaround

The migration commit fails silently — orchestrator detects the partial-staged state and reverts the rename. The flat-layout file remains; migration is deferred until P165 hook fix lands OR until a user-initiated workflow runs the migration outside the hook envelope (e.g., setting `BYPASS_README_REFRESH_GATE=1` in `.claude/settings.json` env before invoking work-problems — permanent change rather than per-commit override).

## Impact Assessment

- **Who is affected**: any adopter still carrying flat-layout ticket files post-RFC-002 migration; orchestrator Step 0a fails-soft each invocation, leaving the orphan files in flat layout indefinitely.
- **Frequency**: every AFK invocation in projects with flat-layout debt.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Extend `detect_readme_refresh_required` to read `tool_input.command` and bypass on registered RISK_BYPASS trailers
- [ ] Sweep sibling PreToolUse:Bash gate hooks (P125, P141) for the same gap
- [ ] Update `packages/itil/lib/migrate-problems-layout.sh` to either (a) include README.md in the migration commit (no-op content edit) or (b) document the env-var prerequisite explicitly for adopters
- [ ] Add behavioural bats fixture: migration commit with RISK_BYPASS trailer should pass the hook

## Dependencies

- **Blocks**: Step 0a auto-migration of flat-layout adopter trees
- **Blocked by**: (none)
- **Composes with**: ADR-031 (per-state subdir layout), ADR-013 Rule 6 (policy-authorised migrations), P165 (the hook itself), P094, P062

## Related

(captured inline during /wr-itil:work-problems Step 0a friction)

- ADR-031 § Backward Compatibility line 124 — defines the standalone migration commit
- `packages/itil/lib/migrate-problems-layout.sh` lines 119-122 — writes the trailer
- `packages/itil/hooks/itil-readme-refresh-discipline.sh` — blocking hook
- `packages/itil/hooks/lib/readme-refresh-detect.sh` lines 114-115 — current env-var-only bypass
- P165 — parent hook
- P125 / P141 — sibling PreToolUse:Bash gates that may carry the same gap
