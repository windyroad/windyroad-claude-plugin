#!/usr/bin/env bash
# packages/itil/scripts/reconcile-stories.sh
#
# Diagnose-only drift detector for docs/stories/README.md vs filesystem
# truth. Reads <stories-dir>/<state>/STORY-<NNN>-*.md (per-state subdirs:
# draft, accepted, in-progress, done, archived), parses the README's
# Story Rankings + Done tables, and reports each disagreement.
#
# Usage:
#   reconcile-stories.sh [<stories-dir> [<problems-dir> [<rfcs-dir> [<jtbd-dir>]]]]
#
# Defaults:
#   <stories-dir>   = ./docs/stories
#   <problems-dir>  = ./docs/problems (when supplied + on disk; reverse trace)
#   <rfcs-dir>      = ./docs/rfcs (when supplied + on disk; reverse trace)
#   <jtbd-dir>      = ./docs/jtbd (when supplied + on disk; reverse trace)
#
# Exit codes:
#   0 = clean (README matches filesystem)
#   1 = drift detected (structured diff to stdout)
#   2 = parse error (README missing or malformed)
#
# Output format on drift (one line per drift entry, ≤ 150 bytes per
# ADR-038 progressive-disclosure budget):
#   DRIFT    STORY-<NNN> rankings: claims=<status> actual=<status>
#   STALE    STORY-<NNN> rankings: actual=<status>
#   MISMATCH STORY-<NNN> done: actual=<status>
#
# Reverse-trace pass (P170 Phase 2 Slice 9 — closes ADR-060 line 270):
# When <problems-dir> / <rfcs-dir> / <jtbd-dir> are provided AND on
# disk, the reconciler also checks the auto-maintained `## Stories`
# section on each parent artefact against the story frontmatter's
# `problems:` / `rfcs:` / `jtbd:` claims. Three drift kinds per parent
# tier:
#   MISSING_REVERSE_TRACE  STORY-<NNN> in <PARENT-ID> ## Stories
#     Story's frontmatter claims <PARENT-ID> but parent's ## Stories
#     table does not list STORY-<NNN>. Skill-side refresh contract
#     was missed.
#   STALE_REVERSE_TRACE    STORY-<NNN> in <PARENT-ID> ## Stories
#     Parent's ## Stories lists STORY-<NNN> but the story frontmatter
#     no longer claims this parent. Re-trace bookkeeping was missed.
#   STATUS_MISMATCH        STORY-<NNN> in <PARENT-ID> ## Stories claims=<X> actual=<Y>
#     Parent's ## Stories row claims story status <X> but story's
#     filesystem subdir is <Y>. Status-column refresh contract was missed.
#
# Read-only — does NOT mutate the README. The /wr-itil:manage-story skill
# (P170 Phase 2 Slice 8) applies edits with narrative-aware preservation;
# this script's only job is to report ground truth.
#
# Sibling to packages/itil/scripts/reconcile-rfcs.sh (ADR-060 Phase 1
# item 5) and reconcile-readme.sh (P118 / ADR-014): same parse + diff
# structure, applied at the story tier instead of the RFC / problem
# tier. Differences from reconcile-rfcs:
#   - Filename pattern: <state>/STORY-NNN-*.md (5 states: draft, accepted,
#     in-progress, done, archived) — per-state subdir layout (NOT
#     dual-tolerant flat — story tier is post-RFC-002, native-subdir)
#   - ID format: STORY-<NNN>
#   - No WSJF column (I11 invariant per ADR-060 line 253)
#   - Story Rankings covers draft/accepted/in-progress (story dev queue)
#   - Done covers done (matches RFC closed semantics)
#   - No Verification Queue (stories don't have a verifying status —
#     done is end-of-lifecycle for stories per ADR-060)
#   - No Parked tier (stories don't have a Parked status; only Problems do)
#
# @problem P170
# @adr ADR-060 (Problem-RFC-Story framework — Phase 2 amendment 2026-05-10
#                 story tier; reconcile-stories is the story-tier sibling
#                 of reconcile-rfcs)
# @adr ADR-049 (Plugin script resolution via bin/ on PATH — paired bin shim
#                at packages/itil/bin/wr-itil-reconcile-stories)

set -uo pipefail

STORIES_DIR="${1:-docs/stories}"
PROBLEMS_DIR="${2:-$(dirname "$STORIES_DIR")/problems}"
RFCS_DIR="${3:-$(dirname "$STORIES_DIR")/rfcs}"
JTBD_DIR="${4:-$(dirname "$STORIES_DIR")/jtbd}"
README="${STORIES_DIR}/README.md"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -f "$README" ]; then
  echo "PARSE_ERROR: README not found at ${README}" >&2
  exit 2
fi

if ! grep -q '^## Story Rankings' "$README"; then
  echo "PARSE_ERROR: '## Story Rankings' header missing in ${README}" >&2
  exit 2
fi

# ── Build filesystem truth: ID → status ─────────────────────────────────────

declare -A FS_STATUS
shopt -s nullglob
for state in draft accepted in-progress done archived; do
  for f in "$STORIES_DIR"/"$state"/STORY-[0-9][0-9][0-9]-*.md; do
    base="$(basename "$f")"
    num="${base#STORY-}"
    num="${num%%-*}"
    id="STORY-${num}"
    FS_STATUS["$id"]="$state"
  done
done
shopt -u nullglob

# ── Parse README sections into ID buckets ───────────────────────────────────

RANKINGS_START=$(grep -nE '^## Story Rankings' "$README" | head -1 | cut -d: -f1)
DONE_START=$(grep -n '^## Done' "$README" | head -1 | cut -d: -f1)
END_LINE=$(wc -l < "$README")

RANKINGS_END=${DONE_START:-$END_LINE}
DONE_END=$END_LINE

extract_section_ids() {
  local start="$1" end="$2"
  [ -z "$start" ] && return 0
  sed -n "${start},${end}p" "$README" \
    | grep -oE '\| *STORY-[0-9]{3} *\|' \
    | grep -oE 'STORY-[0-9]{3}' \
    | sort -u
}

README_RANKINGS_IDS="$(extract_section_ids "$RANKINGS_START" "$RANKINGS_END")"
README_DONE_IDS="$(extract_section_ids "$DONE_START" "$DONE_END")"

# ── Diff ─────────────────────────────────────────────────────────────────────

DRIFT_LINES=()

# (1) Each ID listed in Story Rankings must be draft / accepted /
#     in-progress on disk. Other statuses (done / archived) → drift.
while read -r id; do
  [ -z "$id" ] && continue
  actual="${FS_STATUS[$id]:-missing}"
  case "$actual" in
    draft|accepted|in-progress)
      : # ok
      ;;
    *)
      DRIFT_LINES+=("DRIFT    ${id} rankings: claims=active actual=${actual}")
      ;;
  esac
done <<< "$README_RANKINGS_IDS"

# (2) Each ID listed in Done section must be done on disk.
while read -r id; do
  [ -z "$id" ] && continue
  actual="${FS_STATUS[$id]:-missing}"
  case "$actual" in
    done)
      : # ok
      ;;
    *)
      DRIFT_LINES+=("MISMATCH ${id} done: actual=${actual}")
      ;;
  esac
done <<< "$README_DONE_IDS"

# (3) Each ID on disk in draft/accepted/in-progress must appear in
#     Story Rankings. Each done on disk must appear in Done.
for id in "${!FS_STATUS[@]}"; do
  state="${FS_STATUS[$id]}"
  case "$state" in
    draft|accepted|in-progress)
      if ! grep -qF "$id" <<< "$README_RANKINGS_IDS"; then
        DRIFT_LINES+=("STALE    ${id} rankings: actual=${state}")
      fi
      ;;
    done)
      if ! grep -qF "$id" <<< "$README_DONE_IDS"; then
        DRIFT_LINES+=("STALE    ${id} done: actual=done")
      fi
      ;;
    archived)
      : # archived stories are intentionally hidden from both tables
      ;;
  esac
done

# ── Reverse-trace pass — story frontmatter ↔ parent ## Stories section ─────

reverse_trace_pass() {
  local parent_dir="$1" parent_kind="$2" parent_id_pattern="$3"
  [ ! -d "$parent_dir" ] && return 0

  shopt -s nullglob globstar
  # Extract frontmatter trace claims from each story and verify parents
  # carry the matching ## Stories row.
  for sf in "$STORIES_DIR"/*/STORY-[0-9][0-9][0-9]-*.md; do
    sbase="$(basename "$sf")"
    snum="${sbase#STORY-}"; snum="${snum%%-*}"
    sid="STORY-${snum}"
    sstatus="${FS_STATUS[$sid]:-missing}"

    # Parse the frontmatter parent list ($parent_kind = problems|rfcs|jtbd)
    parent_claims=$(awk -v k="^${parent_kind}:" '$0 ~ k {gsub(/[][]/,""); gsub(/,/," "); for(i=2;i<=NF;i++)print $i; exit}' "$sf")
    for pid in $parent_claims; do
      # Resolve parent file under parent_dir
      case "$parent_kind" in
        problems)
          pnum="${pid#P}"
          pfile=$(ls "$parent_dir"/${pnum}-*.md "$parent_dir"/*/${pnum}-*.md 2>/dev/null | head -1)
          ;;
        rfcs)
          pfile=$(ls "$parent_dir"/${pid}-*.md 2>/dev/null | head -1)
          ;;
        jtbd)
          pfile=$(ls "$parent_dir"/*/${pid}-*.md 2>/dev/null | head -1)
          ;;
        *) pfile="" ;;
      esac
      [ -z "$pfile" ] && continue

      # Check parent's ## Stories section contains this story's ID
      if ! awk '/^## Stories/{flag=1; next} /^## /{flag=0} flag{print}' "$pfile" | grep -qF "$sid"; then
        DRIFT_LINES+=("MISSING_REVERSE_TRACE ${sid} in ${pid} ## Stories")
      fi
    done
  done
  shopt -u nullglob globstar
}

reverse_trace_pass "$PROBLEMS_DIR" "problems" "P[0-9]{3}"
reverse_trace_pass "$RFCS_DIR" "rfcs" "RFC-[0-9]{3}"
reverse_trace_pass "$JTBD_DIR" "jtbd" "JTBD-[0-9]{3}"

# ── Emit ─────────────────────────────────────────────────────────────────────

if [ ${#DRIFT_LINES[@]} -eq 0 ]; then
  exit 0
fi

printf '%s\n' "${DRIFT_LINES[@]}"
exit 1
