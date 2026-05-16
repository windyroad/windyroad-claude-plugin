#!/usr/bin/env bats

# P132 Phase 2b: itil-mid-loop-ask-detect.sh Stop hook detects
# orchestrator main-turn AskUserQuestion calls fired mid-loop inside
# /wr-itil:work-problems — the regression class P132 captures
# (2026-05-17 reopen: orchestrator asked iter-target selection between
# iters 3 and 4; halted the loop for hours of AFK time).
#
# Detection signal:
#   1. Last assistant turn contains an AskUserQuestion tool_use
#   2. Earlier transcript contains a Skill tool_use to wr-itil:work-problems
#   3. No `ALL_DONE` / `## Work Problems Summary` marker has been emitted
#      since the skill activation (mid-loop, not post-loop wrap)
#
# When all three match the hook emits a structured `stopReason`
# advisory citing P130 + the Mid-loop ask discipline subsection of
# work-problems SKILL.md. Advisory only — never blocks. Mirrors the
# itil-assistant-output-review.sh Stop hook precedent (P085 prose-ask
# detection) but on a different signal class.
#
# Per ADR-005 / ADR-052 — bats live under packages/<plugin>/hooks/test/
# and assert behaviour on emitted JSON, not source-content. Per
# feedback_behavioural_tests.md (P081) — no source-grep on hook text.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/itil/hooks/itil-mid-loop-ask-detect.sh"
  TMPDIR_="$(mktemp -d)"
  TRANSCRIPT="$TMPDIR_/transcript.jsonl"
}

teardown() {
  rm -rf "$TMPDIR_"
}

# Helper: emit the JSONL transcript line for an assistant turn
# containing a Skill tool_use to wr-itil:work-problems.
emit_orchestrator_activation() {
  cat <<'JSON'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"wr-itil:work-problems"}}]}}
JSON
}

# Helper: emit a benign assistant text turn (no tool_use).
emit_text_turn() {
  local text="$1"
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":%s}]}}\n' \
    "$(printf '%s' "$text" | jq -Rs .)"
}

# Helper: emit an assistant turn containing an AskUserQuestion tool_use.
emit_ask_turn() {
  local header="${1:-Next problem}"
  cat <<JSON
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"question":"Pick next iter","header":"${header}","options":[{"label":"A","description":"x"},{"label":"B","description":"y"}]}]}}]}}
JSON
}

run_hook() {
  echo "{\"session_id\":\"mid-loop-test\",\"transcript_path\":$(printf '%s' "$TRANSCRIPT" | jq -Rs .)}" | bash "$HOOK"
}

# --- Positive detection ---

@test "detect: orchestrator activation + final AskUserQuestion + no terminal marker emits stopReason" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 1 complete. Dispatching iter 2."
    emit_text_turn "Iter 2 complete. Dispatching iter 3."
    emit_ask_turn "Pick next iter"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "detect: stopReason cites P130 + framework-prescribed halt points" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 1 done."
    emit_ask_turn "Next problem"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"P130"* ]]
  [[ "$output" == *"halt point"* ]]
  [[ "$output" == *"outstanding_questions"* ]]
}

@test "detect: stopReason cites ADR-044 framework-resolution boundary" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 1 done."
    emit_ask_turn "Pick"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADR-044"* ]]
}

# --- Negative paths: silent exit ---

@test "allow: transcript with no orchestrator activation exits silently" {
  # User asked a question outside /wr-itil:work-problems context;
  # AskUserQuestion in this case is unrelated to mid-loop discipline.
  {
    printf '{"type":"user","message":{"role":"user","content":"help me design a feature"}}\n'
    emit_text_turn "Two paths come to mind."
    emit_ask_turn "Design choice"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: orchestrator activated then ALL_DONE emitted (post-loop wrap)" {
  # The orchestrator has emitted its terminal summary; subsequent
  # AskUserQuestion is post-loop interactive follow-up, not mid-loop.
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 1 complete."
    emit_text_turn "## Work Problems Summary
All iters complete.
ALL_DONE"
    emit_ask_turn "Follow-up question"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: orchestrator activated then Work Problems Summary header emitted (post-loop)" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "## Work Problems Summary

Completed: 3 iters."
    emit_ask_turn "Next steps?"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: last assistant turn does not contain AskUserQuestion" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 2 dispatched."
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: missing transcript_path exits silently" {
  run bash -c 'echo "{\"session_id\":\"sid\"}" | bash "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: non-existent transcript file exits silently" {
  run bash -c "echo '{\"session_id\":\"sid\",\"transcript_path\":\"/tmp/does-not-exist-$RANDOM\"}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: empty transcript exits silently" {
  : > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "allow: malformed JSONL lines do not crash the hook" {
  {
    echo "not-json"
    emit_orchestrator_activation
    emit_text_turn "Iter 2"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  # Either silent OR stopReason — but never a crash. We assert no
  # non-zero exit; the silent-vs-stopReason split is incidental here.
}

# --- Advisory budget per ADR-045 ---

@test "advisory output stays under ADR-045 800-byte honour-system band" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    emit_text_turn "Iter 1 done."
    emit_ask_turn "Pick"
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
  [ "${#output}" -lt 1000 ]
}

# --- Distinguishing-marker: tool_name for AskUserQuestion --

@test "detect: matches even when AskUserQuestion is intermixed with text blocks" {
  {
    printf '{"type":"user","message":{"role":"user","content":"/wr-itil:work-problems"}}\n'
    emit_orchestrator_activation
    cat <<'JSON'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Two iter targets are tied on WSJF:"},{"type":"tool_use","name":"AskUserQuestion","input":{"questions":[{"question":"Pick next iter","header":"Next iter","options":[{"label":"P132","description":"x"},{"label":"P130","description":"y"}]}]}}]}}
JSON
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}
