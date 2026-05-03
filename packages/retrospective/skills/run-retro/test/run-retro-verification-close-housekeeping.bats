#!/usr/bin/env bats

# P068: run-retro SKILL.md documents the Verification-close housekeeping
# step (Step 4a) that surfaces in-session evidence for `.verifying.md`
# tickets and delegates the close transition to /wr-itil:manage-problem.
#
# Doc-lint structural test (Permitted Exception per ADR-005). Asserts
# SKILL.md wording for: the glob, the evidence-scan grounding (ADR-026),
# the three categorisation buckets, the AskUserQuestion prompt contract
# (ADR-013 Rule 1), the AFK fallback (ADR-013 Rule 6), the delegation
# boundary to manage-problem Step 7 (ADR-022 + ADR-014 ownership), and
# the ADR-027 auto-delegation compatibility note.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_MD="$REPO_ROOT/packages/retrospective/skills/run-retro/SKILL.md"
}

@test "run-retro: SKILL.md contains Step 4a Verification-close housekeeping (P068)" {
  run grep -F '### 4a. Verification-close housekeeping (P068)' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a globs docs/problems/*.verifying.md per ADR-022" {
  run grep -F 'docs/problems/*.verifying.md' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a delegates the close transition to /wr-itil:manage-problem Step 7" {
  run grep -F '/wr-itil:manage-problem' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'run-retro does **not** rename, edit the Status field, or commit' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a documents all three evidence-category buckets" {
  run grep -F 'Exercised successfully in-session' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Not exercised in-session' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'Exercised with regression' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a requires specific-citation grounding (ADR-026)" {
  run grep -F 'ADR-026 grounding' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'not bare counts' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a close-on-evidence dispatches to /wr-itil:transition-problem (P135 Phase 2 / ADR-044)" {
  # Phase 2 superseded the per-candidate AskUserQuestion (Close/Leave/Flag) with
  # close-on-evidence delegation per ADR-044. The bats now assert the new
  # contract: Step 4a delegates to /wr-itil:transition-problem WITHOUT asking,
  # and ADR-044 framework-resolution boundary is the rationale.
  run grep -F '/wr-itil:transition-problem' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'ADR-044' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a close-on-evidence requires concrete in-session citation (ADR-026 grounding)" {
  # Phase 2 preserves the evidence requirement (ADR-026); without concrete
  # citation, the ticket stays Verification Pending (ambiguous-evidence path).
  run grep -F 'ADR-026' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a documents recovery path inline (P135 R5 — closes are reversible)" {
  # Phase 2's close-on-evidence is reversible via /wr-itil:transition-problem
  # known-error flip-back (the 2026-04-27 P124 precedent). Recovery path is
  # documented inline alongside each close action in the Step 5 retro summary.
  run awk '/^### 4a\./,/^### 4b\./ {print}' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Recovery"* ]] || [[ "$output" == *"reversible"* ]]
}

@test "run-retro: Step 4a AFK and interactive modes use identical close-on-evidence behaviour (ADR-044)" {
  # Phase 2 collapsed the legacy AskUserQuestion-with-AFK-fallback into a
  # single silent-close-on-evidence path. Per ADR-044 framework-resolution
  # boundary: when the framework resolves the decision (concrete evidence
  # per ADR-022 + ADR-026), the agent acts; per-candidate ask is lazy
  # deferral. AFK and interactive paths are identical for this surface.
  # Asserting the legacy "Non-interactive / AFK fallback (per ADR-013 Rule 6)"
  # AskUserQuestion-vs-fallback split is GONE from Step 4a.
  run awk '/^### 4a\./,/^### 4b\./ {print}' "$SKILL_MD"
  [ "$status" -eq 0 ]
  [[ "$output" != *"do NOT auto-close"* ]]
  [[ "$output" != *"Close P<NNN>\` — description"* ]]
}

@test "run-retro: Step 4a ADR-032 supersession note documents post-supersession context handling" {
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

@test "run-retro: Step 4a cites feedback_verify_from_own_observation memory for the deferred-close rationale" {
  run grep -F 'feedback_verify_from_own_observation.md' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a documents interaction with manage-problem Step 9d and same-session verifyings are skipped" {
  run grep -F 'manage-problem Step 9d' "$SKILL_MD"
  [ "$status" -eq 0 ]
  run grep -F 'same-session verifyings' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 5 summary adds a Verification Candidates section" {
  run grep -F '### Verification Candidates' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Verification Candidates table columns match the Step 4a output semantics" {
  run grep -F '| Ticket | Fix summary | In-session citations | Decision |' "$SKILL_MD"
  [ "$status" -eq 0 ]
}

@test "run-retro: Step 4a does not miscite ADR-018 as the retrospective contract (P068 architect review)" {
  # The SKILL.md change must not claim ADR-018 governs the run-retro contract.
  # ADR-018 is about AFK inter-iteration release cadence, not retrospective.
  run grep -iE 'ADR-018.*retrospective (contract|ADR)|retrospective (contract|ADR).*ADR-018' "$SKILL_MD"
  [ "$status" -ne 0 ]
}
