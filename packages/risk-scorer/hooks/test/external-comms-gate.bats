#!/usr/bin/env bats
# Tests for external-comms-gate.sh (P064 / ADR-028 amended).
# Behavioural: the gate denies outbound prose tool calls until the
# wr-risk-scorer:external-comms subagent has reviewed the draft and a
# per-evaluator marker has been written. Hard-fail leak patterns deny
# immediately without delegation.
#
# Note: secret-shaped strings are constructed at runtime via concatenation
# so this test file itself does not trip the secret-leak-gate hook.

setup() {
  HOOKS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$HOOKS_DIR/external-comms-gate.sh"

  TEST_SESSION="bats-extcomms-gate-$$-${BATS_TEST_NUMBER}"
  RDIR="${TMPDIR:-/tmp}/claude-risk-${TEST_SESSION}"
  rm -rf "$RDIR"
  mkdir -p "$RDIR"

  # Default: assume RISK-POLICY.md is present in repo root (it is).
  TEST_PROJECT_DIR="$(mktemp -d)"
  printf "## Confidential Information\n- Client names\n- Revenue figures\n" \
    > "$TEST_PROJECT_DIR/RISK-POLICY.md"

  unset BYPASS_RISK_GATE

  # Construct secret-shaped strings at runtime to avoid tripping the
  # repo's own secret-leak-gate when this file is committed/edited.
  GH_TOKEN_LIKE="g""hp""_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  AWS_KEY_LIKE="A""KIA""IOSFODNN7EXAMPLE"
}

teardown() {
  rm -rf "$RDIR"
  rm -rf "$TEST_PROJECT_DIR"
  unset BYPASS_RISK_GATE
}

# ---------- Helpers ----------

# Build a PreToolUse:Bash input for a given command via python so quoting is safe.
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

# Build a PreToolUse:Write input for a changeset path with body content.
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

# Run the hook in a project dir with RISK-POLICY.md present, piping JSON via stdin.
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

@test "gh issue create with clean draft denies and prompts external-comms delegation (no marker yet)" {
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a build failure on Node 20'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"permissionDecision"* ]]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-risk-scorer:external-comms"* ]]
}

# P173: the BYPASS_RISK_GATE override is clarified as pre-session — it only
# takes effect when set in Claude Code's process env before the session
# started, not via a mid-session Bash export. The in-flight escape-hatch is
# delegation to the external-comms subagent (already named in the deny).
@test "P173 marker-absent deny clarifies the env override is pre-session" {
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a build failure on Node 20'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"pre-session"* ]]
}

@test "hard-fail credential pattern (GitHub token) denies immediately with leak reason" {
  INPUT=$(build_bash_input "gh issue comment 42 --body 'token=${GH_TOKEN_LIKE}'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"permissionDecision"* ]]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"GitHub token"* ]] || [[ "$output" == *"credential"* ]]
}

@test "hard-fail credential pattern (AWS key) denies immediately" {
  INPUT=$(build_bash_input "gh pr create --title T --body 'AWS=${AWS_KEY_LIKE}'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"AWS"* ]] || [[ "$output" == *"credential"* ]]
}

@test "BYPASS_RISK_GATE=1 short-circuits the deny" {
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a build failure'")
  run bash -c "cd '$TEST_PROJECT_DIR' && BYPASS_RISK_GATE=1 printf '%s' \"\$1\" | BYPASS_RISK_GATE=1 '$HOOK'" _ "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "per-evaluator marker (external-comms-risk-reviewed-<KEY>) allows the call (ADR-028 amended 2026-05-14)" {
  DRAFT="we observed a build failure on Node 20"
  SURFACE="gh-issue-create"
  KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-risk-reviewed-${KEY}"

  INPUT=$(build_bash_input "gh issue create --title T --body '$DRAFT'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "legacy combined marker (external-comms-reviewed-<KEY>) does NOT satisfy the risk gate (P038 per-evaluator scheme)" {
  DRAFT="we observed a build failure on Node 20"
  SURFACE="gh-issue-create"
  KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  # Pre-amendment combined marker — should NOT satisfy the new per-evaluator gate.
  touch "${RDIR}/external-comms-reviewed-${KEY}"

  INPUT=$(build_bash_input "gh issue create --title T --body '$DRAFT'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-risk-scorer:external-comms"* ]]
}

@test "RISK-POLICY.md absent yields advisory-only mode (permits)" {
  rm -f "$TEST_PROJECT_DIR/RISK-POLICY.md"
  INPUT=$(build_bash_input "gh issue create --title T --body 'we observed a failure'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  # Must NOT deny when policy file is absent.
  [[ "$output" != *"\"permissionDecision\": \"deny\""* ]]
  [[ "$output" != *"\"permissionDecision\":\"deny\""* ]]
}

@test "PreToolUse:Write on .changeset/*.md with revenue leak content denies" {
  INPUT=$(build_write_input ".changeset/wr-risk-scorer-extcomms.md" "Add gate; covers Acme Corp \$2.4M ARR client.")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
}

@test "PreToolUse:Write on .changeset/*.md with clean content denies-then-delegates (no marker yet)" {
  INPUT=$(build_write_input ".changeset/wr-risk-scorer-extcomms.md" "Add external-comms gate covering gh issue and pr surfaces.")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-risk-scorer:external-comms"* ]]
}

@test "PreToolUse:Write on a non-changeset path is ignored" {
  INPUT=$(build_write_input "src/foo.ts" "Acme Corp client revenue \$2.4M")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "gh api security-advisories triggers the gate" {
  INPUT=$(build_bash_input "gh api repos/foo/bar/security-advisories --method POST --field summary='leak via X'")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-risk-scorer:external-comms"* ]]
}

@test "npm publish triggers the gate" {
  INPUT=$(build_bash_input "npm publish")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"wr-risk-scorer:external-comms"* ]]
}

# ---------------------------------------------------------------------------
# P010 / ADR-028 amended 2026-05-25 — deny-after-PASS regression.
# The gate sees the FULL Write content (YAML frontmatter + body) on the
# changeset-author surface, but the mark hook keys the marker on the body
# the agent wrapped in <draft>. Before the fix the gate hashed the full
# content (incl. frontmatter), so the body-keyed PASS marker landed at a
# key the gate never re-read → permanent deny-after-PASS. After the fix the
# gate strips frontmatter before hashing, so a body-keyed marker permits.
# ---------------------------------------------------------------------------

@test "P010: changeset Write permits when the PASS marker is keyed on the <draft> body (frontmatter stripped before hash)" {
  BODY="external-comms gate strips changeset frontmatter before key hash"
  SURFACE="changeset-author"
  # Marker keyed on the body the mark-hook helper derives from <draft> — for a
  # frontmatter-free body the canonical key equals the raw printf-of-body key.
  KEY=$(printf '%s\n%s' "$BODY" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-risk-reviewed-${KEY}"

  # The gate sees the full changeset file: frontmatter + blank line + body.
  CONTENT=$'---\n"@windyroad/risk-scorer": patch\n---\n\n'"$BODY"
  INPUT=$(build_write_input ".changeset/p010-fix.md" "$CONTENT")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
