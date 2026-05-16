#!/usr/bin/env bats
# ADR-044 alignment contract assertions for create-adr SKILL.md Step 2
# (P132 Phase 2a-iii-B derive-first refactor, 2026-05-16).
#
# tdd-review: structural-permitted (justification: SKILL.md prose contract
# assertions; behavioural skill-runtime harness pending P012 + P081 Phase 2;
# expected to migrate to behavioural form once the harness exists. Added
# during P132 Phase 2a-iii-B per the inline plan's bridge-marker rule —
# isomorphic precedent at manage-problem-adr-044-step4-derive-first.bats.)
#
# This file is the dedicated structural-grep-permitted home for the ADR-044
# alignment contract during the bridge window. After P081 Phase 2 retrofits
# the project's structural-grep tests to behavioural form, this file's
# assertions migrate too.
#
# @problem P132 (agents over-ask in interactive sessions — Phase 2a-iii-B
#   create-adr argument-collection derive-first refactor as 4th adopter)
# @problem P185 (capture-problem Step 1.5 worked-example precedent)
# @problem P136 (ADR-044 alignment audit master)
# @adr ADR-002 (Monorepo per-plugin packages)
# @adr ADR-017 (Shared code duplicated into per-package lib/ kept in sync)
# @adr ADR-044 (Decision-Delegation Contract)
# @adr ADR-013 amended Rule 1 (structured user interaction)
# @adr ADR-026 (cost-source grounding — stderr advisory shape)
# @adr ADR-052 (behavioural-by-default with structural bridge window)
# @jtbd JTBD-001 (enforce governance without slowing down — primary)
# @jtbd JTBD-006 (work backlog AFK — queued for return, not guessed at)
# @jtbd JTBD-101 (extend the suite with consistent patterns)

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
  [ -f "$SKILL_FILE" ]
}

# ----------------------------------------------------------------------
# Step 2 derive-first refactor (P132 Phase 2a-iii-B) — cat-4 silent-framework
# on Title + frontmatter defaults + Context-and-Problem-Statement; cat-1
# direction-setting on Decision Drivers / Considered Options / Decision
# Outcome / Consequences / Confirmation / decision-makers.
# ----------------------------------------------------------------------

@test "SKILL.md Step 2 cross-references ADR-044 category-4 (silent-framework) for derivable fields (P132 derive-first)" {
  # P132 Phase 2a-iii-B: Title (kebab from prose), status (always proposed),
  # date (today), reassessment-date (today+3mo), context-and-problem-statement
  # (verbatim from $ARGUMENTS prose) resolve via silent-framework per
  # ADR-044 category 4.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"silent-framework"* ]] || [[ "$output" == *"category 4"* ]] || [[ "$output" == *"category-4"* ]]
}

@test "SKILL.md Step 2 cross-references ADR-044 category-1 (direction-setting) for user-judgment fields" {
  # Decision Drivers / Considered Options / Decision Outcome / Consequences /
  # Confirmation retain AskUserQuestion as the genuine cat-1 surfaces —
  # ADR creation is fundamentally user-judgment-bound; only the user knows
  # the alternative space, the chosen-option rationale, and the testable
  # confirmation criteria.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"direction-setting"* ]] || [[ "$output" == *"category 1"* ]] || [[ "$output" == *"category-1"* ]]
}

@test "SKILL.md Step 2 derives Title from prose silently (P132 inverse-P078)" {
  # The 2026-05-06 I001 declaration regression cited in P132 was the agent
  # asking "Title" with N candidate options when kebab-casing the description
  # would have produced the slug directly. create-adr Step 2 must ship the
  # same derive-first pattern as the 3 itil declaration-skill surfaces.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Title"* ]] || [[ "$output" == *"title"* ]]
  [[ "$output" == *"derive"* ]] || [[ "$output" == *"derived"* ]]
  [[ "$output" == *"kebab"* ]] || [[ "$output" == *"prose"* ]]
}

@test "SKILL.md Step 2 derives status / date / reassessment-date silently (P132 derive-first)" {
  # Frontmatter defaults (status=proposed, date=today, reassessment-date=
  # today+3mo) are SKILL conventions — no user judgment required at capture.
  # Step 4's existing template already mandates these defaults; Step 2 must
  # name them as silent-framework cat-4 surfaces explicitly so the
  # I2-isomorphic stderr advisory contract covers them.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status"* ]]
  [[ "$output" == *"date"* ]]
  [[ "$output" == *"reassessment"* ]] || [[ "$output" == *"proposed"* ]]
}

@test "SKILL.md Step 2 retains Considered Options + Decision Outcome as AskUserQuestion (negative-of-negative guard)" {
  # Regression-resistance: the refactor MUST preserve the genuine cat-1
  # direction-setting surfaces on Considered Options + Decision Outcome.
  # The framework cannot generate the alternative space — only the user
  # knows the alternatives evaluated. Architect verdict 2026-05-16:
  # confirmed cat-1 over cat-5.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AskUserQuestion"* ]]
  [[ "$output" == *"Considered Options"* ]] || [[ "$output" == *"options"* ]] || [[ "$output" == *"alternative"* ]]
  [[ "$output" == *"Decision Outcome"* ]] || [[ "$output" == *"chosen"* ]] || [[ "$output" == *"rationale"* ]]
}

@test "SKILL.md Step 2 retains decision-makers as AskUserQuestion (architect verdict — no silent derive from git user.name)" {
  # Architect verdict 2026-05-16: decision-makers MUST stay cat-1
  # AskUserQuestion. `git config user.name` would conflate "who committed
  # the ADR" with "who made the decision" — a multi-party decision is one
  # of the canonical mis-attribution risks ADR-013's identity model rejects.
  # Once-per-ADR ask is low-friction in absolute terms.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"decision-makers"* ]] || [[ "$output" == *"decision makers"* ]]
}

@test "SKILL.md Step 2 cites P132 (inverse-P078 audit traceability)" {
  # P132 + ADR-044 must appear in Step 2 or Related section so the audit
  # trail for the Phase 2a-iii-B refactor is recoverable from the SKILL.md
  # surface.
  run grep -nE "P132" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Step 2 documents stderr advisory shape for derived fields (ADR-026 grounding)" {
  # ADR-026 cost-source grounding: each silent derivation emits a stderr
  # advisory citing the source. Pattern parity with capture-problem Step
  # 1.5 + manage-incident Step 4 + manage-problem Step 4 (I2-isomorphic
  # across the four declaration-skill surfaces per Phase 2a-iii-B).
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stderr"* ]] || [[ "$output" == *"advisory"* ]]
}

@test "SKILL.md Step 2 cross-references the 3 prior derive-first surfaces (cross-skill consistency lock-in)" {
  # Phase 2a-iii-B is the 4th adopter. The Step 2 prose must explicitly
  # cite the 3 prior surfaces (capture-problem + manage-incident +
  # manage-problem) so the I2-isomorphic stderr advisory format is
  # locked-in by reference across the 4-surface set.
  run awk '/^### 2\. /,/^### 2b\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"capture-problem"* ]]
  [[ "$output" == *"manage-incident"* ]]
  [[ "$output" == *"manage-problem"* ]]
}

@test "SKILL.md Step 2 references derive-first-dispatch.sh helper (sourced from architect package per ADR-017)" {
  # Per ADR-017 self-contained-published-package property: create-adr lives
  # in @windyroad/architect, so it MUST source the helper from its own
  # package lib (packages/architect/lib/derive-first-dispatch.sh), NOT
  # cross-package from packages/itil/lib/. The canonical source lives at
  # packages/shared/derive-first-dispatch.sh; both itil and architect have
  # synced per-package lib/ copies.
  run grep -E "packages/architect/lib/derive-first-dispatch" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------
# Negative-of-negative guards — Step 2b multi-decision split + Step 5
# confirm-with-user remain unchanged.
# ----------------------------------------------------------------------

@test "SKILL.md Step 2b multi-decision AskUserQuestion is preserved (cat-1 direction-setting, not touched by Phase 2a-iii-B)" {
  # Step 2b is a separate cat-1 direction-setting surface — only the
  # user knows whether multiple decisions can be independently accepted.
  # The Phase 2a-iii-B refactor MUST NOT touch Step 2b's AskUserQuestion gate.
  run awk '/^### 2b\. /,/^### 3\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AskUserQuestion"* ]]
  [[ "$output" == *"decision"* ]] || [[ "$output" == *"split"* ]]
}

@test "SKILL.md Step 5 confirm-with-user AskUserQuestion is preserved (post-write review surface)" {
  # Step 5 is the genuine cat-2 deviation-approval post-write review
  # surface (analogous to manage-incident Step 6 evidence-first gate).
  # The Phase 2a-iii-B refactor MUST NOT touch Step 5's AskUserQuestion gate.
  run awk '/^### 5\. /,/^### 6\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AskUserQuestion"* ]]
}

# ----------------------------------------------------------------------
# P081 + P132 bridge marker
# ----------------------------------------------------------------------

@test "bats file carries the tdd-review: structural-permitted marker" {
  run grep -nE "tdd-review:[[:space:]]+structural-permitted" "${BATS_TEST_FILENAME}"
  [ "$status" -eq 0 ]
}
