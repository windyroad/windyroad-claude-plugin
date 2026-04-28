#!/usr/bin/env bats

# P061: Step 6 consent gate must document a grouping fallback when
# sibling count exceeds AskUserQuestion's 4-option cap. The original
# "one option per sibling + dry-run" contract violates the cap when
# siblings > 3 (observed 2026-04-20: this repo has 5 siblings).
#
# Doc-lint structural test (Permitted Exception per ADR-005).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/.claude/skills/install-updates/SKILL.md"
}

@test "install-updates: Step 6 documents the grouping fallback for siblings > 3 (P061)" {
  run grep -F 'Sibling count > 3 — grouping fallback (P061)' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 cites AskUserQuestion maxItems cap as the reason for fallback" {
  run grep -F 'caps `maxItems` at 4' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 fallback has exactly 4 options (All / Current / Dry-run / Other)" {
  run grep -F 'All <N> projects (Recommended)' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Current project only' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F "Dry-run — show the plan but don't install" "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'auto-provided `Other — provide custom text`' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 fallback preserves ADR-030 sibling enumeration in question body" {
  run grep -F 'name every detected sibling in the question body text' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 preserves the original contract for siblings ≤ 3" {
  run grep -F 'Sibling count ≤ 3' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'original contract applies' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 notes both shapes satisfy the ADR-030 consent gate" {
  run grep -F 'Either shape (≤ 3 or > 3 fallback) satisfies the ADR-030 Confirmation consent gate' "$SKILL_MD"
  [ "$status" -eq 0 ]
}
