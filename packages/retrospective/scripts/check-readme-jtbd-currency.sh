#!/usr/bin/env bash
# packages/retrospective/scripts/check-readme-jtbd-currency.sh
#
# Diagnose-only advisory script for ADR-069 (README markets the persona's
# problem; skill-inventory currency gate). Walks packages/*/README.md and
# emits a skill-inventory-drift signal per package:
#
#   - skills=<count>        — directories under packages/<plugin>/skills/
#   - in_readme=<count>     — those skill directories named in the README
#   - drift_hints=<csv>     — signal vocabulary (inventory-only):
#         skill-inventory-drift  (a directory under packages/<plugin>/skills/
#                                 is not named in the README)
#
# Plus a trailing TOTAL line summarising the window:
#   TOTAL packages=<N> drift_instances=<K>
#
# Exit code is always 0 — the script is advisory; the commit-hook
# (retrospective-readme-jtbd-currency.sh) reads drift_instances and decides
# whether to deny. drift_instances counts packages with a non-empty
# drift_hints set.
#
# HISTORY / NAME-RETENTION: this script formerly enforced ADR-051's
# JTBD-ID-citation rule (grep for JTBD-\d{3}, resolve against docs/jtbd/).
# ADR-069 (P294) superseded ADR-051: plugin READMEs market to the persona's
# problem derived FROM the JTBD, but MUST NOT cite JTBD IDs. The JTBD-ID
# anchor + its docs/jtbd/ resolution are removed; the mechanical
# skill-inventory-drift signal (ADR-051's original P152 empirical core)
# survives as the load-bearing currency gate. The `jtbd-currency` filename
# is retained deliberately per ADR-069 — a rename would ripple into mutable
# ADRs 054/055/057 + the ADR-049 bin-grammar three-touch tax for a filename
# adopters rarely see. A clean rename is deferred to a future
# check-*-currency.sh family consolidation (ADR-069 Reassessment Criteria).
#
# Usage:
#   check-readme-jtbd-currency.sh [<packages-dir>]
#
# Defaults:
#   <packages-dir> = ./packages
#
# A second argument (formerly <jtbd-dir>) is accepted and ignored for
# backward compatibility with pre-ADR-069 callers.
#
# Exit codes:
#   0 = always (advisory only — count is signal, not failure)
#   2 = parse error (packages-dir missing or unreadable)
#
# Output format (one line per package, alphabetical):
#   README package=<name> skills=<N> in_readme=<M> drift_hints=<csv>
#
# @problem P152 (No pressure or nudge for documentation currency — the original driver)
# @problem P294 (ADR-051 superseded — README markets the persona's problem, no JTBD-ID citation)
# @adr ADR-069 (README markets persona problem; skill-inventory currency gate — this script's normative source)
# @adr ADR-051 (superseded — original JTBD-anchored README rule this script no longer enforces)
# @adr ADR-013 Rule 6 (non-interactive fail-safe — advisory script never blocks AFK)
# @adr ADR-040 (declarative-first / advisory-then-escalate precedent)
# @adr ADR-049 (bin/-on-PATH script resolution — paired wr-retrospective-check-readme-jtbd-currency shim)
# @adr ADR-052 / P081 (behavioural tests via bats; no structural-grep on this source)

set -uo pipefail

PACKAGES_DIR="${1:-packages}"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -d "$PACKAGES_DIR" ]; then
  echo "check-readme-jtbd-currency: packages dir not found: $PACKAGES_DIR" >&2
  exit 2
fi

# ── Helpers ─────────────────────────────────────────────────────────────────

append_hint() {
  local current="$1"
  local hint="$2"
  if [ -z "$current" ]; then
    echo "$hint"
  elif [[ ",$current," == *",$hint,"* ]]; then
    echo "$current"
  else
    echo "$current,$hint"
  fi
}

# ── Scan packages ───────────────────────────────────────────────────────────

total_packages=0
total_drift_instances=0

package_dirs=()
for pdir in "$PACKAGES_DIR"/*/; do
  [ -d "$pdir" ] || continue
  package_dirs+=("$pdir")
done

if [ "${#package_dirs[@]}" -eq 0 ]; then
  exit 0
fi

IFS=$'\n' sorted_dirs=($(printf '%s\n' "${package_dirs[@]}" | sort))
unset IFS

for pdir in "${sorted_dirs[@]}"; do
  package="$(basename "$pdir")"
  readme="$pdir/README.md"

  # Skip packages without a README — out of scope
  [ -f "$readme" ] || continue

  total_packages=$(( total_packages + 1 ))

  hints=""
  skills_count=0
  in_readme_count=0

  # Skill inventory drift: every directory under packages/<plugin>/skills/
  # should be named in the README so the inventory stays current.
  if [ -d "$pdir/skills" ]; then
    for sdir in "$pdir/skills"/*/; do
      [ -d "$sdir" ] || continue
      skill="$(basename "$sdir")"
      skills_count=$(( skills_count + 1 ))
      if grep -q -F "$skill" "$readme" 2>/dev/null; then
        in_readme_count=$(( in_readme_count + 1 ))
      else
        hints=$(append_hint "$hints" "skill-inventory-drift")
      fi
    done
  fi

  # Drift instance: any non-empty hint set
  if [ -n "$hints" ]; then
    total_drift_instances=$(( total_drift_instances + 1 ))
  fi

  echo "README package=$package skills=$skills_count in_readme=$in_readme_count drift_hints=$hints"
done

if [ "$total_packages" -gt 0 ]; then
  echo "TOTAL packages=$total_packages drift_instances=$total_drift_instances"
fi

exit 0
