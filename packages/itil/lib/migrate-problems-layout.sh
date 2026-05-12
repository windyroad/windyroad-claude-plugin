#!/usr/bin/env bash
# Canonical shared migration routine — adopter `docs/problems/` flat → per-state subdir.
# P170 / RFC-002 / ADR-031 (accepted 2026-05-12).
#
# Adopter repos that installed `@windyroad/itil` before ADR-031 acceptance
# carry the flat-layout `docs/problems/<NNN>-<slug>.<state>.md` shape. The
# `manage-problem` and `work-problems` skills source this file at Step 1
# (ADR-032 foreground-synchronous) and call `migrate_problems_to_per_state_layout`
# before any layout-dependent logic, so adopter trees auto-migrate on first
# invocation post-update.
#
# Distribution: ADR-017 sync pattern. Canonical lives at
#   packages/shared/lib/migrate-problems-layout.sh
# Synced into each consumer's lib/ (currently only `packages/itil/lib/`)
# by `scripts/sync-migrate-problems-layout.sh`. Drift is asserted by
# `packages/shared/test/sync-migrate-problems-layout.bats` and the
# `npm run check:migrate-problems-layout` CI step.
#
# Dependencies: bash 4+ (uses `shopt -s nullglob`), git, standard core utils.
# Not POSIX-portable — the architect advisory at T7 review explicitly
# scoped this to bash (compgen / nullglob are bash builtins).
#
# Source this file, then call `migrate_problems_to_per_state_layout`:
#   . packages/itil/lib/migrate-problems-layout.sh
#   migrate_problems_to_per_state_layout "$PWD"

# detect_flat_layout REPO_ROOT
# Returns 0 if any docs/problems/*.<state>.md exists at top level of
# docs/problems/ (flat layout present — migration needed); 1 otherwise.
# Partial-migration-safe: returns 0 even when some files have already
# moved into subdirs, so re-invocation completes any tail iteration.
detect_flat_layout() {
  local repo_root="${1:-$PWD}"
  local problems_dir="$repo_root/docs/problems"
  [ -d "$problems_dir" ] || return 1

  local state
  shopt -s nullglob
  for state in open known-error verifying parked closed; do
    local matches=( "$problems_dir"/*."$state".md )
    if [ ${#matches[@]} -gt 0 ]; then
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

# migrate_problems_to_per_state_layout REPO_ROOT
# Idempotent + partial-migration-safe entrypoint.
# Returns 0 when already-migrated (no-op) OR migration completed cleanly.
# Returns non-zero on git failure. Writes a standalone commit with
# subject `docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)`
# and a footer `RISK_BYPASS: adr-031-migration` trailer recognised by the
# commit-gate hook (T11). Standalone-commit grain per ADR-031 §
# Backward Compatibility (line 124).
migrate_problems_to_per_state_layout() {
  local repo_root="${1:-$PWD}"
  local problems_dir="$repo_root/docs/problems"

  if [ ! -d "$problems_dir" ]; then
    return 0
  fi

  if ! detect_flat_layout "$repo_root"; then
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not available; cannot auto-migrate docs/problems/ layout" >&2
    return 1
  fi

  if ! (cd "$repo_root" && git rev-parse --git-dir >/dev/null 2>&1); then
    echo "ERROR: not a git repository at $repo_root; cannot auto-migrate" >&2
    return 1
  fi

  local state f base target moved_count=0
  shopt -s nullglob
  for state in open known-error verifying parked closed; do
    mkdir -p "$problems_dir/$state"
    for f in "$problems_dir"/*."$state".md; do
      [ -e "$f" ] || continue
      base="$(basename "$f" ".$state.md")"
      target="$problems_dir/$state/$base.md"
      if [ -e "$target" ]; then
        echo "WARNING: target $target already exists; skipping $f" >&2
        continue
      fi
      (cd "$repo_root" && git mv "$f" "$target") || {
        shopt -u nullglob
        echo "ERROR: git mv failed for $f" >&2
        return 1
      }
      moved_count=$((moved_count + 1))
    done
  done
  shopt -u nullglob

  if (cd "$repo_root" && git diff --cached --quiet); then
    return 0
  fi

  # JTBD-006 AFK transparency (T8 jtbd-review nitpick c): single stderr
  # line on first-fire so AFK orchestrator output records the action.
  echo "migrate-problems-layout: relocated $moved_count tickets to per-state subdirs (ADR-031)" >&2

  # JTBD-201 audit-trail forward-pointer (T8 jtbd-review nitpick b):
  # commit body cites ADR-031 so future `git log` readers have the
  # semantic context without needing to grep the trailer.
  local commit_msg
  commit_msg=$'docs(problems): auto-migrate to per-state subdirectory layout (ADR-031)\n\nSee: docs/decisions/031-problem-ticket-directory-layout.accepted.md\n\nPolicy-authorised under ADR-013 Rule 6 + ADR-019 precedent (pure-rename + pure-mkdir; fully reversible via git revert).'

  (cd "$repo_root" && git commit \
    --message "$commit_msg" \
    --trailer "RISK_BYPASS: adr-031-migration") || {
    echo "ERROR: migration commit failed" >&2
    return 1
  }

  return 0
}
