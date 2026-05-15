#!/usr/bin/env bats
# ADR-044 alignment contract assertions for manage-incident SKILL.md
# (P136 Phase 2 sub-task 3 — added 2026-04-28).
#
# tdd-review: structural-permitted (justification: SKILL.md prose contract
# assertions; behavioural skill-runtime harness pending P012 + P081 Phase 2;
# expected to migrate to behavioural form once the harness exists. Added
# during P136 Phase 2 ADR-044 alignment audit per the inline plan's
# bridge-marker rule.)
#
# Note: the sibling file manage-incident.bats deliberately avoids structural-
# grep on SKILL.md prose (P011 ban; functional/behavioural-by-default). This
# file is the dedicated structural-grep-permitted home for the ADR-044
# alignment contract during the bridge window. After P081 Phase 2 retrofits
# the project's structural-grep tests to behavioural form, this file's
# assertions migrate too.
#
# @problem P136 (ADR-044 alignment audit master — Phase 2 manage-incident)
# @adr ADR-044 (Decision-Delegation Contract)
# @adr ADR-013 amended Rule 1 (structured user interaction)
# @adr ADR-013 Confirmation criterion #1 (no prose-ask vocabulary)
# @adr ADR-011 (evidence-first workflow)
# @jtbd JTBD-201 (restore service fast with audit trail)
# @jtbd JTBD-001 (enforce governance without slowing down)
# @jtbd JTBD-101 (extend the suite with consistent patterns)

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL_FILE="${SKILL_DIR}/SKILL.md"
  [ -f "$SKILL_FILE" ]
}

# ----------------------------------------------------------------------
# Surface 1 — Step 2 duplicate-check (cat-1 direction-setting; refactor)
# ----------------------------------------------------------------------

@test "SKILL.md Step 2 duplicate-check prompt does NOT use 'would you like' (ADR-013 Confirmation #1)" {
  # Refactor closes ADR-013 Confirmation criterion #1 regression at line 134.
  # The duplicate-check AskUserQuestion options are now structured via the
  # tool's options[] mechanism, not inlined as prose '(a)/(b)/(c)'.
  run awk '/^### 2\. /,/^### 3\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qiE "would you like"
}

@test "SKILL.md Step 2 duplicate-check prompt does NOT use parenthetical (a)/(b)/(c)" {
  run awk '/^### 2\. /,/^### 3\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -qE "\(a\) update|\(b\) declare|\(c\) cancel"
}

@test "SKILL.md Step 2 duplicate-check cross-references ADR-044 category-1 (direction-setting)" {
  run awk '/^### 2\. /,/^### 3\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADR-044"* ]]
  [[ "$output" == *"direction-setting"* ]] || [[ "$output" == *"category 1"* ]] || [[ "$output" == *"category-1"* ]]
}

@test "SKILL.md Step 2 still presents 3 options (update / declare / cancel) for AskUserQuestion" {
  # Negative-of-negative guard — the gate must REMAIN. Refactor changes the
  # SHAPE (options[] vs prose), not the existence of the 3 user choices.
  run awk '/^### 2\. /,/^### 3\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Update"* ]] || [[ "$output" == *"update"* ]]
  [[ "$output" == *"Declare"* ]] || [[ "$output" == *"declare"* ]]
  [[ "$output" == *"Cancel"* ]] || [[ "$output" == *"cancel"* ]]
}

# ----------------------------------------------------------------------
# Surface 2 — Step 4 gather info (P132 derive-first refactor — cat-4 silent-framework
# on derivable fields; cat-1 direction-setting fallback only on Scope)
# ----------------------------------------------------------------------

@test "SKILL.md Step 4 gather-info cross-references ADR-044 category-1 (direction-setting)" {
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADR-044"* ]]
  [[ "$output" == *"direction-setting"* ]] || [[ "$output" == *"category 1"* ]] || [[ "$output" == *"category-1"* ]]
}

@test "SKILL.md Step 4 cross-references ADR-044 category-4 (silent-framework) for derivable fields (P132 derive-first)" {
  # P132 derive-first refactor: Title / Symptoms / Start time / Severity-when-evidence-present
  # resolve via silent-framework per ADR-044 category 4. Only Scope retains AskUserQuestion as
  # the genuine category-1 direction-setting surface.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"silent-framework"* ]] || [[ "$output" == *"category 4"* ]] || [[ "$output" == *"category-4"* ]]
}

@test "SKILL.md Step 4 derives Title from prose silently (P132 inverse-P078)" {
  # I001 regression cited in P132 line 14: agent asked "Title" with 3 candidate
  # options when kebab-casing the description would have produced the slug directly.
  # The refactor names "Title" + "derive"/"derived"/"kebab" in the same step.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Title"* ]]
  [[ "$output" == *"derive"* ]] || [[ "$output" == *"derived"* ]]
  [[ "$output" == *"kebab"* ]] || [[ "$output" == *"prose"* ]]
}

@test "SKILL.md Step 4 derives Start time from evidence sources (P132 inverse-P078)" {
  # I001 regression cited in P132 line 16: agent asked "Start time" with 3 candidate
  # options when git log first-touch evidence would have produced 2026-04-24 directly.
  # The refactor names git-log / timestamp / wall-clock as the three priority-ordered sources.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Start time"* ]] || [[ "$output" == *"start-time"* ]]
  [[ "$output" == *"git log"* ]] || [[ "$output" == *"timestamp"* ]]
}

@test "SKILL.md Step 4 derives Severity from RISK-POLICY matrix + evidence (P132 inverse-P078)" {
  # I001 regression cited in P132 line 15: agent asked "Severity" with 4 candidate
  # options when the RISK-POLICY matrix + observable evidence (cluster age, scorer
  # state) maps to a clear cell. The refactor cites RISK-POLICY.md + evidence in
  # the Severity row of the dispatch table. Ambiguous-evidence fallback to
  # AskUserQuestion is preserved as the genuine cat-5 (taste) surface.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Severity"* ]]
  [[ "$output" == *"RISK-POLICY"* ]]
}

@test "SKILL.md Step 4 retains Scope as AskUserQuestion direction-setting (negative-of-negative guard)" {
  # Regression-resistance: the refactor MUST preserve the genuine cat-1 direction-setting
  # surface on Scope. Semantic scope (who/what affected, blast radius) is user-judgment;
  # the framework cannot resolve it deterministically. Same reasoning as Step 2 duplicate-check.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Scope"* ]]
  [[ "$output" == *"AskUserQuestion"* ]]
}

@test "SKILL.md Step 4 cites P132 (inverse-P078 audit traceability)" {
  # P132 + ADR-044 must appear in Step 4 or Related section so the audit trail
  # for the I001 regression fix is recoverable from the SKILL.md surface.
  run grep -nE "P132" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}

@test "SKILL.md Step 4 documents stderr advisory shape for derived fields (ADR-026 grounding)" {
  # ADR-026 cost-source grounding: each silent derivation emits a stderr advisory
  # citing the source. Pattern parity with capture-problem Step 1.5 stderr advisory.
  run awk '/^### 4\. /,/^### 5\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stderr"* ]] || [[ "$output" == *"advisory"* ]]
}

# ----------------------------------------------------------------------
# Surface 3 — Step 6 evidence-first gate refactor (cat-2; align with mitigate-incident)
# ----------------------------------------------------------------------

@test "SKILL.md Step 6 evidence-first gate uses 3-option pattern (Add / Record-anyway / Cancel)" {
  run awk '/^### 6\. /,/^### 7\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Add evidence"* ]]
  [[ "$output" == *"Record"* ]]
  [[ "$output" == *"audit trail"* ]] || [[ "$output" == *"Audit trail"* ]]
  [[ "$output" == *"Cancel"* ]] || [[ "$output" == *"cancel"* ]]
}

@test "SKILL.md Step 6 evidence-first gate cross-references ADR-044 category-2 (deviation-approval)" {
  run awk '/^### 6\. /,/^### 7\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADR-044"* ]]
  [[ "$output" == *"deviation-approval"* ]] || [[ "$output" == *"category 2"* ]] || [[ "$output" == *"category-2"* ]]
}

@test "SKILL.md Step 6 evidence-first gate documents the bypass-marker (audit-trail consistency)" {
  # Aligns with mitigate-incident Step 3 (line 87): on bypass, append
  # 'Evidence-gate bypassed by user — reason: <justification>' to the
  # ## Audit trail section. Cross-skill consistency.
  run awk '/^### 6\. /,/^### 7\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bypass"* ]] || [[ "$output" == *"bypassed"* ]]
}

# ----------------------------------------------------------------------
# Surface 4 — Step 14 risk-above-appetite (cat-3 cosmetic cross-ref)
# ----------------------------------------------------------------------

@test "SKILL.md Step 14 risk-above-appetite cross-references ADR-044 category-3 (one-time-override)" {
  run awk '/^### 14\. /,/^### 15\. /' "$SKILL_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ADR-044"* ]]
  [[ "$output" == *"one-time-override"* ]] || [[ "$output" == *"category 3"* ]] || [[ "$output" == *"category-3"* ]]
}

# ----------------------------------------------------------------------
# P081 + P136 bridge marker
# ----------------------------------------------------------------------

@test "bats file carries the tdd-review: structural-permitted marker" {
  run grep -nE "tdd-review:[[:space:]]+structural-permitted" "${BATS_TEST_FILENAME}"
  [ "$status" -eq 0 ]
}

# ----------------------------------------------------------------------
# Cross-reference: P136 audit citation in SKILL.md (Related or inline)
# ----------------------------------------------------------------------

@test "SKILL.md cites P136 + ADR-044 (audit traceability)" {
  run grep -nE "P136" "$SKILL_FILE"
  [ "$status" -eq 0 ]
  run grep -nE "ADR-044" "$SKILL_FILE"
  [ "$status" -eq 0 ]
}
