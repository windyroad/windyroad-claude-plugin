#!/usr/bin/env bash
# Sync the canonical derive-first-dispatch.sh from packages/shared/ into
# every packages/*/lib/ copy. Each package is published as a self-contained
# npm bundle, so the lib/ copy must exist at runtime — but the source
# of truth is packages/shared/derive-first-dispatch.sh.
#
# Phase 2a-iii-B (2026-05-16): mirrors scripts/sync-install-utils.sh
# pattern per ADR-017 (Shared code duplicated into per-package lib/ kept
# in sync). Author edits packages/shared/derive-first-dispatch.sh only;
# this script copies the canonical file to every packages/*/lib/ copy.
#
# Run this after editing packages/shared/derive-first-dispatch.sh and
# before committing. The packages/shared/test/sync-derive-first-dispatch.bats
# test fails the build if any copy has diverged.
#
# Usage:
#   bash scripts/sync-derive-first-dispatch.sh          # sync all copies
#   bash scripts/sync-derive-first-dispatch.sh --check  # exit non-zero if any copy differs
#
# @problem P132 (agents over-ask in interactive sessions — Phase 2a-iii-B
#   4-surface set requires canonical packages/shared/ source + per-package sync)
# @adr ADR-017 (Shared code duplicated into per-package lib/ kept in sync)
# @adr ADR-052 (behavioural-by-default — tested via packages/shared/test/sync-derive-first-dispatch.bats)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_SRC="$REPO_ROOT/packages/shared/derive-first-dispatch.sh"

if [ ! -f "$SHARED_SRC" ]; then
  echo "ERROR: canonical source not found at $SHARED_SRC" >&2
  exit 1
fi

MODE="sync"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
fi

# Enumerate target lib/ copies. Only packages that actually have a lib/
# derive-first-dispatch.sh file — we do not create new copies here.
mapfile -t TARGETS < <(find "$REPO_ROOT/packages" -maxdepth 3 -type f -path '*/lib/derive-first-dispatch.sh' | sort)

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "No packages/*/lib/derive-first-dispatch.sh targets found." >&2
  exit 1
fi

DIVERGED=0
SYNCED=0

for target in "${TARGETS[@]}"; do
  if ! diff -q "$SHARED_SRC" "$target" >/dev/null 2>&1; then
    if [ "$MODE" = "check" ]; then
      echo "DIVERGED: $target"
      DIVERGED=$((DIVERGED + 1))
    else
      cp "$SHARED_SRC" "$target"
      echo "synced:   ${target#$REPO_ROOT/}"
      SYNCED=$((SYNCED + 1))
    fi
  fi
done

if [ "$MODE" = "check" ]; then
  if [ "$DIVERGED" -gt 0 ]; then
    echo "" >&2
    echo "ERROR: $DIVERGED copy(ies) of derive-first-dispatch.sh have diverged from packages/shared/derive-first-dispatch.sh." >&2
    echo "Run: bash scripts/sync-derive-first-dispatch.sh" >&2
    exit 1
  fi
  echo "OK: all ${#TARGETS[@]} lib/derive-first-dispatch.sh copies match packages/shared/derive-first-dispatch.sh"
else
  if [ "$SYNCED" -eq 0 ]; then
    echo "OK: all ${#TARGETS[@]} copies already in sync"
  else
    echo ""
    echo "Synced $SYNCED copy(ies). Review with: git diff packages/*/lib/derive-first-dispatch.sh"
  fi
fi
