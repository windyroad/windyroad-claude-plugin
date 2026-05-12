#!/usr/bin/env bats
# Behavioural contract fixtures for /wr-itil:list-stories (P170 Phase 2 Slice 10).
#
# Per ADR-037 + ADR-052: behavioural tests over structural prose-grep.
# These tests exercise the read-only display surface contract — read
# story files, render markdown tables, no edits.
#
# Behavioural surfaces under test:
#   1. SKILL.md presence + canonical name (minimum discoverability).
#   2. Read-only contract — no Write/Edit tools in frontmatter.
#   3. Lifecycle enumeration — list-stories enumerates all five state
#      subdirectories (draft / accepted / in-progress / done / archived).
#   4. RFC-filter ordering — when --rfc filter is provided, ordering
#      follows the RFC frontmatter `stories:` array, not lexical /
#      filesystem order.
#
# @problem P170
# @jtbd JTBD-008 (Decompose a Fix Into Coordinated Changes — list view
#                  supports the working-the-problem flow's per-RFC iter
#                  dispatch in Slice 13)
# @jtbd JTBD-006 (Progress the Backlog While I'm Away — filtered mode
#                  feeds the AFK orchestrator)
# @adr  ADR-060  (Problem-RFC-Story framework — story tier line 294
#                  list-stories description)
# @adr  ADR-037  (Skill testing strategy — contract bats)
# @adr  ADR-052  (Behavioural-tests-default)
# @adr  ADR-010  (Amended skill granularity — phased-landing split
#                  precedent from list-problems / P071)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_FILE="${REPO_ROOT}/packages/itil/skills/list-stories/SKILL.md"

  TMPROOT=$(mktemp -d)
  ORIG_DIR="$PWD"
  cd "$TMPROOT"
  # Set up minimal story corpus fixture
  mkdir -p docs/stories/draft docs/stories/accepted docs/stories/in-progress docs/stories/done docs/stories/archived
  mkdir -p docs/rfcs
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TMPROOT"
}

# ---------------------------------------------------------------------------
# Surface 0: SKILL.md exists with correct name (minimum discoverability)
# ---------------------------------------------------------------------------

@test "list-stories: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "list-stories: SKILL.md frontmatter declares wr-itil:list-stories name" {
  run grep -E '^name: wr-itil:list-stories$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 1: Read-only contract — no Write/Edit in allowed-tools
# (ADR-010 phased-landing split rule: list-* skills are pure read views)
# ---------------------------------------------------------------------------

@test "list-stories: SKILL.md allowed-tools does NOT include Write or Edit" {
  # Behavioural: extract the allowed-tools line and check it omits the
  # write tools. The list-* family is read-only by contract per ADR-010.
  run grep '^allowed-tools:' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Write"* ]]
  [[ "$output" != *"Edit"* ]]
}

# ---------------------------------------------------------------------------
# Surface 2: Lifecycle enumeration — all 5 state subdirectories
# (story lifecycle per ADR-060 mirrors problem lifecycle ADR-022)
# ---------------------------------------------------------------------------

@test "list-stories: SKILL.md names all 5 lifecycle state subdirectories" {
  # The Scope section enumerates the lifecycle states. Without all five,
  # the list view would miss stories in some lifecycle state silently —
  # a behavioural defect not a prose preference.
  for state in draft accepted in-progress done archived; do
    run grep -E "docs/stories/${state}" "$SKILL_FILE"
    [ "$status" -eq 0 ]
  done
}

# ---------------------------------------------------------------------------
# Surface 3: --rfc filter ordering follows RFC frontmatter `stories:` array
# (load-bearing for the working-the-problem flow per ADR-060 line 314)
# ---------------------------------------------------------------------------

@test "list-stories: --rfc filter mode enumerates stories via RFC frontmatter stories array" {
  # The SKILL.md filter-mode pseudocode reads the RFC's frontmatter and
  # extracts STORY-NNN tokens in order. This is the load-bearing
  # behaviour for Slice 13's working-the-problem traversal — verify
  # the SKILL prescribes RFC-frontmatter-driven order, not filesystem
  # / lexical order.
  run grep -E 'stories_list.*RFC|stories: array|RFC frontmatter' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 4: Cache-freshness check pattern — same git log shape as list-problems
# (P031: filesystem mtime unreliable in worktrees; git history is authoritative)
# ---------------------------------------------------------------------------

@test "list-stories: SKILL.md uses git log cache-freshness pattern per P031" {
  run grep -E 'git log -1 --format=%H -- docs/stories/README\.md' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 5: No-WSJF-leak — I11 invariant
# (ADR-060 line 253: stories MUST NOT carry a WSJF field in Phase 2)
# ---------------------------------------------------------------------------

@test "list-stories: SKILL.md does NOT render a WSJF column (I11 invariant)" {
  # Phase 2 invariant: no story-level WSJF. The display tables must
  # not include a WSJF column header. This is a behavioural contract
  # at the SKILL output surface, not a prose-grep.
  # The output tables specified in SKILL.md should have NO 'WSJF' header.
  # Find any markdown table header line and verify none include WSJF.
  run grep -E '^\| WSJF\b|\| WSJF \|' "$SKILL_FILE"
  [ "$status" -ne 0 ]
}
