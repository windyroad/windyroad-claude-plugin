#!/usr/bin/env bats
# Doc-lint guard: wr-itil:hang-off-check agent contract — the agent MUST
# carry the verdict format (HANG_OFF: P<NNN> | PROCEED_NEW), the
# fresh-context subagent rationale, the JTBD-301 maintainer-side firewall,
# the AFK safe-default (PROCEED_NEW on ambiguous), the rationale-citation
# requirement, and the three canonical fixture files. Closes P346 Phase 3
# deliverable — the SKILL's behavioural intent is documented and
# verifiable.
#
# Structural assertion — ADR-052 Surface 2 (structural-justified) +
# P176 harness gap. Behavioural execution of the three canonical fixtures
# lands under RFC-012 (promptfoo eval harness, proposed). Upgrade these
# to behavioural fixtures when RFC-012 ships.
#
# Cross-reference:
#   P346 (review-problems backlog-flow-control master ticket; Phase 3
#         deliverable this agent fulfils)
#   P347 (closed as duplicate-of-P346; canonical regression case driving
#         fixture 1)
#   P176 (agent-side I2 / harness gap — Surface 2 carve-out precedent)
#   ADR-032 (5th invocation pattern — fresh-context-subagent-as-decision-
#            arbiter; P346 amendment 2026-05-31 codifies this agent's shape)
#   ADR-052 (behavioural-tests default; Surface 2 carve-out)
#   ADR-075 (promptfoo as agent-prose verdict harness — future home)
#   RFC-012 (promptfoo retrofit — behavioural eval harness)
#   RFC-013 (P346 multi-phase trace per ADR-071)
#   @jtbd JTBD-001 (enforce governance without slowing down)
#   @jtbd JTBD-006 (progress backlog while I'm away — AFK safe-default)
#   @jtbd JTBD-101 (extend suite with new plugins — pattern reuse)
#   @jtbd JTBD-201 (restore service fast with an audit trail — rationale)

setup() {
  AGENT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AGENT_FILE="${AGENT_DIR}/hang-off-check.md"
  FIXTURES_DIR="${AGENT_DIR}/test/fixtures"
}

# ----- Contract surface: verdict format + structure -----

@test "agent.md exists at packages/itil/agents/hang-off-check.md" {
  [ -f "$AGENT_FILE" ]
}

@test "agent.md frontmatter declares name: hang-off-check" {
  run grep -nE "^name: hang-off-check$" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md frontmatter limits tools to read-only set (Read, Glob, Grep)" {
  # No Edit, no Write, no Bash — read-only reviewer per ADR-032 5th pattern
  run grep -nE "tools:" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "^  - (Read|Glob|Grep)$" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  # Forbid Edit / Write / Bash in the tools list
  ! grep -nE "^  - (Edit|Write|Bash|MultiEdit|NotebookEdit)$" "$AGENT_FILE"
}

@test "agent.md declares HANG_OFF: P<NNN> verdict shape" {
  run grep -nE 'HANG_OFF:\s*P<NNN>' "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md declares PROCEED_NEW verdict shape" {
  run grep -nE "PROCEED_NEW" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md requires a Rationale section on every verdict" {
  run grep -nE "\*\*Rationale\*\*" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md requires Signals matched citation on HANG_OFF (rationale-grounding per ADR-026)" {
  run grep -nE "\*\*Signals matched\*\*" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md requires Where to absorb directive on HANG_OFF (calling-skill action contract)" {
  run grep -nE "\*\*Where to absorb\*\*" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md requires Per-candidate explanation on PROCEED_NEW" {
  run grep -nE "\*\*Per-candidate explanation\*\*" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Driver / context-isolation rationale -----

@test "agent.md cites the fresh-context / session-context-bias driver" {
  run grep -niE "(session-context bias|fresh context|context isolation)" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md cites the P347-vs-P346 canonical regression in the driver section" {
  run grep -nE "P347" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "P346" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md cites ADR-032 5th-pattern codification (P346 amendment)" {
  run grep -nE "ADR-032" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -niE "5th (invocation )?pattern" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Decision rule -----

@test "agent.md names master-ticket / multi-phase as a HANG_OFF signal" {
  run grep -niE "(master ticket|multi-phase|scope expansion)" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md names false-negative-cheaper-than-false-positive safe-default" {
  run grep -niE "false[-]positive.*cheap|cheap.*false[-]positive" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md cites Rule 6 fail-safe / AFK safe-default (ambiguous → PROCEED_NEW)" {
  run grep -niE "(ambiguous.*PROCEED_NEW|--no-prompt|AFK propagation)" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "ADR-013" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md explicitly forbids AskUserQuestion invocation (Rule 6)" {
  run grep -niE "(never|do not|MUST NOT).*(AskUserQuestion|invoke.*AskUserQuestion)" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Scope / firewalls -----

@test "agent.md names the JTBD-301 maintainer-side firewall" {
  run grep -nE "JTBD-301" "$AGENT_FILE"
  [ "$status" -eq 0 ]
  run grep -niE "maintainer-side|maintainer-internal" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md excludes plugin-user-side intake from the dispatch (firewall)" {
  run grep -niE "plugin-user-side|problem-report\.yml" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md excludes manage-problem ingestion-of-plugin-user-reports path" {
  run grep -niE "ingestion[- ]of[- ]plugin[- ]user[- ]reports" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md scopes cardinality to one verdict per invocation" {
  run grep -niE "one verdict per invocation|cardinality" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Output formatting (matches architect / jtbd output formatting convention) -----

@test "agent.md carries Output Formatting section requiring human-readable IDs" {
  run grep -nE "## Output Formatting" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- JTBD annotation (per JTBD review nit 5) -----

@test "agent.md carries @jtbd annotation citing JTBD-001/006/101/201" {
  run grep -nE "^# @jtbd .*JTBD-001.*JTBD-006.*JTBD-101.*JTBD-201" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Canonical behavioural fixtures (RFC-012 future-home) -----

@test "fixture 1 (canonical P347-vs-P346 regression) exists" {
  [ -f "${FIXTURES_DIR}/regression-p347-vs-p346.md" ]
}

@test "fixture 1 names HANG_OFF: P346 as the expected verdict" {
  run grep -nE "HANG_OFF: P346" "${FIXTURES_DIR}/regression-p347-vs-p346.md"
  [ "$status" -eq 0 ]
}

@test "fixture 1 cites P347 as the wrongly-captured-sibling motivator" {
  run grep -nE "P347" "${FIXTURES_DIR}/regression-p347-vs-p346.md"
  [ "$status" -eq 0 ]
}

@test "fixture 2 (genuinely-new) exists" {
  [ -f "${FIXTURES_DIR}/proceed-new-genuinely-new.md" ]
}

@test "fixture 2 names PROCEED_NEW as the expected verdict" {
  run grep -nE "PROCEED_NEW" "${FIXTURES_DIR}/proceed-new-genuinely-new.md"
  [ "$status" -eq 0 ]
}

@test "fixture 3 (subtle sibling-vs-parent) exists" {
  [ -f "${FIXTURES_DIR}/proceed-new-subtle-sibling.md" ]
}

@test "fixture 3 names PROCEED_NEW with reasoned per-candidate rationale" {
  run grep -nE "PROCEED_NEW" "${FIXTURES_DIR}/proceed-new-subtle-sibling.md"
  [ "$status" -eq 0 ]
  run grep -niE "Per-candidate explanation" "${FIXTURES_DIR}/proceed-new-subtle-sibling.md"
  [ "$status" -eq 0 ]
}

# ----- RFC-012 forward-reference -----

@test "agent.md cross-references RFC-012 as future behavioural-eval home" {
  run grep -nE "RFC-012" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

# ----- Cross-references to dispatch sites -----

@test "agent.md cross-references /wr-itil:capture-problem as primary dispatch site" {
  run grep -nE "/wr-itil:capture-problem" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}

@test "agent.md cross-references /wr-itil:manage-problem as secondary dispatch site" {
  run grep -nE "/wr-itil:manage-problem" "$AGENT_FILE"
  [ "$status" -eq 0 ]
}
