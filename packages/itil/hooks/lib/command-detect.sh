#!/bin/bash
# P268: shared command-detection helper for PreToolUse:Bash hooks
# that need to distinguish ACTUAL `git commit` invocations from Bash
# commands that merely MENTION the literal phrase "git commit" in
# argument vectors or heredoc bodies (grep patterns, sed patterns,
# echo strings, cat heredocs, `git log --grep` queries, etc.).
#
# Replaces the case-statement substring match
#
#     case "$COMMAND" in
#       *"git commit"*) ;;
#       *) exit 0 ;;
#     esac
#
# that 5 sibling PreToolUse:Bash hooks previously used to gate on
# `git commit`. The substring match misfired on legitimate non-commit
# Bash whose arguments contained the phrase (P268 ticket Description
# — observed iter-1 retro write and orchestrator grep, ≥3 events per
# session).
#
# Strategy (Fix shape B per P268 ticket):
#   1. Strip leading whitespace from the candidate command string.
#   2. Iteratively strip env-var-assignment prefixes (`VAR=value `,
#      `VAR="..." `, `VAR='...' `) and a `cd <path> &&` prefix until
#      stable (order-independent — both shapes can interleave).
#   3. Check whether the residual leading token pair is literally
#      `git[whitespace]commit` followed by whitespace or end-of-
#      string. The end-of-token boundary check stops `git commit-tree`
#      and similar `git commit-*` plumbing commands from matching.
#
# Scope deliberately narrow (per P268 ticket Description recommended
# Fix shape B): handles only the prefix shapes the orchestrator and
# capture/manage/work skills actually emit — direct `git commit`,
# `cd && git commit`, `VAR=value git commit`. Does NOT split on
# `&&`/`||`/`;`/`|` mid-chain — so `git add foo && git commit` reads
# as `git add` leading and the helper returns 1 (the gate silently
# passes). That is a documented and acceptable false-negative: a
# stand-alone re-run of `git commit` re-triggers detection. False
# positives — the case this fix exists to close — were causing the
# orchestrator to need manual workaround (stage README first, then
# run the offending non-commit command) 3+ times per session.
#
# Pure exit-code contract — helper never writes to stdout or stderr.
# Callers that need to name the trigger surface in deny messages
# should do so from their own delegated-detect helpers (e.g.
# `lib/readme-refresh-detect.sh` echoes the offending ticket path).
#
# References:
#   ADR-005  — plugin testing strategy (this helper's bats live at
#              `packages/itil/hooks/test/command-detect.bats` per
#              behavioural-test discipline).
#   ADR-009  — gate marker lifecycle (helper is per-invocation, no
#              marker state — same precedent as `lib/staging-detect.sh`,
#              `lib/changeset-detect.sh`, `lib/readme-refresh-detect.sh`).
#   ADR-045  — hook injection budget (silent-on-pass / silent-on-fail
#              — pure exit-code contract).
#   P125     — sibling staging-trap hook (candidate for follow-up
#              refactor to use this helper).
#   P141     — sibling changeset-discipline hook (candidate).
#   P165     — sibling README-refresh-discipline hook (first consumer
#              under P268).
#   P268     — this helper's surfacing ticket.

# Returns 0 if $1 is a Bash command that invokes `git commit`.
# Returns 1 otherwise (including commands that merely mention the
# phrase in their argument vectors or heredoc bodies, and commands
# whose leading-effective token is some other git subcommand).
command_invokes_git_commit() {
  local cmd="$1"

  # Strip leading whitespace (spaces, tabs, newlines).
  if [[ "$cmd" =~ ^[[:space:]]+ ]]; then
    cmd="${cmd#"${BASH_REMATCH[0]}"}"
  fi

  # Iteratively strip env-var-assignment prefixes and `cd <path> &&`
  # prefixes until stable. The order is unconstrained: both shapes
  # can appear in either sequence (`VAR=1 cd /tmp && git commit` or
  # `cd /tmp && VAR=1 git commit`).
  local prev=""
  while [ "$cmd" != "$prev" ]; do
    prev="$cmd"

    # Env-var assignment with double-quoted value: VAR="..." then ws.
    if [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=\"[^\"]*\"[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi

    # Env-var assignment with single-quoted value: VAR='...' then ws.
    if [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=\'[^\']*\'[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi

    # Env-var assignment with unquoted value: VAR=word then ws.
    # `word` here is any sequence of non-whitespace characters.
    if [[ "$cmd" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi

    # `cd <path> &&` prefix. Path token is double-quoted, single-
    # quoted, or unquoted (in which case it cannot itself contain
    # whitespace or `&`).
    if [[ "$cmd" =~ ^cd[[:space:]]+\"[^\"]*\"[[:space:]]*\&\&[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi

    if [[ "$cmd" =~ ^cd[[:space:]]+\'[^\']*\'[[:space:]]*\&\&[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi

    if [[ "$cmd" =~ ^cd[[:space:]]+[^[:space:]\&]+[[:space:]]*\&\&[[:space:]]+ ]]; then
      cmd="${cmd#"${BASH_REMATCH[0]}"}"
      continue
    fi
  done

  # After prefix-strip, the leading two tokens must be literally
  # `git` and `commit`, with whitespace or end-of-string after
  # `commit` (so `git commit-tree` and similar do not match).
  [[ "$cmd" =~ ^git[[:space:]]+commit([[:space:]]|$) ]]
}
