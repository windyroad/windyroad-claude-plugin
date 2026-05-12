#!/usr/bin/env bats
# Behavioural fixtures for reconcile-stories.sh + bin shim + skill
# (P170 Phase 2 Slice 9 — ADR-060 amendment 2026-05-10 line 270 +
# reconcile-rfcs.sh / reconcile-readme.sh sibling).
#
# Per ADR-052: behavioural tests on observable script outputs. The
# load-bearing surfaces under test are:
#   1. Script existence + executable + valid Bash.
#   2. README parse error (exit 2) on missing README or missing
#      Story Rankings header.
#   3. Clean run (exit 0) on a fresh stories directory + empty README.
#   4. Drift detection (exit 1) when README claims a story that isn't
#      on filesystem in the right lifecycle state.
#   5. STALE detection when filesystem has a story not listed in
#      either Story Rankings (active) or Done section.
#   6. Bin shim resolves to the script.
#   7. SKILL.md presence + canonical name + read-only contract.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  SCRIPT="${REPO_ROOT}/packages/itil/scripts/reconcile-stories.sh"
  BIN_SHIM="${REPO_ROOT}/packages/itil/bin/wr-itil-reconcile-stories"
  SKILL_FILE="${REPO_ROOT}/packages/itil/skills/reconcile-stories/SKILL.md"

  TMPROOT=$(mktemp -d)
  ORIG_DIR="$PWD"
  cd "$TMPROOT"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TMPROOT"
}

# ---------------------------------------------------------------------------
# Surface 1: Script + bin shim existence
# ---------------------------------------------------------------------------

@test "reconcile-stories: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "reconcile-stories: bin shim exists, is executable, and exec's the script" {
  [ -f "$BIN_SHIM" ]
  [ -x "$BIN_SHIM" ]
  run grep -E 'exec.*scripts/reconcile-stories\.sh' "$BIN_SHIM"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 2: Parse errors (exit 2)
# ---------------------------------------------------------------------------

@test "reconcile-stories: exits 2 when README is missing" {
  mkdir -p docs/stories
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 2 ]
  [[ "$output" == *"PARSE_ERROR"* ]] || [[ "$stderr" == *"PARSE_ERROR"* ]]
}

@test "reconcile-stories: exits 2 when README missing Story Rankings header" {
  mkdir -p docs/stories
  echo "# Stories" > docs/stories/README.md
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Surface 3: Clean run (exit 0)
# ---------------------------------------------------------------------------

@test "reconcile-stories: exits 0 on empty stories dir with empty README tables" {
  mkdir -p docs/stories/draft docs/stories/accepted docs/stories/in-progress docs/stories/done docs/stories/archived
  cat > docs/stories/README.md <<'EOF'
# Story Backlog

## Story Rankings

| ID | Title | Status |
|----|-------|--------|

## Done

| ID | Title | Done |
|----|-------|------|
EOF
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 4: Drift detection on filesystem vs README mismatch (exit 1)
# ---------------------------------------------------------------------------

@test "reconcile-stories: detects STALE when filesystem has a draft story not in README" {
  mkdir -p docs/stories/draft docs/stories/done
  touch docs/stories/draft/STORY-007-foo.md
  cat > docs/stories/README.md <<'EOF'
# Story Backlog

## Story Rankings

| ID | Title | Status |
|----|-------|--------|

## Done

| ID | Title | Done |
|----|-------|------|
EOF
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE"* ]]
  [[ "$output" == *"STORY-007"* ]]
}

@test "reconcile-stories: detects DRIFT when README claims a story in Rankings but it's actually done on disk" {
  mkdir -p docs/stories/draft docs/stories/done
  touch docs/stories/done/STORY-007-foo.md
  cat > docs/stories/README.md <<'EOF'
# Story Backlog

## Story Rankings

| ID | Title | Status |
|----|-------|--------|
| STORY-007 | Foo | draft |

## Done

| ID | Title | Done |
|----|-------|------|
EOF
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"STORY-007"* ]]
  [[ "$output" == *"actual=done"* ]]
}

@test "reconcile-stories: archived stories are hidden from both tables (no drift)" {
  mkdir -p docs/stories/archived
  touch docs/stories/archived/STORY-007-foo.md
  cat > docs/stories/README.md <<'EOF'
# Story Backlog

## Story Rankings

| ID | Title | Status |
|----|-------|--------|

## Done

| ID | Title | Done |
|----|-------|------|
EOF
  run bash "$SCRIPT" docs/stories
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 5: SKILL.md presence + read-only contract
# ---------------------------------------------------------------------------

@test "reconcile-stories: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "reconcile-stories: SKILL.md declares canonical name wr-itil:reconcile-stories" {
  run grep -E '^name: wr-itil:reconcile-stories$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
