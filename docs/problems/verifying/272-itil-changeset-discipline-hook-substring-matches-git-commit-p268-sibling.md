# Problem 272: `itil-changeset-discipline.sh` hook substring-matches `git commit` anywhere in Bash command — P268 sibling

**Status**: Verifying
**Reported**: 2026-05-18
**Root cause confirmed**: 2026-05-18 (same root cause as P268 — substring-match anti-pattern; helper is the right shape; sibling-hook refactor)
**Fix released**: 2026-05-18 (`@windyroad/itil@<pending release cycle>` — source commit (this iter) "fix(itil): P272 changeset-discipline leading-executable command-detect helper" replacing the case-statement `*"git commit"*` substring match at `packages/itil/hooks/itil-changeset-discipline.sh:78` with `command_invokes_git_commit "$COMMAND" || exit 0` + 10 P272-prefixed behavioural bats fixtures appended to `packages/itil/hooks/test/itil-changeset-discipline.bats`; transitions Open → Verifying per ADR-022 P143 fold-fix amendment — bats 31/31 changeset-discipline + 28/28 helper + 39/39 readme-refresh-discipline green; architect PASS + JTBD review marker green; orchestrator Step 6.5 owns the release-cycle drain; recovery path: `/wr-itil:transition-problem 272 known-error` after reverting this iter's commit)
**Priority**: 10 (High) — Impact: 2 × Likelihood: 5
**Effort**: S (re-estimated 2026-05-18 — call shared helper landed by P268 + mirror P268 regression bats fixtures)
**WSJF**: 10/1 = **10.0** (raw Priority/Effort retained per README display convention; multiplier 0 in WSJF Rankings table per ADR-022 Verifying state)

## Description

`packages/itil/hooks/itil-changeset-discipline.sh` line 78 uses the same `*"git commit"*` substring-match anti-pattern that P268 closed in `itil-readme-refresh-discipline.sh`:

```bash
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
```

Surfaced by the P268 sibling-hook sweep (this iter). Like P268, the hook fires on any Bash whose text contains the literal phrase `git commit` — including grep / sed / cat-heredoc / echo / `git log --grep` whose argument vectors merely mention the phrase. The downstream consequence is a false-positive `BLOCKED: missing changeset` deny on commits that aren't actually `git commit` invocations.

## Fix

Replace the case-statement with a call to the new shared helper landed by P268:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/command-detect.sh"
command_invokes_git_commit "$COMMAND" || exit 0
```

The helper `packages/itil/hooks/lib/command-detect.sh::command_invokes_git_commit` (28 helper bats fixtures + 10 P268 integration bats fixtures green at fix-released release-cycle) iteratively strips prefix shapes (leading whitespace, env-var assignments, `cd <path> &&`) and matches the residual leading token pair against `^git[[:space:]]+commit([[:space:]]|$)`.

Coverage: add behavioural bats fixtures to `packages/itil/hooks/test/itil-changeset-discipline.bats` mirroring the P268 regression cases (grep, cat-heredoc, echo, sed, `git log --grep`, `git commit-tree` boundary).

## Workaround

Same as P268: stage the changeset file alongside the offending Bash invocation so the changeset-discipline gate's primary precondition (`@windyroad/*` package change without staged changeset) no longer fires; OR run the command from a different shell.

## Impact Assessment

- **Who is affected**: maintainers running `/wr-itil:work-problems`, `/wr-itil:manage-problem`, `/wr-retrospective:run-retro`, or any orchestrator turn that touches a `@windyroad/*` package and then performs a `git commit`-mentioning Bash invocation (grep / sed / cat / echo).
- **Frequency**: same class as P268 (≥3 events per session); workaround exists.
- **Severity**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — re-rated 2026-05-18 to Priority 10 (Impact 2 × Likelihood 5) / Effort S, WSJF 10.0 per 8-ticket review-problems pass.
- [x] Apply the shared `command_invokes_git_commit` helper to `itil-changeset-discipline.sh:77-80`; cite P268 in the hook comment block — source line 47 now sources `lib/command-detect.sh`; case-statement at the command-shape filter replaced with `command_invokes_git_commit "$COMMAND" || exit 0`; References block extended with P268 + P272 cites; Allow paths docstring updated to leading-executable-token semantics per architect advisory.
- [x] Add behavioural bats fixtures mirroring the P268 regression cases — 10 P272-prefixed fixtures appended to `packages/itil/hooks/test/itil-changeset-discipline.bats` covering grep / grep-rn / sed / echo / git-log / cat-heredoc allow paths, `git commit-tree` boundary allow, plus three positive-regression deny cases (bare `git commit`, `cd && git commit`, `VAR=value git commit`).
- [x] Verify no behavioural regression on the canonical `git commit` invocation surfaces (direct, `cd && git commit`, `VAR=value git commit`) — three positive-regression deny fixtures green; pre-existing 21 fixtures unchanged-green; sibling helper bats 28/28 + readme-refresh-discipline bats 39/39 also confirmed green (no cross-regression).

## Dependencies

- **Blocks**: (none — workaround exists)
- **Blocked by**: P268 fix-released (helper now available)
- **Composes with**: P165 (parent class), P125 / P273 (sibling), P274 (sibling), P275 (sibling), P268 (sibling fix-released this iter), P141 (parent changeset-discipline gate)

## Related

(captured at /wr-itil:work-problems session 8 iter 3 — P268 sibling-hook sweep)

- P268 — fix-released this iter via `packages/itil/hooks/lib/command-detect.sh` helper; consumed by `itil-readme-refresh-discipline.sh`.
- P273 / P274 / P275 — sibling captures from the same sweep.
- `packages/itil/hooks/itil-changeset-discipline.sh:77-80` — case-statement substring-match.
