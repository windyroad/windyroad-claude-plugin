#!/bin/bash
# P085 detector registry: assistant-output-gate + assistant-output-review.
#
# Two detection functions sharing a single library so the UserPromptSubmit
# pre-generation reminder (gate) and the Stop post-hoc review use the
# same canonical phrasing list — one place to update when a new prose-ask
# pattern lands.
#
# Composition: this registry is the shape P078 (correction->ticket) and
# future itil assistant-output validators extend. Each detector is a
# pure function — takes text on stdin or as $1, exits 0 on match,
# non-zero on no-match.

# Canonical prose-ask phrasings — the patterns that should be emitted
# via AskUserQuestion instead. Extracted from P085 ticket + memory
# feedback_act_on_obvious_decisions.md.
#
# Case-insensitive, anchored to word boundaries where meaningful.
# Grep -E extended regex. Each entry is a separate alternation group
# in case future detectors want to report which phrase matched.
PROSE_ASK_PATTERNS=(
  'Want me to'
  'Should I\b'
  'Would you like me to'
  'Shall we\b'
  'Shall I\b'
  'Let me know if'
  'Do you want (me )?to'
  'Do you want to'
  'Option [A-Z][:.]? .*Option [A-Z]'
  '\([a-c]\).*\([a-c]\).*\([a-c]\)'
  '\([a-c]\) ?/ ?\([a-c]\)'
  '\(1\) .*\(2\)'
  'Which (do you|option|one|path) .*\?'
  'Awaiting your (direction|input|decision|response|confirmation|answer|reply)'
  'Pending your (direction|input|decision|response|confirmation|answer|reply)'
  'Once you confirm'
  'Awaiting your direction on whether'
)

# Direction-pinning patterns — signals in the user's incoming prompt
# that the next step is obvious and the assistant should act, not ask.
# Extracted from feedback_act_on_obvious_decisions.md.
DIRECTION_PIN_PATTERNS=(
  '\byes\b'
  '\bgo ahead\b'
  '\bjust do it\b'
  '\bjust go\b'
  '\bproceed\b'
  '\bact now\b'
  '\bact on\b'
  '\bdo it\b'
  '\bmake it so\b'
  '\bdrain\b'
  '\bship it\b'
)

# Correction-signal patterns — strong-affect correction signals in
# the user's incoming prompt that should trigger an offer to capture
# a problem ticket for the underlying behavioural pattern (P078).
# Extracted from feedback_capture_on_correction.md and the P078 ticket
# Root Cause Analysis "missing trigger" vocabulary.
#
# Case-insensitive (grep -Eqi). False-positive budget is accepted per
# P078 Investigation Tasks (a user message quoting the vocabulary in
# non-correction context will fire — minor over-report traded for
# signal reliability).
CORRECTION_SIGNAL_PATTERNS=(
  '\bFFS\b'
  "for f.{1,3}'?s sake"
  '\bDO NOT\b'
  "\bDON'T\b"
  '\bSTOP\b'
  "that'?s wrong"
  "that'?s not right"
  "you'?re not listening"
  '\byou (always|never|keep)\b'
  '!{2,}'
  '\bno\b.*\bwrong\b'
)

# detect_prose_ask: scans text on stdin for canonical prose-ask
# phrasings. Exits 0 if any pattern matches, 1 otherwise. Writes the
# first matched phrase to stdout (for observability in the Stop hook
# stopReason).
#
# Usage:
#   if echo "$text" | detect_prose_ask > /dev/null; then ... fi
detect_prose_ask() {
  local text
  text=$(cat)
  local pattern
  for pattern in "${PROSE_ASK_PATTERNS[@]}"; do
    if echo "$text" | grep -Eqi -- "$pattern"; then
      echo "$pattern"
      return 0
    fi
  done
  return 1
}

# detect_direction_pin: scans text on stdin for direction-pinning
# signals. Exits 0 if any pattern matches, 1 otherwise.
#
# Usage:
#   if echo "$prompt" | detect_direction_pin > /dev/null; then ... fi
detect_direction_pin() {
  local text
  text=$(cat)
  local pattern
  for pattern in "${DIRECTION_PIN_PATTERNS[@]}"; do
    if echo "$text" | grep -Eqi -- "$pattern"; then
      echo "$pattern"
      return 0
    fi
  done
  return 1
}

# detect_correction_signal: scans text on stdin for strong-affect
# correction signals (P078). Exits 0 if any pattern matches, 1
# otherwise. Writes the first matched phrase to stdout for
# observability in the hook's systemMessage.
#
# Usage:
#   if echo "$prompt" | detect_correction_signal > /dev/null; then ... fi
detect_correction_signal() {
  local text
  text=$(cat)
  local pattern
  for pattern in "${CORRECTION_SIGNAL_PATTERNS[@]}"; do
    if echo "$text" | grep -Eqi -- "$pattern"; then
      echo "$pattern"
      return 0
    fi
  done
  return 1
}
