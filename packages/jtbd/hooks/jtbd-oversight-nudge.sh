#!/usr/bin/env bash
# wr-jtbd — SessionStart hook (ADR-068)
#
# Surfaces a one-line nudge when jobs/personas lack the human-oversight marker,
# so the user can drain them via /wr-jtbd:confirm-jobs-and-personas. Sibling of
# packages/architect/hooks/architect-oversight-nudge.sh (ADR-066); same shape as
# the ADR-040 session-start surface.
#
# Detection is token-cheap: delegates to detect-unoversighted.sh (a grep over
# docs/jtbd/ frontmatter — no body reads, no per-file LLM call). Silent when the
# unoversighted count is zero (steady state once the set is drained).
#
# AFK self-suppress: shares the suite-wide WR_SUPPRESS_OVERSIGHT_NUDGE guard with
# the architect oversight nudge (ADR-068 § shared cross-plugin contracts). AFK
# orchestrators export it once (work-problems Step 5) and every oversight nudge
# self-suppresses — so this interactive batch-confirm nudge never fires into an
# absent-user subprocess (JTBD-006 friction guard). Only the literal "1" suppresses.

set -euo pipefail

if [ "${WR_SUPPRESS_OVERSIGHT_NUDGE:-}" = "1" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
JTBD_DIR="$PROJECT_DIR/docs/jtbd"

[ -d "$JTBD_DIR" ] || exit 0

DETECT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/detect-unoversighted.sh"
[ -x "$DETECT" ] || DETECT="$(dirname "$0")/../scripts/detect-unoversighted.sh"

COUNT="$(bash "$DETECT" "$JTBD_DIR" 2>/dev/null | grep -c . || true)"
COUNT="${COUNT:-0}"

[ "$COUNT" -gt 0 ] 2>/dev/null || exit 0

if [ "$COUNT" -eq 1 ]; then
  echo "[wr-jtbd] 1 job/persona lacks human oversight — run /wr-jtbd:confirm-jobs-and-personas to confirm it."
else
  echo "[wr-jtbd] $COUNT jobs/personas lack human oversight — run /wr-jtbd:confirm-jobs-and-personas to confirm them."
fi
