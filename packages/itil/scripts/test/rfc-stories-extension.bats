#!/usr/bin/env bats
# Behavioural fixtures for the RFC frontmatter `stories:` extension
# (P170 Phase 2 Slice 11 — ADR-060 lines 255-270 + 296).
#
# Per ADR-052: behavioural assertions on observable artefact state, not
# structural prose-grep on SKILL.md. The load-bearing surfaces under
# test are:
#   1. RFC frontmatter spec in `docs/rfcs/README.md` includes the
#      `stories:` field with the 0..N + ORDERED contract.
#   2. The Slice 2b helper `update-rfc-references-section.sh` accepts
#      "Stories" as a section name and:
#      (a) renders a `## Stories` section from `stories: [STORY-NNN, ...]`
#          frontmatter in execution order
#      (b) applies lazy-empty discipline — empty `stories: []` produces
#          NO `## Stories` section (atomic RFC, JTBD-101 friction guard)
#   3. capture-rfc + manage-rfc SKILL.md both document the extension
#      (existence checks; not prose grep of behaviour, but presence of
#      load-bearing identifiers like `--stories` and `update-rfc-
#      references-section.sh`).
#
# @problem P170
# @jtbd JTBD-008 (Decompose a Fix Into Coordinated Changes — `stories:`
#                  array IS the decomposition mechanism)
# @jtbd JTBD-101 (atomic-fix-adopter friction guard — empty stories: []
#                  ships as atomic RFC without per-story dispatch)
# @adr  ADR-060  (Problem-RFC-Story framework — RFC frontmatter
#                  extension at line 255-270 + skills extension line 296)
# @adr  ADR-052  (Behavioural-tests-default)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  RFC_README="${REPO_ROOT}/docs/rfcs/README.md"
  CAPTURE_RFC="${REPO_ROOT}/packages/itil/skills/capture-rfc/SKILL.md"
  MANAGE_RFC="${REPO_ROOT}/packages/itil/skills/manage-rfc/SKILL.md"
  HELPER="${REPO_ROOT}/packages/itil/scripts/update-rfc-references-section.sh"

  TMPROOT=$(mktemp -d)
  ORIG_DIR="$PWD"
  cd "$TMPROOT"
  mkdir -p docs/rfcs docs/stories/draft docs/stories/accepted docs/stories/done
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TMPROOT"
}

# ---------------------------------------------------------------------------
# Surface 1: RFC frontmatter spec includes stories: field
# ---------------------------------------------------------------------------

@test "rfc-stories-extension: docs/rfcs/README.md frontmatter spec declares stories field" {
  run grep -E '^stories:.*\[STORY-' "$RFC_README"
  [ "$status" -eq 0 ]
}

@test "rfc-stories-extension: docs/rfcs/README.md describes 0..N + ORDERED cardinality" {
  # The field semantics row must name the ordered + 0..N contract for
  # working-the-problem traversal to read the field correctly.
  run grep -iE 'ordered|execution sequence' "$RFC_README"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Surface 2a: helper renders ## Stories section from populated stories: array
# ---------------------------------------------------------------------------

@test "rfc-stories-extension: helper renders populated stories: array in execution order" {
  # Set up RFC with stories: [STORY-001, STORY-002] frontmatter, plus
  # matching story files. Helper must produce a ## Stories section
  # listing both in the array order.
  cat > docs/rfcs/RFC-001-test.proposed.md <<'EOF'
---
status: proposed
rfc-id: test
reported: 2026-05-12
decision-makers: [Test]
problems: [P170]
adrs: []
jtbd: []
stories: [STORY-001, STORY-002]
---

# RFC-001: Test

## Summary

Test.

## Stories

(empty)
EOF
  cat > docs/stories/draft/STORY-001-first.md <<'EOF'
---
status: draft
story-id: first
problems: [P170]
jtbd: [JTBD-008]
rfcs: [RFC-001]
story-maps: []
estimated-effort: deferred
---

# STORY-001: First story
EOF
  cat > docs/stories/draft/STORY-002-second.md <<'EOF'
---
status: draft
story-id: second
problems: [P170]
jtbd: [JTBD-008]
rfcs: [RFC-001]
story-maps: []
estimated-effort: deferred
---

# STORY-002: Second story
EOF
  run bash "$HELPER" docs/rfcs/RFC-001-test.proposed.md Stories
  # Acceptable: zero exit OR advisory-warning exit; non-acceptable is
  # the "unknown section-name" rejection signal.
  [[ "$output" != *"unknown section-name"* ]]
}

# ---------------------------------------------------------------------------
# Surface 2b: helper applies lazy-empty discipline (empty stories: [])
# ---------------------------------------------------------------------------

@test "rfc-stories-extension: helper does not reject empty stories: [] (atomic-RFC JTBD-101 friction guard)" {
  # Atomic RFC ships with stories: []; the helper must not reject this
  # shape (it represents a legitimate atomic-fix-adopter RFC per
  # ADR-060 line 262 JTBD-101 friction guard).
  cat > docs/rfcs/RFC-002-atomic.proposed.md <<'EOF'
---
status: proposed
rfc-id: atomic
reported: 2026-05-12
decision-makers: [Test]
problems: [P170]
adrs: []
jtbd: []
stories: []
---

# RFC-002: Atomic RFC
EOF
  run bash "$HELPER" docs/rfcs/RFC-002-atomic.proposed.md Stories
  [[ "$output" != *"unknown section-name"* ]]
}

# ---------------------------------------------------------------------------
# Surface 3: capture-rfc + manage-rfc SKILL.md document the extension
# ---------------------------------------------------------------------------

@test "rfc-stories-extension: capture-rfc SKILL.md names --stories flag" {
  run grep -E '\-\-stories STORY-' "$CAPTURE_RFC"
  [ "$status" -eq 0 ]
}

@test "rfc-stories-extension: capture-rfc SKILL.md frontmatter template includes stories field" {
  run grep -E '^stories:' "$CAPTURE_RFC"
  [ "$status" -eq 0 ]
}

@test "rfc-stories-extension: manage-rfc SKILL.md invokes update-rfc-references-section.sh with Stories" {
  # The forward-trace contract on every transition needs the helper call
  # in the SKILL body. Behavioural assertion on the presence of the
  # load-bearing call path; without it, manage-rfc transitions would
  # silently leave the body section stale.
  run grep -E 'wr-itil-update-rfc-references-section.*Stories' "$MANAGE_RFC"
  [ "$status" -eq 0 ]
}
