# Problem 275: `retrospective-readme-jtbd-currency.sh` hook substring-matches `git commit` anywhere in Bash command — P268 sibling

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 5 (Medium) — Impact: 1 × Likelihood: 5
**Effort**: S (re-estimated 2026-05-18 — call shared helper (Option A: ADR-017 sync or Option B: packages/shared/ promotion) + mirror P268 regression bats fixtures; cross-package, advisory-class)
**Type**: technical

## Description

`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh` line 126 uses the same `*"git commit"*` substring-match anti-pattern that P268 closed in `itil-readme-refresh-discipline.sh`:

```bash
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
```

Surfaced by the P268 sibling-hook sweep (this iter). Like P268, the hook fires on any Bash whose text contains the literal phrase `git commit` — including grep / sed / cat-heredoc / echo / `git log --grep` whose argument vectors merely mention the phrase. The downstream consequence is a false-positive currency-advisory emit on commits that aren't actually `git commit` invocations.

This is the only sibling living under `packages/retrospective/`; the other three siblings (P272, P273, P274) live under `packages/itil/`. The helper landed by P268 sits at `packages/itil/hooks/lib/command-detect.sh`. Fix shape options:

**Option A** — copy the helper into `packages/retrospective/hooks/lib/command-detect.sh` (sync between the two via the ADR-017 shared-code sync pattern).

**Option B** — promote the helper to `packages/shared/hooks/lib/command-detect.sh` and consume it from both packages (architect verdict on P268: ADR-017 promotion deferred until "the sibling-hook refactors land — not a precondition for this P268 commit"). This sibling's commit IS one of the sibling-hook refactor commits; promotion is in scope here.

**Option C** — duplicate inline within `retrospective-readme-jtbd-currency.sh` (smallest blast radius; violates DRY).

Recommended: Option B (promote to `packages/shared/`) once any other sibling refactor (P272 / P273 / P274) is in flight; otherwise Option A as bridge.

## Fix

Replace the case-statement with a call to whichever shared helper location lands per the architect-approved Option B/A above. The call shape is identical:

```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/command-detect.sh"   # path varies per Option A/B
command_invokes_git_commit "$COMMAND" || exit 0
```

Coverage: add behavioural bats fixtures to `packages/retrospective/hooks/test/retrospective-readme-jtbd-currency.bats` mirroring the P268 regression cases (grep, cat-heredoc, echo, sed, `git log --grep`, `git commit-tree` boundary).

## Workaround

The advisory shape doesn't deny commits, so no workaround needed; the false-positive is noise rather than a hard block.

## Impact Assessment

- **Who is affected**: maintainers in any session whose Bash invocations mention `git commit` in their arguments — the advisory contaminates the PreToolUse output stream even though no commit is happening.
- **Frequency**: same class as P268 (≥3 events per session); no blast radius beyond noise.
- **Severity**: (deferred to investigation; lower than P272 / P273 since advisory-only, not deny)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Decide Option A (sync copy) vs Option B (promote to `packages/shared/hooks/lib/`) vs Option C (duplicate); architect verdict on P268 favours Option B once any sibling refactor opens the promotion.
- [ ] Apply the shared `command_invokes_git_commit` helper to `retrospective-readme-jtbd-currency.sh:125-128`; cite P268 in the hook comment block.
- [ ] Add behavioural bats fixtures mirroring the P268 regression cases.
- [ ] Verify no behavioural regression on the canonical `git commit` invocation surfaces.

## Dependencies

- **Blocks**: (none — advisory-only)
- **Blocked by**: P268 fix-released (helper now available)
- **Composes with**: P165, ADR-017 (shared-code sync pattern), P268, P272, P273, P274 (sibling captures from the same sweep)

## Related

(captured at /wr-itil:work-problems session 8 iter 3 — P268 sibling-hook sweep)

- P268 — fix-released this iter via `packages/itil/hooks/lib/command-detect.sh` helper; consumed by `itil-readme-refresh-discipline.sh`.
- P272 / P273 / P274 — sibling captures from the same sweep.
- `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh:125-128` — case-statement substring-match.
- ADR-017 — shared-code sync pattern (Option A bridge OR Option B promotion path).
