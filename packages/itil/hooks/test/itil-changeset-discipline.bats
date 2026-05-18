#!/usr/bin/env bats

# P141: itil-changeset-discipline.sh PreToolUse:Bash hook must deny
# `git commit` invocations whose staged set includes packages/<plugin>/
# source files but no .changeset/*.md is staged. Hook-level enforcement
# replaces unreliable iter-prompt-time changeset reminders (40% miss
# rate observed in 2026-04-28 AFK loop session).
#
# Detection logic (per ticket Fix Strategy):
#   On `git commit` invocations, run `git diff --staged --name-only`.
#   If any path matches packages/<plugin>/<non-allow-listed> AND no
#   .changeset/*.md (excluding README.md / config.json) is staged,
#   emit a deny with recovery directive `bun run changeset` and the
#   P141 cite. Allow when at least one valid changeset is staged, when
#   staged packages/<plugin>/ files are entirely allow-listed (test
#   paths or doc paths), or when BYPASS_CHANGESET_GATE=1 is set.
#
# Per ADR-005 (plugin testing strategy) — hook bats live under
# packages/<plugin>/hooks/test/ and assert behaviour on emitted JSON,
# not source-content. Per P081 — no source-grep on hook text. Simulate
# the PreToolUse:Bash payload on stdin and assert on the emitted
# permissionDecision.
#
# Per ADR-045 Pattern 1 (silent-on-pass) — allow paths emit 0 bytes.
# Per ADR-045 deny-band — deny messages target ~245 bytes; cap at 300.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/itil-changeset-discipline.sh"
  ORIG_DIR="$PWD"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init --quiet -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p packages/itil/skills/foo packages/itil/hooks packages/itil/hooks/test \
           packages/itil/hooks/lib packages/itil/scripts/test packages/itil/docs \
           packages/itil/.claude-plugin .changeset .github/workflows docs
  echo "seed" > seed.txt
  git add seed.txt
  git -c commit.gpgsign=false commit --quiet -m "initial"
  unset BYPASS_CHANGESET_GATE
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
  unset BYPASS_CHANGESET_GATE
}

run_bash_hook() {
  local cmd="$1"
  local json
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
  echo "$json" | bash "$HOOK"
}

# --- Trap detection: the canonical P141 shape ---

@test "deny: staged packages/<plugin>/ source without changeset triggers deny on git commit" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P141"* ]]
}

@test "deny: staged packages/<plugin>/hooks/ shell source without changeset triggers deny" {
  echo "#!/bin/bash" > packages/itil/hooks/new-hook.sh
  git add packages/itil/hooks/new-hook.sh
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P141"* ]]
}

@test "deny: staged plugin.json without changeset triggers deny" {
  echo "{}" > packages/itil/.claude-plugin/plugin.json
  git add packages/itil/.claude-plugin/plugin.json
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny message names plugin slug, recovery command, P141 cite" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"itil"* ]]
  [[ "$output" == *"changeset"* ]]
  [[ "$output" == *"P141"* ]]
}

@test "deny message stays under ADR-045 deny-band (<300 bytes)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [ "${#output}" -lt 300 ]
}

# --- Allow paths: each non-trap shape must NOT deny ---

@test "allow: staged packages/<plugin>/ source WITH a staged changeset allows the commit" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  echo "---" > .changeset/wr-itil-p141.md
  echo '"@windyroad/itil": patch' >> .changeset/wr-itil-p141.md
  echo "---" >> .changeset/wr-itil-p141.md
  echo "fix the thing" >> .changeset/wr-itil-p141.md
  git add packages/itil/skills/foo/SKILL.md .changeset/wr-itil-p141.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged test-only changes under packages/<plugin>/hooks/test/ allow without changeset" {
  echo "#!/usr/bin/env bats" > packages/itil/hooks/test/new-test.bats
  git add packages/itil/hooks/test/new-test.bats
  run run_bash_hook "git commit -m 'test'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged test-only changes under packages/<plugin>/scripts/test/ allow without changeset" {
  echo "#!/usr/bin/env bats" > packages/itil/scripts/test/new-script-test.bats
  git add packages/itil/scripts/test/new-script-test.bats
  run run_bash_hook "git commit -m 'test'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged packages/<plugin>/README.md alone allows without changeset (doc-only)" {
  echo "# itil" > packages/itil/README.md
  git add packages/itil/README.md
  run run_bash_hook "git commit -m 'docs'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged docs under packages/<plugin>/docs/ allow without changeset (doc-only)" {
  echo "# guide" > packages/itil/docs/guide.md
  git add packages/itil/docs/guide.md
  run run_bash_hook "git commit -m 'docs'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: staged SKILL.md (NOT in allow-list per architect amendment) triggers deny" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged .github/ workflow change without changeset (non-publishable path)" {
  echo "name: ci" > .github/workflows/ci.yml
  git add .github/workflows/ci.yml
  run run_bash_hook "git commit -m 'ci'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged top-level docs/ change without changeset (non-publishable path)" {
  echo "# briefing" > docs/BRIEFING.md
  git add docs/BRIEFING.md
  run run_bash_hook "git commit -m 'docs'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: BYPASS_CHANGESET_GATE=1 env var allows packages/<plugin>/ commit without changeset" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  BYPASS_CHANGESET_GATE=1 run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Allow path silence (ADR-045 Pattern 1) ---

@test "allow path emits 0 bytes (ADR-045 Pattern 1 silent-on-pass)" {
  echo "#!/usr/bin/env bats" > packages/itil/hooks/test/new-test.bats
  git add packages/itil/hooks/test/new-test.bats
  run run_bash_hook "git commit -m 'test'"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 0 ]
}

# --- Tool-name and command-shape filters ---

@test "allow: non-Bash tool exits 0 without deny" {
  run bash -c "echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"foo.md\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: Bash command that is NOT git commit (e.g., git status) bypasses detection" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git status"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Changeset variants: README.md and config.json don't count as a real changeset ---

@test "deny: staged .changeset/README.md alone does NOT count as a valid changeset" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  echo "# changesets" > .changeset/README.md
  git add packages/itil/skills/foo/SKILL.md .changeset/README.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

# --- Mixed staged sets ---

@test "deny: staged source + test in same commit still requires changeset (mixed set)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  echo "#!/usr/bin/env bats" > packages/itil/hooks/test/new-test.bats
  git add packages/itil/skills/foo/SKILL.md packages/itil/hooks/test/new-test.bats
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

# --- Parse / fail-open contracts ---

@test "allow: empty JSON exits 0 without deny (fail-open on parse-incomplete)" {
  run bash -c "echo '{}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: outside a git work tree exits 0 without deny (fail-open)" {
  cd "$ORIG_DIR"
  TEMP_NONGIT=$(mktemp -d)
  cd "$TEMP_NONGIT"
  run run_bash_hook "git commit -m 'feat'"
  cd "$TEST_DIR"
  rm -rf "$TEMP_NONGIT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- P272: substring-vs-invocation regression coverage ---
#
# Prior to P272, the hook used `case "$COMMAND" in *"git commit"*) ;;`
# which fired on ANY Bash command whose text contained the literal
# phrase "git commit" — including grep patterns, sed substitutions,
# cat heredoc bodies, echo strings, and `git log --grep` queries.
# Workaround was stage-changeset-first-or-different-shell, observed
# ≥3 events per session in the P268 sibling-hook class.
# P272 replaces that match with a leading-executable-token check via
# `lib/command-detect.sh::command_invokes_git_commit` (the shared
# helper landed by P268). The tests below stage `@windyroad/itil/`
# source (which would trigger deny if the gate fired) and run various
# non-commit Bash commands whose argument vectors mention `git commit`.
# The hook MUST pass silently.

@test "P272 allow: grep with 'git commit' pattern does NOT trigger gate" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "grep -n 'git commit' file.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  # Silent pass per ADR-045 Pattern 1.
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: grep -rn 'git commit' packages/ (the recurring orchestrator surface)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "grep -rn 'git commit' packages/"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: sed -i 's/git commit/.../' substitution does NOT trigger gate" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "sed -i 's/git commit/git push/' file.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: echo with 'git commit' inside string does NOT trigger gate" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "echo 'the git commit gate fires here'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: git log --grep 'git commit' does NOT trigger gate (git log is leading)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git log --grep 'git commit'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: cat heredoc whose body contains 'git commit' does NOT trigger gate (retro-write surface)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  # Inline-build JSON with embedded newlines via python3 to mimic the
  # Bash tool's multi-line command payload (the canonical retro-write
  # surface that misfired in the P268 sibling).
  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':'cat >> docs/problems/README-history.md <<EOF\nFlow note: the git commit gate fires here.\nEOF'}}))")
  run bash -c "echo '$payload' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 allow: git commit-tree (boundary check — commit-tree is a different plumbing command)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit-tree HEAD^{tree}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P272 deny: actual git commit invocation with staged packages/<plugin>/ source still triggers gate (positive regression)" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P141"* ]]
}

@test "P272 deny: cd <path> && git commit (prefix-strip path) still triggers gate" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "cd . && git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P272 deny: GIT_AUTHOR_NAME=Test git commit (env-prefix path) still triggers gate" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "GIT_AUTHOR_NAME=Test git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}
