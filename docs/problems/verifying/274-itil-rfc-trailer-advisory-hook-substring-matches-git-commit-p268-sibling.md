# Problem 274: `itil-rfc-trailer-advisory.sh` hook substring-matches `git commit` anywhere in Bash command — P268 sibling

**Status**: Verification Pending
**Reported**: 2026-05-18
**Priority**: 5 (Medium) — Impact: 1 × Likelihood: 5
**Effort**: S (re-estimated 2026-05-18 — call shared helper landed by P268 + mirror P268 regression bats fixtures; advisory-class)
**Fix Released**: pending release (batched P268-sibling sweep with P273 + P275; one-commit ADR-014 batch grain)

## Description

`packages/itil/hooks/itil-rfc-trailer-advisory.sh` line 94 uses the same `*"git commit"*` substring-match anti-pattern that P268 closed in `itil-readme-refresh-discipline.sh`:

```bash
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
```

Surfaced by the P268 sibling-hook sweep (this iter). Like P268, the hook fires on any Bash whose text contains the literal phrase `git commit` — including grep / sed / cat-heredoc / echo / `git log --grep` whose argument vectors merely mention the phrase. The downstream consequence is an advisory-emit on commits that aren't actually `git commit` invocations (lower-severity than P272 / P273 which deny outright, but the noise contaminates the orchestrator's PreToolUse stream and burns ADR-045 hook-injection budget).

## Fix

Replace the case-statement with a call to the new shared helper landed by P268:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/command-detect.sh"
command_invokes_git_commit "$COMMAND" || exit 0
```

The helper `packages/itil/hooks/lib/command-detect.sh::command_invokes_git_commit` (28 helper bats fixtures + 10 P268 integration bats fixtures green at fix-released release-cycle) iteratively strips prefix shapes (leading whitespace, env-var assignments, `cd <path> &&`) and matches the residual leading token pair against `^git[[:space:]]+commit([[:space:]]|$)`.

Coverage: add behavioural bats fixtures to `packages/itil/hooks/test/itil-rfc-trailer-advisory.bats` mirroring the P268 regression cases (grep, cat-heredoc, echo, sed, `git log --grep`, `git commit-tree` boundary).

## Workaround

The advisory shape doesn't deny commits, so no workaround needed; the false-positive advisory is noise rather than a hard block.

## Impact Assessment

- **Who is affected**: maintainers in any session whose Bash invocations mention `git commit` in their arguments — the advisory contaminates the PreToolUse output stream even though no commit is happening.
- **Frequency**: same class as P268 (≥3 events per session); no blast radius beyond noise.
- **Severity**: (deferred to investigation; lower than P272 / P273 since advisory-only, not deny)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Apply the shared `command_invokes_git_commit` helper to `itil-rfc-trailer-advisory.sh:93-96`; cite P268 in the hook comment block.
- [ ] Add behavioural bats fixtures mirroring the P268 regression cases.
- [ ] Verify no behavioural regression on the canonical `git commit` invocation surfaces.

## Dependencies

- **Blocks**: (none — advisory-only)
- **Blocked by**: P268 fix-released (helper now available)
- **Composes with**: P165, P268, P272, P273, P275 (sibling captures from the same sweep)

## Related

(captured at /wr-itil:work-problems session 8 iter 3 — P268 sibling-hook sweep)

- P268 — fix-released this iter via `packages/itil/hooks/lib/command-detect.sh` helper; consumed by `itil-readme-refresh-discipline.sh`.
- P272 / P273 / P275 — sibling captures from the same sweep.
- `packages/itil/hooks/itil-rfc-trailer-advisory.sh:93-96` — case-statement substring-match.
