# Problem 231: README-refresh-discipline hook deny message advertises BYPASS_README_REFRESH_GATE=1 inline-prefix that does not propagate to the PreToolUse hook (recurrence of P173 at a new surface)

**Status**: Closed
**Reported**: 2026-05-15
**Closed**: 2026-05-16
**Priority**: 3 (Low) — Impact: 1 (Negligible — misleading docs; concrete workaround exists) × Likelihood: 3 (Likely — users attempting documented bypass syntax encounter the failure mode)
**Effort**: S (deferred — re-rate at next `/wr-itil:review-problems`)
**WSJF**: (3 × 1.0) / 1 = **3.0** (deferred — provisional)

> Captured 2026-05-15 by `/wr-itil:work-problems` AFK loop iter 1 surfacing pass per user direction. Sibling to [[P230]] (hook misfires on narrative-only edits — same hook, distinct fix). Recurrence/sibling of [[P173]] (BYPASS_*_GATE env vars do not propagate from Bash subshell to PreToolUse hook context).

## Description

`packages/itil/hooks/itil-readme-refresh-discipline.sh` deny message advertises the recovery path: `Bypass: BYPASS_README_REFRESH_GATE=1.` But the env-var inline-prefix syntax (`BYPASS_README_REFRESH_GATE=1 git commit ...`) does NOT propagate to the PreToolUse hook — the hook runs in Claude Code's process tree and reads the parent process env, not the bash subshell env scoped to the `git commit` child. This is a documentation defect (the deny message hints a recovery path that doesn't work) AND a recurrence/sibling of P173 at a new hook surface.

## Symptoms

- iter 1 (2026-05-15) attempted bypass via `BYPASS_README_REFRESH_GATE=1 git commit ...` — same deny verbatim returned, env-var inline-prefix did not bypass.
- Users following the documented bypass syntax encounter the failure mode.

## Workaround

Either (a) accept the deny and apply the README-refresh edit per the gate's intent, OR (b) set the env-var via `.claude/settings.json` env field or shell `export` before `claude` launch (the only contexts where the parent process env actually sees it).

## Impact Assessment

- **Who is affected**: anyone attempting the documented `BYPASS_README_REFRESH_GATE=1` recovery path inline.
- **Frequency**: any time the README-refresh hook denies + user attempts the documented bypass.
- **Severity**: Negligible (one wasted attempt; documented workaround in `.claude/settings.json` or `export` exists).

## Root Cause Analysis

### Investigation Tasks

- [x] Confirm P173's broader root cause (env-var propagation gap) is the same here — confirmed: same parent-process-env-vs-bash-subshell-env propagation gap as P173.
- [x] Decide: correct the deny message OR remove. **Decision: Option A** (correct). Architect rejected Option B — narrative-only short-circuit (P230) doesn't render the bypass redundant; legitimate one-off escape cases remain (force-amend after rebase, partial-progress hand-off).
- [x] If P230 lands and renders bypass unnecessary, fold this ticket into P230 closure — folded into the same commit as Option A correction (not Option B removal), per architect verdict.

## Fix Strategy

**Implemented** — Option A, architect-approved:

`packages/itil/hooks/itil-readme-refresh-discipline.sh` REASON string updated to advertise the working syntax:

```
Bypass: BYPASS_README_REFRESH_GATE=1 via .claude/settings.json env (P173).
```

Replaces the misleading `Bypass: BYPASS_README_REFRESH_GATE=1.` advertisement that implied inline-prefix syntax worked. Stays within ADR-045 deny-band ≤300 bytes. Names P173 inline so future readers can navigate to the propagation-gap class.

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none — but Option B is contingent on [[P230]] landing first)
- **Composes with**: [[P230]] (hook misfire — same hook surface, sibling fix), [[P173]] (parent BYPASS env-var propagation class)

## Related

(captured via direct write at /wr-itil:work-problems orchestrator main-turn wrap)

## Change Log

- **2026-05-15** — Opened by `/wr-itil:work-problems` AFK orchestrator main-turn wrap, per user answer "Yes — capture as two separate tickets" to README-refresh question after iter 1 surfaced the friction.
- **2026-05-16** — Closed by `/wr-itil:work-problems` iter 2. Option A fix landed (deny message advertises `.claude/settings.json` env path + P173 reference). Folded into [[P230]] single commit per ADR-014 single-commit grain.
