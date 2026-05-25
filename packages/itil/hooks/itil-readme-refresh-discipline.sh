#!/bin/bash
# P165: PreToolUse:Bash hook — denies `git commit` invocations whose
# staged set includes a `docs/problems/<state>/NNN-*.md` ticket change
# but does NOT also stage a `docs/problems/README.md` refresh. Hook-
# level enforcement replaces the declarative-only P094 / P062 contract
# in manage-problem SKILL.md Step 5 / Step 7 — iter subprocess commits
# previously could ship a `.verifying.md` rename or Status edit without
# the corresponding Verification Queue / WSJF Rankings row update in
# the README, leaving README staleness for the next iter or
# `/wr-itil:reconcile-readme` to recover.
#
# Detection delegates to `lib/readme-refresh-detect.sh::detect_readme_refresh_required`.
# When the helper returns 1, this hook emits PreToolUse deny JSON with
# the offending ticket path inline and the literal `git add
# docs/problems/README.md` recovery command, satisfying ADR-013
# Rule 1's "deny redirects to a recovery path" contract via the
# mechanical-recovery shape (no skill wrapper required — staging the
# README is a single command).
#
# Allow paths (exit 0 silently per ADR-045 Pattern 1):
#   - tool_name != "Bash"               (only Bash invocations are gated)
#   - command does not invoke           (P268: leading-executable check
#     `git commit` as its leading-       via `lib/command-detect.sh`
#     effective command                  — replaces prior substring match
#                                        that misfired on grep/sed/cat
#                                        whose arguments contained the
#                                        literal phrase)
#   - staged set is README-discipline-  (helper returns 0)
#     clean
#   - BYPASS_README_REFRESH_GATE=1 env  (helper returns 0 first)
#   - outside a git work tree           (helper fails-open)
#   - parse failure on stdin            (mirrors create-gate.sh fail-open)
#
# References:
#   ADR-005 — plugin testing strategy (hook bats live under hooks/test/).
#   ADR-009 — gate marker lifecycle (this hook deliberately does NOT
#             use markers; detection is per-invocation deterministic
#             — same precedent as P125 + P141).
#   ADR-013 Rule 1 — deny redirects with mechanical recovery.
#   ADR-014 — single-commit grain (the contract this hook enforces).
#   ADR-022 — `.verifying.md` lifecycle status.
#   ADR-038 — progressive disclosure / deny-message terseness budget.
#   ADR-045 — hook injection budget (Pattern 1 silent-on-pass; deny
#             band ≤300 bytes for this hook).
#   P062    — parent (README refresh on transition contract).
#   P094    — parent (README refresh on creation contract).
#   P118    — sibling reconcile-readme recovery path.
#   P125    — sibling staging-trap hook (same enforcement-layer shape).
#   P141    — sibling changeset-discipline hook (same shape).
#   P165    — this hook.
#   P268    — leading-executable-token command-detect helper.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/readme-refresh-detect.sh
source "$SCRIPT_DIR/lib/readme-refresh-detect.sh"
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
# is literally `git commit`. P268: replaced the prior substring match
# `*"git commit"*` that misfired on non-commit Bash whose argument
# vectors merely mentioned the phrase (grep/sed/cat-heredoc/echo).
command_invokes_git_commit "$COMMAND" || exit 0

# Run detection. Helper echoes offending ticket path on stdout when
# detected; returns 1 in that case. Returns 0 (allow) on no-trap,
# bypass env, a registered RISK_BYPASS commit-message trailer (P265 —
# `$COMMAND` is threaded in so the helper can inspect the trailer), or
# fail-open (non-git tree, parse error).
TRAPPED_TICKET=$(detect_readme_refresh_required "$COMMAND" 2>/dev/null) && exit 0

# Extract the leading ticket-ID digits from the basename so the deny
# names the ticket as `P<NNN>` rather than the full descriptive path
# (problem tickets carry long slugs; embedding the full path can
# exceed ADR-045 deny-band 300 bytes). `git status` reveals the exact
# staged path for recovery; the deny only needs to name the ticket
# distinctly.
BASENAME="${TRAPPED_TICKET##*/}"
TICKET_NUM="${BASENAME%%-*}"
case "$TICKET_NUM" in
  ''|*[!0-9]*) TICKET_ID="(staged ticket)" ;;
  *) TICKET_ID="P${TICKET_NUM}" ;;
esac

# Trap detected — emit deny with terse recovery.
# Voice-tone budget per ADR-045 deny-band ≤300 bytes total. Names the
# offending ticket ID, the literal recovery command, the BYPASS env
# var escape with correct propagation syntax (P231 / P173), and the
# P165 cite. Inline-prefix `VAR=1 git commit ...` does NOT propagate
# from a Bash subshell to PreToolUse hooks; the env field of
# `.claude/settings.json` (or shell `export` before `claude` launch)
# is the working path.
REASON="BLOCKED: P165. ${TICKET_ID} needs README refresh: git add docs/problems/README.md. Bypass: BYPASS_README_REFRESH_GATE=1 via .claude/settings.json env (P173)."

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
