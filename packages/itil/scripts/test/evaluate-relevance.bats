#!/usr/bin/env bats

# @problem P346 — `/wr-itil:review-problems` has no path to close tickets that
#                 are no longer relevant (evidence-based, NOT age-based) —
#                 structural outflow gap drives monotonic backlog growth.
#                 Phase 1 ships the auto-close on "file no longer exists in
#                 codebase" evidence shape.
#
# Contract: `evaluate-relevance.sh <ticket-file> [<min-age-days>]` reads the
# ticket frontmatter for **Reported**:, applies an age gate, extracts file
# paths matching well-known repo subdirs from the ticket body (excluding
# self-references to docs/problems/*), runs `git ls-files --error-unmatch`
# on each, and emits a structured verdict.
#
# Output (stdout, one line):
#   CLOSE-CANDIDATE <basename> — all <N> file paths absent: <semicolon list>
#   KEEP            <basename> — <M>/<N> paths still present
#   SKIP            <basename> — <reason>
#
# Exit codes:
#   0 = CLOSE-CANDIDATE
#   1 = KEEP
#   2 = SKIP
#   3 = error
#
# @adr ADR-079 (Evidence-based relevance-close pass — Phase 1)
# @adr ADR-049 (bin/ on PATH shim — adopter-safe script resolution)
# @adr ADR-022 (Lifecycle extension — Open|Known Error → Closed-with-reason)
# @adr ADR-026 (Agent output grounding — cite + persist + uncertainty)
# @adr ADR-052 (Behavioural bats default)
# @jtbd JTBD-001 (Enforce Governance — under-60s review-flow served by smaller queue)
# @jtbd JTBD-006 (AFK — mechanical evidence not judgment-call)
# @jtbd JTBD-101 (Extend the Suite — extensible pattern per evidence shape)
# @jtbd JTBD-201 (Audit trail — closed-ticket section preserves close reason)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/evaluate-relevance.sh"
  FIXTURE_DIR="$(mktemp -d)"
  cd "$FIXTURE_DIR"
  git init -q -b main
  git config user.email test@example.com
  git config user.name "Test"
  mkdir -p docs/problems/open docs/problems/known-error packages/itil/scripts docs/decisions

  # An "old" Reported date: 60 days before today. ISO date arithmetic
  # portable across BSD + GNU date.
  OLD_DATE=$(date -u -v-60d "+%Y-%m-%d" 2>/dev/null || date -u -d '60 days ago' "+%Y-%m-%d")
  # A "fresh" Reported date: 1 day before today.
  FRESH_DATE=$(date -u -v-1d "+%Y-%m-%d" 2>/dev/null || date -u -d '1 day ago' "+%Y-%m-%d")
}

teardown() {
  cd /
  rm -rf "$FIXTURE_DIR"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "evaluate-relevance: script exists" {
  [ -f "$SCRIPT" ]
}

@test "evaluate-relevance: script is executable" {
  [ -x "$SCRIPT" ]
}

@test "evaluate-relevance: PATH shim exists and dispatches" {
  SHIM="$SCRIPTS_DIR/../bin/wr-itil-evaluate-relevance"
  [ -f "$SHIM" ]
  [ -x "$SHIM" ]
  # Shim exec's the canonical script body.
  grep -q "evaluate-relevance.sh" "$SHIM"
}

# ── Usage / error path ──────────────────────────────────────────────────────

@test "evaluate-relevance: no args → exit 3 with usage stderr" {
  run "$SCRIPT"
  [ "$status" -eq 3 ]
  [[ "$output" == *"usage"* ]]
}

@test "evaluate-relevance: nonexistent ticket file → exit 3" {
  run "$SCRIPT" /nonexistent/ticket.md
  [ "$status" -eq 3 ]
  [[ "$output" == *"not found"* ]]
}

# ── Age gate (SKIP exit 2) ──────────────────────────────────────────────────

@test "evaluate-relevance: fresh ticket (< 7 days) → SKIP exit 2" {
  cat > docs/problems/open/100-foo.md <<EOF
# Problem 100: foo

**Status**: Open
**Reported**: $FRESH_DATE

## Description

Bug in packages/itil/scripts/imaginary.sh
EOF
  run "$SCRIPT" docs/problems/open/100-foo.md
  [ "$status" -eq 2 ]
  [[ "$output" == "SKIP "*"age gate"* ]]
}

@test "evaluate-relevance: no Reported date → SKIP exit 2" {
  cat > docs/problems/open/101-bar.md <<EOF
# Problem 101: bar

**Status**: Open

## Description

packages/itil/scripts/missing.sh
EOF
  run "$SCRIPT" docs/problems/open/101-bar.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"no Reported date"* ]]
}

# ── No extractable paths (SKIP exit 2) ──────────────────────────────────────

@test "evaluate-relevance: no extractable file paths → SKIP exit 2" {
  cat > docs/problems/open/102-baz.md <<EOF
# Problem 102: baz

**Status**: Open
**Reported**: $OLD_DATE

## Description

A general complaint about agent behaviour with no file references.
EOF
  run "$SCRIPT" docs/problems/open/102-baz.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"no extractable file paths"* ]]
}

@test "evaluate-relevance: only self-references to docs/problems/* → SKIP exit 2" {
  cat > docs/problems/open/103-qux.md <<EOF
# Problem 103: qux

**Status**: Open
**Reported**: $OLD_DATE

## Description

Duplicate concern with docs/problems/open/099-other.md and docs/problems/known-error/088-third.md.
EOF
  run "$SCRIPT" docs/problems/open/103-qux.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"no extractable file paths"* ]]
}

# ── CLOSE-CANDIDATE path (exit 0) ───────────────────────────────────────────

@test "evaluate-relevance: old ticket + all paths absent → CLOSE-CANDIDATE exit 0" {
  cat > docs/problems/open/104-stale.md <<EOF
# Problem 104: stale

**Status**: Open
**Reported**: $OLD_DATE

## Description

Bug in packages/itil/scripts/imaginary-helper.sh that no longer exists.
Related: docs/decisions/999-imaginary-adr.proposed.md.
EOF
  run "$SCRIPT" docs/problems/open/104-stale.md
  [ "$status" -eq 0 ]
  [[ "$output" == "CLOSE-CANDIDATE "*"104-stale.md"*"all 2 file paths absent"* ]]
  [[ "$output" == *"packages/itil/scripts/imaginary-helper.sh"* ]]
  [[ "$output" == *"docs/decisions/999-imaginary-adr.proposed.md"* ]]
}

@test "evaluate-relevance: old ticket + single absent path → CLOSE-CANDIDATE exit 0" {
  cat > docs/problems/open/105-single.md <<EOF
# Problem 105: single

**Status**: Open
**Reported**: $OLD_DATE

## Description

The script at packages/itil/scripts/dead-helper.sh fails.
EOF
  run "$SCRIPT" docs/problems/open/105-single.md
  [ "$status" -eq 0 ]
  [[ "$output" == "CLOSE-CANDIDATE "*"all 1 file paths absent"* ]]
  [[ "$output" == *"packages/itil/scripts/dead-helper.sh"* ]]
}

# ── KEEP path (exit 1) ──────────────────────────────────────────────────────

@test "evaluate-relevance: old ticket + all paths present → KEEP exit 1" {
  # Create + stage the file so git ls-files sees it
  echo "live" > packages/itil/scripts/live-helper.sh
  git add packages/itil/scripts/live-helper.sh

  cat > docs/problems/open/106-live.md <<EOF
# Problem 106: live

**Status**: Open
**Reported**: $OLD_DATE

## Description

Bug in packages/itil/scripts/live-helper.sh.
EOF
  run "$SCRIPT" docs/problems/open/106-live.md
  [ "$status" -eq 1 ]
  [[ "$output" == "KEEP "*"1/1 paths still present"* ]]
}

@test "evaluate-relevance: old ticket + mixed paths (one present, one absent) → KEEP exit 1" {
  echo "live" > packages/itil/scripts/exists.sh
  git add packages/itil/scripts/exists.sh

  cat > docs/problems/open/107-mixed.md <<EOF
# Problem 107: mixed

**Status**: Open
**Reported**: $OLD_DATE

## Description

Interaction between packages/itil/scripts/exists.sh and
packages/itil/scripts/gone.sh produces wrong result.
EOF
  run "$SCRIPT" docs/problems/open/107-mixed.md
  [ "$status" -eq 1 ]
  [[ "$output" == "KEEP "*"1/2 paths still present"* ]]
}

# ── Known Error tickets (exit 0) ────────────────────────────────────────────

@test "evaluate-relevance: known-error ticket with all paths absent → CLOSE-CANDIDATE exit 0" {
  cat > docs/problems/known-error/108-ke-stale.md <<EOF
# Problem 108: ke-stale

**Status**: Known Error
**Reported**: $OLD_DATE

## Description

Fix strategy referenced packages/itil/scripts/abandoned-fix.sh.

## Root Cause Analysis

Root cause was identified in packages/itil/scripts/abandoned-fix.sh.
EOF
  run "$SCRIPT" docs/problems/known-error/108-ke-stale.md
  [ "$status" -eq 0 ]
  [[ "$output" == "CLOSE-CANDIDATE "*"108-ke-stale.md"* ]]
}

# ── Custom age gate ─────────────────────────────────────────────────────────

@test "evaluate-relevance: custom min-age-days=30 keeps a 15-day-old ticket as SKIP" {
  MED_DATE=$(date -u -v-15d "+%Y-%m-%d" 2>/dev/null || date -u -d '15 days ago' "+%Y-%m-%d")
  cat > docs/problems/open/109-medium.md <<EOF
# Problem 109: medium

**Status**: Open
**Reported**: $MED_DATE

## Description

packages/itil/scripts/missing.sh is broken.
EOF
  run "$SCRIPT" docs/problems/open/109-medium.md 30
  [ "$status" -eq 2 ]
  [[ "$output" == *"age gate"* ]]
}

# ── Output contract: verdict starts with the keyword ────────────────────────

@test "evaluate-relevance: CLOSE-CANDIDATE verdict begins with the literal keyword" {
  cat > docs/problems/open/110-verdict.md <<EOF
# Problem 110: verdict

**Status**: Open
**Reported**: $OLD_DATE

## Description

packages/itil/scripts/missing-x.sh
EOF
  run "$SCRIPT" docs/problems/open/110-verdict.md
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "CLOSE-CANDIDATE "* ]]
}

@test "evaluate-relevance: KEEP verdict begins with the literal keyword" {
  echo "x" > packages/itil/scripts/present-x.sh
  git add packages/itil/scripts/present-x.sh

  cat > docs/problems/open/111-keep-verdict.md <<EOF
# Problem 111: keep-verdict

**Status**: Open
**Reported**: $OLD_DATE

## Description

packages/itil/scripts/present-x.sh
EOF
  run "$SCRIPT" docs/problems/open/111-keep-verdict.md
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "KEEP "* ]]
}

@test "evaluate-relevance: SKIP verdict begins with the literal keyword" {
  cat > docs/problems/open/112-skip-verdict.md <<EOF
# Problem 112: skip-verdict

**Status**: Open
**Reported**: $FRESH_DATE

## Description

packages/itil/scripts/anything.sh
EOF
  run "$SCRIPT" docs/problems/open/112-skip-verdict.md
  [ "$status" -eq 2 ]
  [[ "${lines[0]}" == "SKIP "* ]]
}
