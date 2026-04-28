#!/usr/bin/env bats

# P120: Step 6 of /install-updates must check `.claude/.install-updates-consent`
# before invoking AskUserQuestion. Cache-hit path skips the consent gate when
# the cached `scope` array equals the current detected sibling set; cache-miss
# fires the gate with the previous answer surfaced; cache-write at end of run.
# Parallel-pattern shape with ADR-034's `.claude/.auto-install-consent` for the
# SessionStart auto-install surface.
#
# Doc-lint contract assertions per ADR-037 Permitted Exception (structural
# checks on prose contract, not behavioural coverage). Tests assert that
# SKILL.md and REFERENCE.md prose names the cache file path, the gate-on-cache
# language, the invalidation contract, the cache-write language, the ADR-034
# citation, and the ADR-013 Rule 5 (not Rule 6) citation per architect verdict.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/.claude/skills/install-updates/SKILL.md"
  REFERENCE_MD="$REPO_ROOT/.claude/skills/install-updates/REFERENCE.md"
  GITIGNORE="$REPO_ROOT/.gitignore"
  ADR_030="$REPO_ROOT/docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md"
}

@test "install-updates P120: SKILL.md Step 6 names the consent cache file path" {
  run grep -F '.claude/.install-updates-consent' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 documents the cache-hit skip-gate path" {
  run grep -F 'cached scope matches' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'skip Step 6' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 documents sibling-set-change invalidation with previous answer surfaced" {
  run grep -F 'sibling set has changed' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'previous answer surfaced as `(Recommended)`' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 documents cache-write at end of successful run" {
  run grep -F 'write `.claude/.install-updates-consent`' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 cites ADR-034 as the parallel-pattern precedent" {
  run grep -F 'ADR-034' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F '.claude/.auto-install-consent' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 cites ADR-013 Rule 5 (policy-authorised silent proceed)" {
  run grep -F 'ADR-013 Rule 5' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: SKILL.md Step 6 names a cache-silencing escape hatch (envvar or cache-file deletion)" {
  run grep -F 'INSTALL_UPDATES_RECONFIRM' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: REFERENCE.md has a Consent cache (P120) section" {
  run grep -F 'Consent cache (P120)' "$REFERENCE_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: REFERENCE.md documents set-equality match rule and plugin-list-change-no-op" {
  run grep -F 'set equality' "$REFERENCE_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Plugin-list change' "$REFERENCE_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: REFERENCE.md cites ADR-013 Rule 5 (policy-authorised silent proceed) governing cache-hit" {
  run grep -F 'ADR-013 Rule 5' "$REFERENCE_MD"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: .gitignore covers the consent cache file" {
  run grep -F '.claude/.install-updates-consent' "$GITIGNORE"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: .gitignore covers ADR-034 auto-install consent marker" {
  run grep -F '.claude/.auto-install-consent' "$GITIGNORE"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: ADR-030 Confirmation amendment names the cache-hit exemption" {
  run grep -F '.claude/.install-updates-consent' "$ADR_030"
  [ "$status" -eq 0 ]
  run grep -F 'cache hits' "$ADR_030"
  [ "$status" -eq 0 ]
}

@test "install-updates P120: ADR-030 amendment documents set-equality match rule" {
  run grep -F 'set equality' "$ADR_030"
  [ "$status" -eq 0 ]
}
