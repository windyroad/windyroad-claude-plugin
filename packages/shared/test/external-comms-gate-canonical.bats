#!/usr/bin/env bats
# P064 / ADR-028 amended.
# Canonical-source contract for external-comms-gate.sh:
# the canonical lives at packages/shared/hooks/external-comms-gate.sh
# and contains the surface-list regex + leak-detect entrypoint.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  CANONICAL="$REPO_ROOT/packages/shared/hooks/external-comms-gate.sh"
  CANONICAL_LIB="$REPO_ROOT/packages/shared/hooks/lib/leak-detect.sh"
}

@test "canonical external-comms-gate.sh exists and is executable" {
  [ -x "$CANONICAL" ]
}

@test "canonical leak-detect.sh helper exists" {
  [ -f "$CANONICAL_LIB" ]
}

@test "canonical hook matches gh issue create surface" {
  grep -qE 'gh issue create' "$CANONICAL"
}

@test "canonical hook matches gh issue/pr comment surfaces" {
  grep -qE 'gh issue comment' "$CANONICAL"
  grep -qE 'gh pr comment' "$CANONICAL"
}

@test "canonical hook matches gh pr create / edit surfaces" {
  grep -qE 'gh pr create' "$CANONICAL"
  grep -qE 'gh (pr|issue) edit' "$CANONICAL"
}

@test "canonical hook matches gh api security-advisories surface" {
  grep -qE 'security-advisories' "$CANONICAL"
}

@test "canonical hook matches npm publish surface" {
  grep -qE 'npm publish' "$CANONICAL"
}

@test "canonical hook matches .changeset/*.md PreToolUse:Write/Edit surface (P073)" {
  grep -qE '\.changeset/' "$CANONICAL"
}

@test "canonical hook supports BYPASS_RISK_GATE env var override" {
  grep -qE 'BYPASS_RISK_GATE' "$CANONICAL"
}

@test "canonical hook sources per-package external-comms-evaluator.conf (ADR-028 amended 2026-05-14)" {
  # Per-evaluator marker scheme: canonical no longer hard-codes a subagent type;
  # each consumer plugin's .conf names its evaluator id + subagent + verdict prefix.
  grep -qE 'external-comms-evaluator\.conf' "$CANONICAL"
}

@test "canonical hook uses per-evaluator marker filename (external-comms-<id>-reviewed-<KEY>)" {
  # Per ADR-028 amended 2026-05-14: marker filename embeds evaluator id from .conf.
  grep -qE 'external-comms-\$\{EXTERNAL_COMMS_EVALUATOR_ID\}-reviewed-' "$CANONICAL"
}

@test "canonical hook sources leak-detect.sh from lib/" {
  grep -qE 'leak-detect\.sh' "$CANONICAL"
}
