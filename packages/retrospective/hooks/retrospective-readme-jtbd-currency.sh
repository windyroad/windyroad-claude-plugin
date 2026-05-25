#!/bin/bash
# ADR-069 (P294): PreToolUse:Bash hook — denies `git commit` invocations
# whose post-commit working tree exhibits skill-inventory drift in any
# packages/<plugin>/README.md (a directory under packages/<plugin>/skills/
# is not named in the README).
#
# HISTORY: this hook formerly (P159, under superseded ADR-051) also gated on
# JTBD-ID-citation drift (no JTBD-NNN anchor, stale/deprecated citation).
# ADR-069 superseded ADR-051: plugin READMEs market the persona's problem
# derived FROM the JTBD but MUST NOT cite JTBD IDs. The JTBD-ID anchor + its
# docs/jtbd/ resolution are removed; the mechanical skill-inventory-drift
# signal (ADR-051's original P152 empirical core) survives as the load-
# bearing currency gate. Filename retained deliberately per ADR-069.
#
# Hook-level enforcement at commit time (vs retro-time advisory) is retained
# per the carried-forward load-bearing-from-the-start-for-drift-class driver:
# the most-common drift class (contributor adds a skill and forgets the
# README) ships in a commit that does not touch README.md, so a retro-time
# consumer sees the drift only after the contributor has already committed.
#
# Detection delegates to the detector script
# (`packages/retrospective/scripts/check-readme-jtbd-currency.sh`),
# invoked against the project's working tree (`./packages/`). The hook reads
# the detector's `TOTAL packages=<N> drift_instances=<K>` summary and denies
# when `drift_instances > 0`.
#
# Allow paths (exit 0 silently per ADR-045 Pattern 1):
#   - tool_name != "Bash"            (only Bash invocations are gated)
#   - command does not contain      `git commit` substring (non-commit
#                                   Bash bypasses entirely — `git
#                                   status`, `git log`, etc.)
#   - BYPASS_JTBD_CURRENCY=1         (single-most-common legitimate
#                                   escape — bypass-traceable via
#                                   shell history)
#   - outside a git work tree        (adopter sessions outside the
#                                   plugin monorepo)
#   - no `./packages/` directory     (project does not have ADR-051's
#                                   structural anchor — adopter
#                                   project shape; gate is a no-op)
#   - no `./docs/jtbd/` directory    (project has not run
#                                   /wr-jtbd:update-guide; gate is a
#                                   no-op)
#   - detector exits non-zero        (parse error / hostile env;
#                                   fail-open per ADR-013 Rule 6)
#   - detector emits no TOTAL line   (no packages found; nothing to
#                                   gate)
#   - drift_instances == 0           (clean tree)
#
# Deny shape (per ADR-013 Rule 1 — deny redirects with mechanical
# recovery; ADR-045 deny-band ≤300 bytes):
#   - Names the first offending plugin slug + drift hint vocabulary.
#   - Names the wr-jtbd:agent recovery path AND the hand-edit fallback
#     (graceful degradation when @windyroad/jtbd is not installed).
#   - Names BYPASS_JTBD_CURRENCY=1 as the env-var escape.
#   - Cites P159 for traceability.
#   - Truncates the drift_hints CSV to the first hint to keep the
#     deny-band ≤300 bytes for worst-case slug + hint combinations.
#
# Cost: one invocation of `check-readme-jtbd-currency.sh` per `git
# commit` (~80–150ms in the worst case across 12 plugin READMEs +
# ~30 JTBD job files; per the architect's ADR-023 perf review at
# Phase 1 design time). Per-invocation deterministic; no marker
# (mirrors P125 `staging-detect.sh` and P141
# `itil-changeset-discipline.sh` precedent — architect-approved
# no-marker design when detection cost stays under ~150ms).
#
# References:
#   ADR-005 — plugin testing strategy (hook bats live under
#             `packages/<plugin>/hooks/test/`).
#   ADR-013 Rule 1 — deny redirects with mechanical recovery (the
#             deny names the wr-jtbd:agent recovery, the hand-edit
#             fallback, and the BYPASS env override).
#   ADR-013 Rule 6 — non-interactive fail-safe (fail-open outside a
#             git work tree, on parse error, in projects lacking
#             ADR-051 anchors, and on detector failure).
#   ADR-014 — governance skills commit their own work (this hook
#             keeps iter commits self-contained).
#   ADR-018 — inter-iteration release cadence (the hook strengthens
#             release-cadence integrity by ensuring every publishable
#             iter has a current README before commit).
#   ADR-038 — progressive disclosure / deny-message terseness budget.
#   ADR-045 — hook injection budget (Pattern 1 silent-on-pass; deny
#             band ≤300 bytes for this hook).
#   ADR-051 — JTBD-anchored README rule (this hook is the load-
#             bearing-from-the-start commit-gate surface; supersedes
#             retro-time advisory consumption as primary).
#   ADR-052 — behavioural-tests default (bats fixture asserts on
#             emitted JSON, not source content).
#   ADR-017 — shared-code sync pattern (command-detect.sh canonical at
#             packages/shared/hooks/lib/; synced into per-package
#             hooks/lib/ via scripts/sync-command-detect.sh).
#   P081 — behavioural tests preferred over structural greps.
#   P125 — sibling staging-trap helper (per-invocation no-marker).
#   P141 — sibling changeset-discipline gate on `git commit` (same
#             hook shape).
#   P158 — retro Step 2b wiring (backup advisory; survives this
#             hook's primary-surface migration).
#   P159 — this hook.
#   P268 — shared `command_invokes_git_commit` helper landed in
#             packages/shared/hooks/lib/command-detect.sh.
#   P275 — sibling-hook refactor: substring-match → helper here
#             (first cross-package consumer of the shared helper).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECTOR="$SCRIPT_DIR/../scripts/check-readme-jtbd-currency.sh"
# shellcheck source=lib/command-detect.sh
source "$SCRIPT_DIR/lib/command-detect.sh"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Only gate Bash. Non-Bash tools bypass entirely.
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null || echo "")

# Only fire on actual `git commit` invocations. P275: delegates to the
# shared `command_invokes_git_commit` helper for leading-executable
# semantics (was substring match prone to grep/sed/echo false positives).
command_invokes_git_commit "$COMMAND" || exit 0

# Bypass via env var — single most-common legitimate escape.
if [ "${BYPASS_JTBD_CURRENCY:-}" = "1" ]; then
  exit 0
fi

# Fail-open if not inside a git working tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Fail-open if the project lacks the structural anchor (`./packages/`).
# Adopter projects without `./packages/` are not subject to the rule; the
# hook is a no-op for them. (ADR-069: the `./docs/jtbd/` guard is removed —
# skill-inventory drift does not consult docs/jtbd/.)
[ -d "./packages" ] || exit 0

# Fail-open if the detector script itself is missing (defensive —
# hook + detector ship together, but install-time corruption or
# adopter-side patching should not block legitimate commits).
[ -x "$DETECTOR" ] || exit 0

# Run the detector. Capture exit code + output. Fail-open on detector
# error (exit != 0).
DETECTOR_OUTPUT=$(bash "$DETECTOR" "./packages" 2>/dev/null) || exit 0

# Parse the TOTAL summary line. If absent, no packages were
# enumerated — fail-open (no drift to report).
TOTAL_LINE=$(echo "$DETECTOR_OUTPUT" | grep -E '^TOTAL packages=' | tail -n1)
[ -n "$TOTAL_LINE" ] || exit 0

# Extract drift_instances=<K>.
DRIFT_INSTANCES=$(echo "$TOTAL_LINE" | grep -oE 'drift_instances=[0-9]+' | head -n1 | cut -d'=' -f2)
[ -n "$DRIFT_INSTANCES" ] || exit 0

# Allow path: clean tree.
if [ "$DRIFT_INSTANCES" -eq 0 ]; then
  exit 0
fi

# Drift detected — extract first offending package + its drift hints
# for the deny message. The detector emits one "README package=<name>
# ... drift_hints=<csv>" line per package; we name the first one with
# a non-empty drift_hints.
OFFENDING_LINE=$(echo "$DETECTOR_OUTPUT" | grep -E '^README package=' | grep -vE 'drift_hints=$' | head -n1)
OFFENDING_SLUG=$(echo "$OFFENDING_LINE" | grep -oE 'package=[A-Za-z0-9_-]+' | head -n1 | cut -d'=' -f2)
OFFENDING_HINTS=$(echo "$OFFENDING_LINE" | grep -oE 'drift_hints=[A-Za-z0-9,_-]+' | head -n1 | cut -d'=' -f2)

# Fall back to a generic name if parsing failed (shouldn't happen but
# defensive).
[ -n "$OFFENDING_SLUG" ] || OFFENDING_SLUG="(unknown)"
[ -n "$OFFENDING_HINTS" ] || OFFENDING_HINTS="drift"

# Truncate the hints CSV to the first hint. Multi-hint cases (e.g.
# both `missing-jtbd-section` and `skill-inventory-drift` on one
# package) are bounded so the deny-band stays under 300 bytes for
# worst-case slug + hint combinations.
PRIMARY_HINT="${OFFENDING_HINTS%%,*}"

# Deny — voice/tone budget per ADR-045 deny-band ≤300 bytes total
# (envelope ~137 bytes; REASON ~145 bytes for worst-case slug + the
# single inventory hint). Names the offending plugin slug, the drift
# hint, the in-flight mechanical recovery (name the skill in the README
# — NOT a JTBD-ID citation per ADR-069), and the P294 cite. P173: the
# deny no longer advertises BYPASS_JTBD_CURRENCY=1 as an in-flight escape
# — that env var only takes effect when set in Claude Code's process env
# BEFORE the session started; a mid-session Bash export never reaches the
# hook. The deny states the bypass is pre-session-only.
REASON="BLOCKED: P294 README inventory drift in ${OFFENDING_SLUG} (${PRIMARY_HINT}). Recovery: name the skill in the README. Env bypass is pre-session only."

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${REASON}"
  }
}
EOF
exit 0
