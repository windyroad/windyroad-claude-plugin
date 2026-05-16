#!/bin/bash
# P132 Phase 2b — wr-itil Stop hook.
#
# Detects orchestrator main-turn `AskUserQuestion` calls fired mid-loop
# inside `/wr-itil:work-problems` — the regression class P132 captures
# (2026-05-17 reopen evidence: orchestrator asked iter-target selection
# between iters 3 and 4; halted the AFK loop for hours of user time).
#
# Detection signal (all three must hold):
#   1. Last assistant turn in the transcript contains an
#      AskUserQuestion tool_use.
#   2. Earlier in the transcript an assistant message issued a `Skill`
#      tool_use to `wr-itil:work-problems` (orchestrator activation).
#   3. No `ALL_DONE` or `## Work Problems Summary` terminal marker has
#      been emitted since the orchestrator activated (the orchestrator
#      is still mid-loop, not in its post-loop wrap-up).
#
# When all three match the hook emits a structured `stopReason`
# advisory citing P130 + the Mid-loop ask discipline subsection of
# `packages/itil/skills/work-problems/SKILL.md`. Advisory ONLY — the
# hook NEVER blocks. The next assistant turn reads the stopReason in
# its context and self-corrects (queue the question to
# outstanding_questions and continue iterating).
#
# Mirrors the sibling `itil-assistant-output-review.sh` Stop hook
# precedent (P085 prose-ask detection) on transcript-extraction shape
# and stopReason emit format.
#
# References:
#   P132     — this hook (Phase 2b structural enforcement).
#   P130     — orchestrator presence-aware dispatch; named in advisory.
#   ADR-013  — Rule 1 (interactive default) + Rule 6 (AFK fail-safe).
#   ADR-044  — framework-resolution boundary; named in advisory.
#   ADR-045  — hook injection budget; advisory honour-system band.
#   ADR-052  — behavioural tests default.
#   ADR-005  — plugin testing strategy.

# Per-surface configuration. Extending coverage to other orchestrators
# (run-retro Step 4b Stage 1, /install-updates Step 6a) is a future
# Phase 2c/2d variant — copy this hook + retarget these two vars.
ORCHESTRATOR_SKILL="wr-itil:work-problems"
TERMINAL_MARKER_RE='ALL_DONE|## Work Problems Summary'

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")

# Graceful fallback: no transcript_path or file missing means nothing
# to inspect. Exit clean — hook is advisory, never blocking.
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Empty transcript → silent exit.
[ -s "$TRANSCRIPT_PATH" ] || exit 0

# Identify the LAST assistant turn. Each transcript line is a JSON
# object {type, message, ...}; assistant turns have type=="assistant".
# Malformed lines are silently tolerated by jq's `-c` + `2>/dev/null`.
LAST_ASSISTANT=$(grep -E '"type"[[:space:]]*:[[:space:]]*"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -n 1 || true)
if [ -z "$LAST_ASSISTANT" ]; then
  exit 0
fi

# Signal 1: last assistant turn contains AskUserQuestion tool_use.
if ! echo "$LAST_ASSISTANT" | jq -e '
  .message.content
  | if type == "array" then
      map(select(.type == "tool_use" and .name == "AskUserQuestion")) | length > 0
    else false end
' >/dev/null 2>&1; then
  exit 0
fi

# Signal 2: any earlier assistant message contains a Skill tool_use to
# the configured orchestrator skill. Iterate every assistant line; on
# the first match set ORCH_LINE_NUM to its 1-based line index.
ORCH_LINE_NUM=0
LINE_NUM=0
while IFS= read -r line || [ -n "$line" ]; do
  LINE_NUM=$((LINE_NUM + 1))
  # Skip non-assistant + malformed lines.
  echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"assistant"' || continue
  echo "$line" | jq -e . >/dev/null 2>&1 || continue
  if echo "$line" | jq -e --arg s "$ORCHESTRATOR_SKILL" '
    .message.content
    | if type == "array" then
        map(select(.type == "tool_use" and .name == "Skill" and (.input.skill // .input.skillName // "") == $s)) | length > 0
      else false end
  ' >/dev/null 2>&1; then
    ORCH_LINE_NUM=$LINE_NUM
    break
  fi
done < "$TRANSCRIPT_PATH"

if [ "$ORCH_LINE_NUM" -eq 0 ]; then
  exit 0
fi

# Signal 3: no terminal marker emitted AFTER orchestrator activation.
# Scan lines strictly after ORCH_LINE_NUM up to the line BEFORE the
# last assistant turn (the AskUserQuestion turn itself shouldn't be
# considered a terminal-marker source — its content is a tool_use, not
# the orchestrator's final summary). If the AskUserQuestion turn IS
# the same turn that emits ALL_DONE, that's structurally implausible
# (you don't ask while wrapping up) — the conservative read is to
# scan up to and including all prior turns.
TOTAL_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
# Slice: from ORCH_LINE_NUM+1 to TOTAL_LINES-1 (exclude the final
# assistant turn carrying the AskUserQuestion). Edge case: if the
# orchestrator-activation line IS the last-assistant line, the
# AskUserQuestion would be in the same turn as the Skill call —
# impossible in practice. In that degenerate case the slice is empty
# and no terminal marker is seen → advise.
SLICE_END=$((TOTAL_LINES - 1))
TERMINAL_SEEN="no"
if [ "$SLICE_END" -ge "$ORCH_LINE_NUM" ]; then
  if sed -n "$((ORCH_LINE_NUM + 1)),${SLICE_END}p" "$TRANSCRIPT_PATH" \
       | grep -qE "$TERMINAL_MARKER_RE" 2>/dev/null; then
    TERMINAL_SEEN="yes"
  fi
fi

if [ "$TERMINAL_SEEN" = "yes" ]; then
  exit 0
fi

# All three signals present → emit advisory stopReason. The next
# assistant turn reads this in its context and self-corrects.
# Voice-tone target ~600 bytes; ADR-045 honour-system slack < 1000.
jq -n '{
  stopReason: (
    "MID-LOOP ASK DETECTED: AskUserQuestion fired inside /wr-itil:work-problems orchestrator main turn. " +
    "Per P130 + Mid-loop ask discipline subsection of work-problems SKILL.md, mid-loop AskUserQuestion is " +
    "forbidden except at framework-prescribed halt points (Step 0 session-continuity, Step 2.5/2.5b loop-end emit, " +
    "Step 6.5 above-appetite Rule 5 / CI failure, Step 6.75 dirty halt). " +
    "If at a halt point, this advisory is inapplicable. " +
    "If mid-loop, queue the question to outstanding_questions and continue iterating. " +
    "See ADR-044 framework-resolution boundary."
  )
}'

exit 0
