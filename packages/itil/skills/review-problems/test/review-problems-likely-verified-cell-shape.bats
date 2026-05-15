#!/usr/bin/env bats

# P186: `Likely verified?` column in docs/problems/README.md
# Verification Queue must carry an evidence-first cell shape — NOT
# the original P048 Candidate 4 age-based heuristic (≥14 days = yes).
# Sibling proxy-for-evidence anti-pattern to P185 at the review-problems
# Step 3/5 surface. User critique 2026-05-12: "I don't like 'it's been
# a while, so likely verified' approach. We want firm evidence. For
# these, it should be things you actually observe."
#
# Three canonical values per P186:
#   yes — observed: <evidence>   (session-observed evidence the fix works)
#   no — not observed            (fix released, no evidence yet; default)
#   no — observed regression     (fix released, bug recurred)
#
# Hybrid coverage per ADR-005 + ADR-037 + ADR-052:
#   - Structural contract-assertions (Permitted Exception per ADR-005 /
#     contract-assertion pattern per ADR-037 — narrowly scoped to marker
#     presence per architect verdict): each render-block site carries the
#     canonical LIKELY-VERIFIED-CELL-SHAPE marker pointing to P186.
#   - Behavioural-shape assertions: each render site documents the three
#     canonical cell values + the age-based heuristic is NOT cited as
#     authority anywhere the marker fires.
#   - Drift-tripwire prose assertion: primary render sites (review-problems
#     + manage-problem) name P186 in the drift-re-opens contract per
#     P138 / P150 fix-shape precedent.
#
# @problem P186
# @jtbd JTBD-001 (enforce governance without slowing down — evidence-grounded
#   closure decision rather than calendar proxy)
# @jtbd JTBD-006 (progress backlog AFK — `observed: <evidence>` cell IS the
#   audit trail the AFK contract requires)
#
# Cross-reference:
#   P186: docs/problems/open/186-vq-likely-verified-column-uses-age-heuristic-not-evidence.md
#   P185: sibling proxy-for-evidence anti-pattern at capture-problem Step 1.5
#   P150: sibling fix shape — VQ-SORT-DIRECTION marker
#   P138: sibling fix shape — TIE-BREAK-LADDER-SOURCE marker
#   P048: introduced the Verification Queue + 14-day heuristic this ticket supersedes
#   ADR-022 — `.verifying.md` lifecycle; VQ rendering
#   ADR-026 — agent output grounding (evidence-citation discipline)
#   ADR-037 — contract-assertion bats pattern
#   ADR-052 — behavioural-tests default

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../.." && pwd)"
  REVIEW_SKILL="$REPO_ROOT/packages/itil/skills/review-problems/SKILL.md"
  MANAGE_SKILL="$REPO_ROOT/packages/itil/skills/manage-problem/SKILL.md"
  LIST_SKILL="$REPO_ROOT/packages/itil/skills/list-problems/SKILL.md"
  TRANSITION_SKILL="$REPO_ROOT/packages/itil/skills/transition-problem/SKILL.md"
  TRANSITIONS_SKILL="$REPO_ROOT/packages/itil/skills/transition-problems/SKILL.md"
  RECONCILE_SKILL="$REPO_ROOT/packages/itil/skills/reconcile-readme/SKILL.md"

  MARKER='<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->'
}

# ---------------------------------------------------------------------------
# Marker presence at every render site (P138 / P150 fix-shape precedent)
# ---------------------------------------------------------------------------

@test "review-problems carries the LIKELY-VERIFIED-CELL-SHAPE marker" {
  run grep -F "$MARKER" "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
  count=$(grep -c -F "$MARKER" "$REVIEW_SKILL")
  # review-problems is the primary owner — Step 3 presentation AND Step 5
  # README template both render the column.
  [ "$count" -ge 2 ]
}

@test "manage-problem carries the LIKELY-VERIFIED-CELL-SHAPE marker at every render site" {
  run grep -F "$MARKER" "$MANAGE_SKILL"
  [ "$status" -eq 0 ]
  count=$(grep -c -F "$MARKER" "$MANAGE_SKILL")
  # manage-problem renders the VQ at 4 sites: Step 5 P094, Step 7 P062,
  # Step 9c presentation, Step 9e README template. Marker must appear at
  # each — drift re-opens P186.
  [ "$count" -ge 4 ]
}

@test "list-problems VQ rendering carries the LIKELY-VERIFIED-CELL-SHAPE marker" {
  run grep -F "$MARKER" "$LIST_SKILL"
  [ "$status" -eq 0 ]
}

@test "transition-problem Step 7 README refresh carries the LIKELY-VERIFIED-CELL-SHAPE marker" {
  run grep -F "$MARKER" "$TRANSITION_SKILL"
  [ "$status" -eq 0 ]
}

@test "transition-problems batch render carries the LIKELY-VERIFIED-CELL-SHAPE marker" {
  run grep -F "$MARKER" "$TRANSITIONS_SKILL"
  [ "$status" -eq 0 ]
}

@test "reconcile-readme rendering carries the LIKELY-VERIFIED-CELL-SHAPE marker" {
  run grep -F "$MARKER" "$RECONCILE_SKILL"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Canonical cell values present at every render site
# ---------------------------------------------------------------------------

@test "review-problems documents all three canonical cell values" {
  run grep -F 'yes — observed:' "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — not observed' "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — observed regression' "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
}

@test "manage-problem documents all three canonical cell values" {
  run grep -F 'yes — observed:' "$MANAGE_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — not observed' "$MANAGE_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — observed regression' "$MANAGE_SKILL"
  [ "$status" -eq 0 ]
}

@test "list-problems documents all three canonical cell values" {
  run grep -F 'yes — observed:' "$LIST_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — not observed' "$LIST_SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'no — observed regression' "$LIST_SKILL"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Drift-tripwire prose at primary render sites (P138 / P150 precedent)
# ---------------------------------------------------------------------------

@test "review-problems names drift-re-opens-P186 contract" {
  run grep -F 'drift re-opens P186' "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
}

@test "manage-problem names drift-re-opens-P186 contract" {
  # manage-problem hosts the drift-tripwire prose at Step 5 P094 AND Step 7
  # P062 — both render sites name P186 alongside the existing P138 / P150
  # contracts. List-problems / transition-problem(s) / reconcile-readme
  # carry the marker but defer the canonical drift contract to the primary
  # owners (manage-problem / review-problems) per the P138 + P150 precedent.
  run grep -F 'drift here re-opens P186' "$MANAGE_SKILL"
  [ "$status" -eq 0 ]
  count=$(grep -c -i 're-opens P186' "$MANAGE_SKILL")
  [ "$count" -ge 2 ]
}

# ---------------------------------------------------------------------------
# Age-based heuristic must NOT survive as the authoritative cell rule
# ---------------------------------------------------------------------------

@test "review-problems no longer cites the 14-day heuristic as the cell rule" {
  # The P048 Candidate 4 "marks tickets ≥14 days old" phrasing was the
  # exact framing the user critique targeted. After P186, the cell shape
  # contract no longer references age as the authoritative trigger — age
  # is preserved separately via the `Released` column. The phrase may
  # survive in historical context (e.g. Related-section pointer back to
  # P048) but NOT as the live rendering rule.
  run grep -F 'marks tickets ≥14 days old' "$REVIEW_SKILL"
  [ "$status" -ne 0 ]
}

@test "manage-problem Step 9c no longer treats age as the cell trigger" {
  # Pre-P186 Step 9c documented `yes (N days)` and `no (N days)` as the
  # cell values keyed on a 14-day threshold. The new shape replaces both
  # with evidence-first values; the literal `yes (N days)` template must
  # not survive as a documented cell value (it can still appear in
  # historical narrative such as the README VQ rows pending re-render).
  run grep -F '`yes (N days)` — release age ≥ 14 days' "$MANAGE_SKILL"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Behavioural / template-shape — README template row carries the new shape
# ---------------------------------------------------------------------------

@test "review-problems Step 5 README template row uses the new cell-shape vocabulary" {
  # The template ROW (the `| P<NNN> | <title> | ... |` line below the
  # Verification Queue header) must reference the new vocabulary, not
  # the old `yes (N days) / no (N days)` placeholder.
  run grep -F 'yes — observed' "$REVIEW_SKILL"
  [ "$status" -eq 0 ]
  # Old placeholder gone
  run grep -F '<yes (N days) / no (N days)>' "$REVIEW_SKILL"
  [ "$status" -ne 0 ]
}

@test "list-problems Step 3 template row uses the new cell-shape vocabulary" {
  run grep -F 'yes — observed' "$LIST_SKILL"
  [ "$status" -eq 0 ]
  # Old placeholder gone from list-problems template
  run grep -F 'yes (N days) / no (N days)' "$LIST_SKILL"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Behavioural — produced README's VQ section uses the new cell vocabulary
# ---------------------------------------------------------------------------
#
# Behavioural assertion per ADR-052: the actual rendered docs/problems/
# README.md Verification Queue rows must use the new evidence-first cell
# shape, not age-based markers. This is the user-visible artefact the
# entire fix targets.

@test "docs/problems/README.md VQ section contains the new evidence-first cell vocabulary" {
  README="$REPO_ROOT/docs/problems/README.md"
  [ -f "$README" ]
  # At least one row should carry the new vocabulary after the iter
  # re-renders the VQ section. Tests run after the iter's edits land.
  run grep -F 'no — not observed' "$README"
  [ "$status" -eq 0 ]
}

@test "docs/problems/README.md VQ section no longer uses bare age-marker cells like 'no (N days)' as the dominant rendering" {
  README="$REPO_ROOT/docs/problems/README.md"
  [ -f "$README" ]
  # Allow a small residual count for transitional rows or quoted prose,
  # but the bulk of the VQ table must have migrated to the new shape.
  # Concretely: count `no — not observed` occurrences and require they
  # exceed the count of bare `no (<digit>` age-marker cells. This is a
  # behavioural check — the rendered surface, not the SKILL.md template.
  new_shape_count=$(grep -c -F 'no — not observed' "$README" || true)
  old_shape_count=$(grep -cE '\| no \([0-9]+ days?\) \|' "$README" || true)
  [ "$new_shape_count" -gt "$old_shape_count" ]
}
