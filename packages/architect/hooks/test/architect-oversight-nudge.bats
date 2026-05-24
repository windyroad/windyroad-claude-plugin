#!/usr/bin/env bats

# ADR-066: architect-oversight-nudge.sh (SessionStart) emits a one-line nudge
# when ADRs lack the human-oversight marker, is silent when none do, and
# self-suppresses under the AFK guard (WR_SUPPRESS_OVERSIGHT_NUDGE=1) so the
# interactive batch-confirm never fires into an absent-user iteration (JTBD-006).
# Behavioural — exercises the hook against fixture trees and asserts on stdout.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  HOOK="$REPO_ROOT/packages/architect/hooks/architect-oversight-nudge.sh"
  PLUGIN_ROOT="$REPO_ROOT/packages/architect"
  DIR="$(mktemp -d)"
  mkdir -p "$DIR/docs/decisions"
}

teardown() {
  rm -rf "$DIR"
}

mk_unmarked() {
  { echo "---"; echo "status: \"proposed\""; echo "date: 2026-05-25"; echo "---"; echo "# $1"; } \
    > "$DIR/docs/decisions/$1"
}
mk_marked() {
  { echo "---"; echo "status: \"proposed\""; echo "date: 2026-05-25"; echo "human-oversight: confirmed"; echo "---"; echo "# $1"; } \
    > "$DIR/docs/decisions/$1"
}

@test "emits a count line when there are unoversighted ADRs" {
  mk_unmarked "010-a.proposed.md"
  mk_unmarked "011-b.proposed.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 recorded decisions lack human oversight"* ]]
  [[ "$output" == *"/wr-architect:review-decisions"* ]]
}

@test "uses singular wording for exactly one unoversighted ADR" {
  mk_unmarked "010-a.proposed.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [[ "$output" == *"1 recorded decision lacks human oversight"* ]]
}

@test "silent when every ADR is confirmed" {
  mk_marked "010-a.proposed.md"
  run env CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "AFK guard suppresses the nudge entirely" {
  mk_unmarked "010-a.proposed.md"
  run env WR_SUPPRESS_OVERSIGHT_NUDGE=1 CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard value other than 1 does not suppress" {
  mk_unmarked "010-a.proposed.md"
  mk_unmarked "011-b.proposed.md"
  run env WR_SUPPRESS_OVERSIGHT_NUDGE=0 CLAUDE_PROJECT_DIR="$DIR" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [[ "$output" == *"lack human oversight"* ]]
}

@test "silent when project has no docs/decisions dir" {
  run env CLAUDE_PROJECT_DIR="$DIR/empty" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
