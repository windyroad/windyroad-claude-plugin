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

# ---------------------------------------------------------------------------
# P010 / ADR-028 amended 2026-05-25 — deny-after-PASS regression (voice-tone).
# Mirror of the risk-scorer regression: the gate sees the FULL changeset
# content (YAML frontmatter + body) but the mark hook keys the marker on the
# <draft> body. After the fix the gate strips frontmatter before hashing, so
# a body-keyed voice-tone PASS marker permits the changeset Write.
# ---------------------------------------------------------------------------

@test "P010: changeset Write permits when the voice-tone PASS marker is keyed on the <draft> body (frontmatter stripped before hash)" {
  BODY="external-comms gate strips changeset frontmatter before key hash"
  SURFACE="changeset-author"
  KEY=$(printf '%s\n%s' "$BODY" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-voice-tone-reviewed-${KEY}"

  CONTENT=$'---\n"@windyroad/voice-tone": patch\n---\n\n'"$BODY"
  INPUT=$(build_write_input ".changeset/p010-fix.md" "$CONTENT")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# P082 Phase 1 — git commit message surface (voice-tone evaluator).
# Commit messages reach git log / PR commits tab / release notes / CHANGELOG;
# voice-tone evaluator gates the message body for AI-tells, hedging,
# em-dashes, banned-phrase drift before the commit lands. Editor flow
# (bare `git commit`) is out of scope per P082 SC1 — the message is
# written to .git/COMMIT_EDITMSG AFTER PreToolUse fires.
# ---------------------------------------------------------------------------

@test "P082: git commit -m with literal -m body denies and delegates to voice-tone evaluator" {
  INPUT=$(build_bash_input "git commit -m \"I've implemented the feature\"")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"git-commit-message"* ]]
  [[ "$output" == *"wr-voice-tone:external-comms"* ]]
}

@test "P082: git commit --message with literal body denies and delegates" {
  INPUT=$(build_bash_input "git commit --message \"happy to help further with this fix\"")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"git-commit-message"* ]]
}

@test "P082: git commit --amend -m is intercepted (P082 SC2)" {
  INPUT=$(build_bash_input "git commit --amend -m \"rewritten subject\"")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"git-commit-message"* ]]
}

@test "P082: git commit HEREDOC body is intercepted and the body becomes the marker key" {
  # Build a HEREDOC-shaped command. The hook regex pulls the body BETWEEN
  # the <<'EOF' opener and the closing EOF marker — the extracted DRAFT is
  # the inner text, NOT the literal `$(cat <<'EOF' ... EOF)` wrapper.
  BODY=$'feat(foo): add bar\n\nWe observed a build failure on Node 20.'
  CMD=$'git commit -m "$(cat <<\'EOF\'\n'"$BODY"$'\nEOF\n)"'
  INPUT=$(build_bash_input "$CMD")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"deny"* ]]
  [[ "$output" == *"git-commit-message"* ]]

  # Pre-place the per-evaluator marker keyed on the extracted HEREDOC body
  # + the git-commit-message surface; the second run must permit silently.
  SURFACE="git-commit-message"
  KEY=$(printf '%s\n%s' "$BODY" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-voice-tone-reviewed-${KEY}"
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "P082: bare git commit (editor flow) is silently allowed per SC1" {
  # No -m / --message → .git/COMMIT_EDITMSG doesn't exist at PreToolUse
  # time. Phase 1 skip is pragmatic; the editor flow has user-eyeballs.
  INPUT=$(build_bash_input "git commit")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "P082: git merge is silently allowed (not a git commit verb)" {
  INPUT=$(build_bash_input "git merge --no-ff feature-branch")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "P082: BYPASS_RISK_GATE=1 short-circuits the git commit gate" {
  INPUT=$(build_bash_input "git commit -m \"I've implemented the feature\"")
  run bash -c "cd '$TEST_PROJECT_DIR' && BYPASS_RISK_GATE=1 printf '%s' \"\$1\" | BYPASS_RISK_GATE=1 '$HOOK'" _ "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "P082: per-evaluator marker keyed on (body, git-commit-message) permits the call" {
  BODY="docs(retro): close iter 3 ask-hygiene trail"
  SURFACE="git-commit-message"
  KEY=$(printf '%s\n%s' "$BODY" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
  touch "${RDIR}/external-comms-voice-tone-reviewed-${KEY}"

  INPUT=$(build_bash_input "git commit -m \"$BODY\"")
  run_hook "$INPUT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
