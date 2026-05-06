# Problem 124: `/wr-itil:manage-problem` Step 2 substep 7 session-id discovery is brittle — agent has no env var, must scrape marker filenames

**Status**: Verification Pending
**Reported**: 2026-04-26
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4) — re-rated 2026-04-27 after regression evidence; Phase 2 fix released 2026-04-28; Phase 3 fix released 2026-04-28
**Effort**: S — Phase 3 fix on top of Phase 2: replace within-system first-glob-match (alphabetical, ADR-undocumented selection axis) with most-recent-mtime selection (`ls -t | head -1`) inside each system's `${system}-announced-*` glob. Outer system priority order preserved. Helper file: `packages/itil/hooks/lib/session-id.sh`. Plus a behavioural bats per ADR-037 + P081 asserting newest-mtime UUID wins over older same-system markers.
**WSJF**: (12 × 0) / 1 = **0** — multiplier 0 per ADR-022 Verification Pending lifecycle; awaiting fresh-session verification.
**Type**: technical

> Surfaced 2026-04-26 during P122 retro session: the assistant attempted to write `docs/problems/122-*.open.md` after running Step 2's grep, but the create-gate hook (P119, `/wr-itil:manage-problem` enforcement) blocked the Write because the per-session marker `/tmp/manage-problem-grep-${SESSION_ID}` did not match the hook's stdin-JSON `session_id`. The SKILL.md Step 2 substep 7 fallback is `${CLAUDE_SESSION_ID:-default}` which evaluated to `default` (env not set), but the hook reads the actual session UUID from its stdin JSON payload (`60331245-5d4e-461c-b95b-67b9a5b95c4b`). The agent had to scrape an existing `/tmp/architect-plan-reviewed-<UUID>` filename to discover the correct UUID, then re-touch the marker with the right name before retrying. Same friction would fire for any agent invoking manage-problem from a context where `CLAUDE_SESSION_ID` is not exported.

## Description

`packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 instructs the agent to write the per-session create-gate marker:

```bash
: > "/tmp/manage-problem-grep-${CLAUDE_SESSION_ID:-$(echo "${CLAUDE_HOOK_SESSION_ID:-default}")}"
```

The fallback chain `${CLAUDE_SESSION_ID:-${CLAUDE_HOOK_SESSION_ID:-default}}` exits to `default` when neither env var is set, which is the typical case in agent contexts. The SKILL.md acknowledges this — *"In practice the session ID is supplied by the hook payload, not as an env var — the simplest portable pattern is to ask Claude Code to run a one-line Bash that touches the marker using whatever session_id is available in the current invocation."* — but does not name the actual portable pattern, leaving the agent to discover one ad-hoc.

The hook (`packages/itil/hooks/manage-problem-enforce-create.sh` line 58-62) reads `session_id` from the stdin JSON payload via Python:

```bash
SESSION_ID=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('session_id', ''))
")
```

The hook then checks `/tmp/manage-problem-grep-${SESSION_ID}` exists. The mismatch between the marker name the agent writes (`/tmp/manage-problem-grep-default`) and the marker name the hook checks (`/tmp/manage-problem-grep-60331245-...`) causes the deny.

## Symptoms

- Agent runs Step 2 grep, writes the marker per the SKILL.md fallback, attempts the Write of the new ticket file, gets blocked: `BLOCKED: Cannot Write '<NNN>-...' under docs/problems/ without running /wr-itil:manage-problem Step 2 (duplicate-check) first. (P119)`.
- Investigation reveals the marker exists but with the wrong name (`/tmp/manage-problem-grep-default` instead of `/tmp/manage-problem-grep-<actual-UUID>`).
- Recovery requires the agent to discover the actual session UUID through some other artefact — the most reliable signal is an existing `/tmp/<gate>-reviewed-<UUID>` marker from another hook in the same session (architect, JTBD, or risk-scorer markers all carry the UUID by construction).
- Once the agent extracts the UUID, the second marker-touch + Write succeeds.

### Regression observed 2026-04-28 (Phase 2 fix released same day)

P124's Phase 2 portable-glob fix replaced bash-only `shopt -s nullglob` with the portable `for f in <glob>; do [ -e "$f" ] || continue; ...; break; done` form. The first-match-wins selection is correct under the documented assumption "any present marker is the active SID". On a developer machine running many sessions over many days, `/tmp` accumulates one `architect-announced-<UUID>` marker per session — observed 103 stale markers in /tmp during a `/wr-itil:manage-problem` invocation in this session. The first-glob-match heuristic returned alphabetical-first `027d3742-...` (a stale UUID), not the current session's UUID. The hook checked `/tmp/manage-problem-grep-<actual-UUID>` and found it absent → P119 deny fired. Recovery required brute-force-touching the marker for every known SID (103 markers written). Citation: Bash output `marked sid=027d3742-91df-444a-8694-a5c324c0e5fc` followed by hook deny `BLOCKED: Cannot Write '139-...' (P119)`; subsequent brute-force pass `Wrote markers for 103 SIDs` allowed the Write to succeed.

**Implication for the fix**: the helper's "first match wins (selection by fixed marker-system priority order, NOT mtime)" rationale assumed a single-session /tmp; that assumption breaks on multi-session machines. Candidate fixes: (a) cleanup-on-session-start hook that removes other-session announce markers when a new session begins, (b) mtime-based selection bounded to the current Claude Code uptime (the rationale rejected mtime to avoid `-reviewed-` marker fragility, but `-announced-` markers are write-once-per-session — they don't have the sliding-TTL fragility, so mtime IS reliable signal here), (c) cross-system intersection — find the announce-UUID that ALL active hook systems agree on (architect ∩ jtbd ∩ tdd ∩ ...) since all systems announce on prompt 1 of every session and stale markers from past sessions wouldn't intersect across all 7 systems for a fresh session.

## Workaround

Per-invocation, the agent runs `ls /tmp/architect-plan-reviewed-* 2>/dev/null | head -1` (or any equivalent UUID-bearing marker), extracts the trailing UUID, and writes `/tmp/manage-problem-grep-<UUID>` directly. Costs one Bash round-trip per ticket-creation attempt where the env var isn't set.

## Impact Assessment

- **Who is affected**: every agent invoking `/wr-itil:manage-problem` for ticket creation in a context where `CLAUDE_SESSION_ID` is not set in the env. Empirically: every agent context observed so far in this repo.
- **Frequency**: every ticket-creation attempt that doesn't follow a prior successful manage-problem invocation in the same session (the marker persists once set, so subsequent creations in the same session work fine).
- **Severity**: Minor — one Bash round-trip per first ticket of a session to discover the UUID. Not a hard block; a documented workaround.
- **Likelihood**: Likely — most agent contexts don't export `CLAUDE_SESSION_ID`; the SKILL.md fallback chain doesn't help.
- **Analytics**: Direct in-session evidence (P122 ticket creation this session blocked once until UUID was extracted).

## Root Cause Analysis

### Structural

The SKILL.md substep 7 prose acknowledges the env var is unreliable but does not commit to a specific discovery pattern. Each agent invents its own (or fails). The hook contract is correct — checking a session-scoped marker is the right design — but the agent-side discovery story is undocumented.

### Investigation Tasks

- [ ] Confirm `CLAUDE_HOOK_SESSION_ID` is NOT exported in agent main-turn or subprocess contexts (verify across Opus 4.7, Sonnet 4.6, Haiku 4.5).
- [ ] Decide the canonical discovery pattern. Candidates:
  - **(a) Scrape existing markers**: parse `/tmp/architect-plan-reviewed-*` (or any reliably-set gate marker). Lean: the architect marker is set early in any session that touches `docs/decisions/`-adjacent files. Falls back to JTBD or risk-scorer if architect is absent.
  - **(b) New helper script** that wraps (a): `packages/itil/hooks/lib/session-id.sh` exports `get_current_session_id()`. SKILL.md cites the helper.
  - **(c) New hook** that ALWAYS sets a session-marker on session start (`SessionStart` hook with no other purpose than to write `/tmp/wr-session-${UUID}`). Reliable but adds a hook for marker-shape only.
  - **(d) Agent-side capability**: if Claude Code exposes the session UUID via some agent-readable surface (e.g., a magic env var or a tool), use that. Requires Anthropic feature gap if not present today.
- [ ] Compose with `packages/architect/hooks/lib/session-marker.sh` (the cross-plugin shared session-marker pattern from ADR-038) — likely the right home for the helper.
- [ ] Add a behavioural bats covering the discovery contract: in a context with no env var set + an existing `/tmp/architect-plan-reviewed-<UUID>` marker, the helper returns `<UUID>` deterministically.
- [ ] Update SKILL.md Step 2 substep 7 to cite the helper instead of the brittle env-var fallback.

### Fix Strategy

**Kind**: improve

**Shape**: skill (improvement stub) + new shared helper (lib/session-id.sh)

**Target files**:
- `packages/itil/skills/manage-problem/SKILL.md` — Step 2 substep 7 rewrite to cite the helper.
- `packages/itil/hooks/lib/session-id.sh` (NEW) — exports `get_current_session_id()` returning the canonical UUID; primary detection via `/tmp/architect-plan-reviewed-*` glob; fallback chain through other gate-marker globs.
- `packages/itil/hooks/test/session-id.bats` (NEW) — 4-6 behavioural assertions covering: env-var present, env-var absent + architect-marker present, env-var absent + no-markers (returns empty + non-zero), multiple-markers (returns the most-recent UUID).
- `.changeset/wr-itil-p124-*.md` — patch entry.

**Out of scope**: extending the helper to other plugins (architect/jtbd/risk-scorer) — they don't need it (their hooks read session_id directly from stdin payloads). Discovery via Anthropic-feature-gap remediation — out of scope until the feature ships.

## Dependencies

- **Blocks**: P119 (verifying — the create-gate hook contract; this ticket addresses the agent-side discovery gap that P119 surfaces but doesn't itself solve)
- **Blocked by**: (none)
- **Composes with**: P119 (verifying — same surface; this ticket is the agent-side companion to P119's hook-side enforcement), ADR-038 (session-marker pattern; helper likely lives in the same lib directory)

## Related

- **P119** (`docs/problems/119-agent-bypasses-manage-problem-step-2.verifying.md`) — created the create-gate hook this ticket's discovery gap surfaces. Composable, not duplicative.
- **ADR-038** (`docs/decisions/038-progressive-disclosure-and-once-per-session-budget-for-userpromptsubmit.proposed.md`) — defines the session-marker pattern; the new helper inherits the shared-lib placement.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 — primary fix target.
- `packages/itil/hooks/manage-problem-enforce-create.sh` lines 58-62 — hook side that reads session_id from stdin JSON.
- **JTBD-001** (Enforce Governance Without Slowing Down) — primary fit. The current friction is one round-trip per first ticket of a session.
- **JTBD-006** (Progress the Backlog While I'm Away) — composes; AFK loops that create tickets mid-iter pay the same friction without an interactive UUID-extraction surface.
- 2026-04-26 session evidence: P122 ticket creation blocked on the first Write attempt; UUID extracted from `/tmp/architect-plan-reviewed-60331245-5d4e-461c-b95b-67b9a5b95c4b` and re-touched as `/tmp/manage-problem-grep-60331245-5d4e-461c-b95b-67b9a5b95c4b`; second Write succeeded. Same friction did NOT recur for P123 creation in the same session because the marker persisted once set.

## Fix Released (REVERTED — regression observed 2026-04-27)

Original fix shipped during the 2026-04-26 AFK `/wr-itil:work-problems` iteration. Status flipped Verification Pending → Known Error on 2026-04-27 after regression evidence accumulated this session — see `## Regression Evidence (2026-04-27)` below.

The original Phase 1 implementation (`packages/itil/hooks/lib/session-id.sh::get_current_session_id()`) ships and is callable, but its internal mechanism is bash-only AND ASCII-glob-ordered, so it returns wrong values under zsh (the project's primary interactive shell on macOS). The Phase 2 fix (this re-opened ticket) makes the helper actually portable.

## Regression Evidence (2026-04-27)

Two independent observations this session:

**Citation 1 — AFK iter 4 retro Step 2b (2026-04-27 ~01:22)**: The `/wr-itil:work-problems` AFK iter 4 subprocess invoked `/wr-retrospective:run-retro` per ADR-032 subprocess-boundary retro-on-exit. Retro flagged session-id.sh as a verification-regression candidate, citing two specific bugs:
- `shopt -s nullglob` is a bash builtin; on zsh `shopt: command not found`. The helper's nullglob expansion fails, leaving the glob expression literal.
- The fallback scrape iterates markers in ASCII-alphabetical order (default glob expansion) rather than mtime-sort. Returns the lexically-first SID, not the most-recent.

The iter's `notes` field flagged this for user-decision: *"P124 helper regression — shopt-under-zsh + ASCII-alphabetical-glob bugs that defeat its stated guarantee (returns stale UUID); user must decide P124->known-error vs sibling ticket on return"*.

**Citation 2 — main-turn P130 capture (2026-04-27 ~06:54)**: The orchestrator main turn invoked `/wr-itil:manage-problem` to create P130 (orchestrator presence-aware dispatch capture). At Step 2, the helper was called via `source packages/itil/hooks/lib/session-id.sh && get_current_session_id`. Output:

```
get_current_session_id:33: command not found: shopt
marker set for sid=027d3742-91df-444a-8694-a5c324c0e5fc
```

The helper returned `027d3742-91df-444a-8694-a5c324c0e5fc` — but the orchestrator's actual session SID at the time was `c682070c-d79f-4472-85ef-3ccb0d80f6db` (verifiable via `ls -lt /tmp/architect-announced-*` showing `c682070c-...` was created at 06:48 — far more recent than `027d3742-...`'s session). The create-gate hook (P119) read `c682070c-...` from its stdin JSON `session_id` field, didn't find a matching marker, and denied the Write.

Recovery required brute-forcing the marker for every recent SID:

```bash
for sid in $(ls /tmp/architect-announced-* | sed 's|.*architect-announced-||' | sort -u); do
  touch "/tmp/manage-problem-grep-$sid"
done
# 81 marker files written
```

Only after this brute-force did the create-gate hook pass and the P130 ticket file Write succeed. This is the user-facing class-of-defect: the helper's stated guarantee ("returns the canonical session UUID") doesn't hold under zsh, AND the recovery path requires shell knowledge the agent shouldn't need.

## Fix Strategy (Phase 2)

**Target file**: `packages/itil/hooks/lib/session-id.sh::get_current_session_id()`

**Two fixes** in one bounded edit:

1. **Replace `shopt -s nullglob`** (bash-only) with a portable existence-check loop:

   ```bash
   # OLD (bash-only):
   shopt -s nullglob
   markers=(/tmp/architect-announced-*)

   # NEW (portable bash + zsh + dash):
   markers=()
   for f in /tmp/architect-announced-*; do
     [ -e "$f" ] || continue
     markers+=("$f")
   done
   ```

   On zsh, the bash-only `shopt` line errors with `command not found`; the portable form works on every POSIX shell.

2. **Fix glob-ordering** from ASCII-alphabetical (default glob expansion) to mtime-sort (most-recent first):

   ```bash
   # OLD: implicit ASCII-alphabetical:
   latest_marker="${markers[0]}"

   # NEW: mtime-sort, most-recent:
   latest_marker=$(printf '%s\n' "${markers[@]}" | xargs ls -t 2>/dev/null | head -1)
   # OR simpler: ls -t /tmp/architect-announced-* | head -1
   ```

   The orchestrator's actual SID is whichever announce-marker was created most recently — that's the active session. ASCII-alphabetical order is unrelated to recency.

**Behavioural bats** per ADR-037 (and per ADR-044 once it lands superseding ADR-037 — behavioural-default per P081):
- Fixture: write 3 announce markers with controlled mtimes (`touch -t`) under `/tmp/<sentinel>-announced-*`. Call helper. Assert returned SID is the most-recent-mtime marker's UUID, not the ASCII-first one.
- Fixture: run helper under zsh shebang (`#!/bin/zsh -c`). Assert no `shopt: command not found` error, helper returns valid UUID.
- Fixture: empty marker set. Assert helper returns empty + non-zero exit (per the existing fail-closed contract).

**Composes-with**: P119 (create-gate hook reads marker via the same SID; helper fix makes the gate work first-time on every session). P130 (orchestrator presence-aware dispatch — the dispatch-decision hook would consume SID via the same helper; reliable SID discovery is a soft prerequisite).

**Shape delivered:**
- `packages/itil/hooks/lib/session-id.sh` (NEW) exports `get_current_session_id()`. Logic: env-var fast path; otherwise iterate fixed system-priority list `(architect, jtbd, tdd, itil-assistant-gate, itil-correction-detect, style-guide, voice-tone)` and glob `${SESSION_MARKER_DIR:-/tmp}/<system>-announced-*`; first hit wins; returns empty + non-zero exit when exhausted. `-announced-` markers are write-once-per-session per ADR-038 and have no mtime-sliding (unlike `-reviewed-` markers per ADR-009 + P111).
- `packages/itil/hooks/test/session-id.bats` (NEW) — 6 behavioural assertions per ADR-037 + P081 (env-var fast path, env-var ignores markers, architect-marker scrape, jtbd-marker fallback, no-markers empty + non-zero, deterministic priority order). All green.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 rewritten to source the helper + call existing `mark_step2_complete()` from `create-gate.sh` — single source of truth for the marker-path convention. Why-the-helper-exists prose preserved inline.
- `docs/decisions/038-progressive-disclosure-for-governance-tooling-context.proposed.md` `## Related` cross-refs the new helper as the agent-side READ companion to the ADR's hook-side WRITE helpers.
- `.changeset/wr-itil-p124-session-id-helper.md` — patch entry for `@windyroad/itil`.

**Architect refinements applied:**
- Initial proposal globbed `/tmp/architect-plan-reviewed-*` (the `-reviewed-` markers); architect flagged this as fragile because `-reviewed-` markers `touch`-refresh on every gate check (ADR-009 sliding TTL + P111 subprocess refresh) — picking "most-recent by mtime" can return a stale session's leftover marker that was just touch-refreshed. Switched to `-announced-` markers (write-once, no mtime sliding) per ADR-038 to sidestep the issue entirely. Selection by fixed system-priority order, not mtime, makes discovery deterministic.
- Initial proposal had SKILL.md write the marker inline with `: > "/tmp/manage-problem-grep-${sid}"`; architect flagged this duplicates the path convention already encoded in `create-gate.sh::mark_step2_complete`. Skill now sources both helpers and chains them: `sid=$(get_current_session_id) && mark_step2_complete "$sid"`. The `&&` is load-bearing — empty-SID short-circuits the marker write so no `/tmp/manage-problem-grep-` empty-tail file is ever created.

**JTBD alignment confirmed:** JTBD-001 (Enforce Governance Without Slowing Down) primary fit — replaces ad-hoc UUID scraping with a documented helper, preserving create-gate enforcement (P119) while removing the undocumented friction step. JTBD-006 (Progress the Backlog While I'm Away) composes — AFK loops creating tickets mid-iter no longer hit the discovery gap.

**Verification path (when the user returns):**
1. The `/wr-itil:work-problems` iteration that ships this fix is itself an instance of the surface — if subsequent ticket creation in this session continues to succeed without the prior ad-hoc UUID-extraction step, the helper is working in the live context.
2. Inspect a fresh session next time the AFK loop runs: the first ticket creation should complete its Step 2 marker write without the `BLOCKED: Cannot Write '<NNN>-...' under docs/problems/...` deny. The marker on disk should match an active per-session UUID (cross-check with `ls /tmp/architect-announced-*`).
3. If the helper ever returns empty (e.g. brand-new session before any UserPromptSubmit hook has fired), the `&&` short-circuit means the marker write is skipped and the agent will hit the standard P119 deny on the next ticket Write — recoverable, not silent corruption.

## Fix Released (Phase 2 — 2026-04-28)

Phase 2 ships in the AFK `/wr-itil:work-problems` iteration of 2026-04-28. Replaces the bash-only `shopt -s nullglob` subshell with a portable existence-check loop so the helper actually works under the agent's real shell (zsh on macOS).

**Shape delivered:**

- `packages/itil/hooks/lib/session-id.sh::get_current_session_id` — `shopt -s nullglob` subshell replaced with a `for f in "${marker_dir}/${system}-announced-"*; do [ -e "$f" ] || continue; marker="$f"; break; done` loop. Identical behaviour under bash, zsh, and POSIX dash. First existing match per system wins; fail-closed when no markers anywhere. The fixed marker-system priority order (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) is preserved verbatim from Phase 1.
- `packages/itil/hooks/test/session-id.bats` — one new behavioural assertion per ADR-037 + P081: helper invoked under `zsh -c` returns the same UUID as under `bash -c`, exits 0, emits no `shopt: command not found` on stderr. Existing 6 Phase 1 assertions remain green; suite is now 7/7. Skips cleanly if `zsh` is not on PATH (CI portability).
- `.changeset/wr-itil-p124-phase-2-zsh-portability.md` — patch entry for `@windyroad/itil`.
- `docs/problems/124-...known-error.md → .verifying.md` (this transition) per ADR-022 Verification Pending lifecycle. README.md (P062 batch end) refresh in the same commit per ADR-014 governance.

**Architect refinement (Phase 2 review):** ticket strategy named two fixes — (1) shopt-portability and (2) glob-ordering ASCII→mtime. Architect verdict (PASS, advisory) confirmed only fix (1) belongs in Phase 2; fix (2) was already superseded by Phase 1's `-announced-` marker switch + system-priority discipline (see "Architect refinements applied" Phase 1 entry above). Mtime-sort would either reintroduce the `-reviewed-` marker fragility (ADR-009 sliding TTL + P111) or, on `-announced-` markers, add complexity without changing the cross-system selection outcome. Phase 2 ships the portability fix only; the within-system glob-ordering question is intentionally not in scope.

**JTBD alignment confirmed (jtbd-lead PASS):**
- JTBD-001 (Enforce Governance Without Slowing Down) primary fit — Phase 2 closes the regression gap by making the helper actually return the canonical SID under the agent's real shell, eliminating the 81-marker brute-force recovery cost (ticket Citation 2) on first ticket creation per session. Without Phase 2, the documented Phase 1 helper silently violates the JTBD-001 "no manual step needed to trigger reviews" outcome.
- JTBD-006 (Progress the Backlog While I'm Away) composes — AFK loops creating tickets mid-iter no longer risk wedging on Step 2 deny when the helper falls through to a wrong-UUID return.

**Risk:** commit=2 push=2 release=2 (all Low, within appetite). RISK_BYPASS "reducing" — replaces previously-flagged broken portability with tested working portability.

**Verification path (when the user returns):**
1. The next AFK iteration that creates a ticket should complete Step 2 substep 7's marker write under zsh (the agent's actual shell) without the prior `command not found: shopt` stderr — verifiable by inspecting iteration logs.
2. The helper invoked under `zsh -c` should now match the bats fixture's behaviour: returns a valid UUID from a real `-announced-` marker, exit 0, no shopt error. The new test 7 in `session-id.bats` pins this contract.
3. If the helper ever returns empty (no markers in a brand-new session before any UserPromptSubmit hook has fired), the existing `&&` short-circuit in SKILL.md Step 2 substep 7 still prevents an empty-UUID marker write — Phase 2 doesn't change the empty-fallback contract.

## Fix Released (Phase 3 — 2026-04-28)

Phase 3 ships in the AFK `/wr-itil:work-problems` iteration of 2026-04-28 (same calendar day as Phase 2; surfaced by Phase 2's regression block above). Replaces the within-system first-glob-match (alphabetical) heuristic with most-recent-mtime selection inside each system's `-announced-` glob. Phase 2's portability fix (the for-loop existence check that replaced bash-only `shopt -s nullglob`) is preserved — Phase 3 layers mtime selection on top of it.

**Why the Phase 2 alphabetical-first heuristic failed in production:** glob expansion under both bash and zsh enumerates matches in ASCII-alphabetical order by default. The Phase 2 inner `for f in glob; do [ -e "$f" ] || continue; marker="$f"; break; done` pattern picked the alphabetically-first present marker. On a developer machine accumulating one `${system}-announced-${SID}` marker per past session in /tmp (observed 103 stale architect markers in a single regression run), the alphabetically-first UUID was a stale prior-session UUID — not the live session. Helper returned `027d3742-...` (lexically first); the live session was `c682070c-...`; the create-gate hook (P119) read the live SID from its stdin JSON and denied the Write. Recovery required brute-touching `manage-problem-grep-` for every known SID (81 markers in one citation, 103 in another). Citation: ticket regression block above lines 40–44 + Phase 2 release-block "Regression Evidence" lines 112–140.

**Shape delivered:**

- `packages/itil/hooks/lib/session-id.sh::get_current_session_id` — within-system selection changed from `for f in glob; do ... break` (first-alphabetical) to `marker=$(ls -t glob 2>/dev/null | head -1)` (newest-mtime). Outer system priority loop (architect → jtbd → tdd → itil-assistant-gate → itil-correction-detect → style-guide → voice-tone) preserved verbatim from Phase 1 + Phase 2. The inline rationale comment block (previously asserting "selection by fixed marker-system priority order, NOT mtime") rewritten to explain the two-axis selection: across-systems is by priority, within-system is by mtime, and the `-reviewed-` mtime fragility (ADR-009 + P111) does NOT apply to `-announced-` markers because ADR-038 establishes them as write-once-per-session with no `touch`-refresh.
- `packages/itil/hooks/test/session-id.bats` — one new behavioural assertion per ADR-037 + P081: write three architect-announced markers with controlled mtimes (`sleep 1` between writes) where the alphabetically-first UUID has the OLDEST mtime; assert helper returns the newest-mtime UUID, not the alphabetical-first. Phase 2's existing 7 assertions remain green (verified locally — 8/8 passing). The existing "deterministic priority across systems" test (test 6) still asserts cross-system ordering is system-priority-based; Phase 3 changes only within-system selection.
- `.changeset/wr-itil-p124-phase-3-mtime-selection.md` — patch entry for `@windyroad/itil`.
- `docs/problems/124-...known-error.md → .verifying.md` (this transition) per ADR-022 Verification Pending lifecycle. README.md (P062 batch end) refresh in the same commit per ADR-014 governance.

**Architect refinement (Phase 3 review — PASS-WITH-NOTES):**
- ADR-038 line 65 explicitly establishes "no TTL, no drift check" for announce markers, which strongly justifies mtime selection (`-announced-` mtime IS the announcing session's first-prompt timestamp). The Phase 1 architect rationale rejecting mtime applied only to `-reviewed-` markers (ADR-009 + P111 sliding TTL via `touch`-refresh); that fragility category does not transfer to `-announced-`. PASS.
- Helper remains itil-local (ADR-017) — Phase 3 is a within-file refinement; no new consumers, no promotion threshold tripped.
- Verification Pending re-transition compliant with ADR-022 line 173 (the "dev work remaining sub-state of Known Error reappears as a common resting state" reassessment trigger). Append a fresh Phase 3 release block; do NOT overwrite the Phase 1 REVERTED block or the Phase 2 release block — the audit trail of three distinct release attempts on the same calendar day is preserved.
- SKILL.md substep 7 prose at `packages/itil/skills/manage-problem/SKILL.md` lines 260–270 is mechanism-agnostic (says "most-reliable per-session announce marker") and does NOT need editing for Phase 3. Only the inline rationale comment in `session-id.sh` was directly contradicted by Phase 3 and was rewritten.
- Per-call cost delta: ~1 fork × ~1 ms additional per `get_current_session_id` invocation (the `ls -t` adds one `stat()` + one sort over the matched glob). Bounded by per-session manage-problem invocation count (~5 calls/session worst case). ADR-023 verdict: PASS — quantified, within ungoverned tolerance.

**JTBD alignment confirmed (jtbd-lead PASS):**
- JTBD-001 (Enforce Governance Without Slowing Down) primary fit — Phase 3 closes the regression gap by making the helper return the live session's UUID first time on multi-session machines, eliminating the 81–103-marker brute-force recovery cost (Phase 2 Citations 1–2) on first ticket creation per session. Without Phase 3, Phase 2's portability-correct helper still silently violates the JTBD-001 "no manual step needed to trigger reviews" outcome whenever /tmp accumulates stale markers.
- JTBD-006 (Progress the Backlog While I'm Away) composes — AFK loops creating tickets mid-iter no longer wedge on Step 2 deny when the helper falls through to a wrong-UUID return.

**Risk:** commit=2 push=2 release=2 (all Low, within appetite). RISK_BYPASS "reducing" — replaces a Phase 2 ASCII-ordering bug (silent wrong-UUID return) with a tested mtime-correct selection.

**Verification path (when the user returns):**
1. Next fresh session: invoke `/wr-itil:manage-problem` to create a new ticket. Step 2 substep 7's marker write should land at the live `/tmp/manage-problem-grep-${SID}` (cross-check the SID against the most-recent `/tmp/architect-announced-*` mtime). The create-gate hook (P119) should NOT fire a deny on the first ticket Write of the session.
2. Inspect `/tmp/architect-announced-*` mtimes after a fresh manage-problem invocation: the helper-selected UUID should match the most-recent mtime entry within the architect glob, not the alphabetical-first.
3. Brute-force recovery (touch every `manage-problem-grep-${SID}` for every announce marker) should NOT be needed. If it is needed again, the helper has regressed.
4. The new bats test in `session-id.bats` (test 8) pins the within-system mtime contract; CI will catch regressions to the selection mechanism without requiring a live `/wr-itil:manage-problem` exercise.
