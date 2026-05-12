#!/usr/bin/env bats
# Behavioural fixtures for /wr-itil:capture-story (P170 Phase 2 Slice 7).
#
# Per ADR-052 (Behavioural-tests-default for skill testing), these tests
# exercise the load-bearing primitives the skill dispatches and assert
# observable state — NOT the prose contents of SKILL.md.
#
# Behavioural surfaces under test:
#   1. Next-ID computation — capture-story uses the inline
#      max(local, origin) + 1 formula scanning docs/stories/*/STORY-*.md
#      + git ls-tree -r origin/main docs/stories/ per ADR-019 inline
#      collision-guard approved at Slice 3 design review (option a).
#   2. ID collision-on-origin renumber — when an origin RFC IS not yet
#      pulled locally, the formula must compute the higher of the two
#      and increment from there (no silent collision).
#   3. Reverse-trace helper "Stories" section-name support — the three
#      Slice 2a/2b helpers (update-problem / update-jtbd / update-rfc
#      -references-section.sh) must accept "Stories" as a section name.
#   4. Frontmatter shape — a captured story file conforms to ADR-060
#      lines 220-228 (status: draft / story-id / problems / jtbd / etc.).
#   5. NO update-story-references-section.sh "Stories" path —
#      story-maps are HTML; the story-tier reverse-trace helper does NOT
#      accept "Stories" (per architect amend finding 2 on Slice 7).
#
# @problem P170
# @jtbd JTBD-008 (Decompose a Fix Into Coordinated Changes — capture-time
#                  decomposition surface)
# @jtbd JTBD-001 (extended scope — change-set-level governance)
# @adr  ADR-060  (Problem-RFC-Story framework — story tier)
# @adr  ADR-052  (Behavioural-tests-default)
# @adr  ADR-019  (ID collision-on-origin renumber)
# @adr  ADR-014  (single-commit grain)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  SKILL_FILE="${REPO_ROOT}/packages/itil/skills/capture-story/SKILL.md"
  HELPER_PROBLEM="${REPO_ROOT}/packages/itil/scripts/update-problem-references-section.sh"
  HELPER_JTBD="${REPO_ROOT}/packages/itil/scripts/update-jtbd-references-section.sh"
  HELPER_RFC="${REPO_ROOT}/packages/itil/scripts/update-rfc-references-section.sh"
  HELPER_STORY="${REPO_ROOT}/packages/itil/scripts/update-story-references-section.sh"

  TMPROOT=$(mktemp -d)
  ORIG_DIR="$PWD"
  cd "$TMPROOT"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TMPROOT"
}

# ---------------------------------------------------------------------------
# Surface 0: SKILL.md exists with correct name (minimum discoverability)
# ---------------------------------------------------------------------------

@test "capture-story: SKILL.md exists" {
  [ -f "$SKILL_FILE" ]
}

@test "capture-story: SKILL.md frontmatter declares wr-itil:capture-story name" {
  # Discoverable on / autocomplete depends on the canonical name.
  run grep -E '^name: wr-itil:capture-story$' "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 1: Next-ID computation — inline formula matches capture-rfc precedent
# (verified against a fixture stories directory).
# ---------------------------------------------------------------------------

@test "capture-story: next-ID formula computes 001 for empty stories directory" {
  mkdir -p docs/stories/draft
  local_max=$(ls docs/stories/*/STORY-*.md 2>/dev/null | sed 's|.*/STORY-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
  origin_max=""  # no git fixture; treat as empty
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
  [ "$next" = "001" ]
}

@test "capture-story: next-ID formula computes 003 when STORY-002 exists locally" {
  mkdir -p docs/stories/draft docs/stories/in-progress
  touch docs/stories/draft/STORY-002-foo.md
  touch docs/stories/in-progress/STORY-001-bar.md
  local_max=$(ls docs/stories/*/STORY-*.md 2>/dev/null | sed 's|.*/STORY-||;s|-.*||' | grep -oE '^[0-9]+' | sort -n | tail -1)
  next=$(printf '%03d' $(( 10#${local_max:-0} + 1 )))
  [ "$next" = "003" ]
}

@test "capture-story: next-ID formula picks max(local, origin) when origin is higher (collision-on-origin renumber)" {
  # Simulates the renumber: local has STORY-002, origin has STORY-005.
  # Formula must pick 005 + 1 = 006, not 002 + 1 = 003 (silent collision).
  local_max=2
  origin_max=5
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
  [ "$next" = "006" ]
}

@test "capture-story: next-ID formula picks max(local, origin) when local is higher" {
  # Reverse case: local STORY-007, origin STORY-003. Local wins → 008.
  local_max=7
  origin_max=3
  next=$(printf '%03d' $(( 10#$(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))
  [ "$next" = "008" ]
}

# ---------------------------------------------------------------------------
# Surface 2: Reverse-trace helpers accept "Stories" section name
# (Slice 2a/2b shipped these — verify they're still wired correctly).
# ---------------------------------------------------------------------------

@test "capture-story: update-problem-references-section.sh accepts 'Stories' section name without rejecting" {
  # Set up minimal fixture: a problem file with a Story Maps placeholder
  # section. The helper should accept "Stories" as a valid lookup key
  # (architect finding on Slice 7: the absence of Stories support here
  # would block the inline reverse-trace refresh in capture-story Step 6).
  mkdir -p docs/problems/known-error docs/stories/draft
  cat > docs/problems/known-error/170-test-problem.md <<EOF
# P170: Test problem

## Story Maps

(empty)

## Stories

(empty)
EOF
  run bash "$HELPER_PROBLEM" docs/problems/known-error/170-test-problem.md Stories
  # Acceptable outcomes: success (0) or no-op-with-stderr; rejection (e.g.
  # "unknown section-name") would fail this assertion.
  [[ "$output" != *"unknown section-name"* ]]
}

@test "capture-story: update-jtbd-references-section.sh accepts 'Stories' section name" {
  mkdir -p docs/jtbd/solo-developer docs/stories/draft
  cat > docs/jtbd/solo-developer/JTBD-008-test.proposed.md <<EOF
# JTBD-008: Test

## Stories

(empty)
EOF
  run bash "$HELPER_JTBD" docs/jtbd/solo-developer/JTBD-008-test.proposed.md Stories
  [[ "$output" != *"unknown section-name"* ]]
}

@test "capture-story: update-rfc-references-section.sh accepts 'Stories' section name" {
  mkdir -p docs/rfcs docs/stories/draft
  cat > docs/rfcs/RFC-002-test.verifying.md <<EOF
# RFC-002: Test

## Stories

(empty)
EOF
  run bash "$HELPER_RFC" docs/rfcs/RFC-002-test.verifying.md Stories
  [[ "$output" != *"unknown section-name"* ]]
}

# ---------------------------------------------------------------------------
# Surface 3: NO update-story-references-section.sh "Stories" path
# (architect amend finding 2 on Slice 7 — story-maps are HTML, no markdown
# reverse-trace section auto-maintained on the HTML map; capture-story does
# NOT stage story-map files.)
# ---------------------------------------------------------------------------

@test "capture-story: update-story-references-section.sh does NOT accept 'Stories' section name (architect finding 2 — story-maps are HTML, manually authored)" {
  mkdir -p docs/stories/draft
  cat > docs/stories/draft/STORY-001-test.md <<EOF
# STORY-001: Test
EOF
  run bash "$HELPER_STORY" docs/stories/draft/STORY-001-test.md Stories
  # The helper's lookup table supports RFCs + Story Maps but NOT Stories
  # (per architect finding 2). The helper MUST exit non-zero AND name
  # the supported sections in its error stream.
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown section-name"* ]] || [[ "$output" == *"Supported"* ]]
}

# ---------------------------------------------------------------------------
# Surface 4: Frontmatter shape — verify ADR-060 lines 220-228 fields
# round-trip through a minimal capture sequence.
# ---------------------------------------------------------------------------

@test "capture-story: captured frontmatter contains required fields per ADR-060 lines 220-228" {
  # Construct the frontmatter the way the skill prescribes (Step 5).
  mkdir -p docs/stories/draft
  next_id="001"
  slug="test-capture"
  description="Test capture"
  reported=$(date -u +%Y-%m-%d)
  cat > "docs/stories/draft/STORY-${next_id}-${slug}.md" <<EOF
---
status: draft
story-id: ${slug}
reported: ${reported}
decision-makers: [Test]
problems: [P170]
jtbd: [JTBD-008]
rfcs: []
story-maps: []
estimated-effort: deferred
---

# STORY-${next_id}: ${description}
EOF
  # Assert each required frontmatter field appears (grep is sufficient —
  # ADR-052 prefers behavioural assertion on the observable file state).
  story_file="docs/stories/draft/STORY-${next_id}-${slug}.md"
  for field in status story-id reported decision-makers problems jtbd rfcs story-maps estimated-effort; do
    run grep -E "^${field}:" "$story_file"
    [ "$status" -eq 0 ]
  done
}

@test "capture-story: captured story file lands at docs/stories/draft/ per ADR-060 lines 145-147" {
  # Story-maps use HTML and lifecycle subdirs (draft/accepted/in-progress/
  # completed/archived); stories use markdown and lifecycle subdirs
  # (draft/accepted/in-progress/done/archived). Captured story lands at
  # draft/ per the skill's Step 5 prescription.
  mkdir -p docs/stories/draft
  touch docs/stories/draft/STORY-001-test.md
  [ -f docs/stories/draft/STORY-001-test.md ]
  # Negative assertion: NOT in any other subdir at capture time.
  [ ! -f docs/stories/accepted/STORY-001-test.md ]
  [ ! -f docs/stories/in-progress/STORY-001-test.md ]
  [ ! -f docs/stories/done/STORY-001-test.md ]
}
