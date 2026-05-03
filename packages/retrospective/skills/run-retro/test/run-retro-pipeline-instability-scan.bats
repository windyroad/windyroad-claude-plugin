#!/usr/bin/env bats

# P074: run-retro SKILL.md documents a Pipeline-instability scan step
# (Step 2b) that inspects session activity for tool-level friction
# signals and funnels each detection into Step 4's problem-ticket
# creation path. Shape mirrors P068's Step 4a (evidence-scan + ADR-026
# grounding + interactive/AFK branches).
#
# Doc-lint structural test (Permitted Exception per ADR-005). Asserts
# SKILL.md wording for: the step header, the placement between Step 2
# and Step 4, the six signal categories enumerated in the RCA, the
# ADR-026 grounding requirement, the interactive AskUserQuestion
# contract (ADR-013 Rule 1), the AFK fallback (ADR-013 Rule 6), the
# ownership-delegation boundary to /wr-itil:manage-problem, and the
# Step 5 summary integration.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/retrospective/skills/run-retro/SKILL.md"
}

@test "run-retro: SKILL.md contains Step 2b Pipeline-instability scan (P074)" {
  run grep -F '### 2b. Pipeline-instability scan (P074)' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b enumerates all six signal categories" {
  run grep -F 'Hook-protocol friction' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Skill-contract violations' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Release-path instability' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Subagent-delegation friction' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Repeat-work friction' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Session-wrap silent drops' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b requires specific-citation grounding (ADR-026)" {
  run grep -F 'ADR-026' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'specific citations' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b interactive AskUserQuestion contract per ADR-013 Rule 1" {
  run grep -F 'ADR-013 Rule 1' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Create new ticket' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Append to P<NNN>' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Skip — false positive' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b AFK fallback defers ticket creation per ADR-013 Rule 6" {
  run grep -F 'ADR-013 Rule 6' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Pipeline Instability' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b delegates ticket creation to /wr-itil:manage-problem" {
  run grep -F '/wr-itil:manage-problem' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'run-retro surfaces the detection' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b dedup checks existing tickets before creating" {
  run grep -F 'Dedup against existing tickets' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'docs/problems/*.open.md' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'docs/problems/*.known-error.md' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b ADR-032 supersession note documents post-supersession context handling" {
  # ADR-027 was superseded by ADR-032 (2026-04-21). The former
  # "ADR-027 compatibility note" was rewritten to an ADR-032 supersession
  # note that records the obviation of any Step-0 subagent migration.
  # Structural grep retained for now (P081 anti-pattern; convert to
  # behavioural fixture in a follow-up — tracked separately).
  run grep -F 'ADR-032 supersession note' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'No Step-0 subagent migration applies' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b placement between Step 2 reflection and Step 4 ticket creation" {
  # Section 2b must appear after 2 and before 4.
  pos_2=$(grep -n '^### 2\. Reflect on this session' "$SKILL_MD" | head -1 | cut -d: -f1)
  pos_2b=$(grep -n '^### 2b\. Pipeline-instability scan' "$SKILL_MD" | head -1 | cut -d: -f1)
  pos_4=$(grep -n '^### 4\. Create or update problem tickets' "$SKILL_MD" | head -1 | cut -d: -f1)
  [ -n "$pos_2" ]
  [ -n "$pos_2b" ]
  [ -n "$pos_4" ]
  [ "$pos_2" -lt "$pos_2b" ]
  [ "$pos_2b" -lt "$pos_4" ]
}

@test "run-retro: Step 5 summary adds a Pipeline Instability section" {
  run grep -F '### Pipeline Instability' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Pipeline Instability summary table columns match Step 2b output" {
  run grep -F '| Signal | Category | Citations | Decision |' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 2b documents interaction with P068 Step 4a shape (shared evidence-scan pattern)" {
  run grep -F 'P068' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'evidence-scan' "$SKILL_MD"
  [ "$status" -eq 0 ]
}
