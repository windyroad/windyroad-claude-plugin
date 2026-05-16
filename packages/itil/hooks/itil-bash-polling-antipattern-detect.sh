#!/bin/bash
# P232: PreToolUse:Bash hook — denies bash polling loops that
# self-reference via `pgrep -f` (parent class) or `pkill -0`
# (sibling) and deadlock in AFK iters when the polling loop's
# own command line matches the search pattern.
#
# Detection shape: a loop construct (`until` / `while`, with or
# without leading `!`) immediately followed by `pgrep` OR
# `pkill -0`. One-shot `pgrep -f` (no surrounding loop) is allowed
# — the polling-loop shape is the antipattern, not pgrep itself.
#
# Recovery: agents should `wait $bg_pid` (shell-native) for
# backgrounded shell jobs OR use Bash-tool `run_in_background=true`
# plus `BashOutput` polling for harness-tracked processes.
#
# Allow paths (exit 0 without deny):
#   - tool_name != "Bash"          (only Bash invocations are gated)
#   - empty command                (parse-incomplete fail-open)
#   - command does not contain the polling-loop shape
#   - parse failure on stdin       (mirrors create-gate.sh fail-open)
#
# References:
#   ADR-005  — plugin testing strategy (hook bats live under hooks/test/).
#   ADR-013  Rule 1 — deny redirects with mechanical recovery.
#   ADR-038  — progressive disclosure / deny-message terseness budget.
#   ADR-045  — hook injection budget; deny-path band 200-700 bytes.
#   ADR-052  — behavioural tests default (positive + negative cases).
#   P146     — parent class (bash until-loop polls bats output with
#              bats-console-summary regex against TAP output).
#   P232     — this hook; self-referential pgrep -f variant.
#   p057-staging-trap-detect.sh — sibling PreToolUse:Bash detect
#              hook; mirror the deny-message shape.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Only gate Bash. Non-Bash tools bypass entirely.
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Empty / missing command — fail-open per create-gate.sh precedent.
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Polling-antipattern regex: a loop construct (`until` / `while`,
# with or without leading `!`) immediately followed by `pgrep` OR
# `pkill -0`. The `[[:space:]]+!?[[:space:]]*` middle covers
# `until pgrep`, `until ! pgrep`, `until !pgrep`, and the same
# shapes with `while`. The `pkill[[:space:]]+-0` half catches
# the signal-0 polling sibling without false-matching real-signal
# kills (`pkill -TERM`, `pkill -HUP`, etc.).
POLLING_RE='(until|while)[[:space:]]+!?[[:space:]]*(pgrep|pkill[[:space:]]+-0)'

if ! printf '%s' "$COMMAND" | grep -qE "$POLLING_RE"; then
  exit 0
fi

# Antipattern detected — emit deny with terse recovery.
# Voice-tone target ~245 bytes (sibling p057-staging-trap-detect.sh
# precedent). Cites P232, names BOTH recovery alternatives, fits
# inside ADR-045 deny-path 200-700 byte band.
REASON="BLOCKED: P232 self-referential polling antipattern. \\\`pgrep -f\\\` / \\\`pkill -0\\\` inside until/while loop matches the loop's own command line and deadlocks in AFK iters. Use \\\`wait \\\$bg_pid\\\` (shell-native) OR Bash-tool BashOutput polling (run_in_background=true) instead."

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${REASON}"
  }
}
EOF
exit 0
