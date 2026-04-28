#!/usr/bin/env bash
# packages/itil/scripts/check-problems-readme-budget.sh
#
# Diagnose-only advisory script for the docs/problems/README.md "Last
# reviewed" line (line 3). Sibling to P099's
# packages/retrospective/scripts/check-briefing-budgets.sh on a
# different surface — both apply ADR-040 line 92's reusable triplet
# (read-only diagnostic + behavioural bats + ADR-tier-budget
# enforcement clause) to an accumulator-doc surface.
#
# Usage:
#   check-problems-readme-budget.sh [<readme-path>]
#
# Default <readme-path> is ./docs/problems/README.md.
# Threshold is read from PROBLEMS_README_LINE3_MAX_BYTES (default 5120
# — matches ADR-040 Tier 3 Tier 3 envelope; the soft per-fragment cap
# is 1024 bytes, enforced by the SKILL.md authoring contracts in
# manage-problem / transition-problem / transition-problems /
# review-problems / reconcile-readme).
#
# Exit codes:
#   0 = always (advisory only — overflow is signal, not failure)
#   2 = parse error (README path missing or unreadable)
#
# Output format on overflow (one line, terse machine-readable per
# ADR-038 progressive-disclosure budget):
#   OVER <readme-path> line=3 bytes=<N> threshold=<N>
#
# Output is empty (no lines) when line 3 is under the threshold.
#
# Read-only — does NOT mutate the README. Truncation is owned by the
# per-operation refresh contracts in manage-problem Step 5 P094 +
# Step 7 P062 (and the sibling skills).
#
# @problem P134
# @adr ADR-040 (Session-start briefing surface — Tier 3 budget; line 92's
#   reusable-pattern note explicitly names "problems index" as a
#   candidate surface for this triplet)
# @adr ADR-038 (Progressive disclosure — per-row terse budget)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — advisory exit 0)
# @adr ADR-005 (Plugin testing strategy)
# @jtbd JTBD-001 / JTBD-006 / JTBD-101

set -uo pipefail

README_PATH="${1:-docs/problems/README.md}"
THRESHOLD="${PROBLEMS_README_LINE3_MAX_BYTES:-5120}"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -f "$README_PATH" ]; then
  echo "check-problems-readme-budget: README not found: $README_PATH" >&2
  exit 2
fi

# ── Measure line 3 byte size ────────────────────────────────────────────────
# `awk 'NR==3'` extracts line 3 verbatim; the trailing newline that awk
# emits is not part of the line's content. We use printf '%s' to feed
# the line to wc -c with no added newline so the byte count matches the
# in-file content of line 3. Empty / missing line 3 yields 0 bytes.

line3="$(awk 'NR==3' "$README_PATH")"
bytes=$(printf '%s' "$line3" | wc -c | tr -d ' ')

if [ "$bytes" -ge "$THRESHOLD" ] && [ "$bytes" -gt 0 ]; then
  echo "OVER $README_PATH line=3 bytes=$bytes threshold=$THRESHOLD"
fi

# Edge case: threshold of 0 with non-empty line 3 — still report (sanity
# path exercised in bats). The first guard above requires bytes > 0 so
# we never emit OVER for an empty/missing line 3.

exit 0
