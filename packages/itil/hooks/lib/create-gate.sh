#!/bin/bash
# Shared gate logic for new-ticket creation enforcement (P119).
#
# Sourced by manage-problem-enforce-create.sh. Provides:
#   check_create_gate     — returns 0 if Step 2 marker present (allow), 1 if absent (deny)
#   create_gate_deny      — emits PreToolUse deny JSON
#   create_gate_parse_err — emits parse-error fallback (exit 0, no deny)
#
# Why a separate helper from lib/review-gate.sh:
# review-gate.sh enforces a per-session "policy was reviewed" marker with
# TTL + drift detection (the policy file's hash is stored alongside the
# marker; mismatch invalidates the gate). The Step-2 grep marker has
# different semantics — it records "this session has run the duplicate
# check at least once" — and has neither a policy file nor drift-relevant
# state. Per architect approval (P119): keep review-gate.sh untouched and
# add a sibling helper rather than overload review-gate semantics.
#
# Marker convention: /tmp/manage-problem-grep-${SESSION_ID}
#
# Per-session scope is intentional (per architect direction A): a single
# /wr-itil:manage-problem invocation may write multiple tickets (Step 4b
# multi-concern split writes 2-N consecutive .open.md files); per-grep
# scope would block split-create after the first Write.
#
# References:
#   ADR-009 — gate marker lifecycle (covers session-scoped /tmp markers).
#   ADR-038 — progressive disclosure (deny message stays terse + actionable).
#   ADR-013 Rule 1 — deny redirects to /wr-itil:manage-problem where
#                    Step 2 fires AskUserQuestion if duplicates exist.
#
# Empty SESSION_ID fallback: returns 1 (no marker) — fail-closed by
# default. Hook callers may treat empty session_id as parse failure
# and exit 0 without deny (parity with jtbd-enforce-edit.sh).

# Returns 0 if the Step 2 grep marker exists for SESSION_ID; 1 otherwise.
# Empty SESSION_ID => returns 1 (no marker).
#
# Usage: if check_create_gate "$SESSION_ID"; then exit 0; fi
check_create_gate() {
  local SESSION_ID="$1"
  [ -n "$SESSION_ID" ] || return 1
  [ -f "/tmp/manage-problem-grep-${SESSION_ID}" ]
}

# Writes the Step 2 grep marker for SESSION_ID. Empty SESSION_ID => no-op.
# Idempotent — safe to call more than once per session.
#
# Usage: mark_step2_complete "$SESSION_ID"
mark_step2_complete() {
  local SESSION_ID="$1"
  [ -n "$SESSION_ID" ] || return 0
  : > "/tmp/manage-problem-grep-${SESSION_ID}"
}

# Returns 0 if the RFC capture-step marker exists for SESSION_ID; 1 otherwise.
# Empty SESSION_ID => returns 1 (no marker).
#
# Sibling marker per architect verdict on capture-rfc sub-decision (a) —
# preserves audit-trail per-surface granularity (problem-tier vs RFC-tier
# capture). Marker name: /tmp/wr-itil-rfc-capture-grep-${SESSION_ID}.
#
# Usage: if check_rfc_capture_gate "$SESSION_ID"; then exit 0; fi
check_rfc_capture_gate() {
  local SESSION_ID="$1"
  [ -n "$SESSION_ID" ] || return 1
  [ -f "/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}" ]
}

# Writes the RFC capture-step marker for SESSION_ID. Empty SESSION_ID => no-op.
# Idempotent — safe to call more than once per session.
#
# Per ADR-060 + capture-rfc Step 2: the marker records that capture-rfc has
# run its problem-trace validation pass (the RFC-tier analogue of the
# manage-problem Step 2 duplicate-grep). Per-session scope so a single
# capture-rfc invocation may write multiple RFC files (e.g. multi-problem
# trace splits) without re-validating.
#
# Usage: mark_rfc_capture_complete "$SESSION_ID"
mark_rfc_capture_complete() {
  local SESSION_ID="$1"
  [ -n "$SESSION_ID" ] || return 0
  : > "/tmp/wr-itil-rfc-capture-grep-${SESSION_ID}"
}

# Emit fail-closed deny JSON for PreToolUse hooks.
# Usage: create_gate_deny "BLOCKED: <reason>"
create_gate_deny() {
  local REASON="$1"
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$REASON"
  }
}
EOF
}

# Emit fail-closed deny JSON for parse failures.
# Currently unused — empty session_id and empty file_path both exit 0
# without deny per parity with jtbd-enforce-edit.sh. Retained for
# symmetry with review-gate.sh in case a future caller wants strict mode.
create_gate_parse_error() {
  cat <<'EOF'
{ "hookSpecificOutput": { "hookEventName": "PreToolUse", "permissionDecision": "deny",
    "permissionDecisionReason": "BLOCKED: Could not parse hook input. Gate is fail-closed." } }
EOF
}
