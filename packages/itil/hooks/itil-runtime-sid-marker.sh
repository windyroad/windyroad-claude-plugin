#!/bin/bash
# P142 / ADR-050: runtime-SID instrumentation PreToolUse hook.
#
# Captures the runtime stdin `session_id` from Claude Code's PreToolUse
# JSON payload and writes it to a per-machine, per-user, per-project
# marker file. The `get_current_session_id` helper (lib/session-id.sh)
# reads this marker as the authoritative current-session UUID, replacing
# the Phase 3 mtime-based announce-marker selection that misfired in
# orchestrator main turns AFTER subprocess dispatch (P142 ticket).
#
# Why a NEW PreToolUse hook (not an extension of an existing one):
#   - manage-problem-enforce-create.sh already runs on PreToolUse:Write,
#     but its perf-sensitive denial-path needs the runtime SID BEFORE
#     this hook would write it. Writing in a separate, prior hook
#     ensures the marker is in place by the time enforce-create reads.
#   - The architect-enforce-edit / jtbd-enforce-edit / tdd-enforce hooks
#     are owned by sibling plugins; cross-plugin coupling is rejected
#     per ADR-017 (shared-code-sync).
#   - A standalone, single-purpose hook is the cleanest fit for ADR-045
#     Pattern 1 (silent-on-pass, side-effect-only).
#
# Matcher: PreToolUse:Bash|Write|Edit|Read covers the tool calls that
# may invoke `get_current_session_id` indirectly (Bash sources the
# helper; Write/Edit fires the create-gate that consumes the marker;
# Read is included for completeness — every tool call that fires a
# PreToolUse hook contributes a fresh marker).
#
# ADR-045 Pattern 1 binding: this hook MUST emit 0 bytes on stdout.
# Adding stdout output would burn the per-tool-call context budget.
# All side effects are filesystem writes; observability is via the
# marker file itself.
#
# Fail-open contract: any error path (missing jq, malformed JSON, empty
# session_id, write failure) exits 0 without modifying state. The hook
# MUST NOT block tool calls — its only role is to deposit a marker for
# the helper. If the marker is absent, the helper falls back to the
# announce-marker priority logic.
#
# References:
#   ADR-050 — runtime-SID instrumentation surface (this hook).
#   ADR-048 — gate-misfire recovery (superseded by ADR-050).
#   ADR-045 — hook injection budget; Pattern 1 binding.
#   ADR-038 — announce-marker contract (cold-path fallback consumer).
#   P142    — the ticket this hook closes.
#   P124    — Phase 3 helper this hook complements.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runtime-sid.sh
source "$SCRIPT_DIR/lib/runtime-sid.sh"

INPUT=$(cat)

# Empty stdin -> no-op. Hook harnesses, manual invocation, or a
# malformed stdin payload all land here; fail-open per the contract.
if [ -z "$INPUT" ]; then
  exit 0
fi

# Parse session_id with python3 (universally present on macOS + most
# Linux distros; also already used by manage-problem-enforce-create.sh
# as the JSON parser of choice in this plugin). jq fallback if python3
# is absent. Any parse failure -> empty SESSION_ID -> no-op below.
SESSION_ID=""
if command -v python3 >/dev/null 2>&1; then
  SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('session_id', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
elif command -v jq >/dev/null 2>&1; then
  SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Write the marker. printf (not echo) to avoid trailing newline; the
# helper's `cat` reads contents verbatim, and a trailing newline would
# corrupt the SID comparison the runtime hook performs.
MARKER_PATH=$(runtime_sid_path)
printf '%s' "$SESSION_ID" > "$MARKER_PATH" 2>/dev/null || true

exit 0
