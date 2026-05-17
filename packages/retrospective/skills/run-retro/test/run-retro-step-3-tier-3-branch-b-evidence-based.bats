#!/usr/bin/env bats
#
# P247: run-retro SKILL.md Step 3 Tier 3 Branch B MUST encode the
# evidence-based rotation contract — "leave-as-is" is eliminated; the
# fall-through when none of the three concrete triggers (subtopic /
# date / ≥3 noise entries) fire is **split-by-date as the safe default**,
# mirroring Branch A's existing precedent.
#
# This file mirrors the architecture established for P148's Stage 1
# fallback-gating clause: behavioural assertions exercise the
# enforcement layer (check-briefing-budgets.sh) for the OVER /
# MUST_SPLIT signal shape that drives Branch B input, plus narrow
# structural backstops linking SKILL.md prose (canonical human source)
# to the enforcement layer + driver-ticket evidence trail.
#
# Architect verdict (2026-05-18, P247): the rotation decision itself
# is silent agent judgement per ADR-044 framework-mediated surface
# "Briefing add / remove / rotate" — there is no script to behaviourally
# exercise the rotation. The script-side behavioural coverage for the
# Branch B INPUT signal (OVER without MUST_SPLIT) lives in
# `packages/retrospective/scripts/test/check-briefing-budgets.bats`;
# this file is the SKILL-prose backstop that confirms the prose names
# the evidence-based contract terms and the driver ticket.
#
# # @adr ADR-037 permitted exception — narrowest justifiable scope.
# # @adr ADR-044 framework-mediated surface boundary (silent agent rotation).
# # @adr ADR-061 evidence-based-not-time-based principle (parent class).
# # @adr ADR-013 Rule 5 (policy-authorised silent proceed).
# # @adr ADR-052 behavioural-tests-default (structural backstops permitted
# #              for SKILL-prose-to-enforcement-layer linkage per P081).
# # @ticket P247 — Branch B fictional-defer (driver).
# # @ticket P246 — sibling-class at cohort-graduation surface (mirror precedent).
# # @ticket P145 — predecessor at this surface (MUST_SPLIT subset already
# #                evidence-based; P247 generalises to OVER subset).
# # @ticket P081 — behavioural-tests-preferred direction.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/retrospective/skills/run-retro/SKILL.md"
  SCRIPT="$REPO_ROOT/packages/retrospective/scripts/check-briefing-budgets.sh"
  FIXTURE_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: write a markdown file with N bytes of body content.
write_briefing_entry() {
  local path="$1"
  local target_bytes="$2"
  : > "$path"
  printf '# Topic\n\n' >> "$path"
  local header_size
  header_size=$(wc -c < "$path" | tr -d ' ')
  local body_target=$(( target_bytes - header_size ))
  if [ "$body_target" -gt 0 ]; then
    local line="- entry text padded out to a known length for byte-budget testing.   "
    local line_size=${#line}
    line+=$'\n'
    local line_count=$(( (body_target + line_size) / (line_size + 1) ))
    local i=0
    while [ "$i" -lt "$line_count" ]; do
      printf '%s' "$line" >> "$path"
      i=$(( i + 1 ))
    done
  fi
}

# ── Behavioural: Branch B INPUT signal shape ────────────────────────────────
#
# Branch B is defined as "file has only OVER line (ratio between 1.0× and
# 2.0× ceiling)". The check-briefing-budgets.sh script is the enforcement
# layer that produces this signal. These assertions confirm the signal
# shape the SKILL contract reads — they exercise the script (not the
# agent's rotation choice), giving Branch B its input definition.

@test "Branch B input: file at 1.5x ratio emits OVER without MUST_SPLIT (Branch B selector)" {
  # 1.5x of default 5120 ceiling = 7680 bytes — the canonical Branch B input.
  mkdir -p "$FIXTURE_DIR/briefing"
  write_briefing_entry "$FIXTURE_DIR/briefing/branch-b-canonical.md" 7680
  run "$SCRIPT" "$FIXTURE_DIR/briefing"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER branch-b-canonical.md bytes=[0-9]+ threshold=5120"
  ! echo "$output" | grep -q "^MUST_SPLIT branch-b-canonical.md"
}

@test "Branch B input: file at 1.0x exactly emits OVER without MUST_SPLIT (Branch B lower edge)" {
  mkdir -p "$FIXTURE_DIR/briefing"
  printf '%.0s.' $(seq 1 5120) > "$FIXTURE_DIR/briefing/branch-b-lower-edge.md"
  run "$SCRIPT" "$FIXTURE_DIR/briefing"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER branch-b-lower-edge.md bytes=5120 threshold=5120"
  ! echo "$output" | grep -q "^MUST_SPLIT branch-b-lower-edge.md"
}

@test "Branch B input: file just under 2.0x (e.g. 1.96x) emits OVER without MUST_SPLIT (P247 evidence — hooks-and-gates-archive.md at 1.96x was deferred)" {
  # 1.96x of 5120 = 10035 bytes — the upper edge of Branch B, exactly the
  # case the 2026-05-17 session-4 wrap retro hit and deferred via the
  # now-eliminated "leave-as-is" branch.
  mkdir -p "$FIXTURE_DIR/briefing"
  printf '%.0s.' $(seq 1 10035) > "$FIXTURE_DIR/briefing/upper-edge.md"
  run "$SCRIPT" "$FIXTURE_DIR/briefing"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER upper-edge.md bytes=10035 threshold=5120"
  ! echo "$output" | grep -q "^MUST_SPLIT upper-edge.md"
}

@test "Branch B input: file UNDER threshold emits NEITHER signal (no Branch B action)" {
  # The pre-existing skip path: file below threshold = no rotation pass
  # entry. The SKILL contract's "Empty stdout means no files are over
  # budget — skip the rest of this pass" precedent is preserved.
  mkdir -p "$FIXTURE_DIR/briefing"
  write_briefing_entry "$FIXTURE_DIR/briefing/within-budget.md" 3000
  run "$SCRIPT" "$FIXTURE_DIR/briefing"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q "within-budget.md"
}

@test "Branch B / Branch A boundary: file at exactly 2.0x emits BOTH OVER and MUST_SPLIT (Branch A selector)" {
  # The contract boundary: 2.0x and above is Branch A (rotation required,
  # no defer options eligible). 1.0x-2.0x is Branch B. The script-side
  # MUST_SPLIT signal is the discriminator the SKILL prose reads.
  mkdir -p "$FIXTURE_DIR/briefing"
  printf '%.0s.' $(seq 1 10240) > "$FIXTURE_DIR/briefing/exactly-2x.md"
  run "$SCRIPT" "$FIXTURE_DIR/briefing"
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "^OVER exactly-2x.md bytes=10240 threshold=5120"
  echo "$output" | grep -E "^MUST_SPLIT exactly-2x.md reason=ratio-exceeds-2x"
}

# ── Structural backstops: SKILL.md prose contract terms (narrow per P081) ───
#
# These assertions link SKILL.md prose (canonical human-readable source)
# to the evidence-based-rotation contract and the driver ticket. Without
# these links, the prose contract could drift independently from the
# enforcement layer + driver-ticket evidence trail. Per P081, the scope
# is narrowed to the smallest set of tokens that prove the contract
# terms exist in the prose; assertions intentionally avoid coupling to
# line numbers or sentence-level structure.

@test "Branch B prose: SKILL.md no longer permits the 'leave-as-is' fall-through (P247 fix verification)" {
  # The contract negative-assertion: the eliminated branch's literal
  # token "leave-as-is" must NOT appear as a permitted Branch B
  # rotation option. The token may legitimately appear inside a
  # historical-reference context (e.g. "the eliminated 'leave-as-is'
  # branch") — that's why we don't grep for the bare token but for the
  # specific surface that previously authorised the defer.
  ! grep -F "Else: **leave-as-is**" "$SKILL_MD"
}

@test "Branch B prose: SKILL.md names 'split-by-date (safe default)' as the Branch B fall-through (P247 fix verification)" {
  # The contract positive-assertion: the new fall-through must be named
  # explicitly as "split-by-date (safe default)" — the same naming
  # Branch A already uses, so a reader of the prose sees the alignment
  # without having to cross-reference Branch A's bullet.
  grep -F "split-by-date (safe default)" "$SKILL_MD"
}

@test "Branch B prose: SKILL.md cites P247 as the driver ticket (audit-trail link)" {
  # Audit-trail link: the prose names P247 so future readers can locate
  # the evidence trail (user correction quote, sibling-class relationship
  # to P246, the 14-file evidence from 2026-05-17 session 4 wrap retro).
  grep -F "P247" "$SKILL_MD"
}

@test "Branch B prose: SKILL.md cites P246 sibling fix as the evidence-based principle precedent (cross-class linkage)" {
  # Cross-class linkage: P246 (cohort-graduation surface) is the immediate
  # sibling fix. The Branch B prose must cite it so the evidence-based-
  # not-time-based principle is discoverable as a class, not a one-off
  # SKILL fix.
  grep -F "P246" "$SKILL_MD"
}

@test "Branch B prose: SKILL.md cites ADR-044 framework-mediated surface for silent rotation (governance link)" {
  # Governance link: per architect verdict, Branch B's silent-rotation
  # discipline is authorised by ADR-044's framework-resolution boundary
  # ("Briefing add / remove / rotate" line 77). The prose must cite the
  # ADR so a reader sees the authority for not firing AskUserQuestion
  # per file in Branch B's fall-through.
  grep -F "ADR-044" "$SKILL_MD"
}

@test "Branch B prose: SKILL.md cites ADR-013 Rule 5 for policy-authorised silent proceed (governance link)" {
  # Companion governance link: ADR-013 Rule 5 is the originating rule
  # for silent-proceed under policy. Branch B inherits this discipline;
  # the citation makes the rule chain explicit.
  grep -F "ADR-013 Rule 5" "$SKILL_MD"
}
