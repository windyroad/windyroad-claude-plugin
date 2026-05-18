#!/usr/bin/env bats

# P268: lib/command-detect.sh — `command_invokes_git_commit` helper.
#
# Behavioural contract:
#   `command_invokes_git_commit "$cmd"` returns 0 iff `$cmd`, when
#   executed by bash, would actually invoke `git commit` as its
#   leading-effective command (after stripping common prefix shapes:
#   leading whitespace, env-var assignments, `cd <path> &&` prefix).
#   Returns 1 for any other command, including commands whose
#   argument vectors or heredoc bodies merely mention the literal
#   string "git commit".
#
# Replaces the substring-match `case "$COMMAND" in *"git commit"*) ;;`
# pattern that 5 sibling PreToolUse:Bash hooks previously shared. The
# substring match misfired on `grep -n 'git commit' file.md`,
# `cat >> file <<EOF ... git commit ... EOF`, `echo "git commit ..."`,
# `sed -i 's/git commit/.../' file`, `git log --grep 'git commit'`,
# and similar non-commit Bash invocations whose arguments contained
# the literal phrase (P268 ticket Description).
#
# Per P081 (behavioural tests): tests assert helper return code against
# realistic command strings — NOT grep-against-source-content.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HELPER="$SCRIPT_DIR/lib/command-detect.sh"
  # shellcheck source=../lib/command-detect.sh
  source "$HELPER"
}

# --- Positive cases (helper returns 0 — command IS a git commit) ---

@test "positive: bare git commit -m" {
  run command_invokes_git_commit "git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: git commit --amend" {
  run command_invokes_git_commit "git commit --amend"
  [ "$status" -eq 0 ]
}

@test "positive: git commit with no args" {
  run command_invokes_git_commit "git commit"
  [ "$status" -eq 0 ]
}

@test "positive: leading whitespace before git commit" {
  run command_invokes_git_commit "  git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: env-var prefix BYPASS_X=1 git commit" {
  run command_invokes_git_commit "BYPASS_README_REFRESH_GATE=1 git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: multiple env-var prefixes git commit" {
  run command_invokes_git_commit "FOO=1 BAR=baz git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: env-var with double-quoted value git commit" {
  run command_invokes_git_commit "GIT_AUTHOR_NAME=\"Test User\" git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: env-var with single-quoted value git commit" {
  run command_invokes_git_commit "GIT_AUTHOR_NAME='Test User' git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: cd <path> && git commit" {
  run command_invokes_git_commit "cd /tmp && git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: cd <quoted path> && git commit" {
  run command_invokes_git_commit "cd \"/tmp/with spaces\" && git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: env-var then cd then git commit (combined prefixes)" {
  run command_invokes_git_commit "BYPASS=1 cd /tmp && git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: cd then env-var then git commit (reversed prefix order)" {
  run command_invokes_git_commit "cd /tmp && BYPASS=1 git commit -m 'feat'"
  [ "$status" -eq 0 ]
}

@test "positive: tab-indented git commit" {
  run command_invokes_git_commit $'\tgit commit -m feat'
  [ "$status" -eq 0 ]
}

# --- Negative cases (helper returns 1 — command is NOT a git commit) ---

@test "negative: grep with 'git commit' as pattern argument" {
  run command_invokes_git_commit "grep -n 'git commit' file.md"
  [ "$status" -eq 1 ]
}

@test "negative: grep -rn 'git commit' (the recurring orchestrator surface)" {
  run command_invokes_git_commit "grep -rn 'git commit' packages/"
  [ "$status" -eq 1 ]
}

@test "negative: cat heredoc whose body contains the phrase git commit" {
  run command_invokes_git_commit $'cat >> docs/problems/README-history.md <<EOF\nWe added a git commit gate.\nEOF'
  [ "$status" -eq 1 ]
}

@test "negative: echo string containing git commit" {
  run command_invokes_git_commit "echo 'the git commit gate fires here'"
  [ "$status" -eq 1 ]
}

@test "negative: sed substitution mentioning git commit" {
  run command_invokes_git_commit "sed -i 's/git commit/git push/' file.md"
  [ "$status" -eq 1 ]
}

@test "negative: git log --grep 'git commit'" {
  run command_invokes_git_commit "git log --grep 'git commit'"
  [ "$status" -eq 1 ]
}

@test "negative: git status (other git subcommand)" {
  run command_invokes_git_commit "git status"
  [ "$status" -eq 1 ]
}

@test "negative: git push (other git subcommand)" {
  run command_invokes_git_commit "git push origin main"
  [ "$status" -eq 1 ]
}

@test "negative: git commit-tree (plumbing — boundary check)" {
  run command_invokes_git_commit "git commit-tree HEAD^{tree}"
  [ "$status" -eq 1 ]
}

@test "negative: empty command" {
  run command_invokes_git_commit ""
  [ "$status" -eq 1 ]
}

@test "negative: whitespace-only command" {
  run command_invokes_git_commit "   "
  [ "$status" -eq 1 ]
}

@test "negative: cat with single-quoted body containing git commit phrase" {
  run command_invokes_git_commit "printf '%s\n' 'the git commit gate is here' > /tmp/out"
  [ "$status" -eq 1 ]
}

@test "negative: a different command chained before git commit (e.g. git add foo && git commit) — leading is git add, helper passes" {
  # Per Fix shape B narrow scope: helper only checks the leading-
  # effective command after prefix-strip. Mid-chain `git commit`
  # after a non-prefix-shape leading command (here `git add`) is a
  # documented false negative — standalone re-commit would re-trigger
  # detection. Acceptable per P268 ticket Description.
  run command_invokes_git_commit "git add foo && git commit -m 'feat'"
  [ "$status" -eq 1 ]
}

# --- Silence contract (ADR-045 Pattern 1) ---

@test "helper emits zero bytes on stdout (pure exit-code contract)" {
  run command_invokes_git_commit "git commit -m 'feat'"
  [ "${#output}" -eq 0 ]
}

@test "helper emits zero bytes on stdout for negative case too" {
  run command_invokes_git_commit "grep -n 'git commit' file.md"
  [ "${#output}" -eq 0 ]
}
