#!/usr/bin/env bats

# ADR-069 (P294): retrospective-readme-jtbd-currency.sh PreToolUse:Bash hook
# must deny `git commit` invocations whose post-commit working tree exhibits
# skill-inventory drift (a directory under packages/<plugin>/skills/ is not
# named in that plugin's README). Hook-level enforcement at commit time is
# retained per the carried-forward load-bearing-from-the-start-for-drift-class
# driver: the most-common drift class (contributor adds a skill and forgets
# the README) ships in a commit that doesn't touch README.md.
#
# HISTORY: under superseded ADR-051 (P159) this hook also gated on
# JTBD-ID-citation drift. ADR-069 superseded that rule — READMEs market the
# persona's problem derived FROM the JTBD but MUST NOT cite JTBD IDs. The
# JTBD-ID anchor + its docs/jtbd/ resolution (and the docs/jtbd/ activation
# guard) are removed; only skill-inventory-drift remains.
#
# Detection delegates to
# `packages/retrospective/scripts/check-readme-jtbd-currency.sh`, invoked
# against the project's working tree (`./packages/`). The hook reads the
# detector's `TOTAL packages=<N> drift_instances=<K>` summary and denies
# when `drift_instances > 0`.
#
# Per ADR-005 / ADR-052 / P081 — behavioural; assert on emitted JSON, no
# source greps. Per ADR-045 Pattern 1 — allow paths emit 0 bytes; deny-band
# ≤300 bytes. Per ADR-013 Rule 1 — deny redirects to mechanical recovery
# (here: "name the skill in the README"). Per ADR-013 Rule 6 — fail-open
# outside a git work tree, on parse errors, or in projects without
# `./packages/`.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/retrospective-readme-jtbd-currency.sh"
  ORIG_DIR="$PWD"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init --quiet -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "seed" > seed.txt
  git add seed.txt
  git -c commit.gpgsign=false commit --quiet -m "initial"
  unset BYPASS_JTBD_CURRENCY
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
  unset BYPASS_JTBD_CURRENCY
}

run_bash_hook() {
  local cmd="$1"
  local json
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
  echo "$json" | bash "$HOOK"
}

# Helper: stub project with skill-inventory drift —
# packages/stub/skills/orphan/ exists but the README doesn't name "orphan".
make_drifted_project() {
  mkdir -p packages/stub/skills/orphan
  printf '%s\n' "# @windyroad/stub" "Markets a problem in prose; names no skills." > packages/stub/README.md
}

# Helper: clean stub project — every skill directory is named in the README.
make_clean_project() {
  mkdir -p packages/stub/skills/do-thing
  printf '%s\n' "# @windyroad/stub" "Run /wr-stub:do-thing to solve the problem." > packages/stub/README.md
}

# ── Trap detection: deny when drift detected ───────────────────────────────

@test "deny: skill-inventory drift on git commit triggers deny" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P294"* ]]
}

@test "deny message names the offending plugin slug" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub"* ]]
}

@test "deny message names the mechanical recovery (name the skill in the README)" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"name the skill in the README"* ]]
}

@test "deny message does NOT instruct citing a JTBD ID (ADR-069 regression guard)" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"JTBD-NNN"* ]]
  [[ "$output" != *"wr-jtbd"* ]]
}

@test "deny message stays under ADR-045 deny-band (<300 bytes)" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [ "${#output}" -lt 300 ]
}

# P173: the deny must NOT advertise the env bypass as an in-flight escape.
# BYPASS_JTBD_CURRENCY only takes effect when set in Claude Code's process env
# before the session started; a mid-session Bash export never reaches the hook.
# The deny clarifies the bypass is pre-session.
@test "P173 deny message clarifies the env bypass is pre-session (not a mid-session action)" {
  make_drifted_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"pre-session"* ]]
}

@test "deny: canonical release commit shape (chore: version packages) is subject to the gate" {
  make_drifted_project
  # Not a `git commit` invocation — the bare message must NOT deny.
  run run_bash_hook "chore: version packages"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  # The canonical release commit shape IS gated:
  run run_bash_hook "git commit -m 'chore: version packages'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: git commit --amend on drifted tree also triggers deny" {
  make_drifted_project
  run run_bash_hook "git commit --amend --no-edit"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: skill drift with NO docs/jtbd present still denies (ADR-069 guard removed)" {
  make_drifted_project
  # deliberately no docs/jtbd/ — under ADR-051 the hook was a no-op here;
  # ADR-069 removed that guard, so inventory drift is now evaluated.
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

# ── Allow paths: each non-trap shape must NOT deny ─────────────────────────

@test "allow: clean README (all skills named) on git commit allows the commit" {
  make_clean_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: BYPASS_JTBD_CURRENCY=1 env var allows drifted commit" {
  make_drifted_project
  BYPASS_JTBD_CURRENCY=1 run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: non-Bash tool exits 0 without deny" {
  make_drifted_project
  run bash -c "echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"foo.md\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: Bash command that is NOT git commit (e.g., git status) bypasses detection" {
  make_drifted_project
  run run_bash_hook "git status"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# ── Fail-open contracts (ADR-013 Rule 6) ───────────────────────────────────

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

@test "allow: project without packages/ dir exits 0 without deny (fail-open)" {
  # No packages/ — adopter project shape.
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: project with packages/ and no docs/jtbd/, clean README, allows (docs/jtbd no longer required)" {
  make_clean_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: empty JSON exits 0 without deny (fail-open on parse-incomplete)" {
  make_drifted_project
  run bash -c "echo '{}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: malformed JSON exits 0 without deny (fail-open on parse error)" {
  make_drifted_project
  run bash -c "echo 'not-json' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# ── Allow path silence (ADR-045 Pattern 1) ─────────────────────────────────

@test "allow path on clean tree emits 0 bytes (ADR-045 Pattern 1 silent-on-pass)" {
  make_clean_project
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 0 ]
}

@test "allow path on non-Bash tool emits 0 bytes (silent-on-pass)" {
  make_drifted_project
  run bash -c "echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"foo.md\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 0 ]
}

@test "allow path on non-commit Bash emits 0 bytes (silent-on-pass)" {
  make_drifted_project
  run run_bash_hook "git status"
  [ "$status" -eq 0 ]
  [ "${#output}" -eq 0 ]
}

# ── P275 / P268 leading-executable regression cases ─────────────────────────
#
# The hook must fire on ACTUAL `git commit` invocations, NOT on Bash that
# merely MENTIONS the phrase "git commit" in argument vectors or heredoc
# bodies. Mirrors P268 regression fixtures in command-detect.bats.

@test "P275 allow: grep with literal 'git commit' pattern on drifted project does NOT deny" {
  make_drifted_project
  run run_bash_hook "grep -r 'git commit' ."
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P275 allow: sed pattern containing 'git commit' on drifted project does NOT deny" {
  make_drifted_project
  run run_bash_hook "sed -n 's/git commit/X/p' packages/stub/README.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P275 allow: echo with literal 'git commit' string on drifted project does NOT deny" {
  make_drifted_project
  run run_bash_hook "echo 'run git commit -m foo'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P275 allow: git log --grep with 'git commit' search term on drifted project does NOT deny" {
  make_drifted_project
  run run_bash_hook "git log --grep='git commit'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P275 allow: git commit-tree plumbing on drifted project does NOT deny (boundary)" {
  make_drifted_project
  run run_bash_hook "git commit-tree HEAD^{tree} -m 'msg'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

# ── P275 positive leading-executable cases still deny ──────────────────────

@test "P275 deny: env-var-prefixed git commit on drifted project still triggers deny" {
  make_drifted_project
  run run_bash_hook "GIT_AUTHOR_NAME=foo git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P294"* ]]
}

@test "P275 deny: cd-prefixed git commit on drifted project still triggers deny" {
  make_drifted_project
  run run_bash_hook "cd . && git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P275 deny: leading-whitespace git commit on drifted project still triggers deny" {
  make_drifted_project
  run run_bash_hook "   git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}
