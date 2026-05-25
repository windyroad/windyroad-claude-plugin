#!/usr/bin/env bats

# ADR-068: jtbd-oversight-nudge.sh (SessionStart) emits a one-line nudge when
# jobs/personas lack the human-oversight marker, is silent when none do, and
# self-suppresses under the shared AFK guard (WR_SUPPRESS_OVERSIGHT_NUDGE=1).
# Behavioural — exercises the hook against fixture docs/jtbd/ trees.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/jtbd/hooks/jtbd-oversight-nudge.sh"
  PLUGIN_ROOT="$REPO_ROOT/packages/jtbd"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/jtbd/solo-developer"
}

teardown() { rm -rf "$DIR"; }

mk_unmarked() {
  mkdir -p "$(dirname "$DIR/docs/jtbd/$1")"
  { echo "---"; echo "status: proposed"; echo "date-created: 2026-05-25"; echo "---"; echo "# $1"; } \
    > "$DIR/docs/jtbd/$1"
}
mk_marked() {
  mkdir -p "$(dirname "$DIR/docs/jtbd/$1")"
  { echo "---"; echo "status: proposed"; echo "human-oversight: confirmed"; echo "---"; echo "# $1"; } \
    > "$DIR/docs/jtbd/$1"
}

@test "emits a count line when there are unoversighted jobs/personas" {
  mk_unmarked "solo-developer/persona.md"
  mk_unmarked "solo-developer/JTBD-001-foo.proposed.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 jobs/personas lack human oversight"* ]]
  [[ "$output" == *"/wr-jtbd:confirm-jobs-and-personas"* ]]
}

@test "uses singular wording for exactly one unoversighted artifact" {
  mk_unmarked "solo-developer/persona.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [[ "$output" == *"1 job/persona lacks human oversight"* ]]
}

@test "silent when every job/persona is confirmed" {
  mk_marked "solo-developer/persona.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "shared AFK guard suppresses the nudge entirely" {
  mk_unmarked "solo-developer/persona.md"
  run env WR_SUPPRESS_OVERSIGHT_NUDGE=1 CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard value other than 1 does not suppress" {
  mk_unmarked "solo-developer/persona.md"
  mk_unmarked "solo-developer/JTBD-001-foo.proposed.md"
  run env WR_SUPPRESS_OVERSIGHT_NUDGE=0 CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [[ "$output" == *"lack human oversight"* ]]
}

@test "silent when project has no docs/jtbd dir" {
  run env CLAUDE_PROJECT_DIR="$DIR/empty" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
