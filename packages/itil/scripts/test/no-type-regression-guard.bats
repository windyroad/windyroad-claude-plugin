#!/usr/bin/env bats

# P287 regression guard — replaces the historical i2-no-type-branching.bats
# (which asserted no-control-flow-branch-on-type as an I2 invariant).
#
# With the type axis retired per twice-confirmed user direction
# (2026-05-25 + 2026-06-02), the I2 branch-protection invariant is
# vacuous (no `type` field to branch on). This regression guard
# preserves the audit-trail compliance evidence per architect-review
# verdict 2026-06-02 by asserting the POSITIVE state:
#
# - The `**Type**:` body field is GONE from the capture-problem
#   skeleton template and from every committed problem ticket.
# - The `lexical_classify_two_sided` helper function is removed.
# - capture-problem SKILL.md no longer carries the Step 1.5 Type
#   classification section or its dispatch flags.
#
# Drift here = silent reintroduction of the type axis = P287 regression.
#
# @problem P287 (type-classification retirement)
# @problem P176 (agent-side I2 coverage gap — historical; with the
#   type axis retired the gap is vacuous on that axis)
# @adr ADR-052 (behavioural-by-default; this is a regression-guard
#   structural assertion per Surface 2 escape-hatch contract — the
#   contract surface IS the on-disk artefact state)
# @adr ADR-014 (single-purpose; one mechanical regression invariant)
# @jtbd JTBD-001 (enforce governance without slowing down — primary)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  PKG_ROOT="$REPO_ROOT/packages/itil"
  SKILL_FILE="$PKG_ROOT/skills/capture-problem/SKILL.md"
  HELPER="$REPO_ROOT/packages/shared/derive-first-dispatch.sh"
  [ -f "$SKILL_FILE" ]
  [ -f "$HELPER" ]
}

@test "P287: no committed problem ticket carries a **Type**: body field" {
  # Find any docs/problems/**/*.md ticket that still carries the
  # retired type field on a body line. Any match = P287 regression.
  result=$(grep -r --include='*.md' -l '^\*\*Type\*\*: ' "$REPO_ROOT/docs/problems/" 2>/dev/null || true)
  [ -z "$result" ]
}

@test "P287: capture-problem skeleton template does not include a **Type**: line" {
  ! grep -F '**Type**: <type_value>' "$SKILL_FILE"
  ! grep -F '**Type**: technical' "$SKILL_FILE"
  ! grep -F '**Type**: user-business' "$SKILL_FILE"
}

@test "P287: capture-problem SKILL.md does not carry a Step 1.5 Type classification header" {
  # The retired Step 1.5 section was titled "### 1.5 Type classification".
  ! grep -E '^### 1\.5 Type classification' "$SKILL_FILE"
}

@test "P287: shared dispatch helper does not export lexical_classify_two_sided" {
  ! grep -E '^lexical_classify_two_sided\(\)' "$HELPER"
}

@test "P287: per-package lib/ copies are byte-identical to the canonical shared/ source" {
  # ADR-017 sync compliance — the strip removed lexical_classify_two_sided
  # from the canonical packages/shared/derive-first-dispatch.sh; the
  # sync script must propagate the removal to per-package copies.
  diff -q "$HELPER" "$REPO_ROOT/packages/itil/lib/derive-first-dispatch.sh"
  diff -q "$HELPER" "$REPO_ROOT/packages/architect/lib/derive-first-dispatch.sh"
}

@test "P287: capture-problem SKILL.md does not carry --type= or --no-prompt flag rows" {
  # The retired Step 1.5 dispatch flags must not appear in the flag table.
  ! grep -E '^\| `--type=technical`' "$SKILL_FILE"
  ! grep -E '^\| `--type=user-business`' "$SKILL_FILE"
  ! grep -E '^\| `--no-prompt`' "$SKILL_FILE"
}
