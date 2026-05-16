#!/usr/bin/env bats

# P132 Phase 2a-iii-B + ADR-017: derive-first-dispatch.sh duplicated across
# packages. Drift check — every packages/*/lib/derive-first-dispatch.sh
# copy must match the canonical packages/shared/derive-first-dispatch.sh.
# The sync script is the remediation; this test is the CI guard.
#
# Pattern mirrors packages/shared/test/sync-install-utils.bats (P026 / ADR-017
# precedent for install-utils.mjs duplication + sync).
#
# @problem P132 (agents over-ask in interactive sessions — Phase 2a-iii-B)
# @adr ADR-017 (Shared code duplicated into per-package lib/ kept in sync)
# @adr ADR-002 (Monorepo per-plugin packages)
# @adr ADR-052 (behavioural-by-default — these are runtime behaviour
#   assertions on the sync script, not structural greps)
# @jtbd JTBD-001 (enforce governance without slowing down — primary)
# @jtbd JTBD-101 (extend the suite with consistent patterns)

setup() {
  # Test file lives at packages/shared/test/ — 3 levels below repo root.
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SYNC_SCRIPT="$REPO_ROOT/scripts/sync-derive-first-dispatch.sh"
  SHARED_SRC="$REPO_ROOT/packages/shared/derive-first-dispatch.sh"
}

@test "sync-derive-first-dispatch: canonical source exists" {
  [ -f "$SHARED_SRC" ]
}

@test "sync-derive-first-dispatch: sync script exists and is executable" {
  [ -x "$SYNC_SCRIPT" ]
}

@test "sync-derive-first-dispatch: at least one lib/ copy exists" {
  local count
  count=$(find "$REPO_ROOT/packages" -maxdepth 3 -type f -path '*/lib/derive-first-dispatch.sh' | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "sync-derive-first-dispatch: both itil and architect lib copies exist (P132 4-surface set)" {
  # Phase 2a-iii-B mandates synced copies for both adopter packages.
  [ -f "$REPO_ROOT/packages/itil/lib/derive-first-dispatch.sh" ]
  [ -f "$REPO_ROOT/packages/architect/lib/derive-first-dispatch.sh" ]
}

@test "sync-derive-first-dispatch: all lib/derive-first-dispatch.sh copies match shared (drift check)" {
  run bash "$SYNC_SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "sync-derive-first-dispatch: --check flag flags divergence when a copy differs" {
  # Create a temp workspace mirroring the layout so we can intentionally
  # diverge a copy without touching the repo.
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/packages/shared" "$tmp/packages/fakepkg/lib" "$tmp/scripts"
  cp "$SHARED_SRC" "$tmp/packages/shared/derive-first-dispatch.sh"
  cp "$SHARED_SRC" "$tmp/packages/fakepkg/lib/derive-first-dispatch.sh"
  # Diverge the copy
  echo "# drift" >> "$tmp/packages/fakepkg/lib/derive-first-dispatch.sh"
  # Copy script into the temp root so its REPO_ROOT resolves correctly
  cp "$SYNC_SCRIPT" "$tmp/scripts/sync-derive-first-dispatch.sh"
  chmod +x "$tmp/scripts/sync-derive-first-dispatch.sh"

  run bash "$tmp/scripts/sync-derive-first-dispatch.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"DIVERGED"* ]] || [[ "$output" == *"diverged"* ]]

  rm -rf "$tmp"
}

@test "sync-derive-first-dispatch: sync mode overwrites diverged copy from canonical" {
  # Idempotency + healing behaviour: sync mode brings diverged copies back
  # to canonical content.
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/packages/shared" "$tmp/packages/fakepkg/lib" "$tmp/scripts"
  cp "$SHARED_SRC" "$tmp/packages/shared/derive-first-dispatch.sh"
  cp "$SHARED_SRC" "$tmp/packages/fakepkg/lib/derive-first-dispatch.sh"
  echo "# drift" >> "$tmp/packages/fakepkg/lib/derive-first-dispatch.sh"
  cp "$SYNC_SCRIPT" "$tmp/scripts/sync-derive-first-dispatch.sh"
  chmod +x "$tmp/scripts/sync-derive-first-dispatch.sh"

  run bash "$tmp/scripts/sync-derive-first-dispatch.sh"
  [ "$status" -eq 0 ]

  # After sync, the copy should match canonical (byte-identical).
  run diff -q "$tmp/packages/shared/derive-first-dispatch.sh" "$tmp/packages/fakepkg/lib/derive-first-dispatch.sh"
  [ "$status" -eq 0 ]

  rm -rf "$tmp"
}
