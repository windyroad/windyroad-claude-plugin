#!/usr/bin/env bats

# P085: itil-assistant-output-review.sh Stop hook reads the last
# assistant turn from the transcript at `transcript_path` on stdin and
# scans for canonical prose-ask phrasings ("Want me to", "Should I",
# "Option A or Option B", etc.). When a prose-ask is detected, the
# hook emits a stopReason JSON object with a nudge instructing the
# assistant to re-emit via AskUserQuestion (or to act, if the decision
# was obvious). Clean turns pass silently (no stopReason field).
#
# The Stop hook cannot rewrite the emitted turn — only nudge the next
# turn — so its job is post-hoc detection + durable signal, per the
# architect verdict for P085.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/itil/hooks/itil-assistant-output-review.sh"
  TMPDIR_="$(mktemp -d)"
  TRANSCRIPT="$TMPDIR_/transcript.jsonl"
}

teardown() {
  rm -rf "$TMPDIR_"
}

# Writes a JSONL transcript with a user message followed by an
# assistant message. Claude Code transcript format: each line is a
# JSON object with `type: user|assistant` and `message.content` being
# either a string or an array of content blocks (text/tool_use).
write_transcript() {
  local user_text="$1"
  local assistant_text="$2"
  {
    printf '{"type":"user","message":{"role":"user","content":%s}}\n' "$(printf '%s' "$user_text" | jq -Rs .)"
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":%s}]}}\n' "$(printf '%s' "$assistant_text" | jq -Rs .)"
  } > "$TRANSCRIPT"
}

run_hook() {
  echo "{\"session_id\":\"stop-test\",\"transcript_path\":$(printf '%s' "$TRANSCRIPT" | jq -Rs .)}" | bash "$HOOK"
}

@test "review: 'Want me to' in assistant text triggers stopReason nudge" {
  write_transcript "update the ticket" "Done. Want me to also commit now or wait?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
  [[ "$output" == *"AskUserQuestion"* ]]
}

@test "review: 'Should I' in assistant text triggers stopReason nudge" {
  write_transcript "look at this" "I see the issue. Should I fix it now or wait for review?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Would you like me to' triggers stopReason nudge" {
  write_transcript "ok" "Ticket updated. Would you like me to open a PR next?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Option A or Option B' triggers stopReason nudge" {
  write_transcript "plan this" "Two paths: Option A: do it inline. Or Option B: split into two commits. Which do you prefer?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: '(a) / (b) / (c)?' triggers stopReason nudge" {
  write_transcript "go" "Three choices: (a) ship now, (b) wait for review, or (c) add tests first?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: clean informative turn does not trigger stopReason" {
  write_transcript "what changed" "The last commit added three files: detectors.sh, gate.sh, and review.sh. No new decisions were introduced."
  run run_hook
  [ "$status" -eq 0 ]
  # Clean output: either empty or a JSON object WITHOUT stopReason.
  [[ "$output" != *"stopReason"* ]]
}

@test "review: assistant turn containing AskUserQuestion tool_use does NOT flag" {
  # If the assistant used the AskUserQuestion tool, that's the compliant
  # path — we must not nudge them for using prose inside the tool's
  # rendered question text (the tool surface is structured).
  {
    printf '{"type":"user","message":{"role":"user","content":"plan this"}}\n'
    cat <<'JSON'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Here is the choice:"},{"type":"tool_use","name":"AskUserQuestion","input":{"question":"Which option?","options":[{"label":"A"},{"label":"B"}]}}]}}
JSON
  } > "$TRANSCRIPT"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "review: missing transcript_path exits cleanly without error" {
  run bash -c 'echo "{\"session_id\":\"sid\"}" | bash "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "review: non-existent transcript file exits cleanly without error" {
  run bash -c "echo '{\"session_id\":\"sid\",\"transcript_path\":\"/tmp/does-not-exist-$RANDOM\"}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"stopReason"* ]]
}

@test "review: ask-when-obvious pattern triggers stopReason" {
  # Prior user message pins direction ("yes, update the ticket"), next
  # assistant turn ends with a question mark on an obvious-next-step.
  # This is Facet A of P085 — asking when the answer is obvious.
  write_transcript "yes, update the ticket with the findings" "Updated. Want me to commit and close the ticket now, or leave it open for review?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Shall we' triggers stopReason nudge" {
  write_transcript "look at options" "That's one route. Shall we go with it?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Do you want to' triggers stopReason nudge" {
  write_transcript "plan" "I can split into two PRs. Do you want to go that route?"
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

# 2026-04-28 regression evidence (P085 reopen, Citation 1).
# Orchestrator main turn emitted a halt-summary ending with "Awaiting your
# direction on whether to add it + resume on P123, or end the session."
# The Stop hook should have caught this binary-choice prose-ask but the
# pattern list did not match. Detector extension closes the gap.
@test "review: 'Awaiting your direction on whether ... or ...' (Citation 1 shape) triggers stopReason" {
  write_transcript "ok" "Loop is still halted. Remaining open item: missing changeset for b9da37e. Awaiting your direction on whether to add it + resume on P123, or end the session."
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Awaiting your input' triggers stopReason nudge" {
  write_transcript "ok" "Plan staged. Awaiting your input on the next step."
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Pending your decision' triggers stopReason nudge" {
  write_transcript "review" "Refactor scoped to three files. Pending your decision before I continue."
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Once you confirm' triggers stopReason nudge" {
  write_transcript "look" "Rename ready. Once you confirm, I will proceed with the rename."
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}

@test "review: 'Awaiting your response' triggers stopReason nudge" {
  write_transcript "go" "Two paths identified. Awaiting your response so I know which to take."
  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopReason"* ]]
}
