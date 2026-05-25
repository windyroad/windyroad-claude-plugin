#!/usr/bin/env bats
#
# packages/retrospective/scripts/test/check-readme-jtbd-currency.bats
#
# Behavioural tests for `check-readme-jtbd-currency.sh` — the skill-inventory
# README currency advisory (ADR-069 / P294, superseding ADR-051's JTBD-ID
# rule). Mirrors the fixture-based pattern of sibling detectors
# (`check-briefing-budgets.bats`, `check-ask-hygiene.bats`).
#
# Tests are behavioural per ADR-005 / ADR-052 / P081 — they exercise the
# script end-to-end against fixture packages/ trees and assert on stdout /
# exit code shape. No structural greps of the script source.
#
# @problem P152 (No pressure or nudge for documentation currency — original driver)
# @problem P294 (ADR-051 superseded — README markets the persona's problem, no JTBD-ID citation)
# @problem P081 (Structural-content tests are wasteful — behavioural preferred)
# @adr ADR-069 (README markets persona problem; skill-inventory currency gate)
# @adr ADR-051 (superseded — original JTBD-anchored README rule)
# @adr ADR-013 Rule 6 (non-interactive fail-safe)
# @adr ADR-005 / ADR-052 (Plugin testing strategy — behavioural tests)

SCRIPT="${BATS_TEST_DIRNAME}/../check-readme-jtbd-currency.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  PKG_DIR="$TEST_DIR/packages"
  mkdir -p "$PKG_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# Helper: write a synthetic plugin README into PKG_DIR
make_plugin() {
  local name="$1"
  local readme_content="$2"
  mkdir -p "$PKG_DIR/$name"
  printf '%s\n' "$readme_content" > "$PKG_DIR/$name/README.md"
}

# ── Pre-checks ──────────────────────────────────────────────────────────────

@test "script file exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "missing packages dir exits 2 with error message on stderr" {
  run bash "$SCRIPT" "$TEST_DIR/does-not-exist"
  [ "$status" -eq 2 ]
  [[ "$output" == *"packages dir not found"* ]]
}

@test "empty packages dir exits 0 with empty stdout" {
  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "legacy second argument (former jtbd-dir) is accepted and ignored" {
  make_plugin "stub" "# @windyroad/stub
A plugin that solves a problem."
  run bash "$SCRIPT" "$PKG_DIR" "/some/legacy/jtbd/path"
  [ "$status" -eq 0 ]
  [[ "$output" == *"package=stub"* ]]
  [[ "$output" == *"TOTAL packages=1 drift_instances=0"* ]]
}

# ── Drift fixture: skills/ directory not named in README ────────────────────

@test "drift fixture: skills/ directory not named in README emits skill-inventory-drift" {
  mkdir -p "$PKG_DIR/stub/skills/orphan-widget"
  printf '%s\n' "# @windyroad/stub
This README documents no skills." > "$PKG_DIR/stub/README.md"

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"package=stub"* ]]
  [[ "$output" == *"skills=1"* ]]
  [[ "$output" == *"in_readme=0"* ]]
  [[ "$output" == *"drift_hints="*"skill-inventory-drift"* ]]
  [[ "$output" == *"TOTAL packages=1 drift_instances=1"* ]]
}

# ── Clean fixture: every skill named in README ──────────────────────────────

@test "clean fixture: all skills/ directories named in README emit empty drift_hints" {
  mkdir -p "$PKG_DIR/stub/skills/manage-secret"
  printf '%s\n' "# @windyroad/stub
Run /wr-stub:manage-secret to rotate a secret." > "$PKG_DIR/stub/README.md"

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"package=stub"* ]]
  [[ "$output" == *"skills=1"* ]]
  [[ "$output" == *"in_readme=1"* ]]
  [[ "$output" != *"skill-inventory-drift"* ]]
  [[ "$output" == *"TOTAL packages=1 drift_instances=0"* ]]
}

# ── Regression guard: a JTBD-NNN citation must NOT change the verdict ────────
# (ADR-069 removed the JTBD-ID rule; the detector no longer reads JTBD IDs.)

@test "regression: README with NO JTBD-NNN citation is clean when its skills are named" {
  mkdir -p "$PKG_DIR/stub/skills/do-thing"
  printf '%s\n' "# @windyroad/stub
Markets a problem in plain prose. Run /wr-stub:do-thing. No JTBD IDs here." > "$PKG_DIR/stub/README.md"

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"missing-jtbd-section"* ]]
  [[ "$output" != *"stale-jtbd-citation"* ]]
  [[ "$output" == *"TOTAL packages=1 drift_instances=0"* ]]
}

# ── Package with no skills/ directory ───────────────────────────────────────

@test "package without a skills/ directory reports skills=0 and no drift" {
  make_plugin "umbrella" "# @windyroad/umbrella
A marketplace package with no skills of its own."

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"package=umbrella"* ]]
  [[ "$output" == *"skills=0"* ]]
  [[ "$output" == *"in_readme=0"* ]]
  [[ "$output" != *"skill-inventory-drift"* ]]
}

# ── Multi-package aggregation ───────────────────────────────────────────────

@test "multi-package aggregation: emits one README line per package + TOTAL summary" {
  mkdir -p "$PKG_DIR/alpha/skills/run-alpha"
  printf '%s\n' "# alpha
Run /wr-alpha:run-alpha." > "$PKG_DIR/alpha/README.md"
  mkdir -p "$PKG_DIR/bravo/skills/lost-skill"
  printf '%s\n' "# bravo
README forgot to mention its skill." > "$PKG_DIR/bravo/README.md"
  make_plugin "charlie" "# charlie
No skills directory at all."

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"package=alpha"* ]]
  [[ "$output" == *"package=bravo"* ]]
  [[ "$output" == *"package=charlie"* ]]
  # only bravo drifts (lost-skill not named)
  [[ "$output" == *"TOTAL packages=3 drift_instances=1"* ]]
}

# ── Package without README is skipped ───────────────────────────────────────

@test "package without README.md is silently skipped" {
  mkdir -p "$PKG_DIR/no-readme/skills/x"
  mkdir -p "$PKG_DIR/with-readme/skills/y"
  printf '%s\n' "# with-readme
Run /wr-with-readme:y." > "$PKG_DIR/with-readme/README.md"

  run bash "$SCRIPT" "$PKG_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"package=no-readme"* ]]
  [[ "$output" == *"package=with-readme"* ]]
  [[ "$output" == *"TOTAL packages=1"* ]]
}
