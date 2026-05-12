#!/usr/bin/env bats

# P170 / RFC-002 / ADR-031 Open-Execution Q1 resolution: manage-problem
# SKILL.md wires the shared migration routine at Step 0a (before
# Step 0 README reconciliation preflight). Doc-lint structural test —
# the wiring is a SKILL.md preamble integration point; behavioural
# assertions for the routine itself live at
# packages/shared/test/sync-migrate-problems-layout.bats (T7) and the
# end-to-end behavioural fixture
# packages/itil/skills/manage-problem/test/manage-problem-auto-migrate.bats (T10).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/itil/skills/manage-problem/SKILL.md"
}

@test "manage-problem: SKILL.md declares Step 0a auto-migrate (T8 wiring point)" {
  run grep -E '^### 0a\.|^## Step 0a|Step 0a:' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "manage-problem: SKILL.md Step 0a cites P170 / RFC-002 / ADR-031" {
  run grep -F 'P170' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'ADR-031' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "manage-problem: SKILL.md Step 0a sources packages/itil/lib/migrate-problems-layout.sh" {
  run grep -F 'packages/itil/lib/migrate-problems-layout.sh' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "manage-problem: SKILL.md Step 0a calls migrate_problems_to_per_state_layout entrypoint" {
  run grep -F 'migrate_problems_to_per_state_layout' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "manage-problem: SKILL.md Step 0a fires before Step 0 README reconciliation" {
  # Assert the literal line order in the file: Step 0a appears before
  # the existing Step 0 README reconciliation heading.
  local step_0a_line step_0_line
  step_0a_line=$(grep -nE '^### 0a\.|^## Step 0a|Step 0a:' "$SKILL_MD" | head -1 | cut -d: -f1)
  step_0_line=$(grep -nE '^### 0\. README' "$SKILL_MD" | head -1 | cut -d: -f1)
  [ -n "$step_0a_line" ]
  [ -n "$step_0_line" ]
  [ "$step_0a_line" -lt "$step_0_line" ]
}

@test "manage-problem: SKILL.md Step 0a cites ADR-013 Rule 6 (AFK auto-fire authorisation)" {
  run grep -F 'ADR-013' "$SKILL_MD"
  [ "$status" -eq 0 ]
}
