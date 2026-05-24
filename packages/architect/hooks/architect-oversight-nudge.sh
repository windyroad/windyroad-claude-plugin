#!/usr/bin/env bash
# wr-architect — SessionStart hook (ADR-066)
#
# Surfaces a one-line nudge when recorded decisions (ADRs) lack the
# human-oversight marker, so the user can drain them via
# /wr-architect:review-decisions. Modelled on the ADR-040 session-start
# briefing surface and packages/itil/hooks/itil-pending-questions-surface.sh.
#
# Detection is token-cheap: it delegates to detect-unoversighted.sh (a grep
# over ADR frontmatter — no body reads, no per-ADR LLM call). Silent when the
# unoversighted count is zero (steady state once the set is drained).
#
# AFK self-suppress (JTBD-006 friction guard): AFK orchestrators set
# WR_SUPPRESS_OVERSIGHT_NUDGE=1 before spawning each `claude -p` iteration so
# this interactive batch-confirm nudge never fires into an absent-user
# subprocess (the same discipline itil-pending-questions-surface.sh applies
# with WR_SUPPRESS_PENDING_QUESTIONS). Only the literal "1" suppresses.

set -euo pipefail

if [ "${WR_SUPPRESS_OVERSIGHT_NUDGE:-}" = "1" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
DECISIONS_DIR="$PROJECT_DIR/docs/decisions"

# Silent when this project has no decision records.
[ -d "$DECISIONS_DIR" ] || exit 0

DETECT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/detect-unoversighted.sh"
[ -x "$DETECT" ] || DETECT="$(dirname "$0")/../scripts/detect-unoversighted.sh"

# Count unoversighted ADRs. `grep -c .` counts non-empty lines; tolerate the
# detector printing nothing (count 0).
COUNT="$(bash "$DETECT" "$DECISIONS_DIR" 2>/dev/null | grep -c . || true)"
COUNT="${COUNT:-0}"

# Silent-on-no-content per ADR-040 Mechanism step 1.
[ "$COUNT" -gt 0 ] 2>/dev/null || exit 0

if [ "$COUNT" -eq 1 ]; then
  echo "[wr-architect] 1 recorded decision lacks human oversight — run /wr-architect:review-decisions to confirm it."
else
  echo "[wr-architect] $COUNT recorded decisions lack human oversight — run /wr-architect:review-decisions to confirm them."
fi
