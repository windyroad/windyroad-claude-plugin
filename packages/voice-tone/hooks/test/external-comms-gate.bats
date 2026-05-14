#!/usr/bin/env bats
# Tests for packages/voice-tone/hooks/external-comms-gate.sh
# (P038 / ADR-028 amended 2026-05-14).
#
# Behavioural: the gate denies outbound prose tool calls until the
# wr-voice-tone:external-comms subagent has reviewed the draft and the
# per-evaluator marker `external-comms-voice-tone-reviewed-<KEY>` has been
# written. Voice-tone evaluator does NOT run the leak-pattern pre-filter
# (EXTERNAL_COMMS_LEAK_PREFILTER=no in external-comms-evaluator.conf).
# Composition with the risk-scorer evaluator happens at firing level —
# both gates fire on the same PreToolUse event when both plugins installed.

setup() {
  HOOKS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$HOOKS_DIR/external-comms-gate.sh"

  TEST_SESSION="bats-vt-extcomms-gate-$$-${BATS_TEST_NUMBER}"
  RDIR="${TMPDIR:-/tmp}/claude-risk-${TEST_SESSION}"
  rm -rf "$RDIR"
  mkdir -p "$RDIR"

  # Voice-tone evaluator's policy file is docs/VOICE-AND-TONE.md per the .conf.
  TEST_PROJECT_DIR="$(mktemp -d)"
  mkdir -p "$TEST_PROJECT_DIR/docs"
  printf "## Voice principles\n- Direct\n- No hedging\n## Banned patterns\n- 'happy to help further'\n" \
    > "$TEST_PROJECT_DIR/docs/VOICE-AND-TONE.md"

  unset BYPASS_RISK_GATE
}

teardown() {
  rm -rf "$RDIR"
  rm -rf "$TEST_PROJECT_DIR"
  unset BYPASS_RISK_GATE
}

# ---------- Helpers ----------

build_bash_input() {
  local cmd="$1"
  python3 -c "
import json, sys
print(json.dumps({
    'session_id': '$TEST_SESSION',
    'tool_name': 'Bash',
    'tool_input': {'command': sys.argv[1]},
}))
" "$cmd"
}

build_write_input() {
  local file_path="$1"
  local content="$2"
  python3 -c "
import json, sys
print(json.dumps({
    'session_id': '$TEST_SESSION',
    'tool_name': 'Write',
    'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]},
}))
" "$file_path" "$content"
}

run_hook() {
  local input="$1"
  run bash -c "cd '$TEST_PROJECT_DIR' && printf '%s' \"\$1\" | '$HOOK'" _ "$input"
}

# ---------- Tests ----------

@test "non-matching Bash command (ls) is allowed silently" {
  INPUT=$(build_bash_input "ls -la")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "gh issue create with clean draft denies and prompts wr-voice-tone:external-comms delegation (no marker yet)" {
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a build failure on Node 20'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"permissionDecision"* ]]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "voice-tone evaluator skips leak pre-filter (EXTERNAL_COMMS_LEAK_PREFILTER=no)" {
  # A draft with leak-shaped content (revenue figure with business context) would
  # hard-fail in the risk evaluator. The voice-tone gate must NOT hard-fail; leak
  # detection is the risk evaluator's concern. Voice-tone deny-and-delegates for
  # subagent review, same as any clean draft.
  INPUT=$(build_bash_input "gh issue comment 42 --body 'Acme Corp 2.4M ARR is a real concern'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
  # Must NOT name a leak class.
  [[ "$output" != *"credential"* ]]
  [[ "$output" != *"financial"* ]]
}

@test "BYPASS_RISK_GATE=1 short-circuits the deny" {
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a build failure'")
  run bash -c "cd '$TEST_PROJECT_DIR' && BYPASS_RISK_GATE=1 printf '%s' \"\$1\" | BYPASS_RISK_GATE=1 '$HOOK'" _ "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "per-evaluator marker (external-comms-voice-tone-reviewed-<KEY>) allows the call" {
  DRAFT="we observed a build failure on Node 20"
  SURFACE="gh-issue-create"
  KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-voice-tone-reviewed-${KEY}"

  INPUT=$(build_bash_input "gh issue create --title T --body '$DRAFT'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "risk-scorer marker (external-comms-risk-reviewed-<KEY>) does NOT satisfy the voice-tone gate" {
  # Independent per-evaluator markers: a risk-evaluator PASS marker does not
  # imply voice-tone has been reviewed.
  DRAFT="we observed a build failure on Node 20"
  SURFACE="gh-issue-create"
  KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-risk-reviewed-${KEY}"

  INPUT=$(build_bash_input "gh issue create --title T --body '$DRAFT'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "docs/VOICE-AND-TONE.md absent yields advisory-only mode (permits)" {
  rm -f "$TEST_PROJECT_DIR/docs/VOICE-AND-TONE.md"
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a failure'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  # Must NOT deny when policy file is absent.
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" != *"\"permissionDecision\":\"deny\""* ]]
  # Must surface the advisory systemMessage.
  [[ "$output" == *"docs/VOICE-AND-TONE.md not found"* ]]
}

@test "PreToolUse:Write on .changeset/*.md triggers deny+delegate" {
  INPUT=$(build_write_input ".changeset/test.md" "Add some feature. Happy to help further with details.")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "PreToolUse:Write on a non-changeset path is ignored" {
  INPUT=$(build_write_input "src/foo.ts" "happy to help further")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "gh api security-advisories triggers the gate" {
  INPUT=$(build_bash_input "gh api repos/foo/bar/security-advisories --method POST --field summary='vulnerability detail'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "npm publish triggers the gate" {
  INPUT=$(build_bash_input "npm publish")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "deny message references the on-demand skill (/wr-voice-tone:assess-external-comms)" {
  INPUT=$(build_bash_input "gh issue comment 42 --body 'a draft'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/wr-voice-tone:assess-external-comms"* ]]
}

@test "marker name uses evaluator id from external-comms-evaluator.conf (voice-tone, not risk)" {
  # Regression: the canonical hook sources the .conf and uses its EVALUATOR_ID
  # in the marker filename. The risk-scorer's marker name does NOT satisfy the
  # voice-tone gate even if the KEY matches.
  DRAFT="some draft body"
  SURFACE="gh-issue-create"
  KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  # Pre-amendment combined marker — should NOT satisfy the new voice-tone gate.
  touch "${RDIR}/external-comms-reviewed-${KEY}"

  INPUT=$(build_bash_input "gh issue create --title T --body '$DRAFT'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
}
