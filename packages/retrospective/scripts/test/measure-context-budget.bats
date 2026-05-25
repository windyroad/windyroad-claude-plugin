#!/usr/bin/env bats

# @problem P101 — wr-retrospective has no context-usage analysis. ADR-043
# (Progressive context-usage measurement and reporting for retrospective
# sessions) introduces a read-only diagnostic script
# `packages/retrospective/scripts/measure-context-budget.sh` as the cheap-
# layer measurement primitive. This fixture pins the script's behavioural
# contract.
#
# Contract: `measure-context-budget.sh [<project-root>]` walks the
# session's on-disk context contributors and reports per-source bucket
# byte totals. Default project-root is $CLAUDE_PROJECT_DIR if set, else
# the current working directory.
#
# Threshold default 10240 (the 5% / 200K cheap-layer envelope per ADR-043),
# overridable via CONTEXT_BUDGET_MAX_BYTES.
#
# Exit codes:
#   0 = always (advisory only — overflow is signal, not failure)
#   2 = parse error (project root missing or unreadable)
#
# Output format (one line per bucket, terse machine-readable per ADR-038
# progressive-disclosure budget — ≤150 bytes per row):
#   BUCKET <name> bytes=<N>
#   BUCKET <name> not-measured reason=<reason>
#
# Plus one trailing diagnostic row carrying the threshold:
#   THRESHOLD bytes=<N>
#
# @adr ADR-043 (Progressive context-usage measurement; this script is the
#   measurement primitive)
# @adr ADR-038 (Progressive disclosure — per-row byte budget)
# @adr ADR-026 (Agent output grounding — explicit not-measured sentinels)
# @adr ADR-013 Rule 1 / Rule 6 — interactive vs AFK
# @adr ADR-005 (Plugin testing strategy — behavioural fixture)
# @adr ADR-037 (Skill testing strategy — bats-contract precedent)
# @jtbd JTBD-001 / JTBD-005 / JTBD-006

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/measure-context-budget.sh"
  FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "measure-context-budget: script file exists at expected path" {
  [ -f "$SCRIPT" ]
}

@test "measure-context-budget: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Exit codes ──────────────────────────────────────────────────────────────

@test "measure-context-budget: empty project root exits 0 (advisory)" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
}

@test "measure-context-budget: missing project root exits 2 (parse error)" {
  run bash "$SCRIPT" "/path/that/does/not/exist/zz_$$"
  [ "$status" -eq 2 ]
}

# ── Output shape — every run emits all buckets ──────────────────────────────

@test "measure-context-budget: output contains hooks bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^BUCKET hooks '
}

@test "measure-context-budget: output contains skills bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET skills '
}

@test "measure-context-budget: output contains briefing bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET briefing '
}

@test "measure-context-budget: output contains decisions bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET decisions '
}

@test "measure-context-budget: output contains problems bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET problems '
}

@test "measure-context-budget: output contains jtbd bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET jtbd '
}

@test "measure-context-budget: output contains project-claude-md bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET project-claude-md '
}

@test "measure-context-budget: output contains memory bucket row" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET memory '
}

# ── Framework-injected sentinel (ADR-026 ungrounded-field rule) ─────────────

@test "measure-context-budget: framework-injected bucket emits not-measured sentinel" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^BUCKET framework-injected not-measured '
  echo "$output" | grep -q 'reason=framework-injected-no-on-disk-source'
}

# ── Surface-absent sentinels (ADR-026 ungrounded-field rule) ────────────────
# Empty fixture has no docs/decisions/, docs/problems/, docs/jtbd/, etc.

@test "measure-context-budget: empty fixture marks decisions not-measured" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET decisions not-measured '
}

@test "measure-context-budget: empty fixture marks problems not-measured" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET problems not-measured '
}

@test "measure-context-budget: empty fixture marks jtbd not-measured" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET jtbd not-measured '
}

@test "measure-context-budget: empty fixture marks briefing not-measured" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET briefing not-measured '
}

@test "measure-context-budget: empty fixture marks project-claude-md not-measured" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^BUCKET project-claude-md not-measured '
}

# ── Surface-present byte counts ─────────────────────────────────────────────

@test "measure-context-budget: populated decisions bucket reports byte count" {
  mkdir -p "$FIXTURE_DIR/docs/decisions"
  printf '# ADR-001\nbody body body\n' > "$FIXTURE_DIR/docs/decisions/001-foo.proposed.md"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE '^BUCKET decisions bytes=[0-9]+$'
  # Sanity: byte count is non-zero
  decisions_line=$(echo "$output" | grep '^BUCKET decisions ')
  bytes_value="${decisions_line##*bytes=}"
  [ "$bytes_value" -gt 0 ]
}

@test "measure-context-budget: populated problems bucket reports byte count" {
  mkdir -p "$FIXTURE_DIR/docs/problems"
  printf '# Problem 001\nbody\n' > "$FIXTURE_DIR/docs/problems/001-foo.open.md"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -qE '^BUCKET problems bytes=[0-9]+$'
}

# ── Dual-tolerant per-state subdir enumeration (P182 / RFC-002 T4 / ADR-031) ─
# RFC-002 T5 migrated problem tickets from the flat layout
# (docs/problems/<NNN>-*.<state>.md) to per-state subdirs
# (docs/problems/<state>/<NNN>-*.md). The flat-only glob misses the subdir
# tickets and under-counts the bucket ~99% post-migration (P182). The fix
# walks BOTH layouts and dedups on ticket ID — the per-state subdir copy
# wins on collision per ADR-031 §"Authoritative state signal" — mirroring
# the proven reconcile-readme.sh pattern.

@test "measure-context-budget: per-state subdir problem tickets are counted" {
  mkdir -p "$FIXTURE_DIR/docs/problems/open" "$FIXTURE_DIR/docs/problems/known-error"
  printf '# Problem 100\nbody body body\n' > "$FIXTURE_DIR/docs/problems/open/100-foo.md"
  printf '# Problem 101\nbody body\n' > "$FIXTURE_DIR/docs/problems/known-error/101-bar.md"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE '^BUCKET problems bytes=[0-9]+$'
  problems_line=$(echo "$output" | grep '^BUCKET problems ')
  bytes_value="${problems_line##*bytes=}"
  [ "$bytes_value" -gt 0 ]
}

@test "measure-context-budget: problems bucket sums flat + per-state subdir tickets" {
  mkdir -p "$FIXTURE_DIR/docs/problems/open" "$FIXTURE_DIR/docs/problems/verifying"
  # Flat top-level (README + a pre-migration flat ticket) and per-state
  # subdir tickets must all contribute to the bucket total.
  printf '# Problems index\nrow\n' > "$FIXTURE_DIR/docs/problems/README.md"
  printf '# Problem 050 legacy flat\nbody\n' > "$FIXTURE_DIR/docs/problems/050-legacy.open.md"
  printf '# Problem 100\nbody body\n' > "$FIXTURE_DIR/docs/problems/open/100-foo.md"
  printf '# Problem 101\nbody body body body\n' > "$FIXTURE_DIR/docs/problems/verifying/101-bar.md"
  expected=0
  for f in "$FIXTURE_DIR/docs/problems/README.md" \
           "$FIXTURE_DIR/docs/problems/050-legacy.open.md" \
           "$FIXTURE_DIR/docs/problems/open/100-foo.md" \
           "$FIXTURE_DIR/docs/problems/verifying/101-bar.md"; do
    b=$(wc -c < "$f" | tr -d ' ')
    expected=$(( expected + b ))
  done
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  problems_line=$(echo "$output" | grep '^BUCKET problems ')
  bytes_value="${problems_line##*bytes=}"
  [ "$bytes_value" -eq "$expected" ]
}

@test "measure-context-budget: same ticket in flat + per-state subdir counted once (per-state wins)" {
  # Mid-migration race: the same ticket ID exists as a flat file
  # (200-dup.open.md) AND a per-state subdir file (open/200-dup.md) with a
  # DIFFERENT byte size. ID-keyed dedup must count it once; the per-state
  # subdir copy wins (ADR-031). Asserting the total equals the subdir file's
  # size alone proves both: counted-once (not flat+subdir) and per-state-wins
  # (subdir size, not flat size).
  mkdir -p "$FIXTURE_DIR/docs/problems/open"
  printf 'flat\n' > "$FIXTURE_DIR/docs/problems/200-dup.open.md"
  printf 'per-state subdir copy is longer\n' > "$FIXTURE_DIR/docs/problems/open/200-dup.md"
  subdir_bytes=$(wc -c < "$FIXTURE_DIR/docs/problems/open/200-dup.md" | tr -d ' ')
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  problems_line=$(echo "$output" | grep '^BUCKET problems ')
  bytes_value="${problems_line##*bytes=}"
  [ "$bytes_value" -eq "$subdir_bytes" ]
}

@test "measure-context-budget: populated briefing bucket reports byte count" {
  mkdir -p "$FIXTURE_DIR/docs/briefing"
  printf '# Topic\nentry\n' > "$FIXTURE_DIR/docs/briefing/foo.md"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -qE '^BUCKET briefing bytes=[0-9]+$'
}

@test "measure-context-budget: project CLAUDE.md reports byte count" {
  printf '# Project\ninstructions\n' > "$FIXTURE_DIR/CLAUDE.md"
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -qE '^BUCKET project-claude-md bytes=[0-9]+$'
  claude_md_line=$(echo "$output" | grep '^BUCKET project-claude-md ')
  bytes_value="${claude_md_line##*bytes=}"
  [ "$bytes_value" -gt 0 ]
}

# ── Threshold ────────────────────────────────────────────────────────────────

@test "measure-context-budget: trailing THRESHOLD row emitted" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE '^THRESHOLD bytes=[0-9]+$'
}

@test "measure-context-budget: default threshold is 10240" {
  unset CONTEXT_BUDGET_MAX_BYTES
  run bash "$SCRIPT" "$FIXTURE_DIR"
  echo "$output" | grep -q '^THRESHOLD bytes=10240$'
}

@test "measure-context-budget: CONTEXT_BUDGET_MAX_BYTES override respected" {
  CONTEXT_BUDGET_MAX_BYTES=42 run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^THRESHOLD bytes=42$'
}

# ── Per-row byte budget (ADR-038 progressive-disclosure ≤150 bytes/row) ─────

@test "measure-context-budget: every row is at most 150 bytes" {
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  while IFS= read -r line; do
    [ "${#line}" -le 150 ]
  done <<< "$output"
}

# ── Read-only contract — script does not mutate the project tree ────────────

@test "measure-context-budget: read-only — fixture tree unchanged after run" {
  mkdir -p "$FIXTURE_DIR/docs/decisions"
  printf '# ADR-001\nbody\n' > "$FIXTURE_DIR/docs/decisions/001-foo.proposed.md"
  pre_hash=$(find "$FIXTURE_DIR" -type f -exec cksum {} \; 2>/dev/null | sort | cksum | awk '{print $1}')
  run bash "$SCRIPT" "$FIXTURE_DIR"
  [ "$status" -eq 0 ]
  post_hash=$(find "$FIXTURE_DIR" -type f -exec cksum {} \; 2>/dev/null | sort | cksum | awk '{print $1}')
  [ "$pre_hash" = "$post_hash" ]
}

# ── CLAUDE_PROJECT_DIR fallback when no arg ─────────────────────────────────

@test "measure-context-budget: CLAUDE_PROJECT_DIR env var respected when no arg" {
  CLAUDE_PROJECT_DIR="$FIXTURE_DIR" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^BUCKET hooks '
}
