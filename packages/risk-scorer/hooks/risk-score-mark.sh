#!/bin/bash
# PostToolUse:Agent hook: Deterministically writes all risk score files,
# verdict markers, and bypass markers by parsing structured output from
# risk-scorer agents. This is the ONLY place score files are written —
# agents output structured markers, this hook writes the files.
#
# Handles: wr-risk-scorer:pipeline, wr-risk-scorer:plan, wr-risk-scorer:wip, wr-risk-scorer:policy
# Replaces: risk-policy-mark-reviewed.sh (which had fragile P001 backup parsing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/gate-helpers.sh"
_enable_err_trap

_parse_input

TOOL_NAME=$(_get_tool_name)
[ "$TOOL_NAME" = "Agent" ] || exit 0

SUBAGENT=$(_get_subagent_type)
SESSION_ID=$(_get_session_id)
[ -n "$SESSION_ID" ] || exit 0

# Only handle risk-scorer agents
case "$SUBAGENT" in
  *risk-scorer*) ;;
  *) exit 0 ;;
esac

AGENT_OUTPUT=$(_get_tool_output)
RDIR=$(_risk_dir "$SESSION_ID")

# ---------------------------------------------------------------------------
# Pipeline scorer: write commit/push/release scores + bypass markers
# ---------------------------------------------------------------------------
if echo "$SUBAGENT" | grep -qE 'risk-scorer.pipeline'; then
  # Parse RISK_SCORES: commit=N push=N release=N
  SCORES_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^RISK_SCORES:' | tail -1) || true
  if [ -n "$SCORES_LINE" ]; then
    COMMIT=$(echo "$SCORES_LINE" | grep -oE 'commit=[0-9]+' | cut -d= -f2) || true
    PUSH=$(echo "$SCORES_LINE" | grep -oE 'push=[0-9]+' | cut -d= -f2) || true
    RELEASE=$(echo "$SCORES_LINE" | grep -oE 'release=[0-9]+' | cut -d= -f2) || true

    # Birth markers (<action>-born) capture the scorer-run timestamp. Band B
    # of the three-band TTL policy (P090) uses them to enforce a 2×TTL
    # hard-cap on sliding-window extension, so an unchanged-but-idle tree
    # cannot ride a single score indefinitely.
    [ -n "$COMMIT" ] && { printf '%s' "$COMMIT" > "${RDIR}/commit"; touch "${RDIR}/commit-born"; }
    [ -n "$PUSH" ] && { printf '%s' "$PUSH" > "${RDIR}/push"; touch "${RDIR}/push-born"; }
    [ -n "$RELEASE" ] && { printf '%s' "$RELEASE" > "${RDIR}/release"; touch "${RDIR}/release-born"; }
  fi

  # Parse RISK_BYPASS: reducing|incident
  BYPASS_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^RISK_BYPASS:' | tail -1) || true
  if [ -n "$BYPASS_LINE" ]; then
    BYPASS_TYPE=$(echo "$BYPASS_LINE" | sed 's/^RISK_BYPASS:[[:space:]]*//' | tr -d '[:space:]')
    case "$BYPASS_TYPE" in
      reducing)
        touch "${RDIR}/reducing-commit"
        touch "${RDIR}/reducing-push"
        touch "${RDIR}/reducing-release"
        ;;
      incident)
        touch "${RDIR}/incident-release"
        ;;
    esac
  fi

  # Refresh pipeline state hash so drift detection matches scoring time
  CURRENT_HASH=$("$SCRIPT_DIR/lib/pipeline-state.sh" --hash-inputs 2>/dev/null | _hashcmd | cut -d' ' -f1)
  if [ -n "$CURRENT_HASH" ]; then
    echo "$CURRENT_HASH" > "${RDIR}/state-hash"
  fi

  # Save report to .risk-reports/
  REPORT_DIR=".risk-reports"
  mkdir -p "$REPORT_DIR"
  TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%S)
  REPORT_PATH="${REPORT_DIR}/${TIMESTAMP}-commit.md"
  echo "$AGENT_OUTPUT" > "$REPORT_PATH"

  # ---------------------------------------------------------------------------
  # Risk register queue (ADR-056 Phase 2a)
  # Parse RISK_REGISTER_HINT: bullets and append one JSONL line each to
  # .afk-run-state/risk-register-queue.jsonl. Consumer skills (work-problems,
  # manage-problem, install-updates, assess-release) drain the queue in
  # subsequent iters per ADR-014 commit-grain discipline.
  #
  # Dual-parse contract: accept BOTH 3-col (preferred, agent-emitted slug) and
  # 2-col legacy shapes for backward compatibility while in-flight prompt
  # caches transition.
  #
  # Best-effort: errors are swallowed (queue persistence is recoverable via
  # Phase 3 backfill from .risk-reports/). ADR-045 Pattern 2: silent on stdout.
  # ---------------------------------------------------------------------------
  {
    QUEUE_DIR=".afk-run-state"
    QUEUE_FILE="${QUEUE_DIR}/risk-register-queue.jsonl"
    HINT_BLOCK=$(echo "$AGENT_OUTPUT" | awk '
      /^RISK_REGISTER_HINT:[[:space:]]*$/ { in_block=1; next }
      in_block && /^[[:space:]]*$/ { in_block=0; next }
      in_block && /^[A-Z_]+:/ { in_block=0; next }
      in_block && /^- / { print }
    ')
    if [ -n "$HINT_BLOCK" ]; then
      mkdir -p "$QUEUE_DIR"
      QUEUE_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
      while IFS= read -r BULLET; do
        [ -n "$BULLET" ] || continue
        # Strip leading "- " marker
        PAYLOAD="${BULLET#- }"
        PAYLOAD="${PAYLOAD#-}"
        PAYLOAD="${PAYLOAD# }"
        # Count pipe-separated columns (handle 2-col vs 3-col)
        N_PIPES=$(echo "$PAYLOAD" | awk -F'|' '{print NF-1}')
        case "$N_PIPES" in
          1)
            # 2-col legacy: <reason-tag> | <prose>
            REASON=$(echo "$PAYLOAD" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
            SLUG_FROM=$(echo "$PAYLOAD" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            PREFILL="$SLUG_FROM"
            SLUG_SOURCE="derived"
            # Derive slug: reason-tag + first 5 word-stems of prose, kebab, ≤60 chars
            SLUG_BODY=$(echo "$SLUG_FROM" | tr '[:upper:]' '[:lower:]' \
              | sed -E 's/[^a-z0-9 ]+/ /g; s/\b(the|a|an|is|of|to|in|for|on|at|by|and|or)\b//g; s/[[:space:]]+/ /g; s/^ //; s/ $//' \
              | awk '{out=""; for(i=1;i<=NF && i<=5;i++){out = out (i==1?"":"-") $i} print out}')
            SLUG="${REASON}-${SLUG_BODY}"
            SLUG=$(echo "$SLUG" | cut -c1-60)
            ;;
          2|*)
            # 3-col preferred: <reason-tag> | <slug> | <prose>
            REASON=$(echo "$PAYLOAD" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
            SLUG=$(echo "$PAYLOAD" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
            PREFILL=$(echo "$PAYLOAD" | awk -F'|' '{ for(i=3;i<=NF;i++){printf "%s%s", (i==3?"":"|"), $i} print "" }' \
              | sed -E 's/^[ \t]+//; s/[ \t]+$//')
            SLUG_SOURCE="agent"
            ;;
        esac
        # Validate reason-tag is one of three reserved values; skip otherwise
        case "$REASON" in
          above-appetite-residual|confidentiality-disclosure|user-stated-precondition) ;;
          *) continue ;;
        esac
        # Skip if slug or prefill is empty (malformed bullet)
        [ -n "$SLUG" ] && [ -n "$PREFILL" ] || continue
        # Append JSONL line via python3 to ensure proper escaping
        python3 -c "
import json, sys
print(json.dumps({
  'ts': '$QUEUE_TS',
  'session_id': '$SESSION_ID',
  'report_path': '$REPORT_PATH',
  'reason_tag': '$REASON',
  'risk_slug': '$SLUG',
  'slug_source': '$SLUG_SOURCE',
  'prefill': sys.argv[1],
}))
" "$PREFILL" >> "$QUEUE_FILE" 2>/dev/null || true
      done <<< "$HINT_BLOCK"
    fi
  } 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Plan scorer: write plan-reviewed marker on PASS
# ---------------------------------------------------------------------------
if echo "$SUBAGENT" | grep -qE 'risk-scorer.plan'; then
  VERDICT_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^RISK_VERDICT:' | tail -1) || true
  VERDICT=$(echo "$VERDICT_LINE" | sed 's/^RISK_VERDICT:[[:space:]]*//' | tr -d '[:space:]')
  case "$VERDICT" in
    PASS) touch "${RDIR}/plan-reviewed" ;;
    FAIL) ;; # Do NOT create marker — plan must be revised
    *) ;; # Unknown verdict — fail closed
  esac

  # Refresh pipeline state hash
  CURRENT_HASH=$("$SCRIPT_DIR/lib/pipeline-state.sh" --hash-inputs 2>/dev/null | _hashcmd | cut -d' ' -f1)
  if [ -n "$CURRENT_HASH" ]; then
    echo "$CURRENT_HASH" > "${RDIR}/state-hash"
  fi
fi

# ---------------------------------------------------------------------------
# WIP scorer: write wip-reviewed marker (unblocks next edit)
# ---------------------------------------------------------------------------
if echo "$SUBAGENT" | grep -qE 'risk-scorer.wip'; then
  # WIP assessment was done — unblock next edit regardless of CONTINUE/PAUSE
  # (PAUSE is advisory guidance to the user, not a hard gate)
  touch "${RDIR}/wip-reviewed"
fi

# ---------------------------------------------------------------------------
# Policy scorer: write policy-reviewed marker on PASS
# ---------------------------------------------------------------------------
if echo "$SUBAGENT" | grep -qE 'risk-scorer.policy'; then
  VERDICT_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^RISK_VERDICT:' | tail -1) || true
  VERDICT=$(echo "$VERDICT_LINE" | sed 's/^RISK_VERDICT:[[:space:]]*//' | tr -d '[:space:]')
  case "$VERDICT" in
    PASS) touch "${RDIR}/policy-reviewed" ;;
    FAIL) ;; # Do NOT create marker — policy must be revised
    *) ;; # Unknown verdict — fail closed
  esac
fi

# ---------------------------------------------------------------------------
# External-comms reviewer (P064 / ADR-028 amended 2026-05-14): write
# per-evaluator marker keyed on sha256(draft + '\n' + surface). Subagent
# emits the key; this hook trusts and uses it. Marker file:
# external-comms-risk-reviewed-<key>. The voice-tone evaluator (P038)
# writes its own peer marker external-comms-voice-tone-reviewed-<key>
# from packages/voice-tone/hooks/external-comms-mark-reviewed.sh.
# ---------------------------------------------------------------------------
if echo "$SUBAGENT" | grep -qE 'risk-scorer.external-comms'; then
  VERDICT_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^EXTERNAL_COMMS_RISK_VERDICT:' | tail -1) || true
  KEY_LINE=$(echo "$AGENT_OUTPUT" | grep -E '^EXTERNAL_COMMS_RISK_KEY:' | tail -1) || true
  VERDICT=$(echo "$VERDICT_LINE" | sed 's/^EXTERNAL_COMMS_RISK_VERDICT:[[:space:]]*//' | tr -d '[:space:]')
  KEY=$(echo "$KEY_LINE" | sed 's/^EXTERNAL_COMMS_RISK_KEY:[[:space:]]*//' | tr -d '[:space:]')
  # Validate key: 64 hex chars (sha256 output). Reject anything else.
  if echo "$KEY" | grep -qE '^[0-9a-f]{64}$'; then
    case "$VERDICT" in
      PASS) touch "${RDIR}/external-comms-risk-reviewed-${KEY}" ;;
      FAIL) ;; # Do NOT create marker — draft must be revised
      *) ;;    # Unknown verdict — fail closed
    esac
  fi
fi

exit 0
