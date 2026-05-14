#!/usr/bin/env bash
# Sync the canonical external-comms-gate.sh + lib/leak-detect.sh from
# packages/shared/hooks/ into every consumer plugin (P064 / ADR-017 /
# ADR-028 amended).
#
# Each consumer plugin is published as a self-contained npm bundle, so
# the per-plugin copy must exist at runtime — but the source of truth is
# packages/shared/hooks/external-comms-gate.sh.
#
# Run this after editing the canonical and before committing. The CI
# step `npm run check:external-comms-gate` fails the build if any copy
# has diverged.
#
# Usage:
#   bash scripts/sync-external-comms-gate.sh          # sync all copies
#   bash scripts/sync-external-comms-gate.sh --check  # exit non-zero if any copy differs

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_HOOK="$REPO_ROOT/packages/shared/hooks/external-comms-gate.sh"
SHARED_LIB="$REPO_ROOT/packages/shared/hooks/lib/leak-detect.sh"

if [ ! -f "$SHARED_HOOK" ]; then
  echo "ERROR: canonical hook not found at $SHARED_HOOK" >&2
  exit 1
fi
if [ ! -f "$SHARED_LIB" ]; then
  echo "ERROR: canonical lib not found at $SHARED_LIB" >&2
  exit 1
fi

MODE="sync"
if [ "${1:-}" = "--check" ]; then
  MODE="check"
fi

# Consumer plugins that ship the external-comms gate evaluator (ADR-028 amended 2026-05-14).
# Each consumer maintains its OWN external-comms-evaluator.conf (NOT synced)
# alongside the byte-identical canonical gate.sh + lib/leak-detect.sh.
CONSUMERS=(risk-scorer voice-tone)

DIVERGED=0
SYNCED=0
CREATED=0

sync_or_check_pair() {
  local plugin="$1"
  local target_hook="$REPO_ROOT/packages/$plugin/hooks/external-comms-gate.sh"
  local target_lib="$REPO_ROOT/packages/$plugin/hooks/lib/leak-detect.sh"
  local target_lib_dir="$REPO_ROOT/packages/$plugin/hooks/lib"

  for pair in "$SHARED_HOOK:$target_hook" "$SHARED_LIB:$target_lib"; do
    local src="${pair%%:*}"
    local dst="${pair##*:}"

    if [ ! -f "$dst" ]; then
      if [ "$MODE" = "check" ]; then
        echo "MISSING: $dst"
        DIVERGED=$((DIVERGED + 1))
        continue
      fi
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      [ "$dst" = "$target_hook" ] && chmod +x "$dst"
      echo "created:  ${dst#$REPO_ROOT/}"
      CREATED=$((CREATED + 1))
      continue
    fi

    if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      if [ "$MODE" = "check" ]; then
        echo "DIVERGED: $dst"
        DIVERGED=$((DIVERGED + 1))
      else
        cp "$src" "$dst"
        [ "$dst" = "$target_hook" ] && chmod +x "$dst"
        echo "synced:   ${dst#$REPO_ROOT/}"
        SYNCED=$((SYNCED + 1))
      fi
    fi
  done
}

for plugin in "${CONSUMERS[@]}"; do
  sync_or_check_pair "$plugin"
done

if [ "$MODE" = "check" ]; then
  if [ "$DIVERGED" -gt 0 ]; then
    echo "" >&2
    echo "ERROR: $DIVERGED copy(ies) of external-comms-gate.sh / leak-detect.sh have diverged or are missing." >&2
    echo "Run: bash scripts/sync-external-comms-gate.sh" >&2
    exit 1
  fi
  TOTAL=$(( ${#CONSUMERS[@]} * 2 ))
  echo "OK: all $TOTAL external-comms-gate copies match canonical sources"
else
  if [ "$SYNCED" -eq 0 ] && [ "$CREATED" -eq 0 ]; then
    echo "OK: all copies already in sync"
  else
    echo ""
    echo "Synced $SYNCED file(s); created $CREATED new file(s). Review with: git diff packages/*/hooks/external-comms-gate.sh packages/*/hooks/lib/leak-detect.sh"
  fi
fi
