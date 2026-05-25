#!/bin/bash
# P141: PreToolUse:Bash hook — denies `git commit` invocations whose
# staged set includes `packages/<plugin>/` source files but no
# `.changeset/*.md` is staged. Hook-level enforcement replaces the
# unreliable iter-prompt-time changeset reminder (40% miss rate
# observed in 2026-04-28 AFK loop session — see ticket).
#
# Detection delegates to `lib/changeset-detect.sh::detect_changeset_required`.
# When the helper returns 1, this hook emits PreToolUse deny JSON
# with the offending plugin slug inline and the literal `bun run
# changeset` recovery command, satisfying ADR-013 Rule 1's "deny
# redirects to a recovery path" contract via the mechanical-recovery
# shape (no skill wrapper required — authoring a changeset is a
# single command).
#
# Command-shape detection delegates to
# `lib/command-detect.sh::command_invokes_git_commit`, which strips
# common prefix shapes (leading whitespace, env-var assignments,
# `cd <path> &&`) and checks whether the residual leading token pair
# is literally `git commit`. P272: replaced the prior substring match
# `*"git commit"*` that misfired on non-commit Bash whose argument
# vectors merely mentioned the phrase (grep / sed / cat-heredoc /
# echo / `git log --grep`).
#
# Allow paths (exit 0 silently per ADR-045 Pattern 1):
#   - tool_name != "Bash"            (only Bash invocations are gated)
#   - command is not a `git commit` invocation by leading-executable
#                                   semantics (helper returns 1)
#   - staged set is changeset-clean  (helper returns 0)
#   - BYPASS_CHANGESET_GATE=1 env    (helper returns 0 first)
#   - outside a git work tree        (helper fails-open)
#   - parse failure on stdin         (mirrors create-gate.sh fail-open)
#
# References:
#   ADR-005 — plugin testing strategy (hook bats live under hooks/test/).
#   ADR-009 — gate marker lifecycle (this hook deliberately does NOT
#             use markers; detection is per-invocation deterministic
#             — same precedent as P125 `p057-staging-trap-detect.sh`).
#   ADR-013 Rule 1 — deny redirects with mechanical recovery.
#   ADR-014 — governance skills commit their own work (the hook keeps
#             iter commits self-contained — no orchestrator-main-turn
#             back-fill needed).
#   ADR-018 — inter-iteration release cadence (the hook strengthens
#             release-cadence integrity by ensuring every publishable
#             iter has a changeset to drain).
#   ADR-038 — progressive disclosure / deny-message terseness budget.
#   ADR-045 — hook injection budget (Pattern 1 silent-on-pass; deny
#             band ≤300 bytes for this hook).
#   P073    — sibling changeset author-time gate (Write/Edit on
#             `.changeset/*.md`); composes-with as defence-in-depth.
#   P125    — sibling staging-trap hook (same enforcement-layer shape).
#   P141    — this hook.
#   P268    — shared `command_invokes_git_commit` helper landed for
#             `itil-readme-refresh-discipline.sh`; consumed here.
#   P272    — sibling-hook refactor: substring-match → helper here.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/changeset-detect.sh
source "$SCRIPT_DIR/lib/changeset-detect.sh"
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

# Only fire on actual `git commit` invocations. Delegates to
# `lib/command-detect.sh::command_invokes_git_commit`, which strips
# common prefix shapes (leading whitespace, env-var assignments,
# `cd <path> &&`) and checks whether the residual leading token pair
# is literally `git commit`. P272: replaced the prior substring match
# `*"git commit"*` that misfired on non-commit Bash whose argument
# vectors merely mentioned the phrase (grep / sed / cat-heredoc /
# echo / `git log --grep`).
command_invokes_git_commit "$COMMAND" || exit 0

# Run detection. Helper echoes offending plugin slug on stdout when
# detected; returns 1 in that case. Returns 0 (allow) on no-trap,
# bypass env, or fail-open (non-git tree, parse error).
TRAPPED_SLUG=$(detect_changeset_required 2>/dev/null) && exit 0

# Trap detected — emit deny with terse recovery.
# Voice-tone budget per ADR-045 deny-band ≤300 bytes total. Names the
# plugin slug, the literal in-flight recovery command (`bun run
# changeset` — staging ANY changeset satisfies the gate), and the P141
# cite. P173: the deny no longer advertises BYPASS_CHANGESET_GATE=1 as an
# in-flight escape — that env var only takes effect when set in Claude
# Code's process env BEFORE the session started; a mid-session Bash
# export/inline assignment never reaches the hook process. The deny
# states the bypass is pre-session-only so maintainers stop wasting a
# turn trying it mid-session (the original P173 cost).
REASON="BLOCKED: P141 changeset discipline. packages/${TRAPPED_SLUG}/ source needs .changeset/*.md. Recovery: bun run changeset. Env bypass is pre-session only."

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
