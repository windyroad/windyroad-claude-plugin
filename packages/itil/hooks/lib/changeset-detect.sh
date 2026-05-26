#!/bin/bash
# P141: shared changeset-discipline detection helper.
#
# `detect_changeset_required` returns 0 (no change required — allow) /
# 1 (changeset required but not staged — caller should deny). On 1, the
# offending plugin slug is echoed on stdout so callers can name it in
# deny messages without re-parsing diff output.
#
# Trap shape (P141):
#   `/wr-itil:work-problems` AFK iter subprocesses receive prompt-time
#   guidance to author a `.changeset/*.md` whenever they ship a
#   `packages/<plugin>/` change. Under context pressure (heavy SKILL.md
#   + ticket body + architect/JTBD prompt content) the reminder is
#   sometimes dropped — observed at 40% miss rate across 5 publishable
#   iters in the 2026-04-28 evidence session. Hook-level detection at
#   `git commit` time replaces the unreliable prompt-time signal.
#
# Detection logic:
#   - `git diff --staged --name-only` enumerates staged paths.
#   - Categorise each path:
#       * `.changeset/<name>.md` (excluding `README.md`) — counts as
#         a valid changeset.
#       * `packages/<slug>/...` — examined further:
#           - allow-list: `test/*`, `hooks/test/*`, `scripts/test/*`
#             (test code; no publishable behaviour change).
#           - allow-list: `README.md`.
#           - allow-list: `docs/<anything>.md` (per architect verdict
#             2026-05-02 — `*.md` under `docs/` only; SKILL.md is the
#             publishable contract per ADR-037 framing and is NOT in
#             the allow-list).
#           - otherwise: publishable source — record the slug.
#       * any other path: ignored (non-publishable surface — `.github/`,
#         root config, top-level `docs/`, etc.).
#   - If any path is publishable source AND no valid changeset is
#     staged, return 1 + echo the slug.
#
# Bypass:
#   - `BYPASS_CHANGESET_GATE=1` env var → return 0 (allow). For
#     legitimate non-publishable commits (e.g. CI-only changes
#     bundled with a small source tweak the agent has decided not
#     to release). Audit-traceable via shell history.
#
# Fail-open contract:
#   - Outside a git working tree, or when `git diff` fails for any
#     reason (parse error, broken index, permissions), return 0
#     (allow). Mirrors `lib/staging-detect.sh`'s exit-0 fallback —
#     a hook that fails-closed on hostile environments would block
#     legitimate commits in non-git contexts (e.g. agent-driven
#     scripts that happen to mention `git commit` in unrelated
#     contexts).
#
# Cost: one `git diff` invocation per check (~10ms on this repo's
# working tree). Per-invocation deterministic — runs on every
# `git commit` invocation rather than relying on per-tool-call
# session state tracking. Mirrors the P125 `staging-detect.sh`
# precedent (architect-approved no-marker design).
#
# References:
#   ADR-005  — plugin testing strategy (hook bats live under
#              `hooks/test/` per P081 behavioural-test discipline).
#   ADR-013 Rule 1 — deny redirects with mechanical recovery (the deny
#              text names the plugin slug + the literal `bun run
#              changeset` command + the BYPASS env var override).
#   ADR-014  — governance skills commit their own work (this hook
#              ensures iter commits stay self-contained per
#              ADR-014 single-commit grain).
#   ADR-018  — inter-iteration release cadence (this hook strengthens
#              the cadence by ensuring every publishable iter has a
#              changeset to drain at release time).
#   ADR-038  — progressive disclosure / deny-message terseness.
#   ADR-045  — hook injection budget (Pattern 1 silent-on-pass; deny
#              band ≤300 bytes for this hook).
#   P073     — sibling changeset author-time gate (different surface:
#              Write/Edit on `.changeset/*.md`). Composes-with as
#              defence-in-depth.
#   P125     — sibling staging-trap helper (same enforcement-layer
#              shape — per-invocation deterministic, no markers).
#   P141     — this helper.

# Detect whether the current staged set requires a changeset that is
# not staged.
#
# Echoes the offending plugin slug on stdout when detected.
#
# Returns:
#   0 — no change required, or BYPASS env set, or fail-open (allow)
#   1 — change required + no changeset staged (caller should deny)
detect_changeset_required() {
  # Bypass via env var — single most-common legitimate escape.
  if [ "${BYPASS_CHANGESET_GATE:-}" = "1" ]; then
    return 0
  fi

  # Fail-open if not inside a git working tree.
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local staged
  staged=$(git diff --staged --name-only 2>/dev/null) || return 0

  # No staged paths — nothing to gate.
  [ -n "$staged" ] || return 0

  local has_changeset=0
  local plugin_source_slug=""
  local path rest slug subpath

  while IFS= read -r path; do
    [ -n "$path" ] || continue

    case "$path" in
      .changeset/README.md)
        # README in changeset dir is meta-doc, not a real changeset.
        ;;
      .changeset/*.md)
        has_changeset=1
        ;;
      docs/changesets-holding/README.md)
        # README in the holding dir is meta-doc, not a real changeset
        # (mirrors the .changeset/README.md exclusion above).
        ;;
      docs/changesets-holding/*.md)
        # P177: a held-window changeset entry IS a changeset — authored
        # and audit-trailed, just intentionally held outside `.changeset/`
        # per ADR-042 Rule 7 (held-window blessing). Recognising it here
        # gives the gate a held-window-awareness branch so held-window-
        # bound work commits no longer need a separate move-to-holding
        # chore commit. Release/drain semantics are unchanged — the
        # Release workflow reads `.changeset/` only; a held entry is never
        # drained without a graduation `git mv` back into `.changeset/`.
        has_changeset=1
        ;;
      packages/*)
        rest="${path#packages/}"
        slug="${rest%%/*}"
        # When the path has no further segments (e.g. `packages/foo`),
        # ${rest#*/} returns rest unchanged — defensive subpath fallback.
        if [ "$rest" = "$slug" ]; then
          subpath="$rest"
        else
          subpath="${rest#*/}"
        fi

        # Allow-list: test paths.
        case "$subpath" in
          test/*|hooks/test/*|scripts/test/*) continue ;;
        esac

        # Allow-list: package README.
        case "$subpath" in
          README.md) continue ;;
        esac

        # Allow-list: *.md under docs/ (any nesting depth).
        case "$subpath" in
          docs/*)
            case "$subpath" in
              *.md) continue ;;
            esac
            ;;
        esac

        # Anything else under packages/<slug>/ is publishable source.
        plugin_source_slug="$slug"
        ;;
      *)
        # Non-packages/ path: always allow.
        ;;
    esac
  done <<EOF
$staged
EOF

  if [ -n "$plugin_source_slug" ] && [ "$has_changeset" -eq 0 ]; then
    printf '%s\n' "$plugin_source_slug"
    return 1
  fi

  return 0
}
