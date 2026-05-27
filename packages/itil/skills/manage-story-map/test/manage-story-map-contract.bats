#!/usr/bin/env bats
# Behavioural contract fixtures for /wr-itil:manage-story-map (P170 Phase 2 Slice 4).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_FILE="${REPO_ROOT}/packages/itil/skills/manage-story-map/SKILL.md"
}

@test "manage-story-map: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "manage-story-map: SKILL.md frontmatter declares wr-itil:manage-story-map name" {
  run grep -E '^name: wr-itil:manage-story-map$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md declares I3 trace-to-problem invariant" {
  run grep -E 'I3.*trace-to-problem|trace-to-problem.*I3' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md declares I4 trace-to-JTBD invariant" {
  run grep -E 'I4.*trace-to-JTBD|trace-to-JTBD.*I4' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md declares I5 no-WSJF-leak invariant" {
  run grep -E 'I5.*WSJF|WSJF.*I5|no-WSJF-leak' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md names 5 lifecycle states (draft / accepted / in-progress / completed / archived)" {
  for state in draft accepted in-progress completed archived; do
    run grep -E "${state}" "$SKILL_FILE"
    [ "$status" -eq 0 ]
  done
}

@test "manage-story-map: SKILL.md names bootstrap-exemption marker per ADR-060 line 339" {
  run grep -iE 'bootstrap-exempt|ADR-053.*Bootstrapping' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md names reverse-trace refresh on problem parents via Story Maps section" {
  run grep -E 'wr-itil-update-problem-references-section.*Story Maps' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md names reverse-trace refresh on JTBD parents via Story Maps section" {
  run grep -E 'wr-itil-update-jtbd-references-section.*Story Maps' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: SKILL.md states map HTML files do NOT carry markdown reverse-trace section themselves (per Slice 7 architect amend finding 2)" {
  run grep -iE 'do NOT carry.*markdown reverse-trace|authored manually|manual.*data-attribute' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "manage-story-map: argument grammar contains no WSJF token (I5 invariant)" {
  run grep -A 10 '^## Argument grammar' "$SKILL_FILE"
  [[ "$output" != *"WSJF"* ]] && [[ "$output" != *"wsjf"* ]]
}
