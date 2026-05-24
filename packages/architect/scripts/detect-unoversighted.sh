#!/usr/bin/env bash
# wr-architect — detect ADRs lacking the human-oversight marker (ADR-066)
#
# Token-cheap detection: greps each ADR's YAML frontmatter for the presence of
# `human-oversight: confirmed`. No body reads, no per-ADR LLM call. An ADR is
# "unoversighted" when its frontmatter does not carry that marker line (or has
# no frontmatter at all).
#
# Usage:
#   detect-unoversighted.sh [DECISIONS_DIR]
#     DECISIONS_DIR defaults to docs/decisions
#
# Output: one unoversighted ADR file path per line, sorted. Empty output = the
# whole set is confirmed. Callers derive the count with `grep -c .` / `wc -l`.
# Always exits 0 (it is a detector, not a gate).
#
# Consumed by: architect-oversight-nudge.sh (SessionStart count) and
# /wr-architect:review-decisions (the drain list). Marker contract: ADR-066.

set -euo pipefail

DECISIONS_DIR="${1:-docs/decisions}"

[ -d "$DECISIONS_DIR" ] || exit 0

# Match both the flat layout (docs/decisions/*.md) and any per-state subdir
# layout an adopter might introduce later (docs/decisions/*/*.md). README is
# never a decision record.
shopt -s nullglob
for f in "$DECISIONS_DIR"/*.md "$DECISIONS_DIR"/*/*.md; do
  base="$(basename "$f")"
  [ "$base" = "README.md" ] && continue
  # Superseded decisions are retired — a newer ADR replaced them. Confirming a
  # dead decision has no value, so they are not part of the "needs oversight"
  # set (keeps the nudge count and the drain queue focused on live decisions).
  case "$base" in *.superseded.md) continue ;; esac

  # Extract the frontmatter block: lines between the leading `---` and the
  # next `---`. If line 1 is not `---`, the file has no frontmatter and the
  # awk prints nothing → treated as unoversighted.
  fm="$(awk '
    NR==1 && $0 != "---" { exit }
    NR==1 { next }
    /^---[[:space:]]*$/ { exit }
    { print }
  ' "$f")"

  if ! printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*confirmed[[:space:]]*$'; then
    echo "$f"
  fi
done | sort
