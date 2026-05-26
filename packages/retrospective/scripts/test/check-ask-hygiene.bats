#!/usr/bin/env bats
#
# packages/retrospective/scripts/test/check-ask-hygiene.bats
#
# Behavioural tests for `check-ask-hygiene.sh` — the ask-hygiene trail
# advisory script (P135 Phase 5 / ADR-044). Mirrors the test pattern of
# `check-briefing-budgets.bats`.
#
# Tests are behavioural per ADR-005 / ADR-037 — they exercise the
# script end-to-end against fixture trail directories and assert on
# stdout / stderr / exit shape. No structural greps of the script
# source itself per ADR-044's deviation-default to behavioural-by-
# default for skill / script testing.
#
# @problem P135 (Phase 5 measurement)
# @adr ADR-044 (Decision-Delegation Contract — lazy-count metric)
# @adr ADR-040 (Tier 3 advisory-not-fail-closed)
# @adr ADR-005 / ADR-037 (Plugin testing strategy — behavioural tests)
# @jtbd JTBD-001 / JTBD-006 / JTBD-201

SCRIPT="${BATS_TEST_DIRNAME}/../check-ask-hygiene.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ── Pre-checks ──────────────────────────────────────────────────────────────

@test "script file exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "missing retros dir exits 2 with error message on stderr" {
  run bash "$SCRIPT" "$TEST_DIR/does-not-exist"
  [ "$status" -eq 2 ]
  [[ "$output" == *"retros dir not found"* ]]
}

@test "empty retros dir exits 0 with empty stdout" {
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "default retros-dir argument is docs/retros (when omitted)" {
  # Behavioural: script must accept no-arg invocation when invoked from a project root.
  # We exercise from a fresh tmp dir with no docs/retros to assert the missing-dir
  # behaviour fires when the default path is used.
  cd "$TEST_DIR"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"docs/retros"* ]]
}

# ── Single-entry behaviour ──────────────────────────────────────────────────

@test "single trail entry emits one RETRO line and no TREND" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 5**
**Direction count: 2**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RETRO 2026-04-27 lazy=5 direction=2"* ]]
  [[ "$output" != *"TREND"* ]]
}

@test "trail entry without lazy-count line is skipped silently" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
# Some retro file with no lazy count
**Direction count: 3**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ADR-074 substance-confirm ask counts as direction, never inflates lazy" {
  # A retro where the only AskUserQuestion was a substance-confirm-before-build
  # ask: run-retro Step 2d tags it `direction` (cat-1, ADR-074), so the trail
  # records direction=1 lazy=0. The script must report it under direction and
  # leave lazy at 0 — the exclusion holds by construction (category-agnostic tally).
  cat > "$TEST_DIR/2026-05-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 0**
**Direction count: 1**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RETRO 2026-05-27 lazy=0 direction=1"* ]]
}

# ── Multi-entry behaviour ───────────────────────────────────────────────────

@test "multiple trail entries emit RETRO lines sorted oldest-first by date" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 1**
TRAIL
  cat > "$TEST_DIR/2026-04-25-ask-hygiene.md" <<'TRAIL'
**Lazy count: 5**
TRAIL
  cat > "$TEST_DIR/2026-04-26-ask-hygiene.md" <<'TRAIL'
**Lazy count: 3**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  # Assert order: 04-25 (oldest) → 04-26 → 04-27 (newest)
  line1="${lines[0]}"
  line2="${lines[1]}"
  line3="${lines[2]}"
  [[ "$line1" == *"2026-04-25"* ]]
  [[ "$line2" == *"2026-04-26"* ]]
  [[ "$line3" == *"2026-04-27"* ]]
}

@test "two-or-more entries emit TREND line with first/last/delta" {
  cat > "$TEST_DIR/2026-04-25-ask-hygiene.md" <<'TRAIL'
**Lazy count: 5**
TRAIL
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 1**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TREND lazy_first=5 lazy_last=1 delta=-4"* ]]
}

@test "TREND line shows positive delta when lazy count grew" {
  cat > "$TEST_DIR/2026-04-25-ask-hygiene.md" <<'TRAIL'
**Lazy count: 1**
TRAIL
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 4**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TREND lazy_first=1 lazy_last=4 delta=+3"* ]]
}

@test "TREND line shows zero delta when lazy count unchanged" {
  cat > "$TEST_DIR/2026-04-25-ask-hygiene.md" <<'TRAIL'
**Lazy count: 2**
TRAIL
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 2**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TREND lazy_first=2 lazy_last=2 delta=+0"* ]]
}

# ── Window override ──────────────────────────────────────────────────────────

@test "ASK_HYGIENE_WINDOW=2 keeps only the most-recent 2 entries" {
  for d in 25 26 27; do
    cat > "$TEST_DIR/2026-04-$d-ask-hygiene.md" <<TRAIL
**Lazy count: $d**
TRAIL
  done
  ASK_HYGIENE_WINDOW=2 run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  # Assert: 04-25 not present; 04-26 first; 04-27 last
  [[ "$output" != *"2026-04-25"* ]]
  [[ "$output" == *"RETRO 2026-04-26"* ]]
  [[ "$output" == *"RETRO 2026-04-27"* ]]
  # TREND should reflect the windowed pair, not the full 3
  [[ "$output" == *"TREND lazy_first=26 lazy_last=27 delta=+1"* ]]
}

@test "default window 10 keeps all entries when fewer than 10 exist" {
  cat > "$TEST_DIR/2026-04-25-ask-hygiene.md" <<'TRAIL'
**Lazy count: 5**
TRAIL
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 1**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-04-25"* ]]
  [[ "$output" == *"2026-04-27"* ]]
}

# ── Category-coverage shape ──────────────────────────────────────────────────

@test "RETRO line includes all 6 category counts (lazy + 5 non-lazy)" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 0**
**Direction count: 3**
**Override count: 1**
**Silent-framework count: 1**
**Taste count: 0**
**Correction-followup count: 0**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lazy=0"* ]]
  [[ "$output" == *"direction=3"* ]]
  [[ "$output" == *"override=1"* ]]
  [[ "$output" == *"silent=1"* ]]
  [[ "$output" == *"taste=0"* ]]
  [[ "$output" == *"correction=0"* ]]
}

@test "missing non-lazy categories default to 0" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 4**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lazy=4"* ]]
  [[ "$output" == *"direction=0"* ]]
  [[ "$output" == *"override=0"* ]]
  [[ "$output" == *"silent=0"* ]]
}

# ── Format tolerance ──────────────────────────────────────────────────────────

@test "lazy-count line works without bold markdown asterisks" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
Lazy count: 7
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lazy=7"* ]]
}

@test "lazy-count line is case-insensitive on the LAZY label" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**lazy count: 8**
TRAIL
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lazy=8"* ]]
}

# ── Cross-shell portability (P124 / P133 lessons) ───────────────────────────

@test "script glob iteration uses portable for-loop existence check (no shopt nullglob)" {
  # Behavioural: invoking an empty retros dir must NOT emit a literal
  # `*-ask-hygiene.md` because the glob unexpanded to a literal pattern.
  # The script's portable iteration handles this without zsh `shopt -s nullglob`.
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"*-ask-hygiene.md"* ]]
}

# ── Read-only contract ──────────────────────────────────────────────────────

@test "script is read-only — fixture tree unchanged after run" {
  cat > "$TEST_DIR/2026-04-27-ask-hygiene.md" <<'TRAIL'
**Lazy count: 3**
TRAIL
  pre_hash=$(find "$TEST_DIR" -type f -exec cksum {} \; 2>/dev/null | sort | cksum | awk '{print $1}')
  run bash "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  post_hash=$(find "$TEST_DIR" -type f -exec cksum {} \; 2>/dev/null | sort | cksum | awk '{print $1}')
  [ "$pre_hash" = "$post_hash" ]
}
