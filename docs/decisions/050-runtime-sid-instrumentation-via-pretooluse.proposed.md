---
status: "proposed"
date: 2026-05-03
human-oversight: confirmed
oversight-date: 2026-05-26
amended: 2026-05-26
amendment-driver: P260 — corrected the falsified "orchestrator + own subprocess: not a race" claim (the backgrounded work-problems dispatch fires orchestrator hooks concurrently with the subprocess); recorded Option C mitigation (bounded multi-UUID create-gate marker-write); line-191 reassessment trigger met. Human-oversight re-confirmed on the changed posture (user direction 2026-05-26, P283 prong-2 drain). See "Amendment 2026-05-26" in Race-mitigation. Option C implementation tracked at P260.
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, manage-problem SKILL.md authors, plugin developers extending the suite]
reassessment-date: 2026-08-03
supersedes: ["048-gate-misfire-recovery-procedure.proposed.md"]
---

# Capture the runtime stdin session_id via a PreToolUse hook so the create-gate marker binds to the same SID the runtime hook will see

## Context and Problem Statement

P119 (`docs/problems/119-...verifying.md`) gates new problem-ticket creation on a per-session marker (`/tmp/manage-problem-grep-${session_id}`) so the duplicate-check grep is provably executed before a Write lands. P124 (`docs/problems/124-...verifying.md`) introduced `get_current_session_id` (in `packages/itil/hooks/lib/session-id.sh`) to discover the canonical session UUID for the marker write — the agent process does NOT export `CLAUDE_SESSION_ID`, and the hook side reads `session_id` from its stdin JSON payload.

P124 evolved through three phases:
- Phase 1 — first-glob-match selection (alphabetical), shipped 2026-04-26.
- Phase 2 — shopt-portable existence check, shipped 2026-04-28 morning.
- Phase 3 — within-system mtime selection (`ls -t | head -1`), shipped 2026-04-28 afternoon.

Phase 3 introduced a new regression (P142): in orchestrator main turns AFTER subprocess dispatch, subprocess announce markers have NEWER mtime than the orchestrator's, so newest-mtime-wins picks the subprocess SID. The runtime hook stdin still contains the orchestrator SID, so the marker lands under the wrong UUID and the next Write is denied. ADR-048 (proposed 2026-04-29) documented a two-tier recovery procedure (announce-marker scrape + python3-via-Bash file-write) as a stop-gap until a structural fix could ship.

The structural-fix design space has a contradiction the P142 ticket did not initially surface: the helper is called from BOTH orchestrator main turns AND subprocess sessions (iter ticket creation paths). These two contexts have OPPOSITE selection requirements:

- **Orchestrator main turn AFTER subprocess dispatch** — helper must return ORCHESTRATOR SID (subprocess markers have newer mtime; current bug).
- **Subprocess running itself** — helper must return SUBPROCESS SID (subprocess markers ARE the newest; current correct behavior).

No pure-helper algorithm operating only on filesystem state can disambiguate these contexts. Re-ordering the system priority list (P142 option (a)) shifts the misfire from orchestrator to subprocess context. Cross-system intersection by max-count (option (b)) does the same. Hybrid (option (c)) is structurally identical.

ADR-048 considered Option 5 — "Hook-stdin instrumentation: log the runtime SID to a discoverable path so the next agent can read it" — but rejected it AT THAT SCOPE because the only hook surface contemplated was `PreToolUse:Write` (the same surface as `manage-problem-enforce-create.sh`), which is perf-sensitive and already runs on every Write tool call. ADR-048 explicitly invited P142 to revisit: *"Composes with P142 if P142 architect chooses this implementation."*

The decision this ADR answers: **what is the structural fix shape for P142?**

User direction (P142 ticket body, 2026-04-29): *"re-order priority list ... OR cross-system intersection ... Plus matching behavioural bats per ADR-037 + P081"* — surfaced both pure-helper options without yet weighing the runtime-instrumentation alternative the architect now recommends.

## Decision Drivers

- **JTBD-001 (Enforce Governance Without Slowing Down)** — primary fit. P119's create-gate is a load-bearing audit-trail; the helper's SID-discovery must be reliable enough that the gate doesn't false-deny in routine flow. The ADR-048 recovery procedure is a stop-gap; the structural fix removes the failure mode.
- **JTBD-006 (Work the backlog AFK)** — recurring bug pattern in long AFK loops where every iter is a subprocess. Eliminating the SID-mismatch denial removes a class of mid-iter friction (orchestrator-side capture-on-correction).
- **JTBD-101 (Extend the Suite with New Plugins)** — adds a new hook surface (`itil-runtime-sid-marker.sh`) that any future plugin can consume by sourcing `lib/runtime-sid.sh` and reading the marker. The pattern this ADR establishes (PreToolUse hook deposits known-runtime-state for agent-side helpers to read) is a template.
- **P142** — this ADR is the chosen fix shape for the ticket.
- **P124** — Phase 4 of P124's helper evolution. Phases 1-3 stay; this ADR adds the authoritative-source layer that the helper consults BEFORE the existing announce-marker priority.
- **ADR-038** — announce-marker contract (write-once-per-session-per-system). Cold-path consumer of the helper. Phase 4 preserves the announce-marker priority logic AS the cold-path fallback when the runtime marker is absent (first tool call of a session, before any PreToolUse fires).
- **ADR-009** — gate marker lifecycle. The runtime-SID marker fits the `/tmp` placement convention; per-user/per-project scoping is a within-class refinement, not a new semantic class.
- **ADR-017** — shared-code-sync. The new lib (`lib/runtime-sid.sh`) is itil-local because only itil hooks consume it today. Promotion to `packages/shared/` deferred until a second plugin adopts the pattern (mirrors lib/session-id.sh's itil-local rationale).
- **ADR-045** — hook injection budget. The new hook is Pattern 1 (silent-on-pass, side-effect-only) — emits 0 bytes on stdout. No context-budget impact.
- **ADR-023** — performance review scope. The new hook fires on `PreToolUse:Bash|Write|Edit|Read` — most tool calls. Per-call cost: ~0.5-2ms (one JSON parse + one file write). Aggregate: ≤1s wall-clock + ≤100KB tmpfs writes per session (worst-case 500-6000 tool calls). Within ADR-045 Pattern 1 stdout-budget; no perf-budget ADR governs the itil hooks subsystem (ungoverned-risk accepted in Consequences).
- **ADR-044** — decision-delegation contract. The marker-read is mechanical (deterministic from filesystem state); no `AskUserQuestion` surface introduced.
- **ADR-048** — superseded by this ADR. The two-tier recovery procedure becomes unnecessary because SID-mismatch is structurally impossible.
- **P131** — gate-exclusions-as-write-permission anti-pattern. The runtime-SID marker is in `/tmp` (not `.claude/`); no exclusion-list change required.

## Considered Options

1. **Pure helper re-ordering (P142 option (a))** — put orchestrator-only systems (`itil-assistant-gate`, `itil-correction-detect`) first in the priority list. Rejected: context-blind. Fixes orchestrator-main-turn case but breaks subprocess-running-itself case (helper would return orchestrator SID while runtime hook sees subprocess SID; same misfire shape, different context).

2. **Cross-system intersection by max-count (P142 option (b))** — return the SID with markers across the most distinct systems. Rejected: same context-blindness. Orchestrator typically has more system markers than subprocess (because orchestrator received varied prompts over its lifetime), so this works for orchestrator-main-turn case but breaks subprocess-running-itself case for the same reason as option 1.

3. **Hybrid: priority list with intersection fallback (P142 option (c))** — rejected: structurally identical to options 1+2.

4. **Hook-stdin instrumentation via NEW PreToolUse hook (chosen)** — a small, dedicated hook that writes the runtime stdin `session_id` to a per-machine, per-user, per-project marker on every `PreToolUse:Bash|Write|Edit|Read` event. The helper reads the marker as the authoritative current-session SID; the existing announce-marker priority logic is preserved as cold-path fallback when the marker is absent.

5. **Hook-stdin instrumentation extending `manage-problem-enforce-create.sh` (P119's hook)** — write the runtime SID inside the existing PreToolUse:Write hook. Rejected: ordering hazard (the helper writes the create-gate marker BEFORE the Write tool call fires, so the runtime SID would not yet be on disk when the helper needs it). Also conflates two responsibilities (gate enforcement + runtime-state capture) in one script.

6. **Hook fail-open on any-marker** (ADR-048 option 4) — loosen the gate to allow when ANY `/tmp/manage-problem-grep-*` exists. Rejected: removes the SID-binding that anchors the audit trail; weakens P119's enforcement intent.

7. **Park P142 indefinitely; rely on ADR-048 recovery** — rejected: ADR-048 itself names the structural fix as the long-term goal; the recovery procedure is explicitly time-bounded by P142's lifetime.

## Decision Outcome

**Chosen option: Option 4** — hook-stdin instrumentation via a new `PreToolUse:Bash|Write|Edit|Read` hook in `@windyroad/itil`.

### Implementation surfaces

1. **New lib**: `packages/itil/hooks/lib/runtime-sid.sh` exposes `runtime_sid_path()` — the single source of truth for the marker path. Both producer (hook) and consumer (helper) source this lib so they agree on the path.

   - Sandboxed bats: `${SESSION_MARKER_DIR}/itil-runtime-sid.current` (no per-user/project scoping; SANDBOX_TMP is fresh per test).
   - Production: `/tmp/itil-runtime-sid-${USER}-${proj_hash}.current` where `proj_hash = cksum $PWD`.

2. **New hook**: `packages/itil/hooks/itil-runtime-sid-marker.sh`. Parses `session_id` from stdin JSON (python3 with jq fallback). Writes the SID via `printf '%s'` (no trailing newline) to the path returned by `runtime_sid_path()`. Always exits 0; emits 0 bytes on stdout (ADR-045 Pattern 1). Fail-open on every error path (missing parser, malformed JSON, empty SID, write failure).

3. **Hook registration**: `packages/itil/hooks/hooks.json` adds the new hook under `PreToolUse` with matcher `Bash|Write|Edit|Read`.

4. **Helper update**: `packages/itil/hooks/lib/session-id.sh` `get_current_session_id` now checks (in order):
   1. `CLAUDE_SESSION_ID` env-var fast path (unchanged).
   2. **NEW**: runtime-SID marker (returns marker contents if non-empty file exists).
   3. Existing announce-marker priority logic (cold-path fallback).

### Auto-supersession of ADR-048

ADR-048's recovery procedure becomes unreachable in routine flow because the runtime-SID marker eliminates SID-mismatch by construction. The supersession transition fires in the same commit:

- ADR-048 frontmatter: `status: "proposed"` → `status: "superseded"` + `superseded-by: 050-...`. Filename rename from `.proposed.md` → `.superseded.md`.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7: the recovery sub-block (between `<!-- supersedes-when: P142 ships -->` comment and the cross-references) is removed. The substep retains the helper-call snippet and a one-paragraph "Phase 4" pointer to this ADR.
- `packages/itil/hooks/manage-problem-enforce-create.sh`: the conditional `RECOVERY_HINT` append is removed; the deny message stays terse and skill-pointing.

### ADR-045 binding

The new hook is Pattern 1 (silent-on-pass, side-effect-only). Stdout MUST be 0 bytes. Side effects are filesystem writes only. Bats coverage asserts the silence invariant (`runtime-sid-marker.bats` test "hook is silent on stdout").

### ADR-037 + P081 binding

Behavioural bats only. Tests assert observable effects:
- `session-id.bats` — helper returns marker contents over newer announce markers; helper falls back to announce-marker priority on empty/absent marker; env-var fast path unchanged.
- `runtime-sid-marker.bats` — hook writes session_id to marker; hook is silent on stdout; hook overwrites prior marker; hook is no-op on empty/malformed input.

No structural-grep on `session-id.sh` or `itil-runtime-sid-marker.sh` source content.

### Race-mitigation

Two Claude Code sessions in DIFFERENT projects on the same machine: different `proj_hash` → different marker paths → no race.

Two sessions in the SAME project on the same machine (rare developer pattern): race possible. Last-writer-wins on the marker; agent-A's helper may read agent-B's SID. The failure mode is a hook-denied Write (visible, recoverable via re-running Step 2 or pulling fresh from `git`), not silent corruption. Accepted as a documented limitation.

~~Orchestrator + its own subprocess: not a race. The orchestrator blocks in the `claude -p` wait while the subprocess runs; orchestrator-side tool calls do not fire during subprocess execution. The subprocess's PreToolUse hooks write the subprocess's SID; on subprocess exit, the orchestrator's next PreToolUse hook write restores the orchestrator's SID.~~ **[SUPERSEDED-IN-PLACE 2026-05-26 — see Amendment below. This claim is FALSE.]**

#### Amendment 2026-05-26 — orchestrator + own backgrounded subprocess IS a race (P260)

The struck-through claim above is **falsified**. `/wr-itil:work-problems` Step 5 (per P121) does NOT block in a foreground `claude -p` wait — it **backgrounds** the subprocess (`claude -p ... &`) and runs an idle-timeout poll loop (`while kill -0 …; do … git log …; done`) in the orchestrator's main turn. Those orchestrator-side Bash tool calls fire `PreToolUse:Bash` hooks **concurrently** with the running subprocess, so the orchestrator and its own subprocess DO write the per-machine runtime-SID marker concurrently — a same-project last-writer-wins race. This materialised as **P260** (the 2026-05-18 P254/P255 foreground captures hit the race; the create-gate marker mismatch denied the Write). The line-191 reassessment trigger ("a pattern of same-project parallel-session races emerges") is therefore **met**.

**Mitigation — Option C (architect-resolved 2026-05-26):** bounded multi-UUID create-gate marker-write — when setting the create-gate marker, write it under EACH recent `/tmp/<system>-announced-*` UUID plus the current runtime-sid value, so whichever SID the subsequent Write's stdin carries, the marker exists. Option A (per-PID runtime-sid file) was rejected — the agent-side helper runs in a Bash-tool subshell whose PID ancestry does not reliably map to the hook process's PID. Option B (drop runtime-sid, rely on announce-marker mtime) was rejected — it regresses to the P142 mismatch. Implementation (session-id.sh + work-problems SKILL Step 2 substep + concurrent-session behavioural bats + `@windyroad/itil` changeset) is tracked at **P260**. Human-oversight re-confirmed on this corrected posture (user direction 2026-05-26, P283 prong-2 oversight drain).

### Mechanical, not user-decision (ADR-044 binding)

The marker-read is mechanical (deterministic from filesystem state). No `AskUserQuestion` surface introduced. The agent never sees the marker or chooses between SIDs; the helper transparently returns whichever SID the runtime hook just wrote.

## Scope

### In scope (this ADR)

- New `lib/runtime-sid.sh` providing `runtime_sid_path()`.
- New `itil-runtime-sid-marker.sh` PreToolUse hook (matcher `Bash|Write|Edit|Read`).
- `hooks.json` registration of the new hook.
- `session-id.sh` helper update (read runtime marker → fallback to announce-marker priority).
- `runtime-sid-marker.bats` (NEW) and `session-id.bats` (extended) behavioural coverage.
- `manage-problem/SKILL.md` Step 2 substep 7 cleanup (recovery sub-block → "Phase 4" pointer).
- `manage-problem-enforce-create.sh` cleanup (RECOVERY_HINT removal).
- ADR-048 transition to `superseded` (frontmatter + filename rename + supersedes-link).

### Out of scope

- **Promotion of `lib/runtime-sid.sh` to `packages/shared/`** — defer until a second plugin adopts agent-side runtime-SID discovery (per ADR-017).
- **Generalising the pattern to other gate-marker classes** — if other plugins develop similar agent-side SID-discovery needs (architect-create-gate, jtbd-create-gate, etc.), they can source `lib/runtime-sid.sh` and consume the marker; the pattern this ADR sets is the template, but each gate gets its own scoped consumption.
- **Performance budget ADR for the itil hooks subsystem** — recommended but not blocking. The aggregate cost (≤1s/session) is well within typical session budgets; explicit governance can wait for a session with measurable regression.
- **Refactoring the existing announce-marker priority logic** — Phase 3 logic stays as cold-path fallback. Future cleanup may consolidate priority logic if cold-path usage becomes negligible.

## Consequences

### Good

- **SID-mismatch denial is structurally impossible in routine flow** — the marker the helper writes binds to the same SID the runtime hook will see.
- **No `AskUserQuestion` surface introduced** — the recovery is invisible to the agent (and to the user).
- **Pattern is reusable** — future plugins consume runtime-SID discovery by sourcing one lib.
- **ADR-048 cleanup** — the recovery procedure prose, the python3-via-Bash second-tier, and the conditional deny-hint all retire in one commit.
- **Cold-path preserved** — the existing announce-marker priority logic still works for the first tool call of a session (before any PreToolUse fires); no regression for sessions that haven't yet warmed the runtime marker.

### Neutral

- **New `/tmp` marker class** — adds one more file convention to the gate-marker family. Lifecycle is identical to existing markers (lives until next reboot or `/tmp` clean-up).
- **One additional PreToolUse hook in `@windyroad/itil`** — increases the hook-fire fan-out by one. Each call is a single JSON parse + file write; cumulative cost is sub-second per session.

### Bad

- **Same-project parallel-session race** — two Claude Code sessions in the same project on the same machine race on the marker. Mitigation: agent-visible deny + Step 2 re-run. Likelihood: low for solo developers; would need explicit thought for shared dev environments. Accepted as a documented limitation.
- **Slightly more code** — one new lib, one new hook, one new bats file. Net diff is positive (deletes the ADR-048 recovery prose and the conditional RECOVERY_HINT in `manage-problem-enforce-create.sh`).
- **ADR-023 ungoverned-risk** — no perf-budget ADR governs the itil hooks subsystem. Acceptable for now; revisit if any iter session shows measurable wall-clock regression.

## Confirmation

### Source review (at implementation time)

- `packages/itil/hooks/lib/runtime-sid.sh` exists and exports `runtime_sid_path()`.
- `packages/itil/hooks/itil-runtime-sid-marker.sh` exists, is executable, and parses `session_id` from stdin JSON.
- `packages/itil/hooks/hooks.json` registers the new hook under `PreToolUse` with matcher `Bash|Write|Edit|Read`.
- `packages/itil/hooks/lib/session-id.sh` `get_current_session_id` reads runtime marker before announce-marker priority.
- `packages/itil/skills/manage-problem/SKILL.md` Step 2 substep 7 no longer contains the ADR-048 recovery prose.
- `packages/itil/hooks/manage-problem-enforce-create.sh` no longer contains the conditional `RECOVERY_HINT`.

### Bats coverage (per ADR-037 + P081)

- `runtime-sid-marker.bats` — 7 behavioural tests covering write, silence, exit code, overwrite, empty input, malformed JSON, fail-open on jq absence.
- `session-id.bats` — 4 new tests covering runtime-marker priority over announce markers, empty-marker fallback, cold-path fallback, env-var precedence over runtime marker.

### Behavioural replay

1. Orchestrator session: first prompt fires PreToolUse:Bash hooks → runtime marker written with orchestrator SID → orchestrator's `mark_step2_complete` writes `/tmp/manage-problem-grep-${orch-sid}` → Write fires PreToolUse:Write hook → hook reads `${orch-sid}` from stdin → matches marker → allows.
2. Subprocess dispatch: orchestrator dispatches `claude -p` subprocess → subprocess's first prompt fires PreToolUse:Bash hooks (in subprocess context) → runtime marker OVERWRITTEN with subprocess SID → subprocess's `mark_step2_complete` writes `/tmp/manage-problem-grep-${sub-sid}` → Write fires PreToolUse:Write hook (subprocess) → hook reads `${sub-sid}` from stdin → matches marker → allows.
3. Orchestrator main turn AFTER subprocess return: orchestrator's next user prompt arrives → PreToolUse:Bash hooks fire (orchestrator context) → runtime marker OVERWRITTEN with orchestrator SID → Write succeeds bound to orchestrator SID. (P142 bug case, now structurally fixed.)

## Reassessment Criteria

Reassess this ADR (target 2026-08-03) if:

- A second plugin adopts agent-side runtime-SID discovery → promote `lib/runtime-sid.sh` to `packages/shared/` per ADR-017.
- A pattern of same-project parallel-session races emerges → revisit race-mitigation (per-process-tree marker scoping, lock-file protocol, etc.).
- Claude Code begins exporting `CLAUDE_SESSION_ID` as an env var → the env-var fast path becomes the primary surface; this hook becomes redundant.
- Hook injection-budget regression measured → revisit ADR-023 perf-budget governance.

## Related

- **P124** (`docs/problems/124-...verifying.md`) — parent ticket. Phase 4 (this ADR) supersedes Phase 3's mtime-based selection as the primary path.
- **P142** (`docs/problems/142-...open.md`) — this fix's ticket. Closing-in-this-commit.
- **P119** (`docs/problems/119-...verifying.md`) — create-gate hook this ADR's runtime marker feeds.
- **ADR-048** (`docs/decisions/048-...md`) — superseded. Recovery procedure prose retired in the same commit.
- **ADR-038** (`docs/decisions/038-...md`) — announce-marker contract. Cold-path fallback consumer.
- **ADR-045** (`docs/decisions/045-...md`) — hook injection budget. Pattern 1 binding for the new hook.
- **ADR-037** (`docs/decisions/037-...md`) — bats-as-confirmation; behavioural-only per P081.
- **ADR-017** (`docs/decisions/017-...md`) — shared-code-sync. itil-local rationale for the new lib.
- **ADR-009** (`docs/decisions/009-...md`) — gate marker lifecycle.
- **ADR-044** (`docs/decisions/044-...md`) — decision-delegation contract. Mechanical recovery, no AskUserQuestion.
- **ADR-023** (`docs/decisions/023-...md`) — performance review scope.
- **P131** (`docs/problems/131-...md`) — gate-exclusions anti-pattern; boundary preserved (marker in `/tmp`, not `.claude/`).
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-...md`) — primary fit.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-...md`) — AFK loop friction reduction.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-...md`) — pattern reusable by future plugins.
