#!/usr/bin/env bats
# P064 / ADR-017 / ADR-028 amended.
# Drift check for external-comms-gate.sh + leak-detect.sh canonical+copies.
# Mirrors sync-session-marker.bats (P095) and sync-install-utils.bats (P026).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SYNC_SCRIPT="$REPO_ROOT/scripts/sync-external-comms-gate.sh"
  CANONICAL_HOOK="$REPO_ROOT/packages/shared/hooks/external-comms-gate.sh"
  CANONICAL_LIB="$REPO_ROOT/packages/shared/hooks/lib/leak-detect.sh"
}

@test "sync-external-comms-gate: canonical hook exists" {
  [ -f "$CANONICAL_HOOK" ]
}

@test "sync-external-comms-gate: canonical leak-detect lib exists" {
  [ -f "$CANONICAL_LIB" ]
}

@test "sync-external-comms-gate: sync script exists and is executable" {
  [ -x "$SYNC_SCRIPT" ]
}

@test "sync-external-comms-gate: risk-scorer per-package copy exists" {
  [ -f "$REPO_ROOT/packages/risk-scorer/hooks/external-comms-gate.sh" ]
  [ -f "$REPO_ROOT/packages/risk-scorer/hooks/lib/leak-detect.sh" ]
}

@test "sync-external-comms-gate: voice-tone per-package copy exists (P038 / ADR-028 amended 2026-05-14)" {
  [ -f "$REPO_ROOT/packages/voice-tone/hooks/external-comms-gate.sh" ]
  [ -f "$REPO_ROOT/packages/voice-tone/hooks/lib/leak-detect.sh" ]
}

@test "sync-external-comms-gate: each consumer carries its own external-comms-evaluator.conf (per-package, NOT synced)" {
  # The .conf file is per-package divergence by design (ADR-028 amended
  # 2026-05-14). Each consumer must ship its own; the canonical does NOT
  # carry one.
  [ -f "$REPO_ROOT/packages/risk-scorer/hooks/external-comms-evaluator.conf" ]
  [ -f "$REPO_ROOT/packages/voice-tone/hooks/external-comms-evaluator.conf" ]
  [ ! -f "$REPO_ROOT/packages/shared/hooks/external-comms-evaluator.conf" ]
  # Each .conf must declare an evaluator id matching its package.
  grep -qE '^EXTERNAL_COMMS_EVALUATOR_ID=risk$' "$REPO_ROOT/packages/risk-scorer/hooks/external-comms-evaluator.conf"
  grep -qE '^EXTERNAL_COMMS_EVALUATOR_ID=voice-tone$' "$REPO_ROOT/packages/voice-tone/hooks/external-comms-evaluator.conf"
}

@test "sync-external-comms-gate: --check passes when copies are byte-identical" {
  run bash "$SYNC_SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

@test "sync-external-comms-gate: --check flags divergence in a fixture workspace" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/packages/shared/hooks/lib" \
           "$tmp/packages/risk-scorer/hooks/lib" \
           "$tmp/scripts"
  cp "$CANONICAL_HOOK" "$tmp/packages/shared/hooks/external-comms-gate.sh"
  cp "$CANONICAL_LIB"  "$tmp/packages/shared/hooks/lib/leak-detect.sh"
  cp "$CANONICAL_HOOK" "$tmp/packages/risk-scorer/hooks/external-comms-gate.sh"
  cp "$CANONICAL_LIB"  "$tmp/packages/risk-scorer/hooks/lib/leak-detect.sh"
  echo "# drift" >> "$tmp/packages/risk-scorer/hooks/external-comms-gate.sh"

  cp "$SYNC_SCRIPT" "$tmp/scripts/sync-external-comms-gate.sh"
  chmod +x "$tmp/scripts/sync-external-comms-gate.sh"

  run bash "$tmp/scripts/sync-external-comms-gate.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"DIVERGED"* ]] || [[ "$output" == *"diverged"* ]]

  rm -rf "$tmp"
}

@test "sync-external-comms-gate: --check flags a missing copy in fixture workspace" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/packages/shared/hooks/lib" \
           "$tmp/packages/risk-scorer/hooks/lib" \
           "$tmp/scripts"
  cp "$CANONICAL_HOOK" "$tmp/packages/shared/hooks/external-comms-gate.sh"
  cp "$CANONICAL_LIB"  "$tmp/packages/shared/hooks/lib/leak-detect.sh"
  # Don't create the risk-scorer copy.
  cp "$SYNC_SCRIPT" "$tmp/scripts/sync-external-comms-gate.sh"
  chmod +x "$tmp/scripts/sync-external-comms-gate.sh"

  run bash "$tmp/scripts/sync-external-comms-gate.sh" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]

  rm -rf "$tmp"
}
