#!/usr/bin/env bats

# ADR-074: is-decision-unconfirmed.sh is the single-ADR predicate for the
# build-upon guard (manage-problem / work-problems propose-fix surface). It
# answers "is this referenced decision unconfirmed?" via its EXIT CODE, where
# "unconfirmed" mirrors detect-unoversighted.sh EXACTLY (frontmatter lacks
# `human-oversight: confirmed`, and the ADR is not superseded).
#
# Behavioural — exercises the script against fixture trees and asserts on its
# exit code + stdout, not its source text (ADR-052).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/architect/scripts/is-decision-unconfirmed.sh"
  DETECT="$REPO_ROOT/packages/architect/scripts/detect-unoversighted.sh"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/decisions"
}

teardown() {
  rm -rf "$DIR"
}

# mk <filename> <status> [extra-frontmatter-lines...]
mk() {
  local name="$1"; local status="$2"; shift 2
  {
    echo "---"
    echo "status: \"$status\""
    echo "date: 2026-05-27"
    for line in "$@"; do echo "$line"; done
    echo "---"
    echo "# $name"
  } > "$DIR/docs/decisions/$name"
}

@test "proposed ADR without the marker is unconfirmed (exit 0, prints path)" {
  mk "100-no-marker.proposed.md" "proposed"
  run bash "$SCRIPT" "ADR-100" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"100-no-marker.proposed.md"* ]]
}

@test "proposed ADR carrying human-oversight: confirmed is confirmed (exit 1, no stdout)" {
  mk "101-confirmed.proposed.md" "proposed" "human-oversight: confirmed" "oversight-date: 2026-05-27"
  run bash "$SCRIPT" "ADR-101" "$DIR/docs/decisions"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "accepted ADR without the marker is still unconfirmed (exit 0)" {
  mk "102-accepted-no-marker.accepted.md" "accepted"
  run bash "$SCRIPT" "ADR-102" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
}

@test "superseded ADR (even without marker) does NOT fire the guard (exit 1)" {
  mk "103-retired.superseded.md" "superseded"
  run bash "$SCRIPT" "ADR-103" "$DIR/docs/decisions"
  [ "$status" -eq 1 ]
}

@test "a bare numeric ref resolves" {
  mk "104-bare-num.proposed.md" "proposed"
  run bash "$SCRIPT" "104" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"104-bare-num.proposed.md"* ]]
}

@test "a direct path ref resolves" {
  mk "105-by-path.proposed.md" "proposed"
  run bash "$SCRIPT" "$DIR/docs/decisions/105-by-path.proposed.md"
  [ "$status" -eq 0 ]
}

@test "a per-state subdir layout resolves" {
  mkdir -p "$DIR/docs/decisions/proposed"
  {
    echo "---"; echo "status: \"proposed\""; echo "date: 2026-05-27"; echo "---"; echo "# subdir"
  } > "$DIR/docs/decisions/proposed/106-subdir.md"
  run bash "$SCRIPT" "ADR-106" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"106-subdir.md"* ]]
}

@test "an unknown ADR ref exits 2 (not found)" {
  run bash "$SCRIPT" "ADR-999" "$DIR/docs/decisions"
  [ "$status" -eq 2 ]
}

@test "an unparseable ref exits 2" {
  run bash "$SCRIPT" "not-an-adr" "$DIR/docs/decisions"
  [ "$status" -eq 2 ]
}

@test "agrees with detect-unoversighted on the same fixture (sync guard)" {
  # The two scripts share the frontmatter/marker/superseded shape. This guard
  # fails if a future edit drifts one from the other.
  mk "110-unconfirmed.proposed.md" "proposed"
  mk "111-confirmed.proposed.md" "proposed" "human-oversight: confirmed" "oversight-date: 2026-05-27"
  detect_out="$(bash "$DETECT" "$DIR/docs/decisions")"
  # 110 is in the detector's unoversighted list AND the predicate exits 0.
  [[ "$detect_out" == *"110-unconfirmed.proposed.md"* ]]
  run bash "$SCRIPT" "ADR-110" "$DIR/docs/decisions"; [ "$status" -eq 0 ]
  # 111 is NOT in the detector's list AND the predicate exits 1.
  [[ "$detect_out" != *"111-confirmed.proposed.md"* ]]
  run bash "$SCRIPT" "ADR-111" "$DIR/docs/decisions"; [ "$status" -eq 1 ]
}

# ADR-066 amendment (P316): mirror the rejected-pending-supersede exclusion.
# The build-upon guard must NOT fire on an ADR the user explicitly rejected
# with a tracked supersede ticket — otherwise the [Unratified Dependency]
# verdict re-triggers on every iteration that touches the rejected ADR.

@test "rejected-pending-supersede WITH supersede-ticket does NOT fire the guard (exit 1)" {
  mk "120-rejected-tracked.proposed.md" "proposed" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P297"
  run bash "$SCRIPT" "ADR-120" "$DIR/docs/decisions"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "rejected-pending-supersede WITHOUT supersede-ticket DOES fire the guard (exit 0)" {
  mk "121-rejected-untracked.proposed.md" "proposed" \
    "human-oversight: rejected-pending-supersede"
  run bash "$SCRIPT" "ADR-121" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"121-rejected-untracked.proposed.md"* ]]
}

@test "agrees with detect-unoversighted on rejected-pending-supersede (sync guard)" {
  mk "130-rejected.proposed.md" "proposed" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P298"
  mk "131-rejected-untracked.proposed.md" "proposed" \
    "human-oversight: rejected-pending-supersede"
  detect_out="$(bash "$DETECT" "$DIR/docs/decisions")"
  [[ "$detect_out" != *"130-rejected.proposed.md"* ]]
  run bash "$SCRIPT" "ADR-130" "$DIR/docs/decisions"; [ "$status" -eq 1 ]
  [[ "$detect_out" == *"131-rejected-untracked.proposed.md"* ]]
  run bash "$SCRIPT" "ADR-131" "$DIR/docs/decisions"; [ "$status" -eq 0 ]
}
