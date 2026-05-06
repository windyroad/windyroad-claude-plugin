#!/usr/bin/env bash
# packages/itil/scripts/reconcile-readme.sh
#
# Diagnose-only drift detector for docs/problems/README.md vs filesystem
# truth. Reads ticket files from BOTH the flat layout
# `<problems-dir>/<NNN>-*.<status>.md` AND the per-state subdir layout
# `<problems-dir>/<status>/<NNN>-*.md` (RFC-002 dual-tolerant migration
# window), parses the README's WSJF Rankings + Verification Queue +
# Closed tables, and reports each disagreement.
#
# Usage:
#   reconcile-readme.sh [<problems-dir>]
#
# Default <problems-dir> is ./docs/problems.
#
# Dual-layout precedence: when the same ID appears in both layout-halves
# (transient mid-migration race between `git mv` and README refresh),
# the per-state subdir wins — ADR-031 §"Authoritative state signal"
# treats subdirectory as the post-migration ground truth.
#
# Exit codes:
#   0 = clean (README matches filesystem)
#   1 = drift detected (structured diff to stdout)
#   2 = parse error (README missing or malformed)
#
# Output format on drift (one line per drift entry, ≤ 150 bytes per
# ADR-038 progressive-disclosure budget):
#   DRIFT    <ID> wsjf-rankings: claims=<status> actual=<status>
#   MISSING  <ID> wsjf-rankings: actual=<status> file=<basename>
#   STALE    <ID> verification-queue: actual=<status>
#   MISMATCH <ID> closed: actual=<status>
#
# Read-only — does NOT mutate the README. The /wr-itil:reconcile-readme
# skill applies edits with narrative-aware preservation; this script's
# only job is to report ground truth.
#
# @problem P118
# @problem P170 (RFC-002 — dual-tolerant migration window)
# @adr ADR-014 (Reconciliation as preflight robustness layer)
# @adr ADR-022 (Verification Pending lifecycle excludes from WSJF Rankings)
# @adr ADR-031 (Per-state subdir is post-migration authoritative state signal)
# @adr ADR-038 (Progressive disclosure — per-row byte budget)

set -uo pipefail

PROBLEMS_DIR="${1:-docs/problems}"
README="${PROBLEMS_DIR}/README.md"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -f "$README" ]; then
  echo "PARSE_ERROR: README not found at ${README}" >&2
  exit 2
fi

if ! grep -q '^## WSJF Rankings' "$README"; then
  echo "PARSE_ERROR: '## WSJF Rankings' header missing in ${README}" >&2
  exit 2
fi

# ── Build filesystem truth: ID → status ─────────────────────────────────────
#
# RFC-002 dual-tolerant enumeration: walk BOTH the flat layout and the
# per-state subdir layout. Per-state subdir wins on collision (mid-
# migration race; per-state is the migration target per ADR-031).

declare -A FS_STATUS
shopt -s nullglob
# Flat layout: docs/problems/<NNN>-<title>.<state>.md
# Status classified from filename suffix.
for f in "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.open.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.known-error.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.verifying.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.closed.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.parked.md; do
  base="$(basename "$f")"
  num="${base%%-*}"
  id="P${num}"
  # `ticket_status` (not bash `status`) — zsh has `$status` as a read-only
  # built-in mapping to `$?`. Defensive rename per P133 even though this
  # script's `#!/usr/bin/env bash` shebang means it never runs under zsh.
  case "$base" in
    *.open.md)         ticket_status="open" ;;
    *.known-error.md)  ticket_status="known-error" ;;
    *.verifying.md)    ticket_status="verifying" ;;
    *.closed.md)       ticket_status="closed" ;;
    *.parked.md)       ticket_status="parked" ;;
    *)                 continue ;;
  esac
  FS_STATUS["$id"]="$ticket_status"
done
# Per-state subdir layout: docs/problems/<state>/<NNN>-<title>.md
# Status derived from parent directory name (the subdirectory IS the
# state signal post-migration). Writes after the flat loop so per-state
# wins on cross-layout ID collision (ADR-031 authoritative state).
for ticket_status in open known-error verifying closed parked; do
  for f in "$PROBLEMS_DIR"/"$ticket_status"/[0-9][0-9][0-9]-*.md; do
    base="$(basename "$f")"
    num="${base%%-*}"
    id="P${num}"
    FS_STATUS["$id"]="$ticket_status"
  done
done
shopt -u nullglob

# ── Parse README sections into ID buckets ───────────────────────────────────
# We use the section-header line numbers to slice the file into ranges.

WSJF_START=$(grep -n '^## WSJF Rankings' "$README" | head -1 | cut -d: -f1)
VQ_START=$(grep -n '^## Verification Queue' "$README" | head -1 | cut -d: -f1)
CLOSED_START=$(grep -n '^## Closed' "$README" | head -1 | cut -d: -f1)
PARKED_START=$(grep -n '^## Parked' "$README" | head -1 | cut -d: -f1)
END_LINE=$(wc -l < "$README")

# Sentinel each end with the next section start (or EOF).
WSJF_END=${VQ_START:-${CLOSED_START:-${PARKED_START:-$END_LINE}}}
VQ_END=${CLOSED_START:-${PARKED_START:-$END_LINE}}
CLOSED_END=${PARKED_START:-$END_LINE}
PARKED_END=$END_LINE

# Extract IDs claimed by each section. Only data rows of the form
#   | ... | P<NNN> | ... |
# count; header + separator rows are skipped naturally because they
# do not contain a P<NNN> token in the second column.

extract_section_ids() {
  local start="$1" end="$2"
  [ -z "$start" ] && return 0
  sed -n "${start},${end}p" "$README" \
    | grep -oE '\| *P[0-9]{3} *\|' \
    | grep -oE 'P[0-9]{3}' \
    | sort -u
}

README_WSJF_IDS="$(extract_section_ids "$WSJF_START" "$WSJF_END")"
README_VQ_IDS="$(extract_section_ids "$VQ_START" "$VQ_END")"
README_CLOSED_IDS="$(extract_section_ids "$CLOSED_START" "$CLOSED_END")"
README_PARKED_IDS="$(extract_section_ids "$PARKED_START" "$PARKED_END")"

# ── Diff ─────────────────────────────────────────────────────────────────────

DRIFT_LINES=()

# (1) Each ID listed in WSJF Rankings must be .open.md or .known-error.md
#     on disk. .verifying.md → drift (belongs in VQ); .closed.md → drift;
#     .parked.md → drift; missing → drift.
while read -r id; do
  [ -z "$id" ] && continue
  actual="${FS_STATUS[$id]:-missing}"
  case "$actual" in
    open|known-error)
      : # ok
      ;;
    *)
      DRIFT_LINES+=("DRIFT    ${id} wsjf-rankings: claims=open actual=${actual}")
      ;;
  esac
done <<< "$README_WSJF_IDS"

# (2) Each ID listed in Verification Queue must be .verifying.md on disk.
#     .closed.md → STALE (drift class P062 closure didn't refresh);
#     .open.md / .known-error.md → STALE; missing → STALE.
while read -r id; do
  [ -z "$id" ] && continue
  actual="${FS_STATUS[$id]:-missing}"
  case "$actual" in
    verifying)
      : # ok
      ;;
    *)
      DRIFT_LINES+=("STALE    ${id} verification-queue: actual=${actual}")
      ;;
  esac
done <<< "$README_VQ_IDS"

# (3) Each ID listed in Closed section must be .closed.md on disk.
while read -r id; do
  [ -z "$id" ] && continue
  actual="${FS_STATUS[$id]:-missing}"
  case "$actual" in
    closed)
      : # ok
      ;;
    *)
      DRIFT_LINES+=("MISMATCH ${id} closed: actual=${actual}")
      ;;
  esac
done <<< "$README_CLOSED_IDS"

# (4) Each .open.md / .known-error.md file on disk must appear in WSJF
#     Rankings. Build a lookup set for quick membership tests.
declare -A IN_WSJF
while read -r id; do
  [ -z "$id" ] && continue
  IN_WSJF["$id"]=1
done <<< "$README_WSJF_IDS"

declare -A IN_VQ
while read -r id; do
  [ -z "$id" ] && continue
  IN_VQ["$id"]=1
done <<< "$README_VQ_IDS"

for id in "${!FS_STATUS[@]}"; do
  ticket_status="${FS_STATUS[$id]}"
  case "$ticket_status" in
    open|known-error)
      if [ -z "${IN_WSJF[$id]:-}" ]; then
        DRIFT_LINES+=("MISSING  ${id} wsjf-rankings: actual=${ticket_status}")
      fi
      ;;
    verifying)
      if [ -z "${IN_VQ[$id]:-}" ]; then
        DRIFT_LINES+=("MISSING  ${id} verification-queue: actual=${ticket_status}")
      fi
      ;;
    # closed and parked: not required to appear in their respective
    # sections (Closed is curated narrative; Parked is exhaustive but
    # an absence is a soft drift not flagged at this layer).
  esac
done

# ── Report ──────────────────────────────────────────────────────────────────

if [ ${#DRIFT_LINES[@]} -eq 0 ]; then
  exit 0
fi

# Sort for stable output (ID order).
IFS=$'\n' sorted=($(printf '%s\n' "${DRIFT_LINES[@]}" | sort))
unset IFS
for line in "${sorted[@]}"; do
  printf '%s\n' "$line"
done
exit 1
