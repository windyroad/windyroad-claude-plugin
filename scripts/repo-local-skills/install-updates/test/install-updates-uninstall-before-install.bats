#!/usr/bin/env bats

# P106: install-updates SKILL.md Step 6 must uninstall before install.
# `claude plugin install` is a silent no-op when the plugin is already
# installed, so updates never land. The fix is `uninstall + install`
# in `--scope project`, which forces a fresh marketplace download.
#
# Doc-lint structural test (Permitted Exception per ADR-005 — structural
# SKILL.md content checks).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/.claude/skills/install-updates/SKILL.md"
  REF_MD="$REPO_ROOT/.claude/skills/install-updates/REFERENCE.md"
}

@test "install-updates: SKILL.md Step 6 contains uninstall before install (P106)" {
  # Extract Step 6 block (from "### 7. Install" to the next ### or EOF)
  local step7
  step7=$(sed -n '/^### 6\. Install/,/^### /p' "$SKILL_MD" | sed '$d')
  [ -n "$step7" ]

  # Must contain an uninstall command
  run grep -F 'claude plugin uninstall' <<< "$step7"
  [ "$status" -eq 0 ]

  # Must contain an install command
  run grep -F 'claude plugin install' <<< "$step7"
  [ "$status" -eq 0 ]

  # uninstall must appear BEFORE install in the Step 6 block
  local uninstall_line install_line
  uninstall_line=$(grep -nF 'claude plugin uninstall' <<< "$step7" | head -1 | cut -d: -f1)
  install_line=$(grep -nF 'claude plugin install' <<< "$step7" | tail -1 | cut -d: -f1)
  [ -n "$uninstall_line" ]
  [ -n "$install_line" ]
  [ "$uninstall_line" -lt "$install_line" ]
}

@test "install-updates: Step 6 uninstall uses --scope project (P106)" {
  local step7
  step7=$(sed -n '/^### 6\. Install/,/^### /p' "$SKILL_MD" | sed '$d')
  run grep -F -- '--scope project' <<< "$step7"
  [ "$status" -eq 0 ]
}

@test "install-updates: Step 6 captures per-install exit status (P106)" {
  # The fix must not drop the existing "Capture per-install exit status"
  # contract — continue on failure, report and continue.
  run grep -iF 'exit status' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: REFERENCE.md documents the uninstall+install refresh pattern (P106)" {
  run grep -iF 'uninstall + install' "$REF_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates: REFERENCE.md does not claim uninstall refuses project-scope (P106)" {
  # The old incorrect claim must be gone.
  run grep -iF 'claude plugin uninstall' "$REF_MD"
  if [ "$status" -eq 0 ]; then
    run grep -iF 'refuses project-scope' "$REF_MD"
    [ "$status" -ne 0 ]
  fi
}
