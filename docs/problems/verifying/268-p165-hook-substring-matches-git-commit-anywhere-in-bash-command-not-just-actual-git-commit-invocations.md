# Problem 268: P165 hook substring-matches `git commit` anywhere in Bash command, not just actual git commit invocations

**Status**: Verifying
**Reported**: 2026-05-18
**Root cause confirmed**: 2026-05-18
**Fix released**: 2026-05-18 (`@windyroad/itil@<pending release cycle>` — source commit (this iter) "fix(itil): P268 readme-refresh-discipline leading-executable command-detect helper" landing `packages/itil/hooks/lib/command-detect.sh` + `command_invokes_git_commit` substring-match replacement at `packages/itil/hooks/itil-readme-refresh-discipline.sh:80-83` + 28 helper bats fixtures + 10 hook integration regression fixtures; transitions Open → Verifying per ADR-022 P143 fold-fix amendment — bats 28/28 helper + 39/39 hook + 19/19 retrospective-sibling green; architect PASS + JTBD review marker green; orchestrator Step 6.5 owns the release-cycle drain; recovery path: `/wr-itil:transition-problem 268 known-error` after reverting this iter's commit)
**Priority**: 3 (Medium) — Impact: 2 × Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: S (deferred — re-rate at next /wr-itil:review-problems)
**WSJF**: 6/2 = **3.0** (raw Priority/Effort retained per README display convention; multiplier 0 in WSJF Rankings table per ADR-022 Verifying state)
**Type**: technical

## Description

`packages/itil/hooks/itil-readme-refresh-discipline.sh` (P165) gates Bash invocations on a `*"git commit"*` substring match in the command string:

```bash
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
```

This substring match fires on ANY Bash command that contains the literal string `git commit` anywhere in the command body, not just actual `git commit` invocations. Two false-positive surfaces observed this session:

1. **iter-1 retro write** (`cat >> docs/problems/README-history.md`) — the retro file body contained the phrase "git commit" in a sentence about commit-gate flow; PreToolUse hook saw the substring and denied the `cat` invocation even though no commit was happening.
2. **Orchestrator main turn grep** (`grep -n 'git commit\|RISK_BYPASS' packages/...`) — searching for the literal string `git commit` in source files to investigate hook behaviour. The grep's PATTERN argument contained `git commit`, hook denied the grep itself.

Workaround used both times: stage README first → run the command → unstage README OR run the command from a different shell where the hook can't see staged tree.

**Fix**: tighten the hook's command detection. Possible shapes:

- **A**: anchor at start of word: `case "$COMMAND" in "git commit"*|*\ "git commit"*|*\&\&\ "git commit"*|*\&\ "git commit"*) ;; esac` — over-fragile to shell quoting.
- **B**: extract the leading executable token after stripping common prefixes (`cd <dir> && `, `BYPASS_X=1 `, env-var assignments) and check if it's `git` AND the next argument is `commit`. Robust but more parsing.
- **C**: use a regex match against the structural shape `\bgit\s+commit\b` — better than substring but still over-matches grep patterns / sed patterns / echo strings containing the phrase.
- **D**: combine B + C — primary check via B (leading executable), fallback to C (regex) for shell pipelines. Most robust.

Recommended: B with leading-executable extraction. The hook needs to know whether the command is INVOKING `git commit`, not whether the command MENTIONS `git commit`.

Sibling enforcement-layer hooks (P125 staging-trap, P141 changeset-discipline) may carry the same substring-match anti-pattern; sweep all PreToolUse:Bash gates for the issue.

## Symptoms

- Bash commands containing the literal text "git commit" in arguments or piped content denied even when no commit is happening.
- Grep / sed / cat / echo with the phrase in arguments fail with the P165 deny message.

## Workaround

Stage `docs/problems/README.md` first, then run the offending Bash command. The hook's staged-ticket-no-README precondition no longer fires when README IS staged, so the substring-match consequence is moot. Awkward but reliable.

## Impact Assessment

- **Who is affected**: maintainers running `/wr-itil:work-problems` / `/wr-itil:manage-problem` / `/wr-itil:capture-problem` / `/wr-retrospective:run-retro` in interactive or AFK mode.
- **Frequency**: ≥2 events this session; class-of-behaviour likely recurs whenever retros / READMEs / grep investigations touch hook-relevant phrases.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [x] Investigate root cause — confirm B (leading-executable extraction) is sound across shell pipelines / chained commands / env-var prefixes — Fix shape B chosen per ticket recommendation. Iterative prefix-strip strategy validated by 28 helper bats fixtures covering env-var (quoted + unquoted + multi-env), `cd <path> &&` (quoted + unquoted), env+cd interleave, leading whitespace, tab-indent; 13 negative fixtures (grep / sed / echo / cat-heredoc / git-log / git-commit-tree boundary). Scope explicitly narrow per ticket Description: prefix shapes only. Mid-chain `&&` after a non-prefix-shape leading command (`git add foo && git commit`) is documented false-negative — acceptable because standalone re-commit re-triggers detection.
- [x] Create reproduction test (bats fixture: command with "git commit" in argument vs invocation; expect allow + deny respectively) — landed at `packages/itil/hooks/test/command-detect.bats` (28 fixtures) + 10 P268-prefixed integration cases appended to `packages/itil/hooks/test/itil-readme-refresh-discipline.bats`. Pre-fix would-have-failed cases (grep pattern argument, cat heredoc body, echo string, sed substitution, `git log --grep`) now pass silently with `${#output}` == 0 per ADR-045 Pattern 1.
- [x] Sweep sibling PreToolUse:Bash hooks (P125, P141) for the same substring-match anti-pattern — 4 sibling hooks confirmed sharing the pattern: `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh:126`, `packages/itil/hooks/itil-rfc-trailer-advisory.sh:94`, `packages/itil/hooks/itil-changeset-discipline.sh:78`, `packages/itil/hooks/p057-staging-trap-detect.sh:65`. Captured as 4 separate problem tickets per ADR-014 one-concern-per-ticket — the new shared helper `lib/command-detect.sh` is in the right shape for each sibling refactor to consume in its own commit.
- [x] Update P165 hook comment block to document the narrowed surface — allow-paths docstring + sources block + References list amended at `packages/itil/hooks/itil-readme-refresh-discipline.sh`; case-statement substring match replaced with `command_invokes_git_commit "$COMMAND" || exit 0`.

## Dependencies

- **Blocks**: (no hard blocks — workaround exists)
- **Blocked by**: (none)
- **Composes with**: P165 (parent hook), P125 (sibling staging-trap), P141 (sibling changeset-discipline), P094, P062

## Related

(captured at /wr-itil:work-problems session 7 Step 2.5 user-direction routing)

- P165 — parent hook surface
- P125 / P141 — sibling enforcement-layer hooks
- `packages/itil/hooks/itil-readme-refresh-discipline.sh` lines 67-79 — substring-match case statement
