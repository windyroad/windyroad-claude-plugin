#!/usr/bin/env bats

# P165: itil-readme-refresh-discipline.sh PreToolUse:Bash hook must deny
# `git commit` invocations whose staged set includes any
# docs/problems/<state>/NNN-*.md (or legacy docs/problems/NNN-*.md) but
# does NOT also stage docs/problems/README.md. Hook-level enforcement
# closes the P094/P062 README-refresh enforcement gap — iter subprocess
# commits could previously ship a `.verifying.md` rename or Status edit
# without the corresponding Verification Queue / WSJF Rankings row in
# the README.
#
# Detection logic (per ticket Fix Strategy + architect verdict):
#   On `git commit` invocations, run `git diff --staged --name-only`.
#   If any path matches docs/problems/(open|verifying|closed|known-error|parked)/NNN-*.md
#   OR docs/problems/NNN-*.<state>.md (legacy flat layout) AND
#   docs/problems/README.md is NOT staged, emit a deny with recovery
#   directive `git add docs/problems/README.md` and the P165 cite.
#   Allow when README is staged alongside, when no ticket file is
#   staged at all (README-only / retro-only / ADR-only / source-only
#   commits), or when BYPASS_README_REFRESH_GATE=1 is set.
#
# Per ADR-005 (plugin testing strategy) — hook bats live under
# packages/<plugin>/hooks/test/ and assert behaviour on emitted JSON,
# not source content. Per P081 — no source-grep on hook text. Simulate
# the PreToolUse:Bash payload on stdin and assert on the emitted
# permissionDecision.
#
# Per ADR-045 Pattern 1 (silent-on-pass) — allow paths emit 0 bytes.
# Per ADR-045 deny-band — deny messages target ~245 bytes; cap at 300.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/itil-readme-refresh-discipline.sh"
  ORIG_DIR="$PWD"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init --quiet -b main
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p docs/problems/open docs/problems/verifying docs/problems/closed \
           docs/problems/known-error docs/problems/parked docs/retros \
           docs/decisions packages/itil/skills/foo .changeset
  echo "seed" > seed.txt
  git add seed.txt
  git -c commit.gpgsign=false commit --quiet -m "initial"
  # README must exist for the "stage it alongside" tests to work.
  echo "# Problem Backlog" > docs/problems/README.md
  git add docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed readme"
  unset BYPASS_README_REFRESH_GATE
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
  unset BYPASS_README_REFRESH_GATE
}

run_bash_hook() {
  local cmd="$1"
  local json
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
  echo "$json" | bash "$HOOK"
}

# --- Trap detection: the canonical P165 shape ---

@test "deny: staged docs/problems/open/NNN-*.md without README refresh triggers deny on git commit" {
  echo "# Problem 999" > docs/problems/open/999-some-new-ticket.md
  git add docs/problems/open/999-some-new-ticket.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P165"* ]]
}

@test "deny: staged docs/problems/verifying/NNN-*.md without README refresh triggers deny" {
  echo "# Problem 999 verifying" > docs/problems/verifying/999-some-ticket.md
  git add docs/problems/verifying/999-some-ticket.md
  run run_bash_hook "git commit -m 'fix'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P165"* ]]
}

@test "deny: staged docs/problems/closed/NNN-*.md without README refresh triggers deny" {
  echo "# Problem 999 closed" > docs/problems/closed/999-some-ticket.md
  git add docs/problems/closed/999-some-ticket.md
  run run_bash_hook "git commit -m 'close'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: staged docs/problems/known-error/NNN-*.md without README refresh triggers deny" {
  echo "# Problem 999 known error" > docs/problems/known-error/999-some-ticket.md
  git add docs/problems/known-error/999-some-ticket.md
  run run_bash_hook "git commit -m 'transition'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: staged docs/problems/parked/NNN-*.md without README refresh triggers deny" {
  echo "# Problem 999 parked" > docs/problems/parked/999-some-ticket.md
  git add docs/problems/parked/999-some-ticket.md
  run run_bash_hook "git commit -m 'park'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: staged legacy flat-layout docs/problems/NNN-*.<state>.md without README triggers deny" {
  echo "# Problem 999 flat" > docs/problems/999-some-legacy.open.md
  git add docs/problems/999-some-legacy.open.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny message names offending ticket ID, recovery command, P165 cite" {
  echo "# Problem 999" > docs/problems/open/999-some-new-ticket.md
  git add docs/problems/open/999-some-new-ticket.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  # Deny names the ticket as `P<NNN>` (not full path — see hook
  # comment: full descriptive ticket slugs exceed ADR-045 deny-band).
  [[ "$output" == *"P999"* ]]
  [[ "$output" == *"docs/problems/README.md"* ]]
  [[ "$output" == *"P165"* ]]
}

@test "deny message stays under ADR-045 deny-band (<300 bytes)" {
  echo "# Problem 999" > docs/problems/open/999-some-ticket.md
  git add docs/problems/open/999-some-ticket.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [ "${#output}" -lt 300 ]
}

# --- Allow paths: each non-trap shape must NOT deny ---

@test "allow: staged ticket file WITH docs/problems/README.md allows the commit" {
  echo "# Problem 999" > docs/problems/open/999-new.md
  echo "# Problem Backlog updated" > docs/problems/README.md
  git add docs/problems/open/999-new.md docs/problems/README.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: README-only commit (reconcile-readme path) allows without ticket change" {
  echo "# Problem Backlog reconciled" > docs/problems/README.md
  git add docs/problems/README.md
  run run_bash_hook "git commit -m 'docs: reconcile readme'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: retro-only commit allows without ticket change or README refresh" {
  echo "# Retro 2026-05-11" > docs/retros/2026-05-11-iter.md
  git add docs/retros/2026-05-11-iter.md
  run run_bash_hook "git commit -m 'docs(retros): iter'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: ADR-only commit allows without ticket change or README refresh" {
  echo "# ADR 999" > docs/decisions/999-some-decision.proposed.md
  git add docs/decisions/999-some-decision.proposed.md
  run run_bash_hook "git commit -m 'docs(decisions): adr-999'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: source-only commit (packages/) allows without ticket change or README refresh" {
  echo "skill body" > packages/itil/skills/foo/SKILL.md
  git add packages/itil/skills/foo/SKILL.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: BYPASS_README_REFRESH_GATE=1 env var allows ticket commit without README refresh" {
  echo "# Problem 999" > docs/problems/open/999-bypass.md
  git add docs/problems/open/999-bypass.md
  BYPASS_README_REFRESH_GATE=1 run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: docs/problems/README-history.md edit alone does NOT trigger deny (not a ticket file)" {
  echo "# History" > docs/problems/README-history.md
  git add docs/problems/README-history.md
  run run_bash_hook "git commit -m 'docs: rotate history'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Allow path silence (ADR-045 Pattern 1) ---

@test "allow path emits 0 bytes (ADR-045 Pattern 1 silent-on-pass)" {
  echo "# Retro" > docs/retros/2026-05-11-iter.md
  git add docs/retros/2026-05-11-iter.md
  run run_bash_hook "git commit -m 'docs'"
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
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "git status"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Mixed staged sets ---

@test "deny: staged ticket + ADR (no README) still triggers deny (mixed surface dominance)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  echo "# ADR 999" > docs/decisions/999-x.proposed.md
  git add docs/problems/open/999-x.md docs/decisions/999-x.proposed.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: staged ticket + ADR + README allows (mixed set with README)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  echo "# ADR 999" > docs/decisions/999-x.proposed.md
  echo "# Problem Backlog updated" > docs/problems/README.md
  git add docs/problems/open/999-x.md docs/decisions/999-x.proposed.md docs/problems/README.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
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

# --- P230: narrative-only short-circuit (reconcile-readme is authority) ---
#
# When all staged ticket edits are purely narrative (Change Log entries,
# Investigation Task checkbox ticks, prose edits — no ranking-bearing
# field change, no rename between state subdirs, no creation/deletion)
# AND `packages/itil/scripts/reconcile-readme.sh` reports exit=0 against
# the current README, the hook silently passes. Ranking-bearing edits
# still fall through to existing detection per ADR-014 single-commit
# grain (architect verdict: reconcile is robustness layer, not
# supersession of per-operation refresh).

seed_valid_readme_p999_open() {
  cat > docs/problems/README.md <<EOF
# Problem Backlog

## WSJF Rankings

| ID | Title | WSJF |
|---|---|---|
| P999 | Test ticket | 1.0 |

## Verification Queue

(none)

## Closed

(none)
EOF
}

@test "P230 allow: narrative-only edit + reconcile-readme exit=0 → allow silently" {
  cat > docs/problems/open/999-narrative.md <<EOF
# Problem 999: Test ticket
**Status**: Open
**Priority**: 1
EOF
  seed_valid_readme_p999_open
  git add docs/problems/open/999-narrative.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Narrative-only edit: append a Change Log line
  echo "- 2026-05-16 — narrative tweak" >> docs/problems/open/999-narrative.md
  git add docs/problems/open/999-narrative.md
  run run_bash_hook "git commit -m 'docs(problems): narrative tweak'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "P230 allow: Investigation Task checkbox tick (narrative-only) + reconcile=0 → allow silently" {
  cat > docs/problems/open/999-checkbox.md <<EOF
# Problem 999: Test ticket
**Status**: Open
**Priority**: 1

## Investigation Tasks

- [ ] First task
EOF
  seed_valid_readme_p999_open
  git add docs/problems/open/999-checkbox.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Narrative-only edit: tick a checkbox
  sed -i.bak 's/- \[ \] First task/- [x] First task/' docs/problems/open/999-checkbox.md
  rm docs/problems/open/999-checkbox.md.bak
  git add docs/problems/open/999-checkbox.md
  run run_bash_hook "git commit -m 'docs(problems): tick task'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "P230 deny: ranking-bearing Status field change + reconcile=0 → still deny per ADR-014 single-commit grain" {
  cat > docs/problems/open/999-ranking.md <<EOF
# Problem 999: Test ticket
**Status**: Open
**Priority**: 1
EOF
  seed_valid_readme_p999_open
  git add docs/problems/open/999-ranking.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Ranking-bearing edit: change Status
  sed -i.bak 's/\*\*Status\*\*: Open/\*\*Status\*\*: Verifying/' docs/problems/open/999-ranking.md
  rm docs/problems/open/999-ranking.md.bak
  git add docs/problems/open/999-ranking.md
  run run_bash_hook "git commit -m 'transition'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P230 deny: ranking-bearing Priority field change + reconcile=0 → still deny" {
  cat > docs/problems/open/999-priority.md <<EOF
# Problem 999: Test ticket
**Status**: Open
**Priority**: 1
EOF
  seed_valid_readme_p999_open
  git add docs/problems/open/999-priority.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Ranking-bearing edit: change Priority
  sed -i.bak 's/\*\*Priority\*\*: 1/\*\*Priority\*\*: 5/' docs/problems/open/999-priority.md
  rm docs/problems/open/999-priority.md.bak
  git add docs/problems/open/999-priority.md
  run run_bash_hook "git commit -m 're-rate'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P230 deny: git mv between state subdirs (open→verifying) + no README refresh → deny (canonical iter-subprocess case)" {
  cat > docs/problems/open/999-rename.md <<EOF
# Problem 999: Test ticket
**Status**: Open
EOF
  seed_valid_readme_p999_open
  git add docs/problems/open/999-rename.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Rename to verifying state subdir
  git mv docs/problems/open/999-rename.md docs/problems/verifying/999-rename.md
  run run_bash_hook "git commit -m 'transition'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P230 deny: narrative-only edit + reconcile-readme drift (README missing ticket) → still deny per existing logic" {
  cat > docs/problems/open/999-narrative-drift.md <<EOF
# Problem 999: Test ticket
**Status**: Open
EOF
  # README does NOT list P999 → reconcile detects MISSING drift → exit=1
  cat > docs/problems/README.md <<EOF
# Problem Backlog

## WSJF Rankings

| ID | Title | WSJF |
|---|---|---|
EOF
  git add docs/problems/open/999-narrative-drift.md docs/problems/README.md
  git -c commit.gpgsign=false commit --quiet -m "seed p999"
  # Narrative-only edit
  echo "- 2026-05-16 — narrative line" >> docs/problems/open/999-narrative-drift.md
  git add docs/problems/open/999-narrative-drift.md
  run run_bash_hook "git commit -m 'docs(problems): narrative'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

# --- P231: deny message advertises correct bypass syntax (Option A) ---
#
# Deny message advertises `.claude/settings.json env` rather than inline
# prefix (which doesn't propagate to PreToolUse hooks per P173).

@test "P231 deny message advertises .claude/settings.json bypass path + P173 reference" {
  echo "# Problem 999" > docs/problems/open/999-bypass-msg.md
  git add docs/problems/open/999-bypass-msg.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *".claude/settings.json"* ]]
  [[ "$output" == *"P173"* ]]
}

# --- P268: substring-vs-invocation regression coverage ---
#
# Prior to P268, the hook used `case "$COMMAND" in *"git commit"*) ;;`
# which fired on ANY Bash command whose text contained the literal
# phrase "git commit" — including grep patterns, sed substitutions,
# cat heredoc bodies, echo strings, and `git log --grep` queries.
# Workaround was stage-README-first, observed ≥3 times per session.
# P268 replaces that match with a leading-executable-token check via
# `lib/command-detect.sh::command_invokes_git_commit`. The tests
# below stage a ticket file (which would trigger deny if the gate
# fired) and run various non-commit Bash commands whose argument
# vectors mention `git commit`. The hook MUST pass silently.

@test "P268 allow: grep with 'git commit' pattern does NOT trigger gate" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "grep -n 'git commit' file.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  # Silent pass per ADR-045 Pattern 1.
  [ "${#output}" -eq 0 ]
}

@test "P268 allow: grep -rn 'git commit' packages/ (the recurring orchestrator surface)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "grep -rn 'git commit' packages/"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P268 allow: sed -i 's/git commit/.../' substitution does NOT trigger gate" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "sed -i 's/git commit/git push/' file.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P268 allow: echo with 'git commit' inside string does NOT trigger gate" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "echo 'the git commit gate fires here'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P268 allow: git log --grep 'git commit' does NOT trigger gate (git log is leading)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "git log --grep 'git commit'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P268 allow: cat heredoc whose body contains 'git commit' does NOT trigger gate (iter-1 retro write surface)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  # Inline-build JSON with embedded newlines via printf to mimic the
  # Bash tool's multi-line command payload (the canonical retro-write
  # surface that misfired in P268).
  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Bash','tool_input':{'command':'cat >> docs/problems/README-history.md <<EOF\nFlow note: the git commit gate fires here.\nEOF'}}))")
  run bash -c "echo '$payload' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}

@test "P268 deny: actual git commit invocation with staged ticket still triggers gate (positive regression)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P165"* ]]
}

@test "P268 deny: cd <path> && git commit (prefix-strip path) still triggers gate" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "cd . && git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P268 deny: GIT_AUTHOR_NAME=Test git commit (env-prefix path) still triggers gate" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "GIT_AUTHOR_NAME=Test git commit -m 'feat'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "P268 allow: git commit-tree (boundary check — commit-tree is a different plumbing command)" {
  echo "# Problem 999" > docs/problems/open/999-x.md
  git add docs/problems/open/999-x.md
  run run_bash_hook "git commit-tree HEAD^{tree}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [ "${#output}" -eq 0 ]
}
