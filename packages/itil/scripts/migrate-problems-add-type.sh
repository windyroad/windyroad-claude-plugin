#!/usr/bin/env bash
# packages/itil/scripts/migrate-problems-add-type.sh
#
# One-shot bulk migration: ensure every `<problems-dir>/<NNN>-*.<status>.md`
# carries a `**Type**: technical` body field per ADR-060 Phase 1 item 8b.
#
# Default `**Type**: technical` per ADR-060 line 92 (existing tickets
# bulk-migrate to default; per-ticket judgement comes later via
# capture-problem AskUserQuestion in item 8c — out of scope here).
#
# Usage:
#   migrate-problems-add-type.sh [--apply] [<problems-dir>]
#
# Default <problems-dir> is ./docs/problems.
#
# Modes:
#   diagnose (default): read-only. Lists each ticket needing migration on
#     stdout (one per line, basename only). Exit 0 = clean, 1 = drift.
#   --apply: writes `**Type**: technical` after the LAST present body
#     field marker in {Status, Reported, Priority, Effort, WSJF}.
#     Idempotent — re-running with Type already present is a no-op.
#
# Exit codes:
#   0 = clean (diagnose: no migration needed; apply: completed)
#   1 = drift (diagnose only; tickets needing migration listed)
#   2 = parse error
#
# Tickets with NO recognisable header field markers are skipped with a
# `SKIP <basename>` warning on stderr — these are typically malformed
# scaffold leftovers and should not be auto-migrated.
#
# @problem P170 (Slice 4 B7.T2 / item 8b)
# @adr ADR-060 (type-tag schema; default `technical`; spec line 91 amended
#   2026-05-06: header field block in body, NOT YAML frontmatter)
# @adr ADR-014 (one bounded sub-task per script)

set -uo pipefail

APPLY=0
PROBLEMS_DIR=""

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    -*) echo "PARSE_ERROR: unknown flag: $arg" >&2; exit 2 ;;
    *)
      if [ -z "$PROBLEMS_DIR" ]; then
        PROBLEMS_DIR="$arg"
      else
        echo "PARSE_ERROR: multiple positional args: $arg" >&2
        exit 2
      fi
      ;;
  esac
done

PROBLEMS_DIR="${PROBLEMS_DIR:-docs/problems}"

if [ ! -d "$PROBLEMS_DIR" ]; then
  echo "PARSE_ERROR: problems-dir not found: $PROBLEMS_DIR" >&2
  exit 2
fi

drift=0
shopt -s nullglob
for f in "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.open.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.known-error.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.verifying.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.parked.md \
         "$PROBLEMS_DIR"/[0-9][0-9][0-9]-*.closed.md; do
  base="$(basename "$f")"

  # Idempotency check: any line matching `**Type**: <value>` in the
  # first 30 lines counts as already-migrated.
  if head -n 30 "$f" | grep -q '^\*\*Type\*\*:'; then
    continue
  fi

  # Find the LAST body-field marker line (Status / Reported / Priority /
  # Effort / WSJF) in the first 30 lines. Insertion anchor.
  anchor=$(head -n 30 "$f" \
    | grep -n -E '^\*\*(Status|Reported|Priority|Effort|WSJF)\*\*:' \
    | tail -1 | cut -d: -f1)

  if [ -z "$anchor" ]; then
    echo "SKIP $base (no recognisable header field markers)" >&2
    continue
  fi

  drift=1

  if [ "$APPLY" -eq 0 ]; then
    echo "$base"
    continue
  fi

  # Apply: insert `**Type**: technical` after line $anchor.
  # Use a temp file for atomic replace.
  tmp=$(mktemp)
  awk -v anchor="$anchor" '
    NR == anchor { print; print "**Type**: technical"; next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
done
shopt -u nullglob

if [ "$APPLY" -eq 1 ]; then
  exit 0
fi

if [ "$drift" -eq 1 ]; then
  exit 1
fi

exit 0
