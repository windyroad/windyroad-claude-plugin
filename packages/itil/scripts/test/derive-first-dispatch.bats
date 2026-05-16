#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Behavioural assertions for packages/itil/lib/derive-first-dispatch.sh —
# the shared derive-first dispatch helper extracted in P132 Phase 2a-iii-A.
#
# The helper centralises the dispatch mechanism shipped across three
# declaration-skill surfaces (capture-problem Step 1.5, manage-incident
# Step 4, manage-problem Step 4). Each caller passes surface-specific
# signal definitions; the helper owns:
#
#   - Slug derivation (Title) from prose
#   - Two-sided lexical classifier (Type for capture-problem)
#   - RISK-POLICY matrix lookup (Severity / Priority)
#   - I2-isomorphic stderr advisory format
#
# @problem P132 (agents over-ask in interactive sessions — Phase 2a-iii-A
#   shared helper extraction)
# @problem P185 (capture-problem Step 1.5 worked-example precedent)
# @adr ADR-044 (Decision-Delegation Contract — derive-first framework
#   resolution boundary)
# @adr ADR-026 (cost-source grounding — stderr advisory shape)
# @adr ADR-052 (behavioural-by-default — these are runtime behaviour
#   assertions on the helper functions, NOT structural greps)
# @jtbd JTBD-001 (enforce governance without slowing down — primary)
# @jtbd JTBD-101 (extend the suite with consistent patterns)

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../lib" && pwd)"
  HELPER="${LIB_DIR}/derive-first-dispatch.sh"
  [ -f "$HELPER" ]
  # shellcheck disable=SC1090
  source "$HELPER"
  PKG_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  ARCHITECT_PKG_ROOT="$REPO_ROOT/packages/architect"
}

# ----------------------------------------------------------------------
# Stderr advisory contract (I2-isomorphic format across all 3 surfaces).
# Format: <skill>: derived <field>=<value> from <source>; <reversibility>
# ----------------------------------------------------------------------

@test "emit_stderr_advisory writes single canonical line to stderr" {
  run -0 bash -c '
    source "'"$HELPER"'"
    emit_stderr_advisory manage-problem title my-slug "description tokens" \
      "re-invoke with the desired title or rename the file if the slug is wrong"
  '
  # stderr captured in $output via run; assert structure
  [[ "$output" == *"manage-problem: derived title=my-slug from description tokens; re-invoke with the desired title"* ]]
}

@test "emit_stderr_advisory uses default reversibility clause when omitted" {
  run -0 bash -c '
    source "'"$HELPER"'"
    emit_stderr_advisory manage-incident severity "9 (Medium)" "RISK-POLICY matrix"
  '
  [[ "$output" == *"manage-incident: derived severity=9 (Medium) from RISK-POLICY matrix;"* ]]
  [[ "$output" == *"re-invoke"* ]] || [[ "$output" == *"update"* ]]
}

@test "emit_stderr_advisory shape is I2-isomorphic across surfaces (same sentence structure)" {
  run -0 bash -c '
    source "'"$HELPER"'"
    emit_stderr_advisory capture-problem type technical "description signals" "re-invoke with --type=user-business to override"
    emit_stderr_advisory manage-incident title incident-slug "description" "re-invoke or rename"
    emit_stderr_advisory manage-problem priority "9 (Medium)" "RISK-POLICY matrix" "re-invoke or update if mis-rated"
  '
  # Each surface emits the same sentence shape: <skill>: derived <field>=<value> from <source>; <clause>
  line_count=$(printf '%s\n' "$output" | grep -c "^[a-z-]*: derived ")
  [ "$line_count" -eq 3 ]
}

# ----------------------------------------------------------------------
# Kebab-case slug derivation from prose.
# ----------------------------------------------------------------------

@test "derive_kebab_slug produces kebab-case from prose" {
  run -0 bash -c '
    source "'"$HELPER"'"
    derive_kebab_slug "Agent over-asks during interactive sessions"
  '
  [[ "$output" == *"agent"* ]]
  [[ "$output" == *"over"* ]] || [[ "$output" == *"asks"* ]]
  [[ "$output" != *" "* ]]
  [[ "$output" != *"_"* ]]
}

@test "derive_kebab_slug drops stopwords" {
  run -0 bash -c '
    source "'"$HELPER"'"
    derive_kebab_slug "The agent is asking the user a question"
  '
  # stopwords like "the", "a", "is" must NOT appear as standalone tokens
  [[ "$output" != *"-the-"* ]]
  [[ "$output" != "the-"* ]]
  [[ "$output" == *"agent"* ]]
}

@test "derive_kebab_slug caps token count (default 8)" {
  run -0 bash -c '
    source "'"$HELPER"'"
    derive_kebab_slug "one two three four five six seven eight nine ten eleven twelve"
  '
  token_count=$(printf '%s\n' "$output" | tr '-' '\n' | wc -l | tr -d ' ')
  [ "$token_count" -le 8 ]
}

@test "derive_kebab_slug accepts custom token count" {
  run -0 bash -c '
    source "'"$HELPER"'"
    derive_kebab_slug "alpha beta gamma delta epsilon zeta" 3
  '
  token_count=$(printf '%s\n' "$output" | tr '-' '\n' | wc -l | tr -d ' ')
  [ "$token_count" -le 3 ]
}

# ----------------------------------------------------------------------
# Two-sided lexical classifier (capture-problem Step 1.5 mechanism).
# Returns:
#   SIDE_A_UNAMBIGUOUS|<matched signals>  — ≥1 A hit AND 0 B hits
#   SIDE_B_UNAMBIGUOUS|<matched signals>  — 0 A hits AND ≥1 B hit
#   AMBIGUOUS|<reason>                    — mixed (both sides) OR zero
# ----------------------------------------------------------------------

@test "lexical_classify_two_sided returns SIDE_A_UNAMBIGUOUS on technical-only signals" {
  run -0 bash -c '
    source "'"$HELPER"'"
    side_a=("\\b(hook|gate|regex|stderr|stdout|drift|TTL|cache)\\b")
    side_b=("\\b(adopter|UX|friction|JTBD-[0-9]+)\\b")
    lexical_classify_two_sided "the hook fires on stderr and the cache invalidates" side_a side_b
  '
  [[ "$output" == "SIDE_A_UNAMBIGUOUS|"* ]]
}

@test "lexical_classify_two_sided returns SIDE_B_UNAMBIGUOUS on user-business-only signals" {
  run -0 bash -c '
    source "'"$HELPER"'"
    side_a=("\\b(hook|gate|regex|stderr|stdout|drift|TTL|cache)\\b")
    side_b=("\\b(adopter|UX|friction|JTBD-[0-9]+)\\b")
    lexical_classify_two_sided "the adopter friction makes JTBD-101 hard to complete" side_a side_b
  '
  [[ "$output" == "SIDE_B_UNAMBIGUOUS|"* ]]
}

@test "lexical_classify_two_sided returns AMBIGUOUS on mixed signals" {
  run -0 bash -c '
    source "'"$HELPER"'"
    side_a=("\\b(hook|gate|regex|stderr)\\b")
    side_b=("\\b(adopter|UX|friction)\\b")
    lexical_classify_two_sided "the hook causes adopter friction" side_a side_b
  '
  [[ "$output" == "AMBIGUOUS|"* ]]
}

@test "lexical_classify_two_sided returns AMBIGUOUS on zero signals" {
  run -0 bash -c '
    source "'"$HELPER"'"
    side_a=("\\b(hook|gate)\\b")
    side_b=("\\b(adopter|UX)\\b")
    lexical_classify_two_sided "totally bland text with no signals at all" side_a side_b
  '
  [[ "$output" == "AMBIGUOUS|"* ]]
}

# ----------------------------------------------------------------------
# RISK-POLICY matrix lookup (manage-incident / manage-problem mechanism).
# Returns:
#   <score>|<label>|impact=<L>+likelihood=<L>  — clear single-cell match
#   AMBIGUOUS|<reason>                        — multi-band or zero match
# ----------------------------------------------------------------------

@test "risk_policy_matrix_lookup returns clear cell on unambiguous impact + likelihood signals" {
  run -0 bash -c '
    source "'"$HELPER"'"
    impact_high=("\\b(down|outage|data loss|unavailable)\\b")
    impact_mod=("\\b(slow|latency|degraded)\\b")
    impact_low=("\\b(typo|cosmetic)\\b")
    likelihood_high=("\\b(every request|reproducible|always)\\b")
    likelihood_med=("\\b(intermittent|flaky)\\b")
    likelihood_low=("\\b(one-off|single)\\b")
    risk_policy_matrix_lookup "service is down on every request" impact_high impact_mod impact_low likelihood_high likelihood_med likelihood_low
  '
  # Expect impact=high(5) + likelihood=high(5) -> score=25, label=Very High
  [[ "$output" == "25|"* ]] || [[ "$output" == "20|"* ]] || [[ "$output" == "15|"* ]]
  [[ "$output" == *"High"* ]] || [[ "$output" == *"Very High"* ]]
}

@test "risk_policy_matrix_lookup returns AMBIGUOUS on multi-band impact" {
  run -0 bash -c '
    source "'"$HELPER"'"
    impact_high=("\\b(down)\\b")
    impact_mod=("\\b(slow)\\b")
    impact_low=("\\b(typo)\\b")
    likelihood_high=("\\b(every request)\\b")
    likelihood_med=("\\b(intermittent)\\b")
    likelihood_low=("\\b(one-off)\\b")
    risk_policy_matrix_lookup "service is down and slow with typo" impact_high impact_mod impact_low likelihood_high likelihood_med likelihood_low
  '
  [[ "$output" == "AMBIGUOUS|"* ]]
}

@test "risk_policy_matrix_lookup returns AMBIGUOUS when no signals match" {
  run -0 bash -c '
    source "'"$HELPER"'"
    impact_high=("\\b(down)\\b")
    impact_mod=("\\b(slow)\\b")
    impact_low=("\\b(typo)\\b")
    likelihood_high=("\\b(every request)\\b")
    likelihood_med=("\\b(intermittent)\\b")
    likelihood_low=("\\b(one-off)\\b")
    risk_policy_matrix_lookup "totally bland text" impact_high impact_mod impact_low likelihood_high likelihood_med likelihood_low
  '
  [[ "$output" == "AMBIGUOUS|"* ]]
}

@test "risk_policy_matrix_lookup label band aligns with RISK-POLICY.md (Medium = 5-9)" {
  # Verify a specific clear-cell mapping produces the RISK-POLICY-canonical label.
  # impact=mod (3) * likelihood=high (5) = 15 -> "High" band (10-16)
  run -0 bash -c '
    source "'"$HELPER"'"
    impact_high=("\\b(down)\\b")
    impact_mod=("\\b(slow)\\b")
    impact_low=("\\b(typo)\\b")
    likelihood_high=("\\b(every request)\\b")
    likelihood_med=("\\b(intermittent)\\b")
    likelihood_low=("\\b(one-off)\\b")
    risk_policy_matrix_lookup "the service is slow on every request" impact_high impact_mod impact_low likelihood_high likelihood_med likelihood_low
  '
  [[ "$output" == "15|High|"* ]]
}

# ----------------------------------------------------------------------
# Cross-skill consistency: all 4 SKILL.md surfaces reference the helper
# as the shared dispatch mechanism. The I2-isomorphic stderr advisory
# format is locked-in by reference to derive-first-dispatch.sh.
#
# Phase 2a-iii-B (2026-05-16): 4th adopter wr-architect:create-adr added.
# Helper canonical source moved to packages/shared/ per ADR-017 sync
# pattern; per-package lib/ copies in packages/itil/lib/ and
# packages/architect/lib/ stay byte-identical via scripts/sync-derive-first-dispatch.sh.
# ----------------------------------------------------------------------

@test "capture-problem Step 1.5 cross-references derive-first-dispatch.sh helper" {
  run grep -c "derive-first-dispatch\\.sh\\|packages/itil/lib/derive-first-dispatch" \
    "${PKG_ROOT}/skills/capture-problem/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "manage-incident Step 4 cross-references derive-first-dispatch.sh helper" {
  run grep -c "derive-first-dispatch\\.sh\\|packages/itil/lib/derive-first-dispatch" \
    "${PKG_ROOT}/skills/manage-incident/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "manage-problem Step 4 cross-references derive-first-dispatch.sh helper" {
  run grep -c "derive-first-dispatch\\.sh\\|packages/itil/lib/derive-first-dispatch" \
    "${PKG_ROOT}/skills/manage-problem/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "create-adr Step 2 cross-references derive-first-dispatch.sh helper (Phase 2a-iii-B 4th adopter)" {
  # The 4th adopter (architect package) sources from its own per-package
  # lib/ copy (NOT cross-package from itil) per ADR-017.
  run grep -c "derive-first-dispatch\\.sh\\|packages/architect/lib/derive-first-dispatch" \
    "${ARCHITECT_PKG_ROOT}/skills/create-adr/SKILL.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "helper file documents its four caller surfaces (audit trail)" {
  # The helper's header comment must name the four SKILL.md surfaces it
  # serves so the audit trail is recoverable from the helper itself.
  # Phase 2a-iii-B adds create-adr as the 4th adopter.
  run grep -E "capture-problem" "$HELPER"
  [ "$status" -eq 0 ]
  run grep -E "manage-incident" "$HELPER"
  [ "$status" -eq 0 ]
  run grep -E "manage-problem" "$HELPER"
  [ "$status" -eq 0 ]
  run grep -E "create-adr" "$HELPER"
  [ "$status" -eq 0 ]
}

@test "per-package lib/ copies are byte-identical to canonical packages/shared/ source (ADR-017)" {
  # Phase 2a-iii-B + ADR-017: canonical at packages/shared/, synced copies
  # in per-package lib/. The sync script (scripts/sync-derive-first-dispatch.sh)
  # in --check mode is the CI guard; this test asserts the post-condition.
  local shared_src="${REPO_ROOT}/packages/shared/derive-first-dispatch.sh"
  local itil_copy="${REPO_ROOT}/packages/itil/lib/derive-first-dispatch.sh"
  local architect_copy="${REPO_ROOT}/packages/architect/lib/derive-first-dispatch.sh"
  [ -f "$shared_src" ]
  [ -f "$itil_copy" ]
  [ -f "$architect_copy" ]
  run diff -q "$shared_src" "$itil_copy"
  [ "$status" -eq 0 ]
  run diff -q "$shared_src" "$architect_copy"
  [ "$status" -eq 0 ]
}
