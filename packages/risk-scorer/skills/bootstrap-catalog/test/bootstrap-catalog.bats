#!/usr/bin/env bats
# Doc-lint guard: /wr-risk-scorer:bootstrap-catalog SKILL.md MUST define
# the runtime contract per ADR-059 verdicts A4 (on-demand surface) +
# B1 (slug dedupe) + C1 (no threshold) + D1 (Source Evidence required).
#
# Structural assertions — Permitted Exception to the source-grep ban (ADR-005 / P011).
# SKILL.md is a specification document; behavioural verification of LLM-driven
# skills is out of scope for bats. The contract document is what consuming
# orchestrators (install-updates Step 6.5.1 auto-trigger) rely on.
#
# Cross-reference:
#   ADR-059: docs/decisions/059-pipeline-consume-catalog-and-bootstrap-from-reports.proposed.md
#   ADR-056: docs/decisions/056-risk-register-back-channel-write-contract.proposed.md (slug primitive)
#   ADR-026: docs/decisions/026-agent-output-grounding.proposed.md (sentinel)
#   ADR-047: docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md (parent)
#   P168:    docs/problems/168-risk-scorer-doesnt-consume-catalog-or-bootstrap.known-error.md
#   @jtbd JTBD-001 (enforce governance without slowing down — bootstrap eliminates miss-rate gap)
#   @jtbd JTBD-006 (AFK-safety — bootstrap is idempotent + non-interactive)
#   @jtbd JTBD-202 (pre-flight governance — catalog as ISO 31000/27001 audit-trail)

setup() {
  SKILL_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${SKILL_DIR}/SKILL.md"
}

# ──────────────────────────────────────────────────────────────────────────────
# Frontmatter: name, description, allowed-tools, maturity
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md has frontmatter with correct namespaced name" {
  run grep -qE "^name: wr-risk-scorer:bootstrap-catalog" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md frontmatter declares Write tool" {
  run grep -qE "^allowed-tools:.*Write" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md frontmatter declares maturity per ADR-053" {
  run grep -qE "^maturity: (proposed|accepted|recommended)" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Pre-conditions (Step 0): RISK-POLICY.md present, docs/risks/ scaffolded, .risk-reports/ non-empty
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md requires RISK-POLICY.md presence" {
  run grep -qE "RISK-POLICY.md.*present|requires.*RISK-POLICY" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md owns docs/risks/ directory lifecycle (no separate scaffold required)" {
  # Updated 2026-05-05: the previous "requires scaffold" assertion is obsolete.
  # Per user direction 2026-05-04 (commit 8edaf7b), the Phase 1 scaffold step
  # + TEMPLATE.md were wiped because the scaffolded entries were wrong content;
  # bootstrap-catalog now owns the directory's full lifecycle (mkdir -p on demand,
  # writes README + per-slug entries, no separate scaffold step required).
  # The SKILL.md was rewritten accordingly; this test now asserts the new contract.
  run grep -qE "may or may not exist|creates it on demand|owns the directory's full lifecycle" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md requires .risk-reports/ corpus non-empty" {
  run grep -qE "[.]risk-reports/.*non-empty|[.]risk-reports/.*at least one" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Slug dedupe per ADR-056
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md cites ADR-056 for slug primitive" {
  run grep -q "ADR-056" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md describes dedupe-by-slug per ADR-056" {
  run grep -qE "[Dd]edupe by slug|dedupe.*slug|slug is the dedupe key|N reports.*same slug.*ONE" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# No threshold (Verdict C1)
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md emits one entry per unique slug (no frequency floor)" {
  run grep -qE "one R<NNN>-<slug>[.]active[.]md per unique slug|one .*per unique slug" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Source Evidence block required (Verdict D1)
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md requires Source Evidence block on new entries" {
  run grep -q "## Source Evidence" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md cites originating .risk-reports/ files in Source Evidence" {
  run grep -qE "originating reports|originating.*[.]risk-reports/|cite.*[.]risk-reports/" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md cites ADR-026 grounding for Source Evidence pattern" {
  run grep -qE "ADR-026.*grounding|grounding.*ADR-026" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# ADR-026 sentinel for ungrounded scoring fields
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md uses ADR-026 sentinel for ungrounded scoring" {
  run grep -q "not estimated — no prior data" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md sets pending-review Status on auto-scaffolded entries" {
  run grep -q "Active (auto-scaffolded — pending review)" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Idempotency contract
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md describes idempotency via file-existence per slug" {
  run grep -qE "[Ii]dempotent|file-existence|file existence test|re-run produces zero diff|safe to invoke at any time" "$SKILL"
  [ "$status" -eq 0 ]
}

@test "bootstrap-catalog SKILL.md handles slug collision via Source Evidence append" {
  run grep -qE "[Mm]atch exists.*append|slug collision|append.*Source Evidence" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Empty corpus / no reports handling
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md exits cleanly when .risk-reports/ is empty" {
  run grep -qE "no-op|exit cleanly.*no.*reports|nothing to walk|empty.*[Bb]ootstrap.*no-op" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Commit per ADR-014 single-commit grain
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md cites ADR-014 single-commit grain" {
  run grep -q "ADR-014" "$SKILL"
  [ "$status" -eq 0 ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Pure-scorer carve-out: this skill needs Write tool (it's the writer)
# ──────────────────────────────────────────────────────────────────────────────

@test "bootstrap-catalog SKILL.md is the orchestrator-side write surface (per Verdict G)" {
  # ADR-059 verdict G: bootstrap-catalog skill needs Write tool; pipeline agent
  # stays Read+Glob only (pure-scorer contract preserved). This skill's Write
  # grant is the legitimate orchestrator-side write surface.
  run grep -qE "needs Write tool|orchestrator-side|on-demand surface|Verdict G" "$SKILL"
  [ "$status" -eq 0 ]
}
