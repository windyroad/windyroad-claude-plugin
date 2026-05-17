#!/usr/bin/env bats
# Behavioural-fixture coverage for packages/risk-scorer/scripts/evaluate-graduation.sh
# per ADR-052 (behavioural tests default) and ADR-061 (dogfood graduation criteria).
#
# Phase 2a coverage — orthogonal-gate class (Class 3a). Maps to
# ADR-061 Confirmation criterion 2 items a-f.
#
# Phase 2b coverage — atomic-cohort class (Class 3b — Rule 3b cohort enumeration).
# Maps to ADR-061 Confirmation criterion 2 item g (full-cohort evaluation,
# max(Priority) across cohort tickets, atomic VP-blocked + halt propagation).
# Cohort detection reads docs/changesets-holding/README.md "Currently held"
# section and groups entries by shared reinstate-trigger prose (parenthetical
# elaborations stripped before grouping). Single-member "cohorts" fall back
# to class=3a (no Phase 2a regression).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/risk-scorer/scripts/evaluate-graduation.sh"
  SHIM="$REPO_ROOT/packages/risk-scorer/bin/wr-risk-scorer-evaluate-graduation"
  WORK_DIR="$(mktemp -d)"
  cd "$WORK_DIR"
  # Minimal git setup — fixture follows drain-register-queue.bats precedent
  # so dual-layout problem-ticket lookup (flat + per-state subdir) exercises
  # the same shape the script handles in canonical adopter trees.
  git init --quiet
  git config user.email "graduation-test@example.com"
  git config user.name "Graduation Test"
  git commit --quiet --allow-empty -m "init"
  mkdir -p docs/changesets-holding docs/problems/open docs/problems/known-error \
           docs/problems/verifying docs/problems/closed docs/problems/parked
}

teardown() {
  cd /
  rm -rf "$WORK_DIR"
}

# ----- Helpers -----

seed_problem() {
  # seed_problem <id-padded> <state> <priority> [<extra-body>]
  local id="$1" state="$2" priority="$3" extra="${4:-}"
  local path
  # Use per-state subdir layout (RFC-002 canonical post-migration shape)
  path="docs/problems/${state}/${id}-fixture-ticket.md"
  cat > "$path" <<EOF
# Problem ${id}: Fixture ticket

**Status**: ${state}
**Reported**: 2026-05-01
**Priority**: ${priority} (label) — Impact: 3 x Likelihood: $(( priority / 3 ))

## Description

Fixture body for graduation-evaluator tests.

${extra}
EOF
}

seed_problem_flat() {
  # seed_problem_flat <id-padded> <state> <priority>
  # Exercises the flat-layout half of the RFC-002 dual-tolerant glob.
  local id="$1" state="$2" priority="$3"
  cat > "docs/problems/${id}-fixture-flat.${state}.md" <<EOF
# Problem ${id}: Fixture flat ticket

**Status**: ${state}
**Reported**: 2026-05-01
**Priority**: ${priority} (label) — Impact: 3 x Likelihood: $(( priority / 3 ))

## Description

Flat-layout fixture body for graduation-evaluator tests.
EOF
}

seed_changeset() {
  # seed_changeset <filename> [<body>]
  local filename="$1" body="${2:-Default fixture changeset body.}"
  cat > "docs/changesets-holding/${filename}" <<EOF
---
'@windyroad/itil': minor
---

${body}
EOF
}

# ----- Smoke tests -----

@test "shim wrapper exists and is executable" {
  [ -x "$SHIM" ]
}

@test "shim resolves canonical script (not exit 127)" {
  # Empty holding-area → exit 1 (no-op caller signal); but not exit 127.
  run "$SHIM" "$WORK_DIR"
  [ "$status" -ne 127 ]
}

@test "missing docs/ → exit 2 (invalid project root)" {
  cd "$BATS_TEST_TMPDIR"
  empty_dir=$(mktemp -d)
  run bash "$SCRIPT" "$empty_dir"
  [ "$status" -eq 2 ]
}

@test "missing holding dir → exit 1 (no-op signal)" {
  rm -rf docs/changesets-holding
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=0'
}

@test "empty holding dir → exit 1 (no-op signal)" {
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=0'
}

@test "README.md in holding-area is ignored" {
  echo "# Holding Area" > docs/changesets-holding/README.md
  run bash "$SCRIPT" "$WORK_DIR"
  # No other entries — exit 1 (empty after exclusion)
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=0'
}

# ----- ADR-061 Confirmation criterion 2 cases -----

# Case (a) — filename-convention join resolves correctly
@test "case (a): filename-convention join — wr-itil-p085-...md → P085 → Priority" {
  seed_problem "085" "open" "9"
  seed_changeset "wr-itil-p085-assistant-output-gate.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'changeset=wr-itil-p085-assistant-output-gate.md'
  echo "$output" | grep -q 'ticket=P085'
  echo "$output" | grep -q 'priority=9'
  echo "$output" | grep -q 'status=resolved'
  echo "$output" | grep -q 'class=3a'
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=1 resolved=1 vp_blocked=0 halts=0'
}

# Case (b) — body-grep fallback resolves when filename lacks convention
@test "case (b): body-grep fallback — non-conventional filename resolves via P<NNN> in body" {
  seed_problem "100" "known-error" "12"
  seed_changeset "feature-rollout-cohort.md" "Fixes P100. Related to feature work."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'changeset=feature-rollout-cohort.md'
  echo "$output" | grep -q 'ticket=P100'
  echo "$output" | grep -q 'priority=12'
  echo "$output" | grep -q 'status=resolved'
}

# Case (c) — multi-ticket changeset uses max(Priority)
@test "case (c): multi-ticket changeset uses max(Priority) across referenced set" {
  seed_problem "200" "open" "6"
  seed_problem "201" "open" "15"
  seed_problem "202" "open" "9"
  seed_changeset "multi-ticket-cohort.md" "References P200, P201, and P202 in body for max-priority test."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Max priority across P200(6) P201(15) P202(9) is 15 → ticket=P201
  echo "$output" | grep -q 'changeset=multi-ticket-cohort.md'
  echo "$output" | grep -q 'ticket=P201'
  echo "$output" | grep -q 'priority=15'
  echo "$output" | grep -q 'status=resolved'
}

# Case (d) — halt-and-prompt when no resolution path succeeds
@test "case (d.1): halt-no-resolution when filename lacks convention AND body has no P<NNN>" {
  seed_changeset "no-ticket-reference.md" "Body has no problem-ticket references at all."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'changeset=no-ticket-reference.md'
  echo "$output" | grep -q 'status=halt-no-resolution'
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=1 resolved=0 vp_blocked=0 halts=1'
}

@test "case (d.2): halt-no-resolution when filename references missing ticket" {
  # Filename references P999 but ticket file does not exist in fixture
  seed_changeset "wr-itil-p999-orphan.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'status=halt-no-resolution'
  echo "$output" | grep -q 'halts=1'
}

# Case (e) — VP-blocked ticket emitted with vp-blocked marker
@test "case (e): VP-blocked ticket emits status=vp-blocked (Rule 2 carve-out)" {
  seed_problem "300" "verifying" "10"
  seed_changeset "wr-itil-p300-mid-verification.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'changeset=wr-itil-p300-mid-verification.md'
  echo "$output" | grep -q 'ticket=P300'
  echo "$output" | grep -q 'priority=10'
  echo "$output" | grep -q 'status=vp-blocked'
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=1 resolved=0 vp_blocked=1 halts=0'
}

# Case (f) — status-agnostic Priority lookup (open, known-error, closed all resolve)
@test "case (f.1): open ticket resolves" {
  seed_problem "400" "open" "8"
  seed_changeset "wr-itil-p400-open.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P400'
  echo "$output" | grep -q 'status=resolved'
}

@test "case (f.2): known-error ticket resolves" {
  seed_problem "401" "known-error" "8"
  seed_changeset "wr-itil-p401-ke.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P401'
  echo "$output" | grep -q 'status=resolved'
}

@test "case (f.3): closed ticket resolves (Priority still readable)" {
  seed_problem "402" "closed" "8"
  seed_changeset "wr-itil-p402-closed.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P402'
  echo "$output" | grep -q 'status=resolved'
}

@test "case (f.4): parked ticket resolves" {
  seed_problem "403" "parked" "8"
  seed_changeset "wr-itil-p403-parked.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P403'
  echo "$output" | grep -q 'status=resolved'
}

# Dual-tolerant layout coverage (ADR-031 / RFC-002 migration window)
@test "flat-layout ticket resolves (RFC-002 pre-migration shape)" {
  seed_problem_flat "500" "open" "12"
  seed_changeset "wr-itil-p500-flat-layout.md"
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P500'
  echo "$output" | grep -q 'priority=12'
  echo "$output" | grep -q 'status=resolved'
}

# Mixed-state holding-area — multiple changesets in one run
@test "mixed-state holding-area — resolved + vp-blocked + halt in single run" {
  seed_problem "600" "open" "9"
  seed_problem "601" "verifying" "12"
  seed_problem "602" "open" "6"
  seed_changeset "wr-itil-p600-resolved.md"
  seed_changeset "wr-itil-p601-vp.md"
  seed_changeset "no-resolution-ref.md" "Generic body, no P references."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Counts: 3 total, 1 resolved (P600), 1 vp-blocked (P601), 1 halt
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=3 resolved=1 vp_blocked=1 halts=1'
}

# Filename-convention takes precedence over body-grep when both present
@test "filename takes precedence over body — wr-itil-p700-fix.md with P800 in body resolves to P700" {
  seed_problem "700" "open" "5"
  seed_problem "800" "open" "20"
  seed_changeset "wr-itil-p700-fix.md" "Also references P800 in body (should be ignored — filename wins)."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'ticket=P700'
  echo "$output" | grep -q 'priority=5'
  # Confirm body-referenced P800 was NOT picked up
  ! echo "$output" | grep -q 'ticket=P800'
}

# ----- Phase 2b: ADR-061 Confirmation criterion 2 item (g) — atomic-cohort -----

# Helper: seed a Currently held entry into docs/changesets-holding/README.md.
# Cohort detection reads this file and groups entries by shared reinstate-trigger
# prose (parenthetical elaborations stripped) — see evaluate-graduation.sh.
seed_holding_readme() {
  # seed_holding_readme <bullet-line> [<bullet-line>...]
  local readme="docs/changesets-holding/README.md"
  if [ ! -f "$readme" ]; then
    cat > "$readme" <<'EOF'
# Changesets Holding Area

## Currently held

EOF
  fi
  for bullet in "$@"; do
    printf '%s\n' "$bullet" >> "$readme"
  done
}

# Case (g.1) — two members sharing identical reinstate-trigger prose form a cohort
@test "case (g.1): two members sharing reinstate-trigger form Class 3b cohort" {
  seed_problem "170" "open" "9"
  seed_problem "171" "open" "12"
  seed_changeset "wr-itil-p170-phase4.md"
  seed_changeset "wr-itil-p171-phase3.md"
  seed_holding_readme \
    "- \`wr-itil-p170-phase4.md\` — patch. **Reinstate trigger**: Phase 3 + Phase 4 end-of-chain user verification fires." \
    "- \`wr-itil-p171-phase3.md\` — minor. **Reinstate trigger**: Phase 3 + Phase 4 end-of-chain user verification fires."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Both members emit class=3b
  echo "$output" | grep 'changeset=wr-itil-p170-phase4.md' | grep -q 'class=3b'
  echo "$output" | grep 'changeset=wr-itil-p171-phase3.md' | grep -q 'class=3b'
  # Both members share the same cohort= column
  cohort_p170=$(echo "$output" | grep 'changeset=wr-itil-p170-phase4.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  cohort_p171=$(echo "$output" | grep 'changeset=wr-itil-p171-phase3.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  [ -n "$cohort_p170" ]
  [ "$cohort_p170" = "$cohort_p171" ]
}

# Case (g.2) — cohort uses max(Priority) across all member tickets per ADR-061 Rule 3b
@test "case (g.2): cohort priority is max across member tickets" {
  seed_problem "172" "open" "6"
  seed_problem "173" "open" "15"
  seed_problem "174" "open" "9"
  seed_changeset "wr-itil-p172-slice-a.md"
  seed_changeset "wr-itil-p173-slice-b.md"
  seed_changeset "wr-itil-p174-slice-c.md"
  seed_holding_readme \
    "- \`wr-itil-p172-slice-a.md\` — patch. **Reinstate trigger**: RFC-009 end-of-chain verification." \
    "- \`wr-itil-p173-slice-b.md\` — patch. **Reinstate trigger**: RFC-009 end-of-chain verification." \
    "- \`wr-itil-p174-slice-c.md\` — patch. **Reinstate trigger**: RFC-009 end-of-chain verification."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Every cohort member carries priority=15 (max across P172/P173/P174)
  echo "$output" | grep 'changeset=wr-itil-p172-slice-a.md' | grep -q 'priority=15'
  echo "$output" | grep 'changeset=wr-itil-p173-slice-b.md' | grep -q 'priority=15'
  echo "$output" | grep 'changeset=wr-itil-p174-slice-c.md' | grep -q 'priority=15'
}

# Case (g.3) — one VP-blocked cohort member marks the entire cohort vp-blocked
@test "case (g.3): VP-blocked member blocks entire cohort (Rule 2 carve-out symmetric)" {
  seed_problem "175" "open" "9"
  seed_problem "176" "verifying" "12"
  seed_changeset "wr-itil-p175-slice-a.md"
  seed_changeset "wr-itil-p176-slice-b.md"
  seed_holding_readme \
    "- \`wr-itil-p175-slice-a.md\` — minor. **Reinstate trigger**: cohort verification fires." \
    "- \`wr-itil-p176-slice-b.md\` — minor. **Reinstate trigger**: cohort verification fires."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Both members report status=vp-blocked even though only P176 is in verifying state
  echo "$output" | grep 'changeset=wr-itil-p175-slice-a.md' | grep -q 'status=vp-blocked'
  echo "$output" | grep 'changeset=wr-itil-p176-slice-b.md' | grep -q 'status=vp-blocked'
}

# Case (g.4) — one halt-no-resolution member propagates to entire cohort (architect C1)
@test "case (g.4): halt-no-resolution member propagates to entire cohort" {
  seed_problem "177" "open" "9"
  # P178 deliberately NOT seeded → halt-no-resolution
  seed_changeset "wr-itil-p177-slice-a.md"
  seed_changeset "wr-itil-p178-slice-b.md"
  seed_holding_readme \
    "- \`wr-itil-p177-slice-a.md\` — patch. **Reinstate trigger**: shared cohort fires." \
    "- \`wr-itil-p178-slice-b.md\` — patch. **Reinstate trigger**: shared cohort fires."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Both members report status=halt-no-resolution — cohort cannot graduate partially
  echo "$output" | grep 'changeset=wr-itil-p177-slice-a.md' | grep -q 'status=halt-no-resolution'
  echo "$output" | grep 'changeset=wr-itil-p178-slice-b.md' | grep -q 'status=halt-no-resolution'
}

# Case (g.5) — single-member "cohort" falls back to Class 3a (no Phase 2a regression)
@test "case (g.5): single-member 'cohort' falls back to class=3a" {
  seed_problem "179" "open" "9"
  seed_changeset "wr-itil-p179-solo.md"
  seed_holding_readme \
    "- \`wr-itil-p179-solo.md\` — patch. **Reinstate trigger**: nobody else shares this trigger."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep 'changeset=wr-itil-p179-solo.md' | grep -q 'class=3a'
  ! echo "$output" | grep 'changeset=wr-itil-p179-solo.md' | grep -q 'cohort='
}

# Case (g.6) — parenthetical elaborations stripped before grouping
@test "case (g.6): parenthetical elaborations stripped before cohort grouping" {
  seed_problem "180" "open" "9"
  seed_problem "181" "open" "9"
  seed_changeset "wr-itil-p180-a.md"
  seed_changeset "wr-itil-p181-b.md"
  # P180 trigger has no parens; P181 trigger has parenthetical elaboration —
  # cohort detection must strip the paren content before comparison.
  seed_holding_readme \
    "- \`wr-itil-p180-a.md\` — patch. **Reinstate trigger**: end-of-chain fires." \
    "- \`wr-itil-p181-b.md\` — patch. **Reinstate trigger**: end-of-chain fires (only the slice 3 dependency remains, can defer per Reassessment criterion k)."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Despite different surface prose, the normalised trigger matches → both class=3b
  echo "$output" | grep 'changeset=wr-itil-p180-a.md' | grep -q 'class=3b'
  echo "$output" | grep 'changeset=wr-itil-p181-b.md' | grep -q 'class=3b'
}

# Case (g.7) — README without "Currently held" section → all entries fall back to class=3a
@test "case (g.7): README without 'Currently held' section falls back to class=3a (defensive)" {
  seed_problem "182" "open" "9"
  seed_problem "183" "open" "12"
  seed_changeset "wr-itil-p182-a.md"
  seed_changeset "wr-itil-p183-b.md"
  # README exists but has no "Currently held" section — cohort detection finds nothing.
  cat > "docs/changesets-holding/README.md" <<'EOF'
# Holding Area
Some unrelated content.
EOF
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep 'changeset=wr-itil-p182-a.md' | grep -q 'class=3a'
  echo "$output" | grep 'changeset=wr-itil-p183-b.md' | grep -q 'class=3a'
}

# Case (g.8) — README absent entirely → all entries fall back to class=3a (defensive)
@test "case (g.8): missing README falls back to class=3a" {
  seed_problem "184" "open" "9"
  seed_changeset "wr-itil-p184-a.md"
  # Do NOT create README at all
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | grep 'changeset=wr-itil-p184-a.md' | grep -q 'class=3a'
}

# Case (g.9) — multiple distinct cohorts in the same holding-area resolve independently
@test "case (g.9): multiple distinct cohorts coexist with distinct cohort= ids" {
  seed_problem "185" "open" "9"
  seed_problem "186" "open" "10"
  seed_problem "187" "open" "12"
  seed_problem "188" "open" "8"
  seed_changeset "wr-itil-p185-cohort-a.md"
  seed_changeset "wr-itil-p186-cohort-a.md"
  seed_changeset "wr-itil-p187-cohort-b.md"
  seed_changeset "wr-itil-p188-cohort-b.md"
  seed_holding_readme \
    "- \`wr-itil-p185-cohort-a.md\` — minor. **Reinstate trigger**: cohort alpha fires." \
    "- \`wr-itil-p186-cohort-a.md\` — minor. **Reinstate trigger**: cohort alpha fires." \
    "- \`wr-itil-p187-cohort-b.md\` — minor. **Reinstate trigger**: cohort beta fires." \
    "- \`wr-itil-p188-cohort-b.md\` — minor. **Reinstate trigger**: cohort beta fires."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  cohort_a1=$(echo "$output" | grep 'changeset=wr-itil-p185-cohort-a.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  cohort_a2=$(echo "$output" | grep 'changeset=wr-itil-p186-cohort-a.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  cohort_b1=$(echo "$output" | grep 'changeset=wr-itil-p187-cohort-b.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  cohort_b2=$(echo "$output" | grep 'changeset=wr-itil-p188-cohort-b.md' | sed -n 's/.*cohort=\([^ |]*\).*/\1/p')
  [ -n "$cohort_a1" ] && [ "$cohort_a1" = "$cohort_a2" ]
  [ -n "$cohort_b1" ] && [ "$cohort_b1" = "$cohort_b2" ]
  [ "$cohort_a1" != "$cohort_b1" ]
  # Cohort A priority is max(9,10) = 10; Cohort B priority is max(12,8) = 12
  echo "$output" | grep 'changeset=wr-itil-p185-cohort-a.md' | grep -q 'priority=10'
  echo "$output" | grep 'changeset=wr-itil-p187-cohort-b.md' | grep -q 'priority=12'
}

# Case (g.10) — cohort detection does NOT regress Phase 2a summary counts
@test "case (g.10): cohort members still count individually in GRADUATION_SUMMARY" {
  seed_problem "190" "open" "9"
  seed_problem "191" "open" "9"
  seed_changeset "wr-itil-p190-cohort.md"
  seed_changeset "wr-itil-p191-cohort.md"
  seed_holding_readme \
    "- \`wr-itil-p190-cohort.md\` — patch. **Reinstate trigger**: shared cohort." \
    "- \`wr-itil-p191-cohort.md\` — patch. **Reinstate trigger**: shared cohort."
  run bash "$SCRIPT" "$WORK_DIR"
  [ "$status" -eq 0 ]
  # Phase 2a parsers see total=2 resolved=2 — backwards compatible
  echo "$output" | grep -q 'GRADUATION_SUMMARY: total=2 resolved=2 vp_blocked=0 halts=0'
}
