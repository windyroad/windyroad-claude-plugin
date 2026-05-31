#!/usr/bin/env bash
# packages/itil/scripts/evaluate-relevance.sh
#
# Evaluate whether a problem ticket has become "no longer relevant" by
# checking observable evidence per ADR-026 grounding. Phase 1 scope per
# ADR-079: ONE evidence shape — "file no longer exists in codebase" —
# closest analog to P334/P336 close-on-evidence.
#
# Usage:
#   evaluate-relevance.sh <ticket-file> [<min-age-days>]
#
# Default <min-age-days> is 7. Age gate is a GATING condition, not the
# closing condition (per user direction 2026-05-31: "not just because
# they are old").
#
# Algorithm:
#   1. Read **Reported**: YYYY-MM-DD from the ticket frontmatter.
#      If absent or unparseable → SKIP no-reported-date.
#   2. If today - Reported < min-age-days → SKIP too-fresh.
#   3. Extract file-path candidates from the ticket body matching
#      (packages|docs|.changeset|src|test|scripts)/<path>.<known-extension>
#      then drop self-references (docs/problems/*).
#   4. If no candidates remain → SKIP no-extractable-paths.
#   5. For each candidate, run `git ls-files --error-unmatch <path>`.
#      Count present vs missing.
#   6. If ALL candidates missing AND at least 1 was extracted →
#      CLOSE-CANDIDATE. Otherwise → KEEP.
#
# Output (stdout, one line):
#   CLOSE-CANDIDATE <basename> — all <N> file paths absent: <semicolon list>
#   KEEP            <basename> — <M>/<N> paths still present
#   SKIP            <basename> — <reason>
#
# Exit codes:
#   0 = CLOSE-CANDIDATE (close action recommended)
#   1 = KEEP (no action)
#   2 = SKIP (no action; gating condition or unparseable)
#   3 = error (ticket file not found / git not available)
#
# Set LC_ALL=C for portable byte-grep per P328 (BSD grep on macOS
# silently misbehaves on UTF-8 without an explicit locale).
#
# ADR-049: never source repo-relative `packages/...` paths from a SKILL.
# This script is invoked via the `wr-itil-evaluate-relevance` PATH shim.
# ADR-026: every CLOSE-CANDIDATE verdict cites the paths checked AND
# the verdict is reversible (`git mv` back if a rename was missed).
# ADR-052: behavioural bats coverage at scripts/test/evaluate-relevance.bats.

set -euo pipefail
export LC_ALL=C

ticket_file="${1:-}"
min_age_days="${2:-7}"

if [ -z "$ticket_file" ]; then
  echo "evaluate-relevance: usage: $0 <ticket-file> [<min-age-days>]" >&2
  exit 3
fi

if [ ! -f "$ticket_file" ]; then
  echo "evaluate-relevance: ticket file not found: $ticket_file" >&2
  exit 3
fi

basename=$(basename "$ticket_file")

# ── Age gate ────────────────────────────────────────────────────────────────

reported=$(grep -m1 -oE '^\*\*Reported\*\*: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ticket_file" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
if [ -z "$reported" ]; then
  echo "SKIP $basename — no Reported date"
  exit 2
fi

# Portable date arithmetic: compute cutoff date min_age_days ago as
# YYYY-MM-DD, then ISO string-compare. Works on both BSD (macOS) and
# GNU date.
cutoff=$(date -u -v-"${min_age_days}"d "+%Y-%m-%d" 2>/dev/null || date -u -d "${min_age_days} days ago" "+%Y-%m-%d" 2>/dev/null || true)
if [ -z "$cutoff" ]; then
  echo "SKIP $basename — could not compute cutoff date (date binary missing both BSD and GNU forms)"
  exit 2
fi

# ISO strings sort lexicographically. If reported > cutoff, the ticket
# is younger than min_age_days → skip.
if [ "$reported" \> "$cutoff" ]; then
  echo "SKIP $basename — age gate (reported=$reported newer than cutoff=$cutoff, gate=${min_age_days}d)"
  exit 2
fi

# ── Path extraction ─────────────────────────────────────────────────────────

# Regex restricts candidates to well-known repo subdirs with known
# file extensions. Tight on purpose — false-positive-resistant.
# Extension list mirrors the file types typically referenced in
# problem-ticket bodies (markdown, shell scripts, source, configs).
candidates=$(grep -oE '(packages|docs|\.changeset|src|test|scripts)/[A-Za-z0-9._/-]+\.(md|sh|ts|tsx|js|jsx|json|yml|yaml|bats|py|txt|html)' "$ticket_file" 2>/dev/null \
  | sort -u \
  | grep -v '^docs/problems/' \
  || true)

if [ -z "$candidates" ]; then
  echo "SKIP $basename — no extractable file paths (after self-reference exclusion)"
  exit 2
fi

# ── Existence check via git ls-files ────────────────────────────────────────

missing=0
present=0
missing_list=""

while IFS= read -r path; do
  [ -z "$path" ] && continue
  if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
    present=$((present + 1))
  else
    missing=$((missing + 1))
    if [ -z "$missing_list" ]; then
      missing_list="$path"
    else
      missing_list="$missing_list;$path"
    fi
  fi
done <<< "$candidates"

total=$((missing + present))

if [ "$missing" -eq "$total" ] && [ "$missing" -ge 1 ]; then
  echo "CLOSE-CANDIDATE $basename — all ${total} file paths absent: ${missing_list}"
  exit 0
fi

echo "KEEP $basename — ${present}/${total} paths still present"
exit 1
