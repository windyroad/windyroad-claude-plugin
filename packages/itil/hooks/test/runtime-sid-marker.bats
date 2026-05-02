#!/usr/bin/env bats

# P142 / ADR-050: itil-runtime-sid-marker.sh PreToolUse hook.
#
# Behavioural contract:
#   1. Hook receives JSON on stdin with a `session_id` field.
#   2. Hook writes the session_id to the runtime-SID marker path
#      (computed by `runtime_sid_path()` in lib/runtime-sid.sh).
#   3. Hook emits 0 bytes on stdout (ADR-045 Pattern 1: side-effect-only,
#      silent-on-pass — no context budget burn per tool call).
#   4. Hook always exits 0 (fail-open — never block a tool call on
#      marker write).
#   5. Empty session_id -> hook is a no-op (marker not touched).
#   6. Subsequent invocations OVERWRITE the marker (so a subprocess
#      tool call replaces the orchestrator's SID with the subprocess's
#      SID for the duration of the subprocess; the orchestrator's
#      next tool call after subprocess exit overwrites it back).
#
# Per feedback_behavioural_tests.md (P081): tests assert the hook's
# observable effects (marker contents, stdout bytes, exit code) — NOT
# the source content of the hook script.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/itil-runtime-sid-marker.sh"
  SANDBOX_TMP=$(mktemp -d)
  export SESSION_MARKER_DIR="$SANDBOX_TMP"
  MARKER_PATH="$SANDBOX_TMP/itil-runtime-sid.current"
}

teardown() {
  rm -rf "$SANDBOX_TMP"
  unset SESSION_MARKER_DIR
}

# Helper: invoke the hook with a JSON stdin payload.
fire_hook() {
  local json="$1"
  echo "$json" | bash "$HOOK"
}

@test "hook writes session_id to runtime-SID marker" {
  expected_uuid="aaaaaaaa-1111-2222-3333-444444444444"
  fire_hook "{\"session_id\":\"$expected_uuid\",\"tool_name\":\"Bash\"}"
  [ -f "$MARKER_PATH" ]
  [ "$(cat "$MARKER_PATH")" = "$expected_uuid" ]
}

@test "hook is silent on stdout (ADR-045 Pattern 1)" {
  expected_uuid="bbbbbbbb-1111-2222-3333-444444444444"
  output=$(fire_hook "{\"session_id\":\"$expected_uuid\",\"tool_name\":\"Bash\"}")
  [ -z "$output" ]
}

@test "hook exits 0 on success" {
  expected_uuid="cccccccc-1111-2222-3333-444444444444"
  echo "{\"session_id\":\"$expected_uuid\",\"tool_name\":\"Bash\"}" | bash "$HOOK"
  [ "$?" -eq 0 ]
}

@test "hook overwrites prior marker on subsequent invocation" {
  first_uuid="dddddddd-1111-2222-3333-444444444444"
  second_uuid="eeeeeeee-1111-2222-3333-444444444444"
  fire_hook "{\"session_id\":\"$first_uuid\",\"tool_name\":\"Bash\"}"
  [ "$(cat "$MARKER_PATH")" = "$first_uuid" ]
  fire_hook "{\"session_id\":\"$second_uuid\",\"tool_name\":\"Write\"}"
  [ "$(cat "$MARKER_PATH")" = "$second_uuid" ]
}

@test "hook is a no-op when session_id is empty" {
  fire_hook "{\"tool_name\":\"Bash\"}"
  [ ! -f "$MARKER_PATH" ]
}

@test "hook is a no-op when stdin is not valid JSON" {
  echo "not-json-at-all" | bash "$HOOK"
  [ "$?" -eq 0 ]
  [ ! -f "$MARKER_PATH" ]
}

@test "hook fail-open on jq absent (graceful degradation)" {
  # Simulate jq absent by making PATH not include any jq binary.
  expected_uuid="ffffffff-1111-2222-3333-444444444444"
  result=$(echo "{\"session_id\":\"$expected_uuid\",\"tool_name\":\"Bash\"}" | env PATH="/usr/bin:/bin" bash "$HOOK"; echo "EXIT:$?")
  # Either jq is in /usr/bin (fine — marker written), or it's absent
  # (hook should still exit 0 without crashing). The exit-0 contract
  # is the load-bearing assertion; marker presence is a bonus when
  # jq is available.
  [[ "$result" == *"EXIT:0"* ]]
}
