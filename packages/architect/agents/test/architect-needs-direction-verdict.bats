#!/usr/bin/env bats
# Doc-lint guard: architect agent.md must carry the NEEDS DIRECTION verdict
# type (ADR-064) so the architect names the question + viable options for an
# unpinned 2+-option decision instead of auto-picking or prose-asking, and the
# main agent translates it into an AskUserQuestion.
#
# tdd-review: structural-permitted (justification: P176 — agent behaviour is
# prompt-driven with no skill-invocation harness to exercise the verdict
# behaviourally; ADR-052 Surface 2 structural-justified case, NOT an ADR-005
# Permitted Exception — ADR-052 narrows ADR-005 to exclude prose-doc greps).
# When P176 lands, upgrade to a behavioural test per ADR-064 Confirmation item 2.
#
# Cross-reference:
#   P283 (architect should AskUserQuestion when recording a new decision)
#   ADR-064 (Architect Needs-Direction verdict; main agent owns the AskUserQuestion)
#   ADR-052 Surface 2 (structural-justified verdict) + P176 (harness gap)
#   @jtbd JTBD-001 (enforce governance without slowing down)

setup() {
  AGENT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AGENT_FILE="${AGENT_DIR}/agent.md"
}

@test "agent.md carries a NEEDS DIRECTION report verdict (ADR-064)" {
  run grep -n "Architecture Review: NEEDS DIRECTION" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md lists [Needs Direction] as an issue/verdict type" {
  run grep -n "\[Needs Direction\]" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md has a 'When to emit Needs Direction' section citing ADR-064" {
  run grep -n "When to emit Needs Direction" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -n "ADR-064" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md requires the main agent to translate the verdict into AskUserQuestion (not prose)" {
  run grep -n "AskUserQuestion" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md guards the negative bound: do NOT emit Needs Direction on obvious/single-option choices" {
  # inverse-P078 over-ask guard — the verdict must not fire when only one viable option exists
  run grep -niE "Do NOT emit Needs Direction.*(obvious|one-viable|only-one)" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md performance-review section cites ADR-026 as parent (ADR-026 Confirmation item 1)" {
  run grep -nE "Runtime-Path Performance Review \(per ADR-026" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}
