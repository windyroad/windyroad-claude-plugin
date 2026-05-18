---
"@windyroad/itil": patch
---

P268: `itil-readme-refresh-discipline.sh` no longer false-positive denies
Bash commands that merely mention the literal phrase `git commit` in
their argument vectors.

A new shared helper `packages/itil/hooks/lib/command-detect.sh` exposes
`command_invokes_git_commit`, which iteratively strips common prefix
shapes (leading whitespace, env-var assignments, `cd <path> &&`) and
checks whether the residual leading token pair is literally `git
commit` followed by whitespace or end-of-string. This replaces the
prior `case "$COMMAND" in *"git commit"*) ;;` substring match that
fired on any Bash whose text contained the phrase — including grep
patterns, sed substitutions, cat heredoc bodies, echo strings, and
`git log --grep` queries.

Scope deliberately narrow per the ticket's recommended Fix shape B:
handles the prefix shapes orchestrator and capture/manage/work skills
actually emit (direct `git commit`, `cd && git commit`, `VAR=value git
commit`). Mid-chain `&&` after a non-prefix-shape leading command (e.g.
`git add foo && git commit`) is a documented and acceptable false-
negative — a standalone re-run of `git commit` re-triggers detection.

Coverage: 28 helper-level bats fixtures at
`packages/itil/hooks/test/command-detect.bats` plus 10 P268-prefixed
integration cases appended to
`packages/itil/hooks/test/itil-readme-refresh-discipline.bats` covering
the surfaces that previously misfired.

Four sibling PreToolUse:Bash hooks were confirmed sharing the same
substring-match anti-pattern (`retrospective-readme-jtbd-currency.sh`,
`itil-rfc-trailer-advisory.sh`, `itil-changeset-discipline.sh`,
`p057-staging-trap-detect.sh`); each is being captured as its own
problem ticket per ADR-014 one-concern-per-ticket. The new helper is in
the right shape for those sibling refactors to consume in their own
commits.
