#!/usr/bin/env bats

# ADR-066: detect-unoversighted.sh prints ADRs whose frontmatter lacks the
# `human-oversight: confirmed` marker. Behavioural — exercises the script
# against fixture trees and asserts on its stdout, not its source text.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="$REPO_ROOT/packages/architect/scripts/detect-unoversighted.sh"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/decisions"
}

teardown() {
  rm -rf "$DIR"
}

mk() { # mk <filename> <frontmatter-extra-lines...>
  local name="$1"; shift
  {
    echo "---"
    echo "status: \"proposed\""
    echo "date: 2026-05-25"
    for line in "$@"; do echo "$line"; done
    echo "---"
    echo "# $name"
  } > "$DIR/docs/decisions/$name"
}

@test "an ADR without the marker is reported" {
  mk "010-no-marker.proposed.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"010-no-marker.proposed.md"* ]]
}

@test "an ADR carrying human-oversight: confirmed is NOT reported" {
  mk "011-confirmed.proposed.md" "human-oversight: confirmed" "oversight-date: 2026-05-25"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" != *"011-confirmed.proposed.md"* ]]
}

@test "marker match is case-insensitive and tolerant of trailing space" {
  mk "012-spacey.proposed.md" "human-oversight:   confirmed   "
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" != *"012-spacey.proposed.md"* ]]
}

@test "README.md is never reported" {
  echo "# index" > "$DIR/docs/decisions/README.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" != *"README.md"* ]]
}

@test "superseded ADRs are excluded even without the marker" {
  mk "013-old.superseded.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" != *"013-old.superseded.md"* ]]
}

@test "a file with no frontmatter counts as unoversighted" {
  echo "# bare ADR, no frontmatter" > "$DIR/docs/decisions/014-bare.proposed.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" == *"014-bare.proposed.md"* ]]
}

@test "a body line that looks like the marker does not count (frontmatter only)" {
  {
    echo "---"
    echo "status: \"proposed\""
    echo "date: 2026-05-25"
    echo "---"
    echo "# 015"
    echo "human-oversight: confirmed"   # in body, not frontmatter
  } > "$DIR/docs/decisions/015-body-trick.proposed.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" == *"015-body-trick.proposed.md"* ]]
}

@test "accepted ADRs are in scope (oversight is orthogonal to status)" {
  mk "016-shipped.accepted.md"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" == *"016-shipped.accepted.md"* ]]
}

@test "missing decisions dir exits 0 with no output" {
  run bash "$SCRIPT" "$DIR/docs/nonexistent"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fully-confirmed set produces empty output" {
  mk "017-a.proposed.md" "human-oversight: confirmed"
  mk "018-b.accepted.md" "human-oversight: confirmed"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ADR-066 amendment (P316): rejected-pending-supersede is a third oversight
# value alongside `confirmed` and absent. It exists so the drain stops crying
# wolf on ADRs the user has explicitly rejected with a tracked supersede
# ticket (otherwise they re-surface every drain until the supersede ADR
# lands). Exclusion is conditional on BOTH the marker AND a supersede-ticket
# scalar being present — a marker without a ticket is malformed and still
# surfaces (defensive, JTBD-201/202 audit-trail guard).

@test "rejected-pending-supersede WITH supersede-ticket is excluded" {
  mk "020-rejected-tracked.proposed.md" \
    "human-oversight: rejected-pending-supersede" \
    "supersede-ticket: P297"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" != *"020-rejected-tracked.proposed.md"* ]]
}

@test "rejected-pending-supersede WITHOUT supersede-ticket still surfaces (defensive)" {
  mk "021-rejected-untracked.proposed.md" \
    "human-oversight: rejected-pending-supersede"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"021-rejected-untracked.proposed.md"* ]]
}

@test "supersede-ticket alone (without the rejected marker) does NOT exclude" {
  mk "022-ticket-only.proposed.md" "supersede-ticket: P297"
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [ "$status" -eq 0 ]
  [[ "$output" == *"022-ticket-only.proposed.md"* ]]
}

@test "rejected-pending-supersede match tolerates trailing whitespace" {
  mk "023-spacey.proposed.md" \
    "human-oversight:   rejected-pending-supersede   " \
    "supersede-ticket:   P297   "
  run bash "$SCRIPT" "$DIR/docs/decisions"
  [[ "$output" != *"023-spacey.proposed.md"* ]]
}
