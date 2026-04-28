#!/usr/bin/env bats

# @problem P118 — docs/problems/README.md drifts from filesystem truth
# across sessions despite P094 (refresh-on-create) and P062 (refresh-on-
# transition) both being Closed. This script is the cross-session
# robustness layer ON TOP of those per-operation contracts.
#
# Contract: `reconcile-readme.sh [<problems-dir>]` is a diagnose-only
# mechanical drift detector. It reads `<problems-dir>/<NNN>-*.<status>.md`
# files (default `docs/problems`), parses the WSJF Rankings + Verification
# Queue + Closed tables in `<problems-dir>/README.md`, and reports each
# disagreement between README claim and filesystem ground truth.
#
# Exit codes:
#   0 = clean (README matches filesystem for every parsed row)
#   1 = drift detected (structured diff to stdout, one row per drift)
#   2 = parse error (README missing or malformed beyond recovery)
#
# Diff output budget per ADR-038 progressive disclosure: each diff row
# ≤ 150 bytes; output is consumed by Claude in agent context, so it
# must stay terse and machine-readable, not narrative.
#
# The script is read-only — it does NOT mutate the README. Narrative
# content (the long "Last reviewed" prose paragraph, the Closed-section
# closure-via free text) is preserved by the agent-applied-edits pattern
# in the `/wr-itil:reconcile-readme` skill which wraps this script.
#
# @jtbd JTBD-006 (Progress the Backlog While I'm Away — orchestrators
# read the README to pick the highest-WSJF actionable ticket; drift
# burns iterations on already-transitioned tickets)
# @jtbd JTBD-001 (Enforce Governance Without Slowing Down — read-only
# diagnostic, no interactive friction on the happy path)
#
# Cross-reference:
#   P118: docs/problems/118-readme-drifts-from-filesystem-truth-despite-refresh-contracts-closed.open.md
#   ADR-014 amended (Reconciliation as preflight robustness layer)
#   ADR-022 — Verification Pending lifecycle status conventions
#   ADR-038 — Progressive disclosure (per-row byte budget on diff output)
#   ADR-005 — Plugin testing strategy (script-level bats governance)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/reconcile-readme.sh"
  FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "reconcile-readme: script exists" {
  [ -f "$SCRIPT" ]
}

@test "reconcile-readme: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Exit code 0: clean state ─────────────────────────────────────────────────

@test "reconcile-readme: exit 0 when WSJF Rankings matches filesystem .open.md set" {
  cat > "$FIXTURE_DIR/100-foo.open.md" <<EOF
# Problem 100: Foo
**Status**: Open
**WSJF**: 5.0
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 5.0 | P100 | Foo | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
}

# ── Exit code 1: drift cases ─────────────────────────────────────────────────

@test "reconcile-readme: exit 1 when README ranks ticket Open but file is .closed.md (P074 case)" {
  # The exact symptom this ticket addresses: a prior session closed the
  # ticket without staging the README refresh, leaving the WSJF Rankings
  # row stale in subsequent sessions.
  cat > "$FIXTURE_DIR/074-foo.closed.md" <<EOF
# Problem 074: Foo
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 6.0 | P074 | Foo | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  # Output mentions P074 as the drift entry.
  echo "$output" | grep -q "P074"
}

@test "reconcile-readme: exit 1 when ticket on disk as .open.md is missing from WSJF Rankings" {
  # The other half of the drift class: a ticket created in a prior
  # session that never refreshed README — the file exists but the
  # row was never inserted.
  cat > "$FIXTURE_DIR/079-bar.open.md" <<EOF
# Problem 079: Bar
**Status**: Open
**WSJF**: 3.0
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P079"
}

@test "reconcile-readme: exit 1 when README ranks ticket Open but file is .verifying.md (P110 case)" {
  cat > "$FIXTURE_DIR/110-baz.verifying.md" <<EOF
# Problem 110: Baz
**Status**: Verification Pending
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 4.0 | P110 | Baz | 8 Med | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P110"
}

@test "reconcile-readme: exit 1 when Verification Queue lists ticket but file is .closed.md (stale VQ)" {
  cat > "$FIXTURE_DIR/056-qux.closed.md" <<EOF
# Problem 056: Qux
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|
| P056 | Qux | 2026-01-01 | yes |

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P056"
}

# ── Diff output is structured + within byte budget (ADR-038) ────────────────

@test "reconcile-readme: drift output emits one structured line per drift entry" {
  # Two distinct drift entries; output should contain at least two
  # rows (one per ID).
  cat > "$FIXTURE_DIR/074-foo.closed.md" <<EOF
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/079-bar.open.md" <<EOF
**WSJF**: 3.0
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 6.0 | P074 | Foo | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  # Both drift IDs surface in output.
  echo "$output" | grep -q "P074"
  echo "$output" | grep -q "P079"
}

@test "reconcile-readme: each diff row stays under 150 bytes (ADR-038 progressive-disclosure budget)" {
  cat > "$FIXTURE_DIR/074-foo.closed.md" <<EOF
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 6.0 | P074 | Foo | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  # Filter to data rows only (drift entries start with a marker char).
  while IFS= read -r line; do
    # Skip empty lines + the header line.
    [ -z "$line" ] && continue
    case "$line" in
      DRIFT*|MISSING*|STALE*|MISMATCH*)
        len=${#line}
        [ "$len" -le 150 ] || {
          echo "Diff row over 150 bytes ($len): $line" >&2
          return 1
        }
        ;;
    esac
  done <<< "$output"
}

# ── Exit code 2: parse error ────────────────────────────────────────────────

@test "reconcile-readme: exit 2 when README is missing" {
  cat > "$FIXTURE_DIR/100-foo.open.md" <<EOF
**WSJF**: 5.0
EOF
  # No README.md created.
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 2 ]
}

@test "reconcile-readme: exit 2 when README has no WSJF Rankings header (parse error)" {
  cat > "$FIXTURE_DIR/100-foo.open.md" <<EOF
**WSJF**: 5.0
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
# Problem Backlog

This README has no WSJF Rankings section header.
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 2 ]
}

# ── Verification Pending tickets must NOT appear in WSJF Rankings (ADR-022) ─

@test "reconcile-readme: .verifying.md tickets in WSJF Rankings are flagged as drift" {
  # ADR-022 — Verification Pending tickets are excluded from WSJF Rankings
  # (they belong in the Verification Queue section). A .verifying.md row
  # in the dev-work table is drift.
  cat > "$FIXTURE_DIR/105-verify.verifying.md" <<EOF
**Status**: Verification Pending
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 8.0 | P105 | Verify | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P105"
}

# ── Default problems-dir resolution ─────────────────────────────────────────

@test "reconcile-readme: defaults to ./docs/problems when no arg passed" {
  # cd into a fixture root that has docs/problems/README.md to confirm
  # the default-arg branch executes.
  mkdir -p "$FIXTURE_DIR/docs/problems"
  cat > "$FIXTURE_DIR/docs/problems/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  cd "$FIXTURE_DIR"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Parked tickets are excluded (ADR-022 multiplier 0 + own section) ────────

@test "reconcile-readme: .parked.md tickets are not flagged as missing from WSJF Rankings" {
  # Parked tickets live in their own section; they are NOT expected in
  # WSJF Rankings. A .parked.md file with no WSJF Rankings row is
  # correct, not drift.
  cat > "$FIXTURE_DIR/005-parked.parked.md" <<EOF
**Status**: Parked
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|

## Parked

| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|
| P005 | Parked | Upstream | 2026-04-16 |
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
}

# ── Closed tickets never tracked (P001-P028 don't all appear) ───────────────

@test "reconcile-readme: .closed.md tickets absent from Closed section are not drift (history is partial)" {
  # The Closed section is curated narrative — it lists "recently closed
  # this session" with closure-via prose. It is NOT exhaustive over
  # every .closed.md file. A .closed.md file absent from the Closed
  # section is allowed; the only Closed-section drift is when a row
  # in that section names an ID that is NOT .closed.md on disk.
  cat > "$FIXTURE_DIR/001-old.closed.md" <<EOF
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
}

# ── P133: defensive rename of `status` local → `ticket_status` ──────────────

@test "reconcile-readme: drift detection still works when caller-environment exports status=anything (P133 regression)" {
  # P133 — `status` is a read-only built-in under zsh (alias for `$?`). The
  # script's `#!/usr/bin/env bash` shebang means it never runs under zsh
  # directly, but a caller may export `status=…` into the script's environment
  # and the script must not depend on the bash-builtin name for its own state.
  # After the P133 rename (`status` → `ticket_status`), the script's drift
  # detection is independent of any caller-set `status` env var. This test
  # asserts the behaviour: caller exports `status=junk`, script still emits
  # correct drift output (does not pick up the caller's value).
  cat > "$FIXTURE_DIR/074-foo.closed.md" <<EOF
**Status**: Closed
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 6.0 | P074 | Foo | 12 High | Open | M |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
EOF
  # `env status=junk` sets the env var on the script invocation; bats's
  # `run` still captures the script exit code into the test-scope `$status`.
  run env status=junk "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P074"
  # Drift line must report actual filesystem status (`closed`), not the
  # caller's bogus `junk` value — script reads from FS_STATUS, not env.
  echo "$output" | grep -q "actual=closed"
  ! echo "$output" | grep -q "actual=junk"
}

# ── README Closed-section row pointing to non-existent or wrong-status file ──

@test "reconcile-readme: exit 1 when Closed section names ID that is .open.md on disk" {
  cat > "$FIXTURE_DIR/099-still-open.open.md" <<EOF
**Status**: Open
**WSJF**: 3.0
EOF
  cat > "$FIXTURE_DIR/README.md" <<'EOF'
## WSJF Rankings

| WSJF | ID | Title | Severity | Status | Effort |
|------|-----|-------|----------|--------|--------|
| 3.0 | P099 | Still Open | 15 High | Open | L |

## Verification Queue

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|

## Closed

| ID | Title | Closed via |
|----|-------|-----------|
| P099 | Still Open | (incorrectly listed) |
EOF
  run "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "P099"
}
