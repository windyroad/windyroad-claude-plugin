#!/usr/bin/env bats

# ADR-068 surface 3 / RFC-011 / P323: is-job-or-persona-unconfirmed.sh is the
# single-artifact predicate for the JTBD build-upon guard (the wr-jtbd:agent
# [Unratified Dependency] verdict). It answers "is this referenced persona or
# job unconfirmed?" via its EXIT CODE, where "unconfirmed" mirrors
# detect-unoversighted.sh EXACTLY (frontmatter lacks `human-oversight:
# confirmed`, and the artifact is not superseded). The JTBD twin of the
# architect side's is-decision-unconfirmed.sh (ADR-074).
#
# Behavioural — exercises the script against fixture trees and asserts on its
# exit code + stdout, not its source text (ADR-052).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/jtbd/scripts/is-job-or-persona-unconfirmed.sh"
  DETECT="$REPO_ROOT/packages/jtbd/scripts/detect-unoversighted.sh"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/jtbd"
}

teardown() {
  rm -rf "$DIR"
}

# mk_persona <persona-name> <confirmed?yes|no>
mk_persona() {
  local name="$1"; local confirmed="$2"
  mkdir -p "$DIR/docs/jtbd/$name"
  {
    echo "---"
    echo "name: $name"
    echo "description: test persona $name"
    [ "$confirmed" = "yes" ] && { echo "human-oversight: confirmed"; echo "oversight-date: 2026-05-27"; }
    echo "---"
    echo "# $name"
  } > "$DIR/docs/jtbd/$name/persona.md"
}

# mk_job <persona-name> <NNN> <slug> <confirmed?yes|no> [state]
mk_job() {
  local persona="$1"; local num="$2"; local slug="$3"; local confirmed="$4"; local state="${5:-proposed}"
  mkdir -p "$DIR/docs/jtbd/$persona"
  {
    echo "---"
    echo "status: $state"
    echo "job-id: $slug"
    echo "persona: $persona"
    [ "$confirmed" = "yes" ] && { echo "human-oversight: confirmed"; echo "oversight-date: 2026-05-27"; }
    echo "---"
    echo "# $slug"
  } > "$DIR/docs/jtbd/$persona/JTBD-$num-$slug.md"
}

@test "persona without the marker is unconfirmed (exit 0, prints path)" {
  mk_persona "solo-developer" "no"
  run bash "$SCRIPT" "solo-developer" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"solo-developer/persona.md"* ]]
}

@test "persona carrying human-oversight: confirmed is confirmed (exit 1, no stdout)" {
  mk_persona "tech-lead" "yes"
  run bash "$SCRIPT" "tech-lead" "$DIR/docs/jtbd"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "job (JTBD-NNN) without the marker is unconfirmed (exit 0, prints path)" {
  mk_job "solo-developer" "001" "enforce-governance" "no"
  run bash "$SCRIPT" "JTBD-001" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"JTBD-001-enforce-governance.md"* ]]
}

@test "job carrying the marker is confirmed (exit 1)" {
  mk_job "tech-lead" "201" "restore-service-fast" "yes"
  run bash "$SCRIPT" "JTBD-201" "$DIR/docs/jtbd"
  [ "$status" -eq 1 ]
}

@test "superseded job (even without marker) does NOT fire the guard (exit 1)" {
  mkdir -p "$DIR/docs/jtbd/solo-developer"
  {
    echo "---"; echo "status: superseded"; echo "persona: solo-developer"; echo "---"; echo "# retired"
  } > "$DIR/docs/jtbd/solo-developer/JTBD-009-retired.superseded.md"
  run bash "$SCRIPT" "JTBD-009" "$DIR/docs/jtbd"
  [ "$status" -eq 1 ]
}

@test "a bare numeric job ref resolves" {
  mk_job "solo-developer" "002" "ship-with-confidence" "no"
  run bash "$SCRIPT" "002" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"JTBD-002-ship-with-confidence.md"* ]]
}

@test "a direct path ref resolves" {
  mk_persona "plugin-user" "no"
  run bash "$SCRIPT" "$DIR/docs/jtbd/plugin-user/persona.md"
  [ "$status" -eq 0 ]
}

@test "an unknown persona name exits 2 (not found)" {
  run bash "$SCRIPT" "ghost-persona" "$DIR/docs/jtbd"
  [ "$status" -eq 2 ]
}

@test "an unknown job ref exits 2 (not found)" {
  run bash "$SCRIPT" "JTBD-999" "$DIR/docs/jtbd"
  [ "$status" -eq 2 ]
}

@test "agrees with detect-unoversighted on the same fixture (sync guard)" {
  # The two scripts share the frontmatter/marker/superseded shape. This guard
  # fails if a future edit drifts one from the other.
  mk_persona "solo-developer" "no"
  mk_persona "tech-lead" "yes"
  detect_out="$(bash "$DETECT" "$DIR/docs/jtbd")"
  # solo-developer is in the detector's unoversighted list AND the predicate exits 0.
  [[ "$detect_out" == *"solo-developer/persona.md"* ]]
  run bash "$SCRIPT" "solo-developer" "$DIR/docs/jtbd"; [ "$status" -eq 0 ]
  # tech-lead is NOT in the detector's list AND the predicate exits 1.
  [[ "$detect_out" != *"tech-lead/persona.md"* ]]
  run bash "$SCRIPT" "tech-lead" "$DIR/docs/jtbd"; [ "$status" -eq 1 ]
}

# ADR-068 amendment (P316): mirror the architect `rejected-pending-supersede`
# exclusion onto the JTBD predicate.

# mk_rejected_persona <name> [supersede-ticket-or-empty]
mk_rejected_persona() {
  local name="$1"; local ticket="${2:-}"
  mkdir -p "$DIR/docs/jtbd/$name"
  {
    echo "---"
    echo "name: $name"
    echo "human-oversight: rejected-pending-supersede"
    [ -n "$ticket" ] && echo "supersede-ticket: $ticket"
    echo "---"
    echo "# $name"
  } > "$DIR/docs/jtbd/$name/persona.md"
}

@test "persona with rejected-pending-supersede + supersede-ticket does NOT fire the guard (exit 1)" {
  mk_rejected_persona "scrapped-persona" "P299"
  run bash "$SCRIPT" "scrapped-persona" "$DIR/docs/jtbd"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "persona with rejected-pending-supersede WITHOUT supersede-ticket DOES fire the guard (exit 0)" {
  mk_rejected_persona "untracked-persona" ""
  run bash "$SCRIPT" "untracked-persona" "$DIR/docs/jtbd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"untracked-persona/persona.md"* ]]
}

@test "agrees with detect-unoversighted on rejected-pending-supersede (sync guard)" {
  mk_rejected_persona "alpha-tracked" "P297"
  mk_rejected_persona "beta-untracked" ""
  detect_out="$(bash "$DETECT" "$DIR/docs/jtbd")"
  [[ "$detect_out" != *"alpha-tracked/persona.md"* ]]
  run bash "$SCRIPT" "alpha-tracked" "$DIR/docs/jtbd"; [ "$status" -eq 1 ]
  [[ "$detect_out" == *"beta-untracked/persona.md"* ]]
  run bash "$SCRIPT" "beta-untracked" "$DIR/docs/jtbd"; [ "$status" -eq 0 ]
}
