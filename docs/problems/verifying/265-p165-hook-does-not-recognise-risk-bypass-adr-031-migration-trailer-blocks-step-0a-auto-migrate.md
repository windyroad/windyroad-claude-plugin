# Problem 265: P165 hook does not recognise `RISK_BYPASS: adr-031-migration` trailer — blocks Step 0a auto-migrate

**Status**: Verification Pending
**Reported**: 2026-05-18
**Priority**: 8 (Medium) — Impact: 2 × Likelihood: 4
**Effort**: S (re-estimated 2026-05-18 — single hook file extension, reuse P268 helper pattern + 1 bats fixture)
**Type**: technical

## Fix Released

**Released**: 2026-05-26 — fix folded into the closing commit and shipped in `@windyroad/itil` via the accompanying changeset (`fix(itil): P165 README-refresh gate recognises RISK_BYPASS: adr-031-migration trailer (closes P265)`).

`packages/itil/hooks/lib/readme-refresh-detect.sh::detect_readme_refresh_required` now accepts the `git commit` command string and, via the new `_readme_refresh_command_has_bypass_trailer` helper + `_README_REFRESH_BYPASS_TRAILERS=("adr-031-migration")` allow-list, returns allow when the command carries a registered RISK_BYPASS trailer. The recognition grep is byte-identical to `packages/risk-scorer/hooks/risk-score-commit-gate.sh` (P170 T11), so the rename-only ADR-031 layout-migration commit now clears both commit gates. `itil-readme-refresh-discipline.sh` threads `$COMMAND` into the helper. ADR-014's bypass-token registry was updated to name both recognising gates.

**Exercised in-session**: 43/43 bats green in `itil-readme-refresh-discipline.bats` — red-green confirmed (the 2 allow-with-trailer fixtures failed before the helper landed, pass after). The 4 new P265 fixtures cover: registered-trailer rename → allow silently; same rename without trailer → deny (negative control); unregistered RISK_BYPASS token → deny (allow-list scope); registered trailer is staged-shape-agnostic.

**Live verification pending**: PreToolUse hooks run from the installed plugin cache, so end-to-end proof requires this release to be published + installed. This repo currently carries two flat-layout straggler tickets (P285, P286 at `docs/problems/NNN-*.open.md`) — once installed, the next `/wr-itil:manage-problem` or `/wr-itil:work-problems` Step 0a run will auto-migrate them via the now-fixed hook (the real migration-commit path). Successful migration of P285/P286 is the live end-to-end verification.

Awaiting user verification.

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

- [x] Extend `detect_readme_refresh_required` to inspect the `git commit` command string and bypass on registered RISK_BYPASS trailers (allow-list: `adr-031-migration`). Done via a new `_readme_refresh_command_has_bypass_trailer` helper + `_README_REFRESH_BYPASS_TRAILERS` allow-list; the hook now threads `$COMMAND` into the helper. Grep pattern kept byte-identical to `risk-score-commit-gate.sh` (P170 T11) so both commit gates recognise the token the same way.
- [x] Sweep sibling PreToolUse:Bash gate hooks (P125, P141) for the same gap — **no gap**. P125 (staging-detect) fires only on a staged rename whose `<new>` path also has an *unstaged* working-tree edit; the migration is a pure `git mv` then immediate commit (no post-rename edit), so no trap. P141 (changeset-detect) fires only on `packages/<slug>/` publishable source; the migration stages `docs/problems/` only (the `*)` always-allow branch). Only P165 gates the `docs/problems/` ticket-rename surface the migration trips.
- [x] `packages/itil/lib/migrate-problems-layout.sh` — **no change needed**. The helper already writes a clean `RISK_BYPASS: adr-031-migration` line via sequential `-m` paragraphs (the T10 fix). The hook now recognising that trailer resolves the deadlock directly, so neither the README-no-op-edit nor the env-var-prerequisite workaround is required.
- [x] Add behavioural bats fixture: 4 fixtures added to `itil-readme-refresh-discipline.bats` — registered-trailer rename → allow silently; same rename without trailer → deny (negative control); unregistered RISK_BYPASS token → deny (allow-list scope); registered trailer is staged-shape-agnostic.
- [x] Documentation: ADR-014 commit-message bypass-token registry updated to name both recognising gates (was singular).
- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems (moot — fix released; ticket → Verification Pending).

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
