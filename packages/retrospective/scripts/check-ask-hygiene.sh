#!/usr/bin/env bash
# packages/retrospective/scripts/check-ask-hygiene.sh
#
# Diagnose-only advisory script for the ask-hygiene trail (per Step 2d
# in run-retro, ADR-044 / P135 Phase 5). Walks docs/retros/*-ask-hygiene.md
# trail files, extracts the lazy AskUserQuestion count from each, and
# emits a tabular trend over the last N retros so the user can see
# whether ADR-044's framework-resolution boundary is taking hold.
#
# Usage:
#   check-ask-hygiene.sh [<retros-dir>]
#
# Default <retros-dir> is ./docs/retros.
# Window is read from ASK_HYGIENE_WINDOW (default 10 — last N retros).
#
# Exit codes:
#   0 = always (advisory only — count is signal, not failure)
#   2 = parse error (retros dir missing or unreadable)
#
# Output format on populated trail (one line per retro, oldest first):
#   RETRO <YYYY-MM-DD> lazy=<N> direction=<N> override=<N> silent=<N> taste=<N> correction=<N>
#
# Plus a trailing TREND line summarising first vs last lazy count
# (when 2+ entries are in the window):
#   TREND lazy_first=<N> lazy_last=<N> delta=<+|-N>
#
# Output is empty (no lines) when no retro trail entries are found —
# this is the expected first-run state, not an error.
#
# Trail file shape (per Step 2d contract — written by run-retro):
#   docs/retros/<YYYY-MM-DD>-ask-hygiene.md
#
# Each trail file MUST contain a single line of the shape:
#   `Lazy count: <N>` (case-insensitive; allows a leading `**` for bold)
#
# And SHOULD contain matching counts for each non-lazy category:
#   `Direction count: <N>`
#   `Override count: <N>`
#   `Silent-framework count: <N>`
#   `Taste count: <N>`
#   `Correction-followup count: <N>`
#
# The script tolerates missing non-lazy categories (defaults to 0).
# The lazy-count line is the only required field; without it the file
# is skipped silently.
#
# ADR-074 exclusion: a substance-confirm-before-build ask (confirming the
# SUBSTANTIVE chosen option of a genuine >=2-option decision before dependent
# work is built on it) is classified `Direction` (cat-1) by run-retro Step 2d,
# NOT `Lazy`. The framework deliberately does not resolve such a decision, so
# the ask is legitimate. This script is category-agnostic — it tallies whatever
# the trail file records — so the exclusion is realised by the Step 2d rubric
# tagging the ask as Direction; this script then keeps it out of the lazy count
# by construction.
#
# Read-only — does NOT mutate any retro file.
#
# @problem P135 (Phase 5 measurement)
# @adr ADR-044 (Decision-Delegation Contract — framework-resolution boundary; lazy-count metric is the regression signal)
# @adr ADR-074 (Confirm-substance-before-build — substance-confirm asks are Direction/cat-1, excluded from the lazy count)
# @adr ADR-040 (Tier 3 advisory-not-fail-closed — declarative-first precedent)
# @adr ADR-038 (Progressive disclosure — per-row byte budget)
# @adr ADR-026 (Cost-source grounding — trail entries cite specific tool invocations per retro)
# @adr ADR-013 Rule 5 (Policy-authorised silent proceed — script proceeds silently per ADR-040 advisory pattern)
# @adr ADR-005 (Plugin testing strategy)
# @jtbd JTBD-001 / JTBD-006 / JTBD-201

set -uo pipefail

RETROS_DIR="${1:-docs/retros}"
WINDOW="${ASK_HYGIENE_WINDOW:-10}"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -d "$RETROS_DIR" ]; then
  echo "check-ask-hygiene: retros dir not found: $RETROS_DIR" >&2
  exit 2
fi

# ── Scan ────────────────────────────────────────────────────────────────────
# Iterate ask-hygiene trail files at the top level of RETROS_DIR.
# Glob expansion uses an existence-check loop for cross-shell portability
# (P124 lesson — bash's `shopt -s nullglob` fails on zsh).

trail_files=()
for path in "$RETROS_DIR"/*-ask-hygiene.md; do
  [ -e "$path" ] || continue
  trail_files+=("$path")
done

if [ "${#trail_files[@]}" -eq 0 ]; then
  exit 0
fi

# Sort by basename (which starts with the YYYY-MM-DD date prefix), oldest first
IFS=$'\n' sorted_files=($(printf '%s\n' "${trail_files[@]}" | sort))
unset IFS

# Apply the window — keep only the last N entries (most-recent N)
total="${#sorted_files[@]}"
if [ "$total" -gt "$WINDOW" ]; then
  start=$(( total - WINDOW ))
  windowed=("${sorted_files[@]:$start}")
else
  windowed=("${sorted_files[@]}")
fi

# Extract counts per file
extract_count() {
  local path="$1"
  local label="$2"
  local default="${3:-0}"
  # Match lines like "Lazy count: 5" or "**Lazy count: 5**" (case-insensitive).
  # Markdown bold is an enclosing pair, so leading **<text>: <N>** has the
  # trailing ** AFTER the number, not after the label.
  local match
  match=$(grep -iE "^\*{0,2}$label count:[[:space:]]+[0-9]+" "$path" 2>/dev/null \
    | head -1 \
    | grep -oE '[0-9]+' \
    | head -1)
  if [ -z "$match" ]; then
    echo "$default"
  else
    echo "$match"
  fi
}

extract_date() {
  local basename
  basename="$(basename "$1")"
  # Strip the -ask-hygiene.md suffix; what remains is the YYYY-MM-DD prefix
  echo "${basename%-ask-hygiene.md}"
}

# Emit per-retro lines
declare -a lazy_counts=()
for path in "${windowed[@]}"; do
  date=$(extract_date "$path")
  # Lazy count is required (no default); if missing, skip the file silently.
  # Inline rather than calling extract_count() because its `local default=...`
  # falls back to "0" on empty (bash `${3:-0}` semantics), which would
  # mask the "no lazy line" case.
  lazy=$(grep -iE "^\*{0,2}Lazy count:[[:space:]]+[0-9]+" "$path" 2>/dev/null \
    | head -1 \
    | grep -oE '[0-9]+' \
    | head -1)
  if [ -z "$lazy" ]; then
    continue
  fi
  # Other categories default to 0 if the trail entry omits them
  direction=$(extract_count "$path" "Direction" "0")
  override=$(extract_count "$path" "Override" "0")
  silent=$(extract_count "$path" "Silent-framework" "0")
  taste=$(extract_count "$path" "Taste" "0")
  correction=$(extract_count "$path" "Correction-followup" "0")
  echo "RETRO $date lazy=$lazy direction=$direction override=$override silent=$silent taste=$taste correction=$correction"
  lazy_counts+=("$lazy")
done

# Emit trend line when 2+ entries are in the window
if [ "${#lazy_counts[@]}" -ge 2 ]; then
  first="${lazy_counts[0]}"
  last="${lazy_counts[${#lazy_counts[@]}-1]}"
  delta=$(( last - first ))
  if [ "$delta" -ge 0 ]; then
    delta_s="+$delta"
  else
    delta_s="$delta"
  fi
  echo "TREND lazy_first=$first lazy_last=$last delta=$delta_s"
fi

exit 0
