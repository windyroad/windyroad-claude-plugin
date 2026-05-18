---
"@windyroad/itil": patch
---

P272: `itil-changeset-discipline.sh` no longer false-positive denies
Bash commands that merely mention the literal phrase `git commit` in
their argument vectors.

Replaces the prior `case "$COMMAND" in *"git commit"*) ;;` substring
match at the hook's command-shape filter with delegation to the shared
helper `packages/itil/hooks/lib/command-detect.sh::command_invokes_git_commit`
landed by P268. The helper iteratively strips common prefix shapes
(leading whitespace, env-var assignments, `cd <path> &&`) and checks
whether the residual leading token pair is literally `git commit`
followed by whitespace or end-of-string — so grep / sed / cat-heredoc /
echo / `git log --grep` commands whose argument vectors mention the
phrase no longer trip the changeset-discipline gate.

Coverage: 10 P272-prefixed behavioural bats fixtures appended to
`packages/itil/hooks/test/itil-changeset-discipline.bats`, mirroring
the P268 regression suite — grep / grep-rn / sed / echo / git-log /
cat-heredoc allow paths, `git commit-tree` boundary allow, plus three
positive-regression deny cases (bare `git commit`, `cd && git commit`,
`VAR=value git commit`).

Same fix shape as P268 applied verbatim to the next sibling
enforcement-layer hook per ADR-014 one-concern-per-ticket. Siblings
P273 / P274 / P275 remain captured as separate tickets.
