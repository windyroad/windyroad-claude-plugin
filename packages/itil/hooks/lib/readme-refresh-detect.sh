#!/bin/bash
# P165: shared README-refresh-discipline detection helper.
#
# `detect_readme_refresh_required` returns 0 (no change required —
# allow) / 1 (ticket change staged but README refresh not staged —
# caller should deny). On 1, the offending ticket file path is echoed
# on stdout so callers can name it in deny messages without re-parsing
# diff output.
#
# Trap shape (P165):
#   `manage-problem` SKILL.md Step 5 (P094) and Step 7 (P062) say every
#   ticket creation, ranking-bearing update, and status transition MUST
#   stage the refreshed `docs/problems/README.md` in the same commit as
#   the ticket change (ADR-014 single-commit grain). The contract is
#   declarative; iter subprocess commits have shipped `.verifying.md`
#   renames or Status edits without the README refresh (observed iter
#   3 commit d28bd51 — P156 row missing from VQ until iter 4 backfill).
#   Hook-level detection at `git commit` time replaces the declarative-
#   only enforcement.
#
# Detection logic:
#   - `git diff --staged --name-only` enumerates staged paths.
#   - Categorise each path:
#       * `docs/problems/(open|verifying|closed|known-error|parked)/NNN-*.md`
#         (new state-directory layout per ADR-031) — counts as a
#         ticket-state-transition surface; records the path.
#       * `docs/problems/NNN-*.(open|verifying|closed|known-error|parked).md`
#         (legacy flat layout) — also counts; supports adopter repos
#         and any residual flat-layout tickets.
#       * `docs/problems/README.md` — counts as a README refresh.
#       * `docs/problems/README-history.md` — ignored (rotated history
#         per P134; not a ticket file, not the load-bearing README).
#       * Anything else — ignored (non-ticket surface; the gate has no
#         opinion on retros, ADRs, source, etc.).
#   - If any ticket path is recorded AND README is NOT staged, return
#     1 + echo the first offending ticket path.
#
# Bypass:
#   - `BYPASS_README_REFRESH_GATE=1` env var → return 0 (allow). For
#     legitimate one-off escape (e.g. force-amend after rebase rewrote
#     history). Audit-traceable via shell history. Set in
#     `.claude/settings.json` env field or shell `export` before
#     launching `claude` — inline-prefix syntax (`VAR=1 git commit ...`)
#     does NOT propagate from a Bash subshell to PreToolUse hooks (P173).
#   - Registered `RISK_BYPASS: <token>` commit-message trailer (P265) →
#     return 0 (allow). Narrow allow-list (currently only
#     `adr-031-migration`, the standalone ADR-031 layout-migration
#     commit, which is a rename-only change that legitimately stages no
#     README refresh). The trailer is read from the live `git commit`
#     command string at PreToolUse time (the commit message is not yet
#     written), matching the sibling `risk-score-commit-gate.sh`
#     recognition (P170 T11) so one logical migration commit clears both
#     gates. Registry of record: ADR-014 commit-message bypass-token
#     table.
#
# Narrative-only short-circuit (P230):
#   - When all staged ticket edits are purely narrative — no
#     ranking-bearing field change (Priority / Effort / Status / WSJF /
#     Type field-lines), no title change, no rename between state
#     subdirs, no creation/deletion — AND
#     `packages/itil/scripts/reconcile-readme.sh` reports exit=0 against
#     the current README, return 0 (allow). Reconcile-readme is the
#     authoritative drift oracle for narrative-only edits.
#   - Ranking-bearing edits still fall through to existing detection
#     regardless of reconcile state, preserving ADR-014 single-commit
#     grain for the change-set surface (architect verdict: reconcile is
#     a robustness layer on top of per-operation refresh, not a
#     supersession of either).
#
# Fail-open contract:
#   - Outside a git working tree, or when `git diff` fails for any
#     reason (parse error, broken index, permissions), return 0
#     (allow). Mirrors `lib/staging-detect.sh` + `lib/changeset-detect.sh`
#     fail-open precedent — a hook that fails-closed on hostile
#     environments would block legitimate commits in non-git contexts.
#
# Cost: one `git diff` invocation per check (~10ms on this repo's
# working tree). Per-invocation deterministic — runs on every
# `git commit` invocation rather than relying on per-tool-call session
# state tracking. Mirrors P125 `staging-detect.sh` + P141
# `changeset-detect.sh` precedent (architect-approved no-marker design
# per ADR-009 carve-out).
#
# References:
#   ADR-005  — plugin testing strategy (hook bats live under
#              `hooks/test/` per P081 behavioural-test discipline).
#   ADR-009  — gate marker lifecycle (this helper deliberately does
#              NOT use markers; detection is per-invocation
#              deterministic, not per-session trust window — same
#              precedent as P125 / P141).
#   ADR-013 Rule 1 — deny redirects with mechanical recovery (the deny
#              text names the offending ticket path + the literal
#              `git add docs/problems/README.md` recovery command +
#              the BYPASS env var override).
#   ADR-014  — single-commit grain (this hook enforces it for the
#              ticket-state-transition surface).
#   ADR-022  — `.verifying.md` lifecycle status (one of the surface
#              shapes the hook detects).
#   ADR-031  — per-state-subdir problem ticket layout (the new layout
#              the hook detects).
#   ADR-038  — progressive disclosure / deny-message terseness.
#   ADR-045  — hook injection budget (Pattern 1 silent-on-pass; deny
#              band ≤300 bytes for this hook).
#   P062     — parent (README refresh on transition contract — manage-
#              problem Step 7).
#   P094     — parent (README refresh on creation contract — manage-
#              problem Step 5).
#   P118     — sibling reconcile-readme recovery path (the after-the-
#              fact rescue this hook obviates).
#   P125     — sibling staging-trap helper (same enforcement-layer
#              shape — per-invocation deterministic, no markers).
#   P141     — sibling changeset-discipline helper (same shape).
#   P165     — this helper.
#   P265     — RISK_BYPASS trailer allow-list bypass (this addition).

# Allow-list of registered RISK_BYPASS commit-message trailer tokens
# (P265). A policy-authorised commit may carry `RISK_BYPASS: <token>` in
# its message body; when <token> is registered here, the README-refresh
# gate allows the commit even though no README refresh is staged. The
# allow-list keeps the bypass narrow and auditable — a generic
# `RISK_BYPASS:` match would let any commit self-exempt.
#
# Registered tokens:
#   adr-031-migration — the standalone per-state-subdir layout-migration
#     commit written by lib/migrate-problems-layout.sh. It is a pure
#     rename (no README content change — the table references tickets by
#     ID, not path), so requiring a README refresh would deadlock the
#     migration (P265). The same token clears the sibling
#     risk-score-commit-gate.sh (P170 T11); both gates recognise it via
#     the identical grep below so one logical migration commit clears
#     both. Registry of record: ADR-014 commit-message bypass-token table.
_README_REFRESH_BYPASS_TRAILERS=("adr-031-migration")

# Returns 0 if the given `git commit` command string carries a
# registered RISK_BYPASS trailer from the allow-list above. The grep
# pattern is kept byte-identical to risk-score-commit-gate.sh so both
# commit gates recognise the token the same way (P265 architect verdict).
_readme_refresh_command_has_bypass_trailer() {
  local command="${1:-}"
  [ -n "$command" ] || return 1
  local token
  for token in "${_README_REFRESH_BYPASS_TRAILERS[@]}"; do
    if printf '%s' "$command" \
        | grep -qE "RISK_BYPASS:[[:space:]]*${token}([^A-Za-z0-9_-]|\$)"; then
      return 0
    fi
  done
  return 1
}

# Detect whether the current staged set requires a README refresh that
# is not staged.
#
# $1 (optional) — the `git commit` command string. Inspected for a
#   registered RISK_BYPASS trailer (P265). Empty/absent → no trailer
#   bypass (fail-safe; preserves pre-P265 behaviour for any caller that
#   does not thread the command through).
#
# Echoes the offending ticket path on stdout when detected.
#
# Returns:
#   0 — no change required, BYPASS env set, a registered RISK_BYPASS
#       trailer is present, or fail-open (allow)
#   1 — ticket change staged + README not staged (caller should deny)
detect_readme_refresh_required() {
  local command="${1:-}"

  # Bypass via env var — single most-common legitimate escape.
  if [ "${BYPASS_README_REFRESH_GATE:-}" = "1" ]; then
    return 0
  fi

  # Bypass via registered RISK_BYPASS commit-message trailer (P265).
  # The ADR-031 layout-migration commit is a rename-only change that
  # legitimately stages no README refresh; its `RISK_BYPASS:
  # adr-031-migration` trailer carries the policy authorisation
  # (ADR-031 § Backward Compatibility + ADR-013 Rule 6).
  if _readme_refresh_command_has_bypass_trailer "$command"; then
    return 0
  fi

  # Fail-open if not inside a git working tree.
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local staged
  staged=$(git diff --staged --name-only 2>/dev/null) || return 0

  # No staged paths — nothing to gate.
  [ -n "$staged" ] || return 0

  local has_readme=0
  local offending_ticket=""
  local path basename
  local staged_tickets=()

  while IFS= read -r path; do
    [ -n "$path" ] || continue

    case "$path" in
      docs/problems/README.md)
        has_readme=1
        ;;
      docs/problems/README-history.md)
        # Rotated history file — not a ticket, not the load-bearing
        # README. Ignored.
        ;;
      docs/problems/open/*.md \
      | docs/problems/verifying/*.md \
      | docs/problems/closed/*.md \
      | docs/problems/known-error/*.md \
      | docs/problems/parked/*.md)
        # New state-directory layout (ADR-031). Filename must start
        # with digits to be a ticket file — exclude any future
        # state-directory-local README or similar.
        basename="${path##*/}"
        case "$basename" in
          [0-9]*.md)
            [ -z "$offending_ticket" ] && offending_ticket="$path"
            staged_tickets+=("$path")
            ;;
        esac
        ;;
      docs/problems/[0-9]*.md)
        # Legacy flat layout: docs/problems/NNN-*.<state>.md.
        # Excludes README.md and README-history.md (already cased
        # above; both start with `R`, not a digit).
        [ -z "$offending_ticket" ] && offending_ticket="$path"
        staged_tickets+=("$path")
        ;;
      *)
        # Non-ticket surface: ignored.
        ;;
    esac
  done <<EOF
$staged
EOF

  # No staged ticket — nothing to gate.
  [ -n "$offending_ticket" ] || return 0

  # README staged alongside — clean.
  [ "$has_readme" -eq 1 ] && return 0

  # P230 narrative-only short-circuit. Detect whether the staged ticket
  # set is purely narrative (no ranking-bearing field change, no rename
  # between state subdirs, no creation/deletion). If so, consult
  # reconcile-readme.sh as the authoritative drift oracle; exit=0 means
  # the README is in sync with filesystem truth and narrative-only
  # ticket edits are safe to allow silently.
  if ! _readme_refresh_staged_is_ranking_bearing "${staged_tickets[@]}"; then
    if _readme_refresh_reconcile_clean; then
      return 0
    fi
  fi

  # Either ranking-bearing, or narrative-only with reconcile drift —
  # fall through to deny.
  printf '%s\n' "$offending_ticket"
  return 1
}

# Returns 0 if any staged ticket exhibits a ranking-bearing change:
#   - field-line diff matching ^[+-]**(Priority|Effort|Status|WSJF|Type)**:
#   - title-line diff matching ^[+-]# Problem
#   - new ticket file added (A entry on a ticket path)
#   - ticket file deleted (D entry on a ticket path)
#   - rename between state subdirs (R<NN> entry where either path is a
#     ticket path)
# Returns 1 if narrative-only.
_readme_refresh_staged_is_ranking_bearing() {
  local tickets=("$@")
  [ "${#tickets[@]}" -gt 0 ] || return 1

  # (i) Field-line / title-line diff
  if git diff --staged -- "${tickets[@]}" 2>/dev/null \
      | grep -qE '^[+-](\*\*(Priority|Effort|Status|WSJF|Type)\*\*:|# Problem )'; then
    return 0
  fi

  # (ii) Creation / deletion / rename via --name-status -M
  local namestatus
  namestatus=$(git diff --staged --name-status -M 2>/dev/null) || return 1

  local ticket_re='^docs/problems/(open|verifying|closed|known-error|parked)/[0-9].*\.md$'
  local legacy_re='^docs/problems/[0-9].*\.md$'

  while IFS=$'\t' read -r status p1 p2; do
    [ -n "$status" ] || continue
    case "$status" in
      A|D)
        if [[ "$p1" =~ $ticket_re ]] || [[ "$p1" =~ $legacy_re ]]; then
          return 0
        fi
        ;;
      R*)
        if [[ "$p1" =~ $ticket_re ]] || [[ "$p1" =~ $legacy_re ]] \
           || [[ "$p2" =~ $ticket_re ]] || [[ "$p2" =~ $legacy_re ]]; then
          return 0
        fi
        ;;
    esac
  done <<EOF
$namestatus
EOF

  return 1
}

# Returns 0 if reconcile-readme.sh reports the README is in sync with
# filesystem truth (exit=0), 1 otherwise (drift, parse error, or script
# not located).
_readme_refresh_reconcile_clean() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return 1
  local reconcile="$lib_dir/../../scripts/reconcile-readme.sh"
  [ -f "$reconcile" ] || return 1
  bash "$reconcile" "docs/problems" >/dev/null 2>&1
}
