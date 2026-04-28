#!/usr/bin/env bats

# P112: Step 7 of /install-updates must retry install on failure with
# bounded exponential backoff, attempt a rollback path if all retries
# exhaust, and report a distinct terminal status per outcome. Addresses
# the unrecoverable failure window introduced by the P106 uninstall+install
# workaround: if uninstall succeeds but install fails (network, rate limit,
# signature mismatch), the plugin must not be silently lost.
#
# Behavioural test: extracts `install_with_retry_rollback` from SKILL.md
# Step 7, sources it with a mocked `claude` CLI, and asserts retry counts,
# rollback invocation, and terminal status per scenario. Aligns with P081
# direction (behavioural over structural grep).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/.claude/skills/install-updates/SKILL.md"

  FN_FILE="$BATS_TEST_TMPDIR/step7-fn.sh"
  awk '
    /^install_with_retry_rollback\(\) \{/ { in_fn=1 }
    in_fn { print }
    in_fn && /^\}/ { exit }
  ' "$SKILL_MD" > "$FN_FILE"

  TARGET_DIR="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET_DIR"
}

# Stand up a PATH-shadowing `claude` mock that consumes a comma-delimited
# install-exit sequence (e.g. "fail,fail,ok"). Uninstall and marketplace
# subcommands always succeed. Every call appends to $BATS_TEST_TMPDIR/claude-log.
make_claude_mock() {
  local pattern="$1"
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  printf '%s' "$pattern" > "$BATS_TEST_TMPDIR/install-pattern"
  printf '0' > "$BATS_TEST_TMPDIR/install-counter"
  : > "$BATS_TEST_TMPDIR/claude-log"
  cat > "$bindir/claude" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$BATS_TEST_TMPDIR/claude-log"
case "$1 $2" in
  "plugin uninstall") exit 0 ;;
  "plugin install")
    pattern=$(cat "$BATS_TEST_TMPDIR/install-pattern")
    count=$(cat "$BATS_TEST_TMPDIR/install-counter")
    count=$((count + 1))
    printf '%s' "$count" > "$BATS_TEST_TMPDIR/install-counter"
    next=$(printf '%s' "$pattern" | cut -d, -f"$count")
    [ "$next" = "ok" ] && exit 0
    exit 1
    ;;
  "plugin marketplace") exit 0 ;;
  *) exit 0 ;;
esac
MOCK
  chmod +x "$bindir/claude"
  PATH="$bindir:$PATH"
  export PATH
}

# Suppress real sleeps during tests — exponential backoff must not
# inflate test wall-time.
stub_sleep() {
  eval 'sleep() { :; }'
  export -f sleep
}

@test "install-updates Step 6 P112: install succeeds on first attempt — no retry, no rollback" {
  [ -s "$FN_FILE" ] || { echo "install_with_retry_rollback missing from SKILL.md"; return 1; }
  # shellcheck disable=SC1090
  source "$FN_FILE"
  make_claude_mock "ok"
  stub_sleep

  run install_with_retry_rollback "itil" "$TARGET_DIR" "0.10.0"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]

  install_calls=$(grep -c 'plugin install' "$BATS_TEST_TMPDIR/claude-log")
  marketplace_calls=$(grep -c 'plugin marketplace' "$BATS_TEST_TMPDIR/claude-log" || true)
  [ "$install_calls" -eq 1 ]
  [ "${marketplace_calls:-0}" -eq 0 ]
}

@test "install-updates Step 6 P112: install fails twice then succeeds on third attempt — no rollback" {
  [ -s "$FN_FILE" ] || { echo "install_with_retry_rollback missing from SKILL.md"; return 1; }
  # shellcheck disable=SC1090
  source "$FN_FILE"
  make_claude_mock "fail,fail,ok"
  stub_sleep

  run install_with_retry_rollback "itil" "$TARGET_DIR" "0.10.0"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]

  install_calls=$(grep -c 'plugin install' "$BATS_TEST_TMPDIR/claude-log")
  marketplace_calls=$(grep -c 'plugin marketplace' "$BATS_TEST_TMPDIR/claude-log" || true)
  [ "$install_calls" -eq 3 ]
  [ "${marketplace_calls:-0}" -eq 0 ]
}

@test "install-updates Step 6 P112: all retries exhaust, rollback install succeeds — status 'restored'" {
  [ -s "$FN_FILE" ] || { echo "install_with_retry_rollback missing from SKILL.md"; return 1; }
  # shellcheck disable=SC1090
  source "$FN_FILE"
  # Three retries fail; rollback-path install (4th) succeeds.
  make_claude_mock "fail,fail,fail,ok"
  stub_sleep

  run install_with_retry_rollback "itil" "$TARGET_DIR" "0.10.0"
  [ "$status" -eq 0 ]
  [ "$output" = "restored" ]

  install_calls=$(grep -c 'plugin install' "$BATS_TEST_TMPDIR/claude-log")
  marketplace_calls=$(grep -c 'plugin marketplace' "$BATS_TEST_TMPDIR/claude-log")
  [ "$install_calls" -eq 4 ]
  [ "$marketplace_calls" -eq 1 ]
}

@test "install-updates Step 6 P112: all retries and rollback fail — status 'lost', non-zero exit" {
  [ -s "$FN_FILE" ] || { echo "install_with_retry_rollback missing from SKILL.md"; return 1; }
  # shellcheck disable=SC1090
  source "$FN_FILE"
  make_claude_mock "fail,fail,fail,fail"
  stub_sleep

  run install_with_retry_rollback "itil" "$TARGET_DIR" "0.10.0"
  [ "$status" -ne 0 ]
  [ "$output" = "lost" ]

  install_calls=$(grep -c 'plugin install' "$BATS_TEST_TMPDIR/claude-log")
  [ "$install_calls" -eq 4 ]
}

@test "install-updates Step 6 P112: uninstall runs exactly once regardless of install retry count" {
  [ -s "$FN_FILE" ] || { echo "install_with_retry_rollback missing from SKILL.md"; return 1; }
  # shellcheck disable=SC1090
  source "$FN_FILE"
  make_claude_mock "fail,fail,ok"
  stub_sleep

  run install_with_retry_rollback "itil" "$TARGET_DIR" "0.10.0"
  [ "$status" -eq 0 ]

  uninstall_calls=$(grep -c 'plugin uninstall' "$BATS_TEST_TMPDIR/claude-log")
  [ "$uninstall_calls" -eq 1 ]
}

@test "install-updates Step 6 P112: SKILL.md final report documents new Status vocabulary" {
  # Users must be able to interpret the retry/rollback outcomes from the
  # final-report table — the new status tokens must appear in the report
  # section prose.
  local report_section
  report_section=$(sed -n '/^### 7\. Final report/,/^## /p' "$SKILL_MD")
  grep -F 'restored' <<< "$report_section"
  grep -F 'lost' <<< "$report_section"
}

@test "install-updates Step 6 P112: SKILL.md Step 6 preserves --scope project invariant (ADR-004)" {
  # Any retry or rollback command must still carry --scope project.
  local step6
  step6=$(sed -n '/^### 6\. Install/,/^### /p' "$SKILL_MD")
  local count
  count=$(grep -cF -- '--scope project' <<< "$step6")
  [ "$count" -ge 2 ]
}
