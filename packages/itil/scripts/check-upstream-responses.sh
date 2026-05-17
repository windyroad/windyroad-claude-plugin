#!/usr/bin/env bash
# packages/itil/scripts/check-upstream-responses.sh
#
# Phase 1 of P249 — outbound symmetric counterpart to ADR-062's inbound
# discovery pipeline. Scans local problem tickets for `## Reported
# Upstream` back-link sections (written by `/wr-itil:report-upstream`
# Step 7), polls each upstream issue via `gh issue view`, diffs against
# cache, and surfaces new comments / state changes / label changes since
# last check.
#
# Read-only externally: only `gh issue view` (read-only) — no
# `gh issue comment` / `gh issue create`. Does NOT trip ADR-028
# external-comms gate. AFK-safe.
#
# Usage:
#   check-upstream-responses.sh
#     [--problems-dir <dir>]           default: docs/problems
#     [--cache-file <path>]            default: <problems-dir>/.outbound-responses-cache.json
#     [--audit-log <path>]             default: docs/audits/outbound-responses-log.md
#     [--ticket P<NNN>]                restrict polling to one ticket
#     [--force-recheck]                ignore cache; treat all as new
#     [--gh-bin <path>]                gh binary (default: gh) — testability seam
#
# Exit codes:
#   0 = success (zero or more new responses surfaced; stdout has per-ticket lines)
#   1 = error (problems-dir missing, malformed cache, malformed CLI args)
#   2 = partial — some upstream polls failed; successful ones are still
#       written to cache + audit-log
#
# Structured stdout (one per ticket; ≤ 150 bytes per line per ADR-038):
#   NEW     P<NNN> <url> state=<state> new-comments=<N>
#   STATE   P<NNN> <url> state=<old>→<new>
#   LABEL   P<NNN> <url> labels-added=<csv> labels-removed=<csv>
#   NONE    P<NNN> <url> no-change-since=<last-checked>
#   FAIL    P<NNN> <url> reason=<gh-error-short>
#
# Precedence when multiple change classes apply: STATE > NEW (comments) > LABEL > NONE.
#
# @problem P249 — no process for issue reporters to check for responses (Phase 1)
# @adr ADR-014 (governance skills commit their own work)
# @adr ADR-024 (back-link source of truth — Reported Upstream URL)
# @adr ADR-031 (cache file placement under docs/problems/)
# @adr ADR-032 (foreground synchronous skill)
# @adr ADR-038 (progressive disclosure — per-row byte budget)
# @adr ADR-049 (invoked via wr-itil-check-upstream-responses bin shim)
# @adr ADR-062 (inbound discovery — symmetric counterpart)
# @jtbd JTBD-004 (cross-repo coordination — primary anchor)
# @jtbd JTBD-006 (AFK-safe)
# @jtbd JTBD-001 (governance without slowing down)
# @jtbd JTBD-201 (audit trail)

set -uo pipefail

# ── Parse CLI args ──────────────────────────────────────────────────────────

PROBLEMS_DIR="docs/problems"
CACHE_FILE=""
AUDIT_LOG="docs/audits/outbound-responses-log.md"
TICKET_FILTER=""
FORCE_RECHECK=0
GH_BIN="gh"

while [ $# -gt 0 ]; do
  case "$1" in
    --problems-dir) PROBLEMS_DIR="$2"; shift 2 ;;
    --cache-file) CACHE_FILE="$2"; shift 2 ;;
    --audit-log) AUDIT_LOG="$2"; shift 2 ;;
    --ticket) TICKET_FILTER="$2"; shift 2 ;;
    --force-recheck) FORCE_RECHECK=1; shift ;;
    --gh-bin) GH_BIN="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Default cache path lives under problems-dir.
if [ -z "$CACHE_FILE" ]; then
  CACHE_FILE="${PROBLEMS_DIR}/.outbound-responses-cache.json"
fi

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -d "$PROBLEMS_DIR" ]; then
  echo "ERROR: problems-dir not found: $PROBLEMS_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

# ── Read existing cache (or start fresh) ────────────────────────────────────

if [ -f "$CACHE_FILE" ]; then
  if ! jq -e . "$CACHE_FILE" >/dev/null 2>&1; then
    echo "ERROR: cache file is malformed: $CACHE_FILE" >&2
    exit 1
  fi
  CACHE_JSON="$(cat "$CACHE_FILE")"
else
  CACHE_JSON='{"last_checked":null,"tickets":{}}'
fi

# Build a fresh updated cache JSON in memory; flush at end.
UPDATED_CACHE="$CACHE_JSON"

# ── Discover tickets with `## Reported Upstream` URL ────────────────────────
#
# Dual-tolerant per RFC-002: flat layout `<NNN>-*.<status>.md` AND
# per-state subdir layout `<status>/<NNN>-*.md`.

shopt -s nullglob

declare -a TICKET_FILES
TICKET_FILES=()
for f in "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.open.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.known-error.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.verifying.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.parked.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.closed.md \
         "$PROBLEMS_DIR"/open/[0-9][0-9][0-9]-*.md \
         "$PROBLEMS_DIR"/known-error/[0-9][0-9][0-9]-*.md \
         "$PROBLEMS_DIR"/verifying/[0-9][0-9][0-9]-*.md \
         "$PROBLEMS_DIR"/parked/[0-9][0-9][0-9]-*.md \
         "$PROBLEMS_DIR"/closed/[0-9][0-9][0-9]-*.md ; do
  TICKET_FILES+=("$f")
done

# Extract `## Reported Upstream` URL from a ticket file.
# Returns the first URL found in a `- **URL**:` line within the section.
extract_upstream_url() {
  awk '
    /^## Reported Upstream/ { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^- \*\*URL\*\*:/ {
      # Strip prefix; the URL is the first whitespace-delimited token after.
      sub(/^- \*\*URL\*\*: */, "")
      sub(/[[:space:]].*$/, "")
      print
      exit
    }
  ' "$1"
}

# Extract numeric ID prefix from a ticket file basename.
extract_ticket_id() {
  local base
  base="$(basename "$1")"
  echo "P${base%%-*}"
}

# ── Per-ticket polling loop ─────────────────────────────────────────────────

PARTIAL_FAILURE=0
POLL_COUNT=0
NEW_COUNT=0
STATE_CHANGE_COUNT=0
LABEL_CHANGE_COUNT=0
NONE_COUNT=0
FAIL_COUNT=0

declare -A SEEN_IDS

for ticket_file in "${TICKET_FILES[@]}"; do
  ticket_id="$(extract_ticket_id "$ticket_file")"

  # Filter: --ticket only processes the named ticket.
  if [ -n "$TICKET_FILTER" ] && [ "$ticket_id" != "$TICKET_FILTER" ]; then
    continue
  fi

  # Dedup: if the same ID appears via both layouts (mid-migration), per-state subdir wins.
  if [ -n "${SEEN_IDS[$ticket_id]:-}" ]; then
    if [[ "$ticket_file" != *"/"+(open|known-error|verifying|parked|closed)"/"* ]]; then
      continue
    fi
  fi
  SEEN_IDS[$ticket_id]="$ticket_file"

  upstream_url="$(extract_upstream_url "$ticket_file")"
  if [ -z "$upstream_url" ]; then
    # No upstream link — silently skip.
    continue
  fi

  POLL_COUNT=$((POLL_COUNT + 1))

  # Poll the upstream.
  if ! gh_output="$("$GH_BIN" issue view "$upstream_url" --json comments,state,labels,updatedAt 2>&1)"; then
    short_reason="$(echo "$gh_output" | head -1 | cut -c1-80)"
    printf "FAIL    %s %s reason=%s\n" "$ticket_id" "$upstream_url" "$short_reason"
    PARTIAL_FAILURE=1
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Parse upstream state.
  current_state="$(echo "$gh_output" | jq -r '.state // "UNKNOWN"')"
  current_comment_count="$(echo "$gh_output" | jq -r '.comments | length')"
  current_labels_csv="$(echo "$gh_output" | jq -r '[.labels[].name] | sort | join(",")')"
  current_updated_at="$(echo "$gh_output" | jq -r '.updatedAt // ""')"

  # Look up cache entry.
  cache_state="$(echo "$UPDATED_CACHE" | jq -r ".tickets[\"$ticket_id\"].last_seen_state // \"\"")"
  cache_comment_count="$(echo "$UPDATED_CACHE" | jq -r ".tickets[\"$ticket_id\"].last_seen_comment_count // -1")"
  cache_labels_csv="$(echo "$UPDATED_CACHE" | jq -r ".tickets[\"$ticket_id\"].last_seen_labels // [] | sort | join(\",\")")"
  cache_last_checked="$(echo "$UPDATED_CACHE" | jq -r ".tickets[\"$ticket_id\"].last_checked_at // \"\"")"

  # Decide the change class (precedence: STATE > NEW (comments) > LABEL > NONE).
  no_cache_entry=0
  if [ -z "$cache_state" ] || [ "$cache_comment_count" = "-1" ]; then
    no_cache_entry=1
  fi

  if [ "$FORCE_RECHECK" -eq 1 ] || [ "$no_cache_entry" -eq 1 ]; then
    delta="$current_comment_count"
    if [ "$no_cache_entry" -eq 0 ]; then
      delta=$((current_comment_count - cache_comment_count))
      [ "$delta" -lt 0 ] && delta=0
    fi
    printf "NEW     %s %s state=%s new-comments=%s\n" "$ticket_id" "$upstream_url" "$current_state" "$delta"
    NEW_COUNT=$((NEW_COUNT + 1))
  elif [ "$current_state" != "$cache_state" ]; then
    printf "STATE   %s %s state=%s→%s\n" "$ticket_id" "$upstream_url" "$cache_state" "$current_state"
    STATE_CHANGE_COUNT=$((STATE_CHANGE_COUNT + 1))
  elif [ "$current_comment_count" -ne "$cache_comment_count" ]; then
    delta=$((current_comment_count - cache_comment_count))
    [ "$delta" -lt 0 ] && delta=0
    printf "NEW     %s %s state=%s new-comments=%s\n" "$ticket_id" "$upstream_url" "$current_state" "$delta"
    NEW_COUNT=$((NEW_COUNT + 1))
  elif [ "$current_labels_csv" != "$cache_labels_csv" ]; then
    # Compute labels added/removed.
    added="$(comm -13 <(echo "$cache_labels_csv" | tr ',' '\n' | sort) <(echo "$current_labels_csv" | tr ',' '\n' | sort) | grep -v '^$' | paste -sd',' -)"
    removed="$(comm -23 <(echo "$cache_labels_csv" | tr ',' '\n' | sort) <(echo "$current_labels_csv" | tr ',' '\n' | sort) | grep -v '^$' | paste -sd',' -)"
    printf "LABEL   %s %s labels-added=%s labels-removed=%s\n" "$ticket_id" "$upstream_url" "$added" "$removed"
    LABEL_CHANGE_COUNT=$((LABEL_CHANGE_COUNT + 1))
  else
    printf "NONE    %s %s no-change-since=%s\n" "$ticket_id" "$upstream_url" "$cache_last_checked"
    NONE_COUNT=$((NONE_COUNT + 1))
  fi

  # Update cache entry for this ticket.
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  UPDATED_CACHE="$(echo "$UPDATED_CACHE" | jq \
    --arg id "$ticket_id" \
    --arg url "$upstream_url" \
    --arg state "$current_state" \
    --arg checked "$now_iso" \
    --arg updated "$current_updated_at" \
    --argjson count "$current_comment_count" \
    --argjson labels "$(echo "$gh_output" | jq '[.labels[].name] | sort')" \
    '.tickets[$id] = {
      upstream_url: $url,
      last_checked_at: $checked,
      last_seen_state: $state,
      last_seen_comment_count: $count,
      last_seen_labels: $labels,
      last_seen_updated_at: $updated
    }')"
done

# ── Flush cache + append audit-log ──────────────────────────────────────────

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UPDATED_CACHE="$(echo "$UPDATED_CACHE" | jq --arg now "$NOW_ISO" '.last_checked = $now')"

# Ensure cache file parent dir exists.
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$UPDATED_CACHE" | jq . > "$CACHE_FILE"

# Append audit-log entry.
mkdir -p "$(dirname "$AUDIT_LOG")"
if [ ! -f "$AUDIT_LOG" ]; then
  cat > "$AUDIT_LOG" <<'EOF'
# Outbound upstream-response check — audit log

> Forward-chronology audit trail of `/wr-itil:check-upstream-responses` passes (P249 Phase 1). Each pass appends a `## YYYY-MM-DDTHH:MM:SSZ` heading with tickets polled, response classes observed, and cache refresh confirmation. Mirrors `docs/audits/inbound-discovery-log.md` shape per ADR-062's audit-log surface contract.
>
> Path is intentional per CLAUDE.md P131 — project-generated artefacts go under `docs/`, never `.claude/`.

EOF
fi

{
  echo ""
  echo "## ${NOW_ISO} — Outbound response check pass"
  echo ""
  echo "- Tickets polled: ${POLL_COUNT}"
  echo "- New responses: ${NEW_COUNT}"
  echo "- State changes: ${STATE_CHANGE_COUNT}"
  echo "- Label changes: ${LABEL_CHANGE_COUNT}"
  echo "- No changes: ${NONE_COUNT}"
  echo "- Poll failures: ${FAIL_COUNT}"
  echo "- Cache: ${CACHE_FILE}"
  echo "- Force recheck: $([ "$FORCE_RECHECK" -eq 1 ] && echo "yes" || echo "no")"
  if [ -n "$TICKET_FILTER" ]; then
    echo "- Filter: ${TICKET_FILTER}"
  fi
} >> "$AUDIT_LOG"

if [ "$PARTIAL_FAILURE" -eq 1 ]; then
  exit 2
fi
exit 0
