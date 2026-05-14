#!/bin/bash
# PreToolUse hook: gates outbound prose for evaluator review (P064 / P038 / ADR-028 amended 2026-05-14).
#
# This is the CANONICAL hook synced byte-identically into each consumer plugin
# (risk-scorer, voice-tone, …) via ADR-017 duplicate-script pattern. Each copy
# sources `${SCRIPT_DIR}/external-comms-evaluator.conf` to determine its
# evaluator identity (risk / voice-tone / …) — the .conf file is per-package
# and NOT synced.
#
# Surface (matched on Bash command text or Edit/Write file_path):
#   - gh issue create | comment | edit            (public issue bodies)
#   - gh pr   create | comment | edit             (public PR bodies)
#   - gh api .../security-advisories              (advisory drafts)
#   - gh api .../comments                         (any REST surface accepting prose)
#   - npm publish                                 (README / package metadata to npm)
#   - PreToolUse:Write|Edit on .changeset/*.md    (P073 — gates author-time)
#
# Gate behaviour:
#   1. BYPASS_RISK_GATE=1 short-circuits the gate (consistent with git-push-gate.sh).
#   2. POLICY_FILE absent → advisory-only mode (permits with systemMessage).
#   3. Hybrid leak-pattern pre-filter (lib/leak-detect.sh) hard-fails on
#      credentials, prod-URL prefixes, business-context-paired financial figures,
#      or business-context-paired user counts. Deny includes the matched class.
#      (Voice-tone evaluator: skips leak pre-filter — leak detection is the
#      risk evaluator's concern; voice-tone reviews tone/voice only.)
#   4. Otherwise: check for THIS evaluator's per-evaluator marker keyed on
#      sha256(draft_body + '\n' + surface). Marker present → permit.
#      Marker absent → deny with directive to delegate to this plugin's
#      subagent (configured via external-comms-evaluator.conf).
#
# Marker location: ${TMPDIR:-/tmp}/claude-risk-${SESSION_ID}/external-comms-<EVALUATOR_ID>-reviewed-<sha256>
# Marker writer:   PostToolUse:Agent hook in each consumer plugin
#                  (risk-score-mark.sh or external-comms-mark-reviewed.sh) on
#                  subagent type wr-<plugin>:external-comms.
#
# Per-evaluator marker scheme (ADR-028 amended 2026-05-14): when both
# voice-tone and risk-scorer are installed, both gates fire on the same
# PreToolUse event; each gate denies until its own per-evaluator marker
# exists. Gates compose at firing level — no shared composite marker.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/leak-detect.sh
source "$SCRIPT_DIR/lib/leak-detect.sh"

# ---------- Per-package evaluator config (ADR-028 amended 2026-05-14) ----------
# Each consumer plugin ships its own external-comms-evaluator.conf alongside this
# byte-identical canonical hook. The .conf defines:
#   EXTERNAL_COMMS_EVALUATOR_ID    — short id (risk, voice-tone)
#   EXTERNAL_COMMS_SUBAGENT_TYPE   — subagent to delegate to (wr-<plugin>:external-comms)
#   EXTERNAL_COMMS_VERDICT_PREFIX  — structured-output prefix the mark hook parses
#   EXTERNAL_COMMS_ASSESS_SKILL    — on-demand skill path for manual delegation
#   EXTERNAL_COMMS_POLICY_FILE     — policy doc whose absence triggers advisory-only
#   EXTERNAL_COMMS_LEAK_PREFILTER  — yes|no — whether to run leak-detect pre-filter
# Fail-closed if absent: this hook cannot operate without a configured evaluator.
CONF_FILE="$SCRIPT_DIR/external-comms-evaluator.conf"
if [ ! -f "$CONF_FILE" ]; then
    echo "ERROR: external-comms-gate.sh requires $CONF_FILE (ADR-028 amended 2026-05-14)" >&2
    exit 0
fi
# shellcheck source=/dev/null
source "$CONF_FILE"
: "${EXTERNAL_COMMS_EVALUATOR_ID:?evaluator id missing from $CONF_FILE}"
: "${EXTERNAL_COMMS_SUBAGENT_TYPE:?subagent type missing from $CONF_FILE}"
: "${EXTERNAL_COMMS_ASSESS_SKILL:?assess-skill missing from $CONF_FILE}"
EXTERNAL_COMMS_POLICY_FILE="${EXTERNAL_COMMS_POLICY_FILE:-RISK-POLICY.md}"
EXTERNAL_COMMS_LEAK_PREFILTER="${EXTERNAL_COMMS_LEAK_PREFILTER:-yes}"

# ---------- Bypass ----------
if [ "${BYPASS_RISK_GATE:-0}" = "1" ]; then
    exit 0
fi

INPUT=$(cat)

# Extract tool name + tool_input via python3 (consistent with sibling hooks).
TOOL_NAME=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('session_id', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Permit silently when session_id is absent; the gate cannot key a marker.
[ -n "$SESSION_ID" ] || exit 0

# ---------- Surface detection ----------
SURFACE=""
DRAFT=""

case "$TOOL_NAME" in
    Bash)
        COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

        # Surface match — most-specific first.
        if echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh issue create(\s|$)'; then
            SURFACE="gh-issue-create"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh issue comment(\s|$)'; then
            SURFACE="gh-issue-comment"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh issue edit(\s|$)'; then
            SURFACE="gh-issue-edit"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh pr create(\s|$)'; then
            SURFACE="gh-pr-create"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh pr comment(\s|$)'; then
            SURFACE="gh-pr-comment"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*gh pr edit(\s|$)'; then
            SURFACE="gh-pr-edit"
        elif echo "$COMMAND" | grep -qE 'gh api .*security-advisories'; then
            SURFACE="gh-api-security-advisories"
        elif echo "$COMMAND" | grep -qE 'gh api .*/comments'; then
            SURFACE="gh-api-comments"
        elif echo "$COMMAND" | grep -qE '(^|;|&&|\|\|)\s*npm publish(\s|$)'; then
            SURFACE="npm-publish"
        else
            exit 0
        fi

        # Best-effort body extraction: --body 'TEXT' or --body "TEXT" or --field summary='TEXT'.
        # When absent (npm publish, --body-file), DRAFT="" is acceptable: the agent will
        # be invoked with command context and read whatever body source the call uses.
        DRAFT=$(printf '%s' "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# Match --body '...' or --body \"...\" or --field summary='...'
for pat in [r\"--body[= ]'([^']*)'\", r'--body[= ]\"([^\"]*)\"',
            r\"--field [a-zA-Z_]+='([^']*)'\", r'--field [a-zA-Z_]+=\"([^\"]*)\"']:
    m = re.search(pat, cmd)
    if m:
        print(m.group(1))
        break
" 2>/dev/null || echo "")
        ;;

    Write|Edit)
        FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    ti = json.load(sys.stdin).get('tool_input', {})
    print(ti.get('file_path', ti.get('path', '')))
except Exception:
    print('')
" 2>/dev/null || echo "")

        case "$FILE_PATH" in
            *.changeset/*.md|*/.changeset/*.md|.changeset/*.md)
                SURFACE="changeset-author"
                ;;
            *)
                exit 0
                ;;
        esac

        DRAFT=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    ti = json.load(sys.stdin).get('tool_input', {})
    print(ti.get('content', '') + ti.get('new_string', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
        ;;

    *)
        exit 0
        ;;
esac

# ---------- Helpers ----------
deny_with_reason() {
    local reason="$1"
    python3 -c "
import json, sys
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': sys.argv[1]
    }
}))
" "$reason"
}

permit_with_advisory() {
    local msg="$1"
    python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$msg"
}

# ---------- Advisory-only fallback when policy file is absent ----------
if [ ! -f "$EXTERNAL_COMMS_POLICY_FILE" ]; then
    permit_with_advisory "$EXTERNAL_COMMS_POLICY_FILE not found — $EXTERNAL_COMMS_SUBAGENT_TYPE gate is advisory-only on $SURFACE."
    exit 0
fi

# ---------- Hard-fail leak-pattern pre-filter (risk evaluator only) ----------
# Voice-tone evaluator skips this — leak detection is the risk evaluator's
# concern. Each per-package external-comms-evaluator.conf sets
# EXTERNAL_COMMS_LEAK_PREFILTER=yes (risk) or =no (voice-tone).
if [ "$EXTERNAL_COMMS_LEAK_PREFILTER" = "yes" ]; then
    if ! leak_detect_scan "$DRAFT"; then
        REASON=$(printf 'BLOCKED (external-comms gate / %s evaluator): %s on %s. Remove the leak before retrying. Override only if intentional: BYPASS_RISK_GATE=1.' \
            "$EXTERNAL_COMMS_EVALUATOR_ID" "$LEAK_DETECT_REASON" "$SURFACE")
        deny_with_reason "$REASON"
        exit 0
    fi
fi

# ---------- Marker-based gate (per-evaluator marker per ADR-028 amended 2026-05-14) ----------
SESSION_DIR="${TMPDIR:-/tmp}/claude-risk-${SESSION_ID}"
mkdir -p "$SESSION_DIR"
KEY=$(printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1)
MARKER="${SESSION_DIR}/external-comms-${EXTERNAL_COMMS_EVALUATOR_ID}-reviewed-${KEY}"

if [ -f "$MARKER" ]; then
    exit 0
fi

# Marker absent — deny + delegate.
VERDICT_PREFIX="${EXTERNAL_COMMS_VERDICT_PREFIX:-EXTERNAL_COMMS_${EXTERNAL_COMMS_EVALUATOR_ID^^}}"
REASON=$(printf 'BLOCKED (external-comms gate / %s evaluator): %s draft has not been reviewed by %s. Delegate to %s (subagent_type: '"'"'%s'"'"') with the draft body for review. The PostToolUse hook will mark this draft reviewed when the subagent emits %s_VERDICT: PASS. Use %s for an interactive walkthrough. Override only when intentional: BYPASS_RISK_GATE=1.' \
    "$EXTERNAL_COMMS_EVALUATOR_ID" "$SURFACE" "$EXTERNAL_COMMS_SUBAGENT_TYPE" "$EXTERNAL_COMMS_SUBAGENT_TYPE" "$EXTERNAL_COMMS_SUBAGENT_TYPE" "$VERDICT_PREFIX" "$EXTERNAL_COMMS_ASSESS_SKILL")
deny_with_reason "$REASON"
exit 0
