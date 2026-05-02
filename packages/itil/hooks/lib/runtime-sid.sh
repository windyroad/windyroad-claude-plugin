#!/bin/bash
# P142 (P124 Phase 4): runtime-SID marker path helper.
#
# Computes the per-machine, per-user, per-project marker path that the
# `itil-runtime-sid-marker.sh` PreToolUse hook writes the runtime
# `session_id` to (parsed from hook stdin JSON) and that
# `get_current_session_id` reads as the authoritative current-session
# identifier. Both producer (hook) and consumer (helper) source this
# lib so they agree on the path.
#
# Why this exists:
#   The Phase 3 helper relied on within-system mtime selection across
#   ADR-038 announce markers. In orchestrator main turns AFTER subprocess
#   dispatch, subprocess announce markers had NEWER mtimes than the
#   orchestrator's, so newest-mtime-wins picked the wrong UUID. No pure-
#   helper algorithm can disambiguate orchestrator vs subprocess context
#   from filesystem state alone (P142 ticket Investigation Tasks). The
#   structural fix is to capture the runtime stdin SID — known with
#   certainty by the hook on every tool call — into a discoverable file
#   the helper can read. See ADR-050.
#
# Path scoping:
#   When SESSION_MARKER_DIR is set (sandboxed bats per session-id.bats
#   convention), the marker lives at "${SESSION_MARKER_DIR}/itil-runtime-sid.current"
#   — a single fixed filename, no per-user/per-project scoping. Tests
#   create and tear down their own SANDBOX_TMP, so cross-test pollution
#   is impossible without further scoping.
#
#   In production (no SESSION_MARKER_DIR), the path is
#   "/tmp/itil-runtime-sid-${USER}-${proj_hash}.current" where
#   proj_hash = cksum of $PWD. Two Claude Code sessions in DIFFERENT
#   projects do not race (different proj_hash). Two sessions in the
#   SAME project on the same machine still race; per ADR-050 this is
#   accepted as a documented limitation — the failure mode is a hook-
#   denied Write that the agent can recover from, not silent corruption.
#
# References:
#   ADR-050 — runtime-SID instrumentation via PreToolUse (this surface).
#   ADR-048 — gate-misfire recovery procedure (superseded by ADR-050 +
#             P142 + this lib).
#   ADR-038 — announce-marker contract (cold-path fallback consumer).
#   ADR-009 — gate marker lifecycle.
#   P142    — this fix's ticket.

# Echoes the runtime-SID marker path on stdout. Always exits 0.
#
# Usage:
#   source packages/itil/hooks/lib/runtime-sid.sh
#   path=$(runtime_sid_path)
runtime_sid_path() {
  if [ -n "${SESSION_MARKER_DIR:-}" ]; then
    echo "${SESSION_MARKER_DIR}/itil-runtime-sid.current"
    return 0
  fi
  local user="${USER:-anon}"
  local proj_hash
  # cksum is POSIX; portable across macOS BSD and Linux GNU.
  # Trailing whitespace stripped via awk; first field is the checksum.
  proj_hash=$(printf '%s' "${PWD:-/}" | cksum 2>/dev/null | awk '{print $1}')
  echo "/tmp/itil-runtime-sid-${user}-${proj_hash:-0}.current"
}
