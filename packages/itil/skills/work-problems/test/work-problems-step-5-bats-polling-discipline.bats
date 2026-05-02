#!/usr/bin/env bats
# Doc-lint guard: work-problems SKILL.md Step 5 iteration prompt body must
# carry a prompt-discipline rule forbidding the bash-until-loop bats-output-
# polling antipattern that caused P146.
#
# Antipattern (observed 2026-04-29, iter 1, PID 23580 child PID 16408 —
# 68m34s wall-clock burn + lost JSON metadata):
#   until [ -f $TASK_OUTPUT ] && grep -qE '^[0-9]+ tests?,' $TASK_OUTPUT \
#     2>/dev/null; do sleep 5; done; tail -25 $TASK_OUTPUT
# The regex `^[0-9]+ tests?,` matches bats's *default* (non-TAP) console-
# summary line. `bats --tap` never emits that line, so the until-loop spins
# forever after bats completes. Silent deadlock; no error; no exit.
#
# The polling idiom is NOT taught by any SKILL.md (grep across the repo
# returns only this ticket itself). It is agent-learned from training data —
# a generic bash + bats Bourne idiom. The fix per the ticket strategy is a
# prompt-discipline rule + behavioural assertion: the iteration prompt body
# must explicitly forbid the antipattern AND name a safe substitute, so the
# iteration agent does not fall back on the learned idiom.
#
# Structural assertion — Permitted Exception under ADR-037 (SKILL.md is
# explicitly a contract document; doc-lint contract assertion against the
# contract document itself is the named permitted pattern; same rationale
# as work-problems-step-5-delegation.bats's @problem P083 / P089 fixtures).
# Behavioural alternative would require spawning a real `claude -p`
# subprocess and observing its tool-call traces; that harness sits outside
# the skill layer.
#
# @problem P146
# @jtbd JTBD-006
# @jtbd JTBD-001
# @jtbd JTBD-101
#
# Cross-reference:
#   P146 (bash until-loop polls bats output with bats-console regex against
#     TAP-format) — driver for this clause
#   P147 (sibling — SIGTERM-flush metadata-loss caveat fires when an iter
#     deadlocks before ITERATION_SUMMARY emission; P146's regex-poll is the
#     concrete mechanism behind today's stuck-before-emit incident)
#   ADR-037 (skill testing strategy — contract-assertion Permitted Exception)
#   ADR-014 (single-commit grain — fix + bats + ticket transition land
#     together)

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
}

@test "SKILL.md Step 5 iteration prompt forbids bats-console-summary regex polling (P146)" {
  # The iteration prompt body MUST explicitly name the antipattern so the
  # iteration agent does not reach for the learned bash idiom. The
  # prohibition phrase must reference the regex-poll-on-bats-output shape
  # OR the bats-console-summary line shape, since both are the failure
  # surface today.
  run grep -niE "do not poll.{0,40}bats|bats.{0,40}console.summary.{0,40}regex|never poll.{0,40}bats|grep.{0,20}tests\\?,.{0,80}(forbidden|antipattern|do not|never)" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Step 5 iteration prompt names a safe substitute for backgrounded bats waits (P146)" {
  # Forbidding the antipattern without naming a substitute leaves the agent
  # without a path forward, and the agent will silently fall back on the
  # antipattern. The prompt must name `wait \$bg_pid` (Unix idiom) OR the
  # Bash tool's `run_in_background=true` + BashOutput check (Claude Code
  # idiom) as the recommended replacement.
  run grep -niE "wait[[:space:]]+[\"']?\\\$[A-Z_]*pid|wait[[:space:]]+[\"']?\\\$[A-Z_]*PID|run_in_background.{0,80}BashOutput|BashOutput.{0,80}run_in_background|background.{0,40}wait.{0,40}exit" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Step 5 bats-polling clause cites P146 (self-documenting contract)" {
  # The clause must cite P146 inline so a future contributor reading the
  # rule understands why it exists before deleting it (mirrors the P083
  # ScheduleWakeup-clause discipline already in place at line ~301).
  run grep -nE "P146" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Step 5 bats-polling clause names the TAP/console-summary divergence (P146)" {
  # The clause must explain WHY the regex `^[0-9]+ tests?,` fails — the
  # divergence between bats's default (console-summary) and `--tap` output
  # formats. Without this, a future contributor who switches from `--tap`
  # to default formatting may "fix" the rule incorrectly.
  run grep -niE "TAP.{0,80}console.summary|console.summary.{0,80}TAP|--tap.{0,80}(does not|never|no console summary)|tap.format.{0,80}(does not|never).{0,40}emit" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Related section cites P146" {
  # Self-documenting contract: ticket cited in Related so a future reader
  # of the file finds the driving incident without scrolling to find it.
  run grep -nE "P146" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
