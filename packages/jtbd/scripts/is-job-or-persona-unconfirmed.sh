#!/usr/bin/env bash
# wr-jtbd — predicate: is a referenced persona or job unconfirmed? (ADR-068 surface 3)
#
# Single-artifact sibling of detect-unoversighted.sh (ADR-068). Where the
# detector LISTS the whole unoversighted set and always exits 0, this answers
# ONE question for ONE persona/job via its EXIT CODE — for the build-upon guard
# the wr-jtbd:agent runs (the [Unratified Dependency] verdict, RFC-011 / P323).
# The JTBD twin of packages/architect/scripts/is-decision-unconfirmed.sh
# (ADR-074). A separate script (not a mode flag on the detector) keeps the
# detector's "always exit 0, path-list on stdout" contract intact.
#
# "Unconfirmed" mirrors detect-unoversighted.sh EXACTLY:
#   - the artifact's frontmatter lacks `human-oversight: confirmed`, AND
#   - the artifact is not superseded.
# CANONICAL SHAPE: detect-unoversighted.sh. Keep the frontmatter-extraction
# awk block + the `human-oversight: confirmed` grep + the superseded skip in
# sync with that script. The `@test "agrees with detect-unoversighted ..."`
# case in test/is-job-or-persona-unconfirmed.bats fails if these two drift.
#
# Usage:
#   is-job-or-persona-unconfirmed.sh <ref> [JTBD_DIR]
#     <ref> = JTBD-NNN | NNN | <persona-name> | path/to/<file>.md
#     JTBD_DIR defaults to docs/jtbd
#
# Ref resolution (ADR-008 layout: docs/jtbd/<persona>/persona.md +
# docs/jtbd/<persona>/JTBD-NNN-*.md):
#   - a path to an existing file        → that file
#   - JTBD-NNN or a bare NNN            → docs/jtbd/*/JTBD-NNN-*.md (first match)
#   - anything else (a persona name)   → docs/jtbd/<name>/persona.md
#
# Exit codes:
#   0 = unconfirmed — the build-upon guard SHOULD fire. Prints the resolved path.
#   1 = confirmed OR superseded — guard should NOT fire. No stdout.
#   2 = not found / unparseable ref. No stdout; reason on stderr.

set -uo pipefail

REF="${1:-}"
JTBD_DIR="${2:-docs/jtbd}"

[ -n "$REF" ] || { echo "is-job-or-persona-unconfirmed: missing <ref>" >&2; exit 2; }

# ── Resolve the persona/job file ──────────────────────────────────────────
file=""
if [ -f "$REF" ]; then
  file="$REF"
elif printf '%s' "$REF" | grep -qiE 'JTBD-?[0-9]+|^[0-9]+$'; then
  # Job ref: JTBD-NNN or a bare numeric. Match the per-persona job file.
  num="$(printf '%s' "$REF" | grep -oE '[0-9]+' | head -1)"
  [ -n "$num" ] || { echo "is-job-or-persona-unconfirmed: cannot parse job id from '$REF'" >&2; exit 2; }
  shopt -s nullglob
  for cand in "$JTBD_DIR"/*/JTBD-"$num"-*.md "$JTBD_DIR"/*/"$num"-*.md; do
    file="$cand"; break
  done
  shopt -u nullglob
else
  # Persona-name ref → the persona's persona.md.
  cand="$JTBD_DIR/$REF/persona.md"
  [ -f "$cand" ] && file="$cand"
fi

[ -n "$file" ] && [ -f "$file" ] || {
  echo "is-job-or-persona-unconfirmed: no persona/job file for '$REF' under $JTBD_DIR" >&2
  exit 2
}

base="$(basename "$file")"

# Superseded artifacts are retired — a newer job/persona replaced them. The
# build-upon guard does not fire (mirror of detect-unoversighted.sh's skip).
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

# ADR-068 amendment (P316): mirror the architect predicate's
# rejected-pending-supersede exclusion. A persona/job the user explicitly
# rejected with a tracked supersede ticket is ratified-equivalent for the
# build-upon guard — the [Unratified Dependency] verdict must NOT re-fire on
# it. Marker without ticket still fires (defensive).
if printf '%s\n' "$fm" | grep -qiE '^human-oversight:[[:space:]]*rejected-pending-supersede[[:space:]]*$' \
   && printf '%s\n' "$fm" | grep -qiE '^supersede-ticket:[[:space:]]*P[0-9]+[[:space:]]*$'; then
  exit 1
fi

# Unconfirmed — the build-upon guard SHOULD fire. Name the file for the guard.
echo "$file"
exit 0
