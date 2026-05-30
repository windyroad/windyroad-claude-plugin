#!/usr/bin/env bash
# wr-jtbd — detect jobs/personas lacking the human-oversight marker (ADR-068)
#
# @jtbd JTBD-202 (Run Pre-Flight Governance Checks — oversight state of the JTBD corpus)
# @jtbd JTBD-101 (Extend the Suite with New Plugins — reusable adopter-portable primitive)
#
# Sibling of packages/architect/scripts/detect-unoversighted.sh (ADR-066). Token-cheap:
# greps each job/persona's YAML frontmatter for `human-oversight: confirmed`. No body
# reads, no per-file LLM call. A file is "unoversighted" when its frontmatter does not
# carry that marker (or has no frontmatter).
#
# Usage:
#   detect-unoversighted.sh [JTBD_DIR]
#     JTBD_DIR defaults to docs/jtbd
#
# Output: one unoversighted job/persona file path per line, sorted. Empty output = the
# whole set is confirmed. Always exits 0 (it is a detector, not a gate).
#
# Consumed by: jtbd-oversight-nudge.sh (SessionStart count) and
# /wr-jtbd:confirm-jobs-and-personas (the drain list). Marker contract: ADR-068 (= ADR-066 field).

set -euo pipefail

JTBD_DIR="${1:-docs/jtbd}"
[ -d "$JTBD_DIR" ] || exit 0

# JTBD layout (ADR-008): docs/jtbd/<persona>/persona.md + docs/jtbd/<persona>/JTBD-NNN-*.md,
# with docs/jtbd/README.md as the top-level index. Match the per-persona files; README is
# never a job/persona record.
shopt -s nullglob
for f in "$JTBD_DIR"/*/*.md "$JTBD_DIR"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "README.md" ] && continue
  # Superseded artifacts (if an adopter uses a .superseded.md suffix) are retired.
  case "$base" in *.superseded.md) continue ;; esac

  fm="$(awk '
    NR==1 && $0 != "---" { exit }
    NR==1 { next }
    /^---[[:space:]]*$/ { exit }
    { print }
  ' "$f")"

  if printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*confirmed[[:space:]]*$'; then
    continue
  fi

  # ADR-068 amendment (P316): mirror the architect detector's
  # rejected-pending-supersede exclusion. Both the marker AND a
  # supersede-ticket: P<NNN> scalar must be present; an un-ticketed marker
  # still surfaces (defensive — preserves JTBD-201/202 audit-trail guard).
  if printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*rejected-pending-supersede[[:space:]]*$' \
     && printf '%s\n' "$fm" | grep -qiE '^supersede-ticket:[[:space:]]*P[0-9]+[[:space:]]*$'; then
    continue
  fi

  echo "$f"
done | sort
