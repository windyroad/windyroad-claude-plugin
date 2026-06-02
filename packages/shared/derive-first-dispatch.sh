#!/usr/bin/env bash
# Shared derive-first dispatch helper — canonical source-of-truth.
#
# P132 Phase 2a-iii-A extracted this helper from three declaration-skill
# surfaces. Phase 2a-iii-B (2026-05-16) added wr-architect:create-adr as
# the 4th adopter, which required moving the canonical source from
# packages/itil/lib/ to packages/shared/ per ADR-017 (Shared code
# duplicated into per-package lib/ kept in sync by script + CI drift
# check). The per-package lib/ copies are byte-identical to this file:
#
#   - packages/itil/lib/derive-first-dispatch.sh        (sync target)
#   - packages/architect/lib/derive-first-dispatch.sh   (sync target)
#
# Sync mechanism: scripts/sync-derive-first-dispatch.sh (mirrors the
# sync-install-utils.sh pattern). CI guard: npm run check:derive-first-dispatch.
# Drift test: packages/shared/test/sync-derive-first-dispatch.bats.
#
# Maintainer-side SKILL.md surfaces that source the helper:
#   - packages/itil/skills/capture-problem/SKILL.md       Step 1.5
#   - packages/itil/skills/manage-incident/SKILL.md       Step 4
#   - packages/itil/skills/manage-problem/SKILL.md        Step 4
#   - packages/architect/skills/create-adr/SKILL.md       Step 2     (P132 Phase 2a-iii-B)
#
# Each caller passes surface-specific signal definitions; this helper
# centralises the dispatch mechanism: slug derivation, two-sided lexical
# classifier, RISK-POLICY matrix lookup, and the I2-isomorphic stderr
# advisory format.
#
# <!-- DERIVE-FIRST-DISPATCH-CONTRACT-SOURCE: P132 Phase 2a-iii-A + Phase 2a-iii-B -->
# Drift in the stderr advisory format here re-opens P132 — any change MUST
# update all four caller SKILL.md surfaces in the same commit.
#
# Usage (sourced):
#   . packages/<pkg>/lib/derive-first-dispatch.sh   # callers source their own package's copy
#
# Exported functions:
#   emit_stderr_advisory <skill> <field> <value> <source> [reversibility]
#   derive_kebab_slug <description> [max_tokens=8]
#   risk_policy_matrix_lookup <text> <impact_high> <impact_mod> <impact_low>
#                                    <likelihood_high> <likelihood_med> <likelihood_low>
#
# RETIRED 2026-06-02 (P287): lexical_classify_two_sided was the two-sided
# binary classifier used exclusively by capture-problem Step 1.5 Type
# classification (technical vs user-business). With the type axis retired
# per twice-confirmed user direction, the function has no remaining
# consumer and was removed. The slug + advisory + matrix helpers stay —
# they serve manage-incident severity, manage-problem priority, and
# create-adr title derivation.
#
# @adr ADR-002 (Monorepo per-plugin packages — architecture context for ADR-017)
# @adr ADR-017 (Shared code duplicated into per-package lib/ kept in sync)
# @adr ADR-044 (Decision-Delegation Contract — derive-first framework boundary)
# @adr ADR-026 (cost-source grounding — stderr advisory)
# @adr ADR-013 Rule 5 (policy-authorised silent proceed)
# @adr ADR-052 (behavioural-by-default — tested via scripts/test/derive-first-dispatch.bats
#               and packages/shared/test/sync-derive-first-dispatch.bats)
# @problem P132 (agents over-ask in interactive sessions — Phase 2a-iii-A shared helper +
#                Phase 2a-iii-B 4th-adopter migration to packages/shared/)
# @problem P185 (capture-problem Step 1.5 worked-example precedent)
# @jtbd JTBD-001 (enforce governance without slowing down — primary)
# @jtbd JTBD-101 (extend the suite with consistent patterns)
#
# NOT exporting `set -e` at file scope — callers source the helper and
# expect functions that return AMBIGUOUS sentinels rather than errexit.

# ---------------------------------------------------------------------------
# emit_stderr_advisory — canonical I2-isomorphic stderr advisory format.
#
# Format: <skill>: derived <field>=<value> from <source>; <reversibility>
#
# This is the single source-of-truth for the advisory sentence shape
# across all derive-first declaration-skill surfaces. The format is
# load-bearing for cross-skill consistency — drift here re-opens P132.
# ---------------------------------------------------------------------------
emit_stderr_advisory() {
  local skill="$1"
  local field="$2"
  local value="$3"
  local source_desc="$4"
  local reversibility="${5:-re-invoke or update if mis-rated}"
  printf '%s: derived %s=%s from %s; %s\n' \
    "$skill" "$field" "$value" "$source_desc" "$reversibility" >&2
}

# ---------------------------------------------------------------------------
# derive_kebab_slug — kebab-case slug from prose.
#
# Lowercases, strips non-alphanumeric (preserves space and hyphen as
# token separators), drops stopwords, joins surviving tokens with `-`,
# caps the token count (default 8 per the SKILL.md surface contract).
#
# Used at:
#   - capture-problem Step 1.4 Title derivation
#   - manage-incident Step 4 Title derivation
#   - manage-problem Step 4 Title derivation
#   - create-adr Step 2 Title derivation (P132 Phase 2a-iii-B)
# ---------------------------------------------------------------------------
derive_kebab_slug() {
  local description="$1"
  local max_tokens="${2:-8}"
  # Stopword list — common English function words plus "I/you/we" pronouns.
  local stopwords='^(the|a|an|and|or|but|if|then|else|when|while|for|to|of|in|on|at|by|from|with|as|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|may|might|must|can|i|you|we|they|it|its|this|that|these|those|so|because|since|just|only|than|like|some|any|all|each|every|no|not)$'

  printf '%s' "$description" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9 -' ' ' \
    | tr -s ' ' \
    | tr ' ' '\n' \
    | grep -vE "$stopwords" \
    | grep -v '^$' \
    | head -n "$max_tokens" \
    | paste -sd '-' -
}

# ---------------------------------------------------------------------------
# risk_policy_matrix_lookup — RISK-POLICY.md Impact × Likelihood lookup.
#
# Used by:
#   - manage-incident Step 4 Severity derivation
#   - manage-problem Step 4 Priority derivation
#
# Caller passes description text plus six regex pattern arrays (by
# name) keyed by impact band (high/mod/low) and likelihood band
# (high/med/low). Helper echoes one of:
#
#   <score>|<label>|impact=<L>+likelihood=<L>
#     Single dominant impact band AND single dominant likelihood band
#     matched. Score = impact_val * likelihood_val; label per
#     RISK-POLICY.md § Label Bands (Very Low / Low / Medium / High /
#     Very High).
#   AMBIGUOUS|<reason>
#     Multi-band hit (signals point to conflicting cells) OR zero hit
#     (no mappable signal). Caller fires AskUserQuestion as the
#     genuine ADR-044 category-5 (taste) fallback surface.
#
# Band-to-numeric mapping (preserves RISK-POLICY.md Impact / Likelihood
# Levels table):
#   impact:     high = 5 (Severe),     mod = 3 (Moderate), low = 1 (Negligible)
#   likelihood: high = 5 (Almost certain), med = 3 (Possible), low = 1 (Rare)
#
# Label bands (RISK-POLICY.md):
#   1-2   Very Low
#   3-4   Low
#   5-9   Medium
#   10-16 High
#   17-25 Very High
#
# This helper preserves the band-to-score mapping; callers that need a
# wider granularity (e.g. Significant=4 / Minor=2) must extend the
# pattern arrays' band-buckets in a follow-on contract change.
# ---------------------------------------------------------------------------
risk_policy_matrix_lookup() {
  local description="$1"
  local -n _impact_high_ref="$2"
  local -n _impact_mod_ref="$3"
  local -n _impact_low_ref="$4"
  local -n _likelihood_high_ref="$5"
  local -n _likelihood_med_ref="$6"
  local -n _likelihood_low_ref="$7"

  local pat
  local impact_high_hits=0
  local impact_mod_hits=0
  local impact_low_hits=0
  local likelihood_high_hits=0
  local likelihood_med_hits=0
  local likelihood_low_hits=0

  for pat in "${_impact_high_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      impact_high_hits=$((impact_high_hits + 1))
    fi
  done
  for pat in "${_impact_mod_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      impact_mod_hits=$((impact_mod_hits + 1))
    fi
  done
  for pat in "${_impact_low_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      impact_low_hits=$((impact_low_hits + 1))
    fi
  done
  for pat in "${_likelihood_high_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      likelihood_high_hits=$((likelihood_high_hits + 1))
    fi
  done
  for pat in "${_likelihood_med_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      likelihood_med_hits=$((likelihood_med_hits + 1))
    fi
  done
  for pat in "${_likelihood_low_ref[@]}"; do
    if printf '%s' "$description" | grep -qiE "$pat" 2>/dev/null; then
      likelihood_low_hits=$((likelihood_low_hits + 1))
    fi
  done

  local nonzero_impact=0
  (( impact_high_hits > 0 )) && nonzero_impact=$((nonzero_impact + 1))
  (( impact_mod_hits > 0 )) && nonzero_impact=$((nonzero_impact + 1))
  (( impact_low_hits > 0 )) && nonzero_impact=$((nonzero_impact + 1))

  if (( nonzero_impact != 1 )); then
    printf 'AMBIGUOUS|impact-bands-hit=%d\n' "$nonzero_impact"
    return 0
  fi

  local impact_band=0
  local impact_label=""
  if (( impact_high_hits > 0 )); then
    impact_band=5
    impact_label="Severe"
  elif (( impact_mod_hits > 0 )); then
    impact_band=3
    impact_label="Moderate"
  elif (( impact_low_hits > 0 )); then
    impact_band=1
    impact_label="Negligible"
  fi

  local nonzero_likelihood=0
  (( likelihood_high_hits > 0 )) && nonzero_likelihood=$((nonzero_likelihood + 1))
  (( likelihood_med_hits > 0 )) && nonzero_likelihood=$((nonzero_likelihood + 1))
  (( likelihood_low_hits > 0 )) && nonzero_likelihood=$((nonzero_likelihood + 1))

  if (( nonzero_likelihood != 1 )); then
    printf 'AMBIGUOUS|likelihood-bands-hit=%d\n' "$nonzero_likelihood"
    return 0
  fi

  local likelihood_band=0
  local likelihood_label=""
  if (( likelihood_high_hits > 0 )); then
    likelihood_band=5
    likelihood_label="Almost-certain"
  elif (( likelihood_med_hits > 0 )); then
    likelihood_band=3
    likelihood_label="Possible"
  elif (( likelihood_low_hits > 0 )); then
    likelihood_band=1
    likelihood_label="Rare"
  fi

  local score=$((impact_band * likelihood_band))
  local label
  if (( score >= 17 )); then
    label="Very High"
  elif (( score >= 10 )); then
    label="High"
  elif (( score >= 5 )); then
    label="Medium"
  elif (( score >= 3 )); then
    label="Low"
  else
    label="Very Low"
  fi

  printf '%d|%s|impact=%s+likelihood=%s\n' \
    "$score" "$label" "$impact_label" "$likelihood_label"
}
