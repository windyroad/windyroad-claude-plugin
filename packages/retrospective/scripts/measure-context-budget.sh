#!/usr/bin/env bash
# packages/retrospective/scripts/measure-context-budget.sh
#
# Read-only diagnostic script for context-usage measurement (P101 / ADR-043
# Progressive context-usage measurement and reporting for retrospective sessions).
# Walks the session's on-disk context contributors and reports per-source
# bucket byte totals so run-retro Step 2c can render the cheap-layer table
# (interactive or AFK; same output shape) and the deep-layer skill can
# consume the same data as its baseline.
#
# Usage:
#   measure-context-budget.sh [<project-root>]
#
# Default <project-root> is $CLAUDE_PROJECT_DIR if set, else the current
# working directory.
#
# Threshold for the optional fail-open ceiling is read from
# CONTEXT_BUDGET_MAX_BYTES (default 10240 — the 5% / 200K cheap-layer
# envelope per ADR-043). The script does NOT enforce the threshold; it
# is exposed for the bats fixture and for Step 2c's defensive trip.
#
# Exit codes:
#   0 = always (advisory only — overflow is signal, not failure)
#   2 = parse error (project root missing or unreadable)
#
# Output format (one line per bucket, terse machine-readable per ADR-038
# progressive-disclosure budget — ≤150 bytes per row):
#   BUCKET <name> bytes=<N>
#   BUCKET <name> not-measured reason=<reason>
#
# The output is sorted by bucket name for stable diffs (per the
# check-briefing-budgets.sh precedent + bats fixture contract).
#
# Read-only — does NOT mutate any project file. Snapshot persistence
# (HTML-comment trailer in docs/retros/<date>-context-analysis.md) is the
# deep-layer skill's responsibility, not this script's.
#
# @problem P101
# @adr ADR-043 (Progressive context-usage measurement and reporting for
#   retrospective sessions; this script is the measurement primitive)
# @adr ADR-038 (Progressive disclosure — per-row byte budget)
# @adr ADR-026 (Agent output grounding — explicit not-measured sentinels
#   for surfaces without an on-disk source)
# @adr ADR-013 (Rule 1 / Rule 6 — interactive vs AFK; this script's
#   advisory exit-0 contract supports both)
# @adr ADR-005 (Plugin testing strategy)
# @adr ADR-037 (Skill testing strategy — bats-contract precedent)
# @jtbd JTBD-001 / JTBD-005 / JTBD-006

set -uo pipefail

PROJECT_ROOT="${1:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
THRESHOLD="${CONTEXT_BUDGET_MAX_BYTES:-10240}"

# ── Pre-checks ──────────────────────────────────────────────────────────────

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "measure-context-budget: project root not found: $PROJECT_ROOT" >&2
  exit 2
fi

# Helper — sum byte sizes of files matching a glob. Returns 0 (zero bytes)
# if the glob matches nothing, distinguishing "scanned, empty" from
# "surface not present".
sum_globs() {
  local total=0
  local file
  for pattern in "$@"; do
    # Use shopt nullglob so an empty match expands to nothing
    shopt -s nullglob
    local matches=( $pattern )
    shopt -u nullglob
    for file in "${matches[@]}"; do
      if [ -f "$file" ] && [ -r "$file" ]; then
        local bytes
        bytes=$(wc -c < "$file" 2>/dev/null | tr -d ' ')
        total=$(( total + ${bytes:-0} ))
      fi
    done
  done
  echo "$total"
}

# Helper — emit one bucket row. Use a "not-measured" sentinel when the
# surface is absent (e.g. project has no docs/jtbd/) per ADR-026's
# ungrounded-field rule.
emit_bucket() {
  local name="$1"
  local bytes="$2"
  local present="$3"  # 1 if surface present, 0 if absent
  local reason="${4:-source-absent}"
  if [ "$present" = "1" ]; then
    echo "BUCKET $name bytes=$bytes"
  else
    echo "BUCKET $name not-measured reason=$reason"
  fi
}

# ── Bucket: hooks ───────────────────────────────────────────────────────────
# Aggregate over packages/*/hooks/**/*.sh + project-local .claude/hooks/**/*.sh
# Surface present if either exists.

hooks_present=0
if [ -d "$PROJECT_ROOT/packages" ] || [ -d "$PROJECT_ROOT/.claude/hooks" ]; then
  hooks_present=1
fi

if [ "$hooks_present" = "1" ]; then
  hooks_bytes=$(
    cd "$PROJECT_ROOT" 2>/dev/null && {
      shopt -s nullglob globstar
      pkg_files=( packages/*/hooks/**/*.sh )
      proj_files=( .claude/hooks/**/*.sh )
      shopt -u nullglob globstar
      total=0
      for f in "${pkg_files[@]}" "${proj_files[@]}"; do
        if [ -f "$f" ] && [ -r "$f" ]; then
          b=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
          total=$(( total + ${b:-0} ))
        fi
      done
      echo "$total"
    }
  )
fi
emit_bucket hooks "${hooks_bytes:-0}" "$hooks_present"

# ── Bucket: skills ──────────────────────────────────────────────────────────
# Aggregate over packages/*/skills/**/SKILL.md + .claude/skills/**/SKILL.md

skills_present=0
if [ -d "$PROJECT_ROOT/packages" ] || [ -d "$PROJECT_ROOT/.claude/skills" ]; then
  skills_present=1
fi

if [ "$skills_present" = "1" ]; then
  skills_bytes=$(
    cd "$PROJECT_ROOT" 2>/dev/null && {
      shopt -s nullglob globstar
      pkg_files=( packages/*/skills/**/SKILL.md )
      proj_files=( .claude/skills/**/SKILL.md )
      shopt -u nullglob globstar
      total=0
      for f in "${pkg_files[@]}" "${proj_files[@]}"; do
        if [ -f "$f" ] && [ -r "$f" ]; then
          b=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
          total=$(( total + ${b:-0} ))
        fi
      done
      echo "$total"
    }
  )
fi
emit_bucket skills "${skills_bytes:-0}" "$skills_present"

# ── Bucket: briefing ────────────────────────────────────────────────────────
# Aggregate over docs/briefing/*.md (top-level only; nested archives are
# the deep layer's concern). Single bucket row aggregating per-file detail
# already exposed via P099's check-briefing-budgets.sh.

briefing_dir="$PROJECT_ROOT/docs/briefing"
briefing_present=0
briefing_bytes=0
if [ -d "$briefing_dir" ]; then
  briefing_present=1
  briefing_bytes=$( cd "$PROJECT_ROOT" && sum_globs "docs/briefing/*.md" )
fi
emit_bucket briefing "$briefing_bytes" "$briefing_present"

# ── Bucket: decisions ───────────────────────────────────────────────────────

decisions_dir="$PROJECT_ROOT/docs/decisions"
decisions_present=0
decisions_bytes=0
if [ -d "$decisions_dir" ]; then
  decisions_present=1
  decisions_bytes=$( cd "$PROJECT_ROOT" && sum_globs "docs/decisions/*.md" )
fi
emit_bucket decisions "$decisions_bytes" "$decisions_present"

# ── Bucket: problems ────────────────────────────────────────────────────────
# Dual-tolerant enumeration per RFC-002 T4 (the proven reconcile-readme.sh
# pattern). RFC-002 T5 / ADR-031 migrated tickets from the flat layout
# (docs/problems/<NNN>-*.<state>.md) to per-state subdirs
# (docs/problems/<state>/<NNN>-*.md). Walk BOTH layouts; a flat-only glob
# misses the subdir tickets and under-counts the bucket ~99% post-migration
# (P182). Dedup on ticket ID (the per-state layout drops the `.<state>`
# suffix, so the same ticket has different basenames across layouts — key on
# ID, not basename, mirroring reconcile-readme.sh). Non-ticket files (README)
# live only at the top level and never collide with subdir content, so they
# key on full basename. The per-state subdir loop runs AFTER the flat loop so
# the per-state copy wins on collision (ADR-031 §"Authoritative state signal").

problems_dir="$PROJECT_ROOT/docs/problems"
problems_present=0
problems_bytes=0
if [ -d "$problems_dir" ]; then
  problems_present=1
  problems_bytes=$(
    cd "$PROJECT_ROOT" 2>/dev/null && {
      declare -A seen
      shopt -s nullglob
      # Flat layout: top-level *.md (READMEs + any pre-migration flat tickets).
      for f in docs/problems/*.md; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        case "$base" in
          [0-9][0-9][0-9]-*) key="${base%%-*}" ;;  # ticket: dedup on numeric ID
          *)                 key="$base" ;;        # README etc: full basename
        esac
        seen["$key"]="$f"
      done
      # Per-state subdir layout (RFC-002 T5 / ADR-031) — wins on ID collision.
      for state in open known-error verifying closed parked; do
        for f in docs/problems/"$state"/*.md; do
          [ -f "$f" ] || continue
          base="$(basename "$f")"
          case "$base" in
            [0-9][0-9][0-9]-*) key="${base%%-*}" ;;
            *)                 key="$base" ;;
          esac
          seen["$key"]="$f"
        done
      done
      shopt -u nullglob
      total=0
      for f in "${seen[@]}"; do
        if [ -r "$f" ]; then
          b=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
          total=$(( total + ${b:-0} ))
        fi
      done
      echo "$total"
    }
  )
fi
emit_bucket problems "$problems_bytes" "$problems_present"

# ── Bucket: jtbd ────────────────────────────────────────────────────────────

jtbd_dir="$PROJECT_ROOT/docs/jtbd"
jtbd_present=0
jtbd_bytes=0
if [ -d "$jtbd_dir" ]; then
  jtbd_present=1
  jtbd_bytes=$(
    cd "$PROJECT_ROOT" 2>/dev/null && {
      shopt -s nullglob globstar
      files=( docs/jtbd/**/*.md )
      shopt -u nullglob globstar
      total=0
      for f in "${files[@]}"; do
        if [ -f "$f" ] && [ -r "$f" ]; then
          b=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
          total=$(( total + ${b:-0} ))
        fi
      done
      echo "$total"
    }
  )
fi
emit_bucket jtbd "$jtbd_bytes" "$jtbd_present"

# ── Bucket: project-claude-md ───────────────────────────────────────────────

project_claude_md="$PROJECT_ROOT/CLAUDE.md"
claude_md_present=0
claude_md_bytes=0
if [ -f "$project_claude_md" ] && [ -r "$project_claude_md" ]; then
  claude_md_present=1
  claude_md_bytes=$( wc -c < "$project_claude_md" 2>/dev/null | tr -d ' ' )
fi
emit_bucket project-claude-md "${claude_md_bytes:-0}" "$claude_md_present"

# ── Bucket: memory ──────────────────────────────────────────────────────────
# User-owned per-project memory files. Read-only attempt; emit not-measured
# sentinel when the directory is inaccessible (e.g. the running agent is
# in a different user account or the path doesn't exist for this project).

memory_root="${HOME:-/tmp}/.claude/projects"
memory_present=0
memory_bytes=0
if [ -d "$memory_root" ] && [ -r "$memory_root" ]; then
  # Best-effort: sum *.md files under any subdirectory of memory_root.
  # Per-project filtering is the deep layer's concern.
  memory_present=1
  shopt -s nullglob globstar
  mem_files=( "$memory_root"/**/memory/*.md )
  shopt -u nullglob globstar
  for f in "${mem_files[@]}"; do
    if [ -f "$f" ] && [ -r "$f" ]; then
      b=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
      memory_bytes=$(( memory_bytes + ${b:-0} ))
    fi
  done
fi
if [ "$memory_present" = "1" ]; then
  emit_bucket memory "$memory_bytes" 1
else
  emit_bucket memory 0 0 user-memory-inaccessible
fi

# ── Bucket: framework-injected ──────────────────────────────────────────────
# Available-skills, subagent-types, deferred-tools listings are emitted by
# the framework on every turn but are NOT byte-countable from the project
# filesystem. Per ADR-026 ungrounded-field rule, emit explicit sentinel.

emit_bucket framework-injected 0 0 framework-injected-no-on-disk-source

# ── Done ────────────────────────────────────────────────────────────────────
# Threshold is exposed for callers (Step 2c defensive trip + bats fixture).
# Echoed as a trailing diagnostic line — callers can grep for `THRESHOLD `
# to retrieve it without parsing every BUCKET row.

echo "THRESHOLD bytes=$THRESHOLD"

exit 0
