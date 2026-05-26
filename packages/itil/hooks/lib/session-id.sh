#!/bin/bash
# P124: agent-side session-ID discovery helper.
#
# `get_current_session_id` returns the canonical Claude Code session UUID
# for the current invocation, used by /wr-itil:manage-problem Step 2
# substep 7 to write the create-gate marker (`/tmp/manage-problem-grep-${SID}`)
# under the same SID the manage-problem-enforce-create.sh hook reads from
# its stdin JSON payload.
#
# Why this helper exists:
#   The agent's process does NOT export CLAUDE_SESSION_ID. The hook side
#   reads session_id from its stdin JSON payload (per the Claude Code
#   PreToolUse contract); the agent side has no equivalent surface, so
#   /wr-itil:manage-problem Step 2's prior fallback `${CLAUDE_SESSION_ID:-default}`
#   wrote the marker under "default" while the hook checked the real UUID.
#   Marker mismatch -> Write deny -> agent had to scrape an existing
#   announce marker filename ad-hoc to recover. P124.
#
# Discovery strategy (announce markers preferred over reviewed markers):
#   /tmp/${SYSTEM}-announced-${SESSION_ID} markers are write-once-per-session
#   per ADR-038 and are emitted on the FIRST UserPromptSubmit of every
#   session by every active plugin (architect, jtbd, tdd, style-guide,
#   voice-tone, itil-assistant-gate, itil-correction-detect). They have
#   no mtime sliding (unlike `-reviewed-` gate markers, which `touch`-refresh
#   on every gate check per ADR-009 sliding TTL + P111 subprocess refresh),
#   so the announce-marker UUID is the most reliable per-session signal
#   reachable from agent-side code without an env var.
#
# Why itil-local instead of packages/shared (cf. ADR-017):
#   The discovery direction is the OPPOSITE of ADR-038's announce helper —
#   ADR-038's session-marker.sh WRITES announce markers from hook side;
#   this helper READS them from agent side. Only manage-problem SKILL.md
#   needs agent-side discovery today (Step 2 substep 7), so the helper
#   is itil-local with read-only fallbacks across other plugins' marker
#   filenames (no write coupling, no sync obligation). If a second skill
#   adopts agent-side SID discovery, promote to packages/shared/ at that
#   point per ADR-017 shared-code-sync. Mirrors create-gate.sh's "Why a
#   separate helper from lib/review-gate.sh" precedent.
#
# Empty SESSION_ID fallback:
#   No env-var + no markers -> echo nothing, return 1. Callers MUST check
#   the return code; a marker-write under an empty SID would land at
#   /tmp/manage-problem-grep- which the hook never matches. Fail-closed.
#
# References:
#   ADR-038 — progressive disclosure / session-marker pattern (announce
#             markers, /tmp/${SYSTEM}-announced-${SESSION_ID} convention).
#   ADR-009 — gate marker lifecycle (covers /tmp marker conventions).
#   ADR-017 — shared-code-sync (consulted; itil-local is the right home today).
#   P119    — create-gate hook this discovery helper feeds.
#   P124    — this helper.
#
# Test override: SESSION_MARKER_DIR (defaults to /tmp) lets bats run
# under a sandboxed marker directory without polluting real session
# state in /tmp.

# Returns the canonical session UUID for the current invocation.
# Echoes the UUID on stdout. Exit 0 if discovered, 1 if not.
#
# Usage:
#   source packages/itil/hooks/lib/session-id.sh
#   sid=$(get_current_session_id) || { echo "no SID available" >&2; exit 1; }
get_current_session_id() {
  # Env-var fast path. CLAUDE_SESSION_ID is not exported in agent
  # contexts today, but if a future Claude Code release adds it,
  # this branch picks it up for free.
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    echo "$CLAUDE_SESSION_ID"
    return 0
  fi

  # P142 / ADR-050: runtime-SID marker. The PreToolUse hook
  # (itil-runtime-sid-marker.sh) writes the runtime stdin session_id
  # to a per-machine marker on EVERY tool call. The helper, running
  # inside a Bash tool call, reads the marker that the same Bash
  # tool call's PreToolUse hook just wrote — by construction the
  # current session's SID. This is the authoritative path; the
  # announce-marker fallback below is the cold-path (no PreToolUse
  # has fired yet in this session).
  local rt_lib_dir
  rt_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "${rt_lib_dir}/runtime-sid.sh" ]; then
    # shellcheck source=runtime-sid.sh
    source "${rt_lib_dir}/runtime-sid.sh"
    local rt_path rt_sid
    rt_path=$(runtime_sid_path)
    if [ -s "$rt_path" ]; then
      rt_sid=$(cat "$rt_path" 2>/dev/null)
      if [ -n "$rt_sid" ]; then
        echo "$rt_sid"
        return 0
      fi
    fi
  fi

  local marker_dir="${SESSION_MARKER_DIR:-/tmp}"

  # Marker-system priority order. Architect first because architect-
  # enforce-edit.sh fires on virtually every project edit and so its
  # announce marker is the most reliably present early in any session
  # touching this repo. JTBD second for the same reason on this project.
  # The remaining systems give graceful degradation if the higher-
  # priority hooks haven't yet announced (rare — UserPromptSubmit
  # announces fire on prompt 1).
  local systems=(
    architect
    jtbd
    tdd
    itil-assistant-gate
    itil-correction-detect
    style-guide
    voice-tone
  )

  local system marker
  for system in "${systems[@]}"; do
    # Two-axis selection:
    #   ACROSS systems — fixed priority order (architect first, then
    #     jtbd, ...). The outer for-loop encodes this. The first system
    #     with any present marker wins; later systems are not consulted.
    #   WITHIN a system — most-recent-mtime wins (`ls -t | head -1`).
    #     Multi-session developer machines accumulate one
    #     `${system}-announced-${SID}` marker per past session in /tmp;
    #     the live session's marker is by construction the most-recently-
    #     created one. P124 Phase 2 used first-glob-match (alphabetical),
    #     which returned the lexically-first stale UUID when /tmp had
    #     accumulated markers from prior sessions — observed regression
    #     2026-04-28 with 103 stale architect markers selecting the
    #     wrong UUID, denying the create-gate (P119).
    #
    # Why mtime is safe here even though Phase 1 architect rejected it:
    #   The Phase 1 rejection applied to `-reviewed-` markers, which
    #   `touch`-refresh on every gate check (ADR-009 sliding TTL +
    #   P111 subprocess refresh). Mtime on a `-reviewed-` marker is
    #   "last seen", not "first written" — selecting newest-mtime can
    #   surface a stale session whose marker was just touch-refreshed.
    #   `-announced-` markers are write-once-per-session per ADR-038
    #   (no `touch`-refresh, no TTL); their mtime IS the announcing
    #   session's first-prompt timestamp. Newest mtime within a single
    #   `-announced-` glob unambiguously identifies the live session.
    #
    # Portability: `ls -t` is POSIX (sort by modification time, newest
    # first). 2>/dev/null suppresses "no such file" when the glob
    # expands to nothing under both bash and zsh; head -1 gracefully
    # returns empty in that case.
    marker=$(ls -t "${marker_dir}/${system}-announced-"* 2>/dev/null | head -1)
    if [ -n "$marker" ]; then
      # Strip the prefix to recover the trailing UUID.
      basename "$marker" | sed "s/^${system}-announced-//"
      return 0
    fi
  done

  return 1
}

# P260 / ADR-050 Option C: bounded multi-UUID candidate enumeration.
#
# Echoes EVERY candidate session UUID — one per line, deduplicated — that
# the create-gate hook (manage-problem-enforce-create.sh) might read from
# the Write's stdin `session_id`. The create-gate marker-write
# (`mark_step2_complete_candidates`, lib/create-gate.sh) writes the marker
# under each, so whichever SID the hook reads, a matching marker provably
# exists.
#
# Why enumerate instead of picking one (get_current_session_id):
#   `/wr-itil:work-problems` Step 5 BACKGROUNDS the iter subprocess and runs
#   the orchestrator's poll loop in the main turn, so the orchestrator's
#   PreToolUse hooks fire CONCURRENTLY with the subprocess. Both sessions
#   write the same per-machine runtime-sid marker (same project => same
#   proj_hash), last-writer-wins. When the orchestrator captures a ticket
#   while the subprocess holds the runtime-sid, `get_current_session_id`
#   returns the SUBPROCESS SID, but the orchestrator's Write carries the
#   ORCHESTRATOR SID on its stdin — marker mismatch, create-gate deny (P260).
#   ADR-050 §Context establishes that no agent-side algorithm can PREDICT
#   the right single SID from filesystem state alone. Option C stops
#   predicting and writes under every recent candidate instead.
#
# Candidate set (each line is one UUID):
#   1. `get_current_session_id`'s pick (env-var > runtime-sid > announce-
#      marker priority). Emitting this FIRST guarantees the candidate set is
#      never a strict subset of the prior single-SID behaviour — Option C
#      only ADDS the concurrent-session SIDs.
#   2. Every announce-marker UUID across ALL systems whose marker mtime is
#      within the window (the concurrently-active sessions: orchestrator +
#      its running subprocess(es)). Announce markers are write-once-per-
#      session (ADR-038, no touch-refresh), so mtime is the announcing
#      session's first-prompt timestamp — a stable bound.
#
# Bounding (NOT a global fail-open):
#   The mtime window (SESSION_CANDIDATE_WINDOW_MINS, default 1440 = 24h)
#   bounds the enumeration against the P124 stale-marker pathology (103
#   accumulated UUIDs selecting the wrong SID). 24h comfortably covers any
#   realistic single AFK loop while excluding multi-day marker accumulation.
#   Extra markers under recently-stale UUIDs are HARMLESS — empty files; the
#   hook only matches the marker equal to the Write's stdin SID. The P119
#   audit invariant holds: every marker still records that THIS session ran
#   the duplicate-check grep (the marker is only written because Step 2's
#   grep provably ran this turn; widening WHICH SID files receive that proof
#   does not weaken the proof). A loop running >24h degrades gracefully to
#   the recoverable create-gate deny (status quo), not silent corruption.
#
# Test overrides: SESSION_MARKER_DIR (marker dir, default /tmp) +
# SESSION_CANDIDATE_WINDOW_MINS (window minutes, default 1440).
#
# Usage:
#   source packages/itil/hooks/lib/session-id.sh
#   source packages/itil/hooks/lib/create-gate.sh
#   get_candidate_session_ids | mark_step2_complete_candidates
get_candidate_session_ids() {
  local marker_dir="${SESSION_MARKER_DIR:-/tmp}"
  local window_mins="${SESSION_CANDIDATE_WINDOW_MINS:-1440}"
  {
    # Guaranteed member: the single-SID discovery's pick. Suppress its
    # non-zero exit (no-SID cold path) so the pipeline still emits the
    # enumerated candidates.
    get_current_session_id 2>/dev/null || true

    # Concurrent-session SIDs: every recent announce marker across all
    # systems, within the mtime window. `*-announced-*` is system-agnostic
    # (picks up any present or future announcing plugin). `-maxdepth 1` and
    # `-mmin -N` are portable across BSD (macOS) and GNU find. The sed strips
    # the leading path then the `<system>-announced-` prefix, leaving the
    # trailing UUID (UUIDs never contain the literal "-announced-").
    find "$marker_dir" -maxdepth 1 -name '*-announced-*' -mmin "-${window_mins}" 2>/dev/null \
      | sed 's|.*/||; s/.*-announced-//'
  } | awk 'NF && !seen[$0]++'
}
