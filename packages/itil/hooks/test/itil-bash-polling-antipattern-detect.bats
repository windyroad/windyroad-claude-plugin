#!/usr/bin/env bats

# P232: itil-bash-polling-antipattern-detect.sh PreToolUse:Bash hook
# must deny bash polling loops that self-reference via `pgrep -f`
# (parent class) or `pkill -0` (sibling), advising `wait $bg_pid` or
# Bash-tool `BashOutput` polling instead.
#
# Detection shape: a loop construct (`until` / `while`) combined with a
# polling mechanism (`pgrep -f` / `pkill -0`). One-shot `pgrep -f` (no
# surrounding loop) is allowed — the polling shape is the antipattern,
# not pgrep itself.
#
# Per ADR-005 / ADR-052 — bats live under packages/<plugin>/hooks/test/
# and assert behaviour on emitted JSON, not source-content. Per
# feedback_behavioural_tests.md (P081) — no source-grep on hook text.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/itil-bash-polling-antipattern-detect.sh"
}

# Helper: simulate the PreToolUse:Bash payload on stdin.
# Uses python to build the JSON so we don't escape-hell with bash.
run_bash_hook() {
  local cmd="$1"
  python3 -c "
import json, sys
print(json.dumps({'tool_name': 'Bash', 'tool_input': {'command': sys.argv[1]}}))
" "$cmd" | bash "$HOOK"
}

# --- Antipattern detection: positive cases (deny) ---

@test "deny: until ! pgrep -f loop" {
  run run_bash_hook "until ! pgrep -f 'bats --recursive' > /dev/null 2>&1; do sleep 5; done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P232"* ]]
}

@test "deny: while pgrep -f loop (positive form, no negation)" {
  run run_bash_hook "while pgrep -f 'long-running-job'; do sleep 2; done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" == *"P232"* ]]
}

@test "deny: until ! pkill -0 signal-0 poll" {
  run run_bash_hook "until ! pkill -0 -f 'worker'; do sleep 3; done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: while pkill -0 signal-0 poll" {
  run run_bash_hook "while pkill -0 12345; do sleep 1; done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: pgrep poll embedded in heredoc body" {
  # Heredoc body lands in the same tool_input.command string.
  run run_bash_hook "bash <<'EOF'
until ! pgrep -f 'bats'; do sleep 5; done
EOF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

@test "deny: P232 deadlock witness — multi-line shape with trailing tail" {
  run run_bash_hook "until ! pgrep -f 'bats --recursive' > /dev/null 2>&1; do sleep 5; done; echo done; tail -30 /tmp/bats-out.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"permissionDecision\": \"deny\""* ]]
}

# --- Allow paths: legitimate non-polling uses ---

@test "allow: one-shot pgrep -f without surrounding loop" {
  run run_bash_hook "pgrep -f 'nginx' && echo running"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: one-shot pkill (no -0, real signal — not a poll)" {
  run run_bash_hook "pkill -TERM -f 'stale-worker'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: wait \$bg_pid (the canonical recovery shape)" {
  run run_bash_hook "bats --recursive packages/itil/hooks/test/ & wait \$!"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: while loop without pgrep/pkill (unrelated)" {
  run run_bash_hook "while read line; do echo \$line; done < input.txt"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: until loop without pgrep/pkill (unrelated)" {
  run run_bash_hook "until [ -f /tmp/sentinel ]; do sleep 1; done"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: commit message text mentioning pgrep does not deny" {
  # The literal pair is in the commit message body, not a poll shape.
  # The hook should not over-match on commit prose.
  run run_bash_hook "git commit -m 'document pgrep antipattern in P232'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Tool-name filters ---

@test "allow: non-Bash tool exits 0 without deny" {
  run bash -c "echo '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"foo.md\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Parse / fail-open ---

@test "allow: empty JSON fails open" {
  run bash -c "echo '{}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

@test "allow: empty command field fails open" {
  run bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
}

# --- Deny message contract (ADR-038 progressive disclosure / ADR-045 budget) ---

@test "deny message cites P232 + names BOTH recovery alternatives" {
  run run_bash_hook "until ! pgrep -f 'bats'; do sleep 5; done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"P232"* ]]
  [[ "$output" == *"wait"* ]]
  [[ "$output" == *"BashOutput"* ]]
}

@test "deny message stays under ADR-045 deny-path budget (<700 bytes)" {
  # Voice-tone target ~245 bytes (sibling p057-staging-trap-detect.sh
  # precedent). ADR-045 deny-path band hard cap at 700 bytes keeps the
  # message terse — fail loudly if it bloats.
  run run_bash_hook "until ! pgrep -f 'bats'; do sleep 5; done"
  [ "$status" -eq 0 ]
  [ "${#output}" -lt 700 ]
}
