#!/usr/bin/env bats

# Tests for the RISK_REGISTER_HINT queue-write extension to risk-score-mark.sh
# (ADR-056 Phase 2a). Verifies the PostToolUse:Agent hook parses the
# RISK_REGISTER_HINT block from pipeline-agent output and appends one JSONL
# line per valid bullet to .afk-run-state/risk-register-queue.jsonl.
#
# Behavioural fixtures per ADR-052: each test pipes a mock agent output to
# the hook and asserts on side-effects (queue file content / shape / silence).
# No structural grep against source.
#
# Cross-references:
#   ADR-056: docs/decisions/056-risk-register-back-channel-write-contract.proposed.md
#   ADR-045: hook injection budget Pattern 2 (silent on stdout)
#   P033:    docs/problems/033-no-persistent-risk-register.known-error.md (driver)
#   P110:    pipeline back-channel hint (consumer of this contract)

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="$SCRIPT_DIR/risk-score-mark.sh"
  ORIG_DIR="$PWD"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  TMPDIR="$TEST_DIR/tmp"
  export TMPDIR
  mkdir -p "$TMPDIR"
  SESSION_ID="test-session-$$"
  RDIR="$TMPDIR/claude-risk-${SESSION_ID}"
  QUEUE_FILE="$TEST_DIR/.afk-run-state/risk-register-queue.jsonl"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

# Build mock PostToolUse:Agent JSON envelope and pipe to the hook.
run_hook() {
  local subagent="$1"
  local agent_output="$2"
  python3 -c "
import json, sys
print(json.dumps({
  'tool_name': 'Agent',
  'session_id': '${SESSION_ID}',
  'tool_input': {'subagent_type': '${subagent}'},
  'tool_response': {'content': [{'type': 'text', 'text': sys.stdin.read()}]}
}))" <<<"$agent_output" | bash "$HOOK"
}

# Capture hook stdout (separate from filesystem side-effects).
run_hook_capture_stdout() {
  local subagent="$1"
  local agent_output="$2"
  python3 -c "
import json, sys
print(json.dumps({
  'tool_name': 'Agent',
  'session_id': '${SESSION_ID}',
  'tool_input': {'subagent_type': '${subagent}'},
  'tool_response': {'content': [{'type': 'text', 'text': sys.stdin.read()}]}
}))" <<<"$agent_output" | bash "$HOOK"
}

# ---------------------------------------------------------------------------
# 3-column (preferred) parse path
# ---------------------------------------------------------------------------

@test "3-col hint with one above-appetite bullet → one JSONL line, slug_source=agent" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=12 push=8 release=4

RISK_REGISTER_HINT:
- above-appetite-residual | cumulative-residual-commit-layer-above-appetite | Cumulative residual reached 12/25 due to mass-edit across 17 files."
  [ -f "$QUEUE_FILE" ]
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 1 ]
  REASON=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['reason_tag'])" < "$QUEUE_FILE")
  SLUG=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['risk_slug'])" < "$QUEUE_FILE")
  SOURCE=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['slug_source'])" < "$QUEUE_FILE")
  PREFILL=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['prefill'])" < "$QUEUE_FILE")
  [ "$REASON" = "above-appetite-residual" ]
  [ "$SLUG" = "cumulative-residual-commit-layer-above-appetite" ]
  [ "$SOURCE" = "agent" ]
  [[ "$PREFILL" == *"mass-edit across 17 files"* ]]
}

@test "3-col hint with three bullets → three JSONL lines in order, all slug_source=agent" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=8 release=5

RISK_REGISTER_HINT:
- above-appetite-residual | cumulative-residual-above-appetite | Above-appetite residual.
- confidentiality-disclosure | revenue-figures-leaked | Revenue figures in changeset.
- user-stated-precondition | paired-capability-unmet | Pair B not yet shipped."
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 3 ]
  TAGS=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    for line in f:
        print(json.loads(line)['reason_tag'])
")
  EXPECTED="above-appetite-residual
confidentiality-disclosure
user-stated-precondition"
  [ "$TAGS" = "$EXPECTED" ]
  ALL_AGENT=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    src = [json.loads(line)['slug_source'] for line in f]
print(all(s == 'agent' for s in src))
")
  [ "$ALL_AGENT" = "True" ]
}

@test "3-col hint includes report_path matching the just-written .risk-reports file" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- above-appetite-residual | example-slug | Example."
  REPORT_PATH=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['report_path'])" < "$QUEUE_FILE")
  [[ "$REPORT_PATH" == .risk-reports/*-commit.md ]]
  [ -f "$REPORT_PATH" ]
}

# ---------------------------------------------------------------------------
# 2-column legacy parse path (backward compatibility)
# ---------------------------------------------------------------------------

@test "2-col legacy hint → JSONL line with derived slug, slug_source=derived" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=12 push=8 release=4

RISK_REGISTER_HINT:
- above-appetite-residual | Cumulative residual risk for commit layer."
  [ -f "$QUEUE_FILE" ]
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 1 ]
  SOURCE=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['slug_source'])" < "$QUEUE_FILE")
  SLUG=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['risk_slug'])" < "$QUEUE_FILE")
  [ "$SOURCE" = "derived" ]
  # Derived slug starts with reason-tag prefix
  [[ "$SLUG" == above-appetite-residual-* ]]
  # Derived slug is filename-safe (lowercase, kebab, no spaces)
  [[ "$SLUG" =~ ^[a-z0-9-]+$ ]]
}

@test "2-col legacy hint: same prefill produces same derived slug across runs" {
  PREFILL_TEXT="Cumulative residual risk for commit layer."
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=12 push=8 release=4

RISK_REGISTER_HINT:
- above-appetite-residual | $PREFILL_TEXT"
  SLUG_1=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['risk_slug'])" < "$QUEUE_FILE")
  rm -f "$QUEUE_FILE"
  sleep 1  # ensure different timestamp on second .risk-reports write
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=12 push=8 release=4

RISK_REGISTER_HINT:
- above-appetite-residual | $PREFILL_TEXT"
  SLUG_2=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['risk_slug'])" < "$QUEUE_FILE")
  [ "$SLUG_1" = "$SLUG_2" ]
}

@test "Mixed 3-col and 2-col bullets in same block → both shapes appended with correct slug_source" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- above-appetite-residual | preferred-slug | First risk.
- confidentiality-disclosure | Second risk in legacy shape."
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 2 ]
  SOURCES=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    for line in f:
        print(json.loads(line)['slug_source'])
")
  EXPECTED="agent
derived"
  [ "$SOURCES" = "$EXPECTED" ]
}

# ---------------------------------------------------------------------------
# Silence + no-op paths
# ---------------------------------------------------------------------------

@test "no hint emitted (silent-pass) → queue file is not created" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=2 push=2 release=1
RISK_BYPASS: reducing"
  [ ! -f "$QUEUE_FILE" ]
}

@test "empty agent output → no queue file, no crash" {
  run_hook "wr-risk-scorer:pipeline" ""
  [ ! -f "$QUEUE_FILE" ]
}

@test "malformed hint bullet (invalid reason-tag) is skipped; valid bullet appended" {
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- not-a-real-tag | bogus-slug | Should be skipped.
- above-appetite-residual | valid-slug | Should be kept."
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 1 ]
  SLUG=$(python3 -c "import json,sys; print(json.loads(sys.stdin.readline())['risk_slug'])" < "$QUEUE_FILE")
  [ "$SLUG" = "valid-slug" ]
}

# ---------------------------------------------------------------------------
# Append semantics (queue is append-only; dedupe is drain-step concern)
# ---------------------------------------------------------------------------

@test "two consecutive hook runs with same hint → six JSONL lines (queue is append-only)" {
  HINT="RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- above-appetite-residual | slug-a | First.
- confidentiality-disclosure | slug-b | Second.
- user-stated-precondition | slug-c | Third."
  run_hook "wr-risk-scorer:pipeline" "$HINT"
  sleep 1
  run_hook "wr-risk-scorer:pipeline" "$HINT"
  LINE_COUNT=$(wc -l < "$QUEUE_FILE")
  [ "$LINE_COUNT" -eq 6 ]
}

# ---------------------------------------------------------------------------
# Directory creation
# ---------------------------------------------------------------------------

@test ".afk-run-state/ absent → hook creates it; queue file written" {
  [ ! -d ".afk-run-state" ]
  run_hook "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- above-appetite-residual | example | Example."
  [ -d ".afk-run-state" ]
  [ -f "$QUEUE_FILE" ]
}

# ---------------------------------------------------------------------------
# ADR-045 Pattern 2: silent on stdout
# ---------------------------------------------------------------------------

@test "hook stdout is empty on queue-write success (ADR-045 Pattern 2)" {
  STDOUT=$(run_hook_capture_stdout "wr-risk-scorer:pipeline" "RISK_SCORES: commit=10 push=5 release=2

RISK_REGISTER_HINT:
- above-appetite-residual | quiet-slug | Quiet please.")
  [ -z "$STDOUT" ]
  # Verify the side-effect did happen
  [ -f "$QUEUE_FILE" ]
}
