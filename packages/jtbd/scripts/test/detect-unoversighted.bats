#!/usr/bin/env bats

# ADR-068: detect-unoversighted.sh prints jobs/personas whose frontmatter lacks the
# `human-oversight: confirmed` marker. Behavioural — exercises the script against
# fixture docs/jtbd/<persona>/ trees and asserts on stdout.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/jtbd/scripts/detect-unoversighted.sh"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/jtbd/solo-developer"
}

teardown() { rm -rf "$DIR"; }

mk() { # mk <relpath under docs/jtbd> <extra frontmatter lines...>
  local rel="$1"; shift
  mkdir -p "$(dirname "$DIR/docs/jtbd/$rel")"
  {
    echo "---"
    echo "status: proposed"
    echo "date-created: 2026-05-25"
    for line in "$@"; do echo "$line"; done
    echo "---"
    echo "# $rel"
  } > "$DIR/docs/jtbd/$rel"
}

@test "a job without the marker is reported" {
  mk "solo-developer/JTBD-001-foo.proposed.md"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"JTBD-001-foo.proposed.md"* ]]
}

@test "a persona file without the marker is reported" {
  mk "solo-developer/persona.md"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" == *"solo-developer/persona.md"* ]]
}

@test "a job carrying human-oversight: confirmed is NOT reported" {
  mk "solo-developer/JTBD-002-bar.proposed.md" "human-oversight: confirmed" "oversight-date: 2026-05-25"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"JTBD-002-bar.proposed.md"* ]]
}

@test "the top-level docs/jtbd/README.md is never reported" {
  echo "# JTBD index" > "$DIR/docs/jtbd/README.md"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"README.md"* ]]
}

@test "a per-persona README is also excluded" {
  echo "# persona index" > "$DIR/docs/jtbd/solo-developer/README.md"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"README.md"* ]]
}

@test "a file with no frontmatter counts as unoversighted" {
  mkdir -p "$DIR/docs/jtbd/tech-lead"
  echo "# bare persona, no frontmatter" > "$DIR/docs/jtbd/tech-lead/persona.md"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" == *"tech-lead/persona.md"* ]]
}

@test "marker match is case-insensitive and tolerant of trailing space" {
  mk "solo-developer/JTBD-003-baz.proposed.md" "human-oversight:   confirmed   "
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"JTBD-003-baz.proposed.md"* ]]
}

@test "missing jtbd dir exits 0 with no output" {
  run bash "$SCRIPT" "$DIR/docs/nonexistent"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fully-confirmed corpus produces empty output" {
  mk "solo-developer/persona.md" "human-oversight: confirmed"
  mk "solo-developer/JTBD-001-foo.proposed.md" "human-oversight: confirmed"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ADR-068 amendment (P316): mirror the architect `rejected-pending-supersede`
# exclusion onto the JTBD detector. Exclusion requires BOTH the marker AND
# a supersede-ticket: P<NNN> scalar; a marker without the ticket is
# malformed and still surfaces (defensive).

@test "JTBD with rejected-pending-supersede + supersede-ticket is excluded" {
  mk "solo-developer/JTBD-020-rejected.proposed.md" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P297"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"JTBD-020-rejected.proposed.md"* ]]
}

@test "JTBD with rejected-pending-supersede WITHOUT supersede-ticket still surfaces (defensive)" {
  mk "solo-developer/JTBD-021-untracked.proposed.md" \
    "human-oversight: rejected-pending-supersede"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" == *"JTBD-021-untracked.proposed.md"* ]]
}

@test "persona with rejected-pending-supersede + ticket is also excluded" {
  mk "rejected-persona/persona.md" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P299"
  run bash "$SCRIPT" "$DIR/docs/jtbd"
  [[ "$output" != *"rejected-persona/persona.md"* ]]
}
