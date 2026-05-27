#!/usr/bin/env bats
# Doc-lint guard: architect agent.md must carry the [Unratified Dependency]
# verdict (ADR-074 enforcement surface 3 / RFC-010 / P318) — flag a change or
# plan that explicitly cites/implements an ADR lacking `human-oversight:
# confirmed` (unratified, non-superseded), keyed on the oversight marker NOT
# `status:`. Closes the residual P315 foreground gap at the architect-review
# surface (the ITIL propose-fix surface is covered by RFC-008).
#
# tdd-review: structural-permitted (justification: P176 — agent behaviour is
# prompt-driven with no skill-invocation harness to exercise the verdict
# behaviourally; ADR-052 Surface 2 structural-justified case, NOT an ADR-005
# Permitted Exception). When P176 lands, upgrade to a behavioural test that
# feeds the agent a change citing an unratified ADR and asserts the verdict.
#
# Cross-reference:
#   ADR-074 (Confirm a decision's substance before building dependent work — surface 3)
#   ADR-066 (oversight marker; orthogonal status/oversight axes; the "unconfirmed" definition)
#   RFC-010 / P318 (this enforcement surface)
#   ADR-052 Surface 2 (structural-justified verdict) + P176 (harness gap)
#   @jtbd JTBD-002 (ship with confidence) / JTBD-001 (enforce governance without slowing down)

setup() {
  AGENT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AGENT_FILE="${AGENT_DIR}/agent.md"
}

@test "agent.md lists [Unratified Dependency] as an issue/verdict type (ADR-074 surface 3)" {
  run grep -n '\[Unratified Dependency\]' "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md has a 'When to flag [Unratified Dependency]' section citing ADR-074" {
  run grep -niE "When to flag \[Unratified Dependency\]" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -n "ADR-074" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md keys the flag on the oversight marker, NOT on status (orthogonal axes)" {
  # ADR-066 / user correction 2026-05-27: building on a ratified-but-proposed ADR is fine.
  run grep -niE "NEVER on .?status|not .?\`?status|orthogonal" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md scopes the marker check to frontmatter + skips superseded (mirrors is-decision-unconfirmed.sh)" {
  run grep -niE "frontmatter" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -niE "superseded" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md guards against over-firing on transitive/ambient dependence (inverse-P078)" {
  run grep -niE "explicit(ly)? cite|over-?(fire|scan)|transitive" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}
