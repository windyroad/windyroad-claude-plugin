#!/usr/bin/env bats

# @problem P134 — docs/problems/README.md line 3 narrative-blob accumulator
# bloat. Sibling to P099 (briefing tier 3) on a different surface. The
# "Last reviewed" line accumulates session-summary fragments unbounded;
# at ~62 KB it breaks the Read tool entirely (25K-token limit on the
# whole file regardless of offset/limit). P134 promotes the same
# advisory-triplet pattern P099 documented (advisory script + behavioural
# bats + ADR-040-tier-budget enforcement clause) to this surface.
#
# Contract: `check-problems-readme-budget.sh [<readme-path>]` is a
# diagnose-only advisory script. It reads `docs/problems/README.md`
# (or the supplied path), measures the byte size of line 3, and reports
# overflow when line 3 is at or above the configured threshold (default
# 5120 bytes per ADR-040 Tier 3 envelope; overridable via the
# `PROBLEMS_README_LINE3_MAX_BYTES` env var).
#
# Exit codes:
#   0 = always (advisory only — overflow is signal, not failure)
#   2 = parse error (README path missing or unreadable)
#
# Output format on overflow (one line, terse machine-readable per
# ADR-038 progressive-disclosure budget):
#   OVER <readme-path> line=3 bytes=<N> threshold=<N>
#
# Output is empty (no lines) when line 3 is under the threshold.
#
# The script is read-only — it does NOT mutate the README. Truncation
# is owned by the per-operation refresh contracts in `manage-problem`
# Step 5 P094 + Step 7 P062 (and the sibling skills `transition-problem`,
# `transition-problems`, `review-problems`, `reconcile-readme`).
#
# @jtbd JTBD-001 (Enforce Governance Without Slowing Down — restores
#   Read-tool affordance to the highest-traffic problems-management surface)
# @jtbd JTBD-006 (Progress the Backlog While I'm Away — every AFK iter's
#   manage-problem call previously paid an awk/grep workaround tax)
# @jtbd JTBD-101 (Extend the Suite with Clear Patterns — re-applies P099's
#   advisory-script + bats + ADR-tier-budget triplet to a new surface,
#   exactly the reusable shape ADR-040 line 92 documents)
#
# Cross-reference:
#   P134: docs/problems/134-docs-problems-readme-md-line-3-narrative-blob-accumulator-bloat-sibling-p099.*.md
#   P099: docs/problems/099-briefing-md-grows-unbounded-via-run-retro-appends-violating-progressive-disclosure.*.md
#   ADR-040 — Session-start briefing surface (Tier 3 budget; line 92's
#     reusable-pattern note explicitly names "problems index" as a
#     candidate surface for this triplet)
#   ADR-038 — Progressive disclosure (per-row terse budget)
#   ADR-013 Rule 6 — non-interactive fail-safe (advisory-only / exit 0)
#   ADR-005 — Plugin testing strategy (script-level bats governance)

setup() {
  SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$SCRIPTS_DIR/check-problems-readme-budget.sh"
  FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: write a problems README fixture with the given line-3 byte size.
# Lines 1, 2 are short header; line 3 is the synthetic "Last reviewed"
# blob padded to target_bytes; lines 4+ contain a short stub so the
# multi-line shape mirrors the production README.
write_problems_readme() {
  local path="$1"
  local target_bytes="$2"
  : > "$path"
  printf '# Problem Backlog\n\n' >> "$path"
  if [ "$target_bytes" -gt 0 ]; then
    # Build a single line of exactly target_bytes bytes (no trailing
    # newline before the byte budget completes). The newline at the
    # end is part of the file structure but not counted in line 3's
    # byte size — `awk 'NR==3' | wc -c` would include it; the script
    # under test must strip it to match the threshold semantics.
    local prefix='> Last reviewed: '
    local prefix_size=${#prefix}
    local body_target=$(( target_bytes - prefix_size ))
    if [ "$body_target" -gt 0 ]; then
      printf '%s' "$prefix" >> "$path"
      # Append body_target dots — a single contiguous line.
      printf '%.0s.' $(seq 1 "$body_target") >> "$path"
    else
      # target smaller than prefix — emit only the requested bytes
      printf '%.0s.' $(seq 1 "$target_bytes") >> "$path"
    fi
    printf '\n' >> "$path"
  else
    printf '\n' >> "$path"
  fi
  printf '\n## WSJF Rankings\n\n(stub)\n' >> "$path"
}

# ── Existence + executable ──────────────────────────────────────────────────

@test "check-problems-readme-budget: script exists" {
  [ -f "$SCRIPT" ]
}

@test "check-problems-readme-budget: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── Default-threshold behaviour (5120 bytes per ADR-040 Tier 3 envelope) ────

@test "check-problems-readme-budget: line 3 well under threshold produces no output and exits 0" {
  write_problems_readme "$FIXTURE_DIR/README.md" 1024
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-problems-readme-budget: line 3 at exactly the default threshold emits OVER (>= boundary)" {
  write_problems_readme "$FIXTURE_DIR/README.md" 5120
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER .*README.md line=3 bytes=5120 threshold=5120$"
}

@test "check-problems-readme-budget: line 3 well over threshold emits OVER with bytes + threshold" {
  write_problems_readme "$FIXTURE_DIR/README.md" 12000
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER .*README.md line=3 bytes=12000 threshold=5120$"
}

@test "check-problems-readme-budget: short line 3 (single fragment ~600 bytes) produces no output" {
  write_problems_readme "$FIXTURE_DIR/README.md" 600
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── Configurable threshold via env var ──────────────────────────────────────

@test "check-problems-readme-budget: PROBLEMS_README_LINE3_MAX_BYTES env var overrides default" {
  write_problems_readme "$FIXTURE_DIR/README.md" 3000
  # Default 5120: under threshold, no output. With env var set to 2000:
  # over threshold, expect OVER line.
  PROBLEMS_README_LINE3_MAX_BYTES=2000 run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER .*README.md line=3 bytes=3000 threshold=2000$"
}

@test "check-problems-readme-budget: env var threshold of 0 emits OVER for non-empty line 3 (sanity)" {
  write_problems_readme "$FIXTURE_DIR/README.md" 100
  PROBLEMS_README_LINE3_MAX_BYTES=0 run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER .*README.md line=3 bytes=100 threshold=0$"
}

# ── Argument and error handling ─────────────────────────────────────────────

@test "check-problems-readme-budget: defaults to docs/problems/README.md when no arg provided" {
  cd "$FIXTURE_DIR"
  mkdir -p docs/problems
  write_problems_readme docs/problems/README.md 8000
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER docs/problems/README.md line=3 bytes=8000 threshold=5120$"
}

@test "check-problems-readme-budget: missing README path exits 2 with parse error on stderr" {
  run "$SCRIPT" "$FIXTURE_DIR/does-not-exist/README.md"
  [ "$status" -eq 2 ]
  echo "$output" | grep -iE "not found|missing|does not exist"
}

@test "check-problems-readme-budget: file with no line 3 (only 2 lines) exits 0 with no output" {
  printf '# Problem Backlog\n\n' > "$FIXTURE_DIR/README.md"
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-problems-readme-budget: file with empty line 3 exits 0 with no output" {
  printf '# Problem Backlog\n\n\n## WSJF Rankings\n\n(stub)\n' > "$FIXTURE_DIR/README.md"
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── Read-only contract ──────────────────────────────────────────────────────

@test "check-problems-readme-budget: script does not mutate the README under audit" {
  write_problems_readme "$FIXTURE_DIR/README.md" 12000
  pre_hash=$(shasum -a 256 "$FIXTURE_DIR/README.md" | awk '{print $1}')
  run "$SCRIPT" "$FIXTURE_DIR/README.md"
  [ "$status" -eq 0 ]
  post_hash=$(shasum -a 256 "$FIXTURE_DIR/README.md" | awk '{print $1}')
  [ "$pre_hash" = "$post_hash" ]
}
