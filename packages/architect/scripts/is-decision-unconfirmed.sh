#!/usr/bin/env bash
# wr-architect — predicate: is a referenced decision unconfirmed? (ADR-074)
#
# Single-ADR sibling of detect-unoversighted.sh (ADR-066). Where the detector
# LISTS the whole unoversighted set and always exits 0, this answers ONE
# question for ONE ADR via its EXIT CODE — for the ADR-074 build-upon guard at
# the propose-fix surface (/wr-itil:manage-problem + /wr-itil:work-problems).
# A separate script (not a mode flag on the detector) keeps the detector's
# "always exit 0, path-list on stdout" contract intact (architect verdict
# 2026-05-27).
#
# "Unconfirmed" mirrors detect-unoversighted.sh EXACTLY:
#   - the ADR's frontmatter lacks `human-oversight: confirmed`, AND
#   - the ADR is not superseded.
# CANONICAL SHAPE: detect-unoversighted.sh. Keep the frontmatter-extraction
# awk block + the `human-oversight: confirmed` grep + the superseded skip in
# sync with that script. The `@test "agrees with detect-unoversighted ..."`
# case in test/is-decision-unconfirmed.bats fails if these two drift.
#
# Usage:
#   is-decision-unconfirmed.sh <adr-ref> [DECISIONS_DIR]
#     <adr-ref> = ADR-NNN | NNN | path/to/NNN-title.<state>.md
#     DECISIONS_DIR defaults to docs/decisions
#
# Exit codes:
#   0 = unconfirmed — the build-upon guard SHOULD fire. Prints the resolved path.
#   1 = confirmed OR superseded — guard should NOT fire. No stdout.
#   2 = not found / unparseable ref. No stdout; reason on stderr.

set -uo pipefail

REF="${1:-}"
DECISIONS_DIR="${2:-docs/decisions}"

[ -n "$REF" ] || { echo "is-decision-unconfirmed: missing <adr-ref>" >&2; exit 2; }

# ── Resolve the ADR file ──────────────────────────────────────────────────
file=""
if [ -f "$REF" ]; then
  file="$REF"
else
  # Extract the leading numeric ID from ADR-NNN / NNN.
  num="$(printf '%s' "$REF" | grep -oE '[0-9]+' | head -1)"
  [ -n "$num" ] || { echo "is-decision-unconfirmed: cannot parse ADR id from '$REF'" >&2; exit 2; }
  # Match flat (docs/decisions/NNN-*.md) + per-state subdir (docs/decisions/*/NNN-*.md)
  # layouts; first match wins.
  shopt -s nullglob
  for cand in "$DECISIONS_DIR"/"$num"-*.md "$DECISIONS_DIR"/*/"$num"-*.md; do
    file="$cand"; break
  done
  shopt -u nullglob
fi

[ -n "$file" ] && [ -f "$file" ] || {
  echo "is-decision-unconfirmed: no decision file for '$REF' under $DECISIONS_DIR" >&2
  exit 2
}

base="$(basename "$file")"

# Superseded decisions are retired — a newer ADR replaced them. The build-upon
# guard does not fire (mirror of detect-unoversighted.sh's superseded skip).
case "$base" in *.superseded.md) exit 1 ;; esac

# Extract the frontmatter block (mirror of detect-unoversighted.sh): lines
# between the leading `---` and the next `---`. No leading `---` ⇒ no
# frontmatter ⇒ treated as unconfirmed.
fm="$(awk '
  NR==1 && $0 != "---" { exit }
  NR==1 { next }
  /^---[[:space:]]*$/ { exit }
  { print }
' "$file")"

if printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*confirmed[[:space:]]*$'; then
  exit 1   # confirmed — OK to build on
fi

# ADR-066 amendment (P316): rejected-pending-supersede with a tracked
# supersede-ticket is "ratified-equivalent" for the build-upon guard — the
# user has explicitly rejected the ADR and pinned a supersede in flight, so
# the [Unratified Dependency] flag must NOT re-fire on the rejected ADR.
# Marker without ticket is malformed and still fires (defensive).
if printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*rejected-pending-supersede[[:space:]]*$' \
   && printf '%s\n' "$fm" | grep -qiE '^supersede-ticket:[[:space:]]*P[0-9]+[[:space:]]*$'; then
  exit 1
fi

# Unconfirmed — the build-upon guard SHOULD fire. Name the file for the guard.
echo "$file"
exit 0
