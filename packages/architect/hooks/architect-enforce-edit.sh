#!/bin/bash
# Architecture - PreToolUse enforcement hook
# BLOCKS Edit/Write to all project files until architect is consulted.
# Excludes only non-architectural files: stylesheets, images, generated files.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/architect-gate.sh"

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty') || true
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty') || true

if [ -z "$SESSION_ID" ]; then
  architect_gate_parse_error
  exit 0
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# P004: Only gate files inside the project root. Absolute paths outside
# $PWD (e.g., ~/.claude/channels/*) are not project files.
case "$FILE_PATH" in
  /*)
    case "$FILE_PATH" in
      "$PWD"/*) ;;
      *) exit 0 ;;
    esac
    ;;
esac

# Only gate if the project has architecture decisions
if [ ! -d "docs/decisions" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Exclude non-architectural files
case "$FILE_PATH" in
  *.css|*.scss|*.sass|*.less)
    exit 0 ;;
  *.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|*.webp)
    exit 0 ;;
  *.woff|*.woff2|*.ttf|*.eot)
    exit 0 ;;
  *package-lock.json|*yarn.lock|*pnpm-lock.yaml)
    exit 0 ;;
  *.map)
    exit 0 ;;
  *.changeset/*.md|*/.changeset/*.md)
    exit 0 ;;
  */MEMORY.md|*/.claude/projects/*/memory/*)
    exit 0 ;;
  # READ tolerance only — gate skips user edits to .claude/plans/. NOT a write
  # target for agents. .claude/ is user-controlled config space; agents must not
  # write project-generated artefacts here. See P131.
  */.claude/plans/*.md|*.claude/plans/*.md)
    exit 0 ;;
  */RISK-POLICY.md)
    exit 0 ;;
  */.risk-reports/*)
    exit 0 ;;
  */docs/BRIEFING.md|docs/BRIEFING.md)
    exit 0 ;;
  */docs/briefing/*|docs/briefing/*)
    exit 0 ;;
  */docs/problems/*.md|docs/problems/*.md)
    exit 0 ;;
  # ADR-031 / RFC-002 T1 dual-pattern: per-state subdir layout
  # (`docs/problems/<state>/<NNN>-<slug>.md`). Coexists with the
  # flat-layout pattern above during the migration window. Drops to
  # single-pattern at RFC-002 T6 once Slice A migration verifies.
  */docs/problems/*/*.md|docs/problems/*/*.md)
    exit 0 ;;
  # Peer-plugin policy files — governed by their own plugin's enforce hook, not architect (P009)
  */docs/PRODUCT_DISCOVERY.md|docs/PRODUCT_DISCOVERY.md)
    exit 0 ;;
  */docs/jtbd/*|docs/jtbd/*)
    exit 0 ;;
  */docs/VOICE-AND-TONE.md|docs/VOICE-AND-TONE.md)
    exit 0 ;;
  */docs/STYLE-GUIDE.md|docs/STYLE-GUIDE.md)
    exit 0 ;;
esac

# Check gate
if check_architect_gate "$SESSION_ID"; then
  exit 0
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED: Cannot edit '${BASENAME}' without architecture review. You MUST first delegate to wr-architect:agent using the Agent tool (subagent_type: 'wr-architect:agent'). The architect will review against existing decisions in docs/decisions/ and flag if a new decision should be documented. After the review completes, this file will be unblocked automatically."
  }
}
EOF
exit 0
