# Problem 111: Agent/Task subprocess tool calls do not refresh parent session's gate markers — TTL inflation is a symptom-treatment, not the fix

**Status**: Verification Pending
**Reported**: 2026-04-24
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Very Likely (4)
**Effort**: M
**WSJF**: 0 (Verification Pending — excluded from dev-work ranking per ADR-022)

## Fix Released

Pending release in next changeset bundle (`@windyroad/architect`, `@windyroad/jtbd`, `@windyroad/style-guide`, `@windyroad/voice-tone`, `@windyroad/risk-scorer` patch). Awaiting user verification.

Implementation (Option 1 — subprocess-completion refresh, per architect review 2026-04-25):

- New shared helper `slide_marker_on_subprocess_return` in `packages/{architect,jtbd,style-guide,voice-tone,risk-scorer}/hooks/lib/gate-helpers.sh` (five byte-identical copies). Touches an existing marker on PostToolUse:Agent|Bash if `tool_response.is_error` is not true; never creates a marker; fail-safe on parse error.
- New PostToolUse:Agent|Bash hook per plugin: `architect-slide-marker.sh`, `jtbd-slide-marker.sh`, `style-guide-slide-marker.sh`, `voice-tone-slide-marker.sh`, `risk-slide-marker.sh`. Each registered in its plugin's `hooks.json`.
- For risk-scorer: slides only the score files `${RDIR}/{commit,push,release}`. The `*-born` markers are deliberately NOT slid (the 2×TTL hard-cap from P090 must remain invariant under sliding).
- ADR-009 amendment: new "Subprocess-boundary refresh (P111, 2026-04-25)" subsection documents the helper contract, the cross-process isolation invariant from ADR-032 line 123, and the orthogonal composition with P090's three-band TTL refinement.
- Behavioural bats coverage: `packages/{architect,jtbd,style-guide,voice-tone,risk-scorer}/hooks/test/slide-marker-on-subprocess-return.bats` (6 tests each, 30 total) plus `packages/architect/hooks/test/architect-slide-marker.bats` (6 hook-level integration tests). Asserts the canonical P111 reproduction case: a 50-minute-old marker survives a successful subprocess return.

Verification path: run a session that delegates a long-running subprocess (e.g. an Agent-tool call to a non-architect/jtbd subagent that takes > 30 minutes, or a `claude -p` iteration subprocess that exceeds the parent's TTL window). After the subprocess returns, attempt an Edit or Write that triggers the architect / JTBD / style-guide / voice-tone / risk-scorer gate. The gate should pass without forcing re-delegation, and the marker mtime should be approximately NOW. Confirm via `stat` on `/tmp/<gate>-reviewed-<SESSION_ID>` that the mtime advanced after subprocess return.

> Identified 2026-04-24 during post-release review of the 9a1f96c TTL-extension commit (P107 fix). The commit doubled default TTL from 1800s → 3600s and closed P107, but the underlying cause is architectural, not a number. The hook libraries (`packages/{architect,jtbd,style-guide,voice-tone,risk-scorer}/hooks/lib/*-gate.sh`) already implement sliding-window refresh — `touch "$MARKER"` fires on every valid PreToolUse check. If the hook fires during work, the TTL never expires. Expiry only happens when the agent is silent for longer than TTL — and in practice that means **subprocess boundaries**: Agent-tool delegations, `claude -p` dispatches, and other nested flows whose internal tool calls don't trigger the parent session's hooks. Doubling TTL pushes that cliff from 30 min to 60 min; the next long subprocess hits it again. P107 closed the immediate symptom; this ticket tracks the root cause.

## Description

The edit-gate hook families share a common design:

- On `PreToolUse`, the gate checks `/tmp/<gate>-reviewed-<SESSION_ID>`; if present and within TTL, `touch` the marker (slide the window forward) and allow the edit.
- On `PostToolUse` after an agent delegation, the relevant subagent touches the marker to mark the review complete.

This works cleanly for sequential work in one session. It breaks under subprocess dispatch:

1. The parent session's agent delegates to a subprocess (Agent tool, `claude -p`, Task, or nested skill subprocess).
2. The subprocess does tool calls that take many minutes (edits, bats, gate loops of its own).
3. The subprocess's PreToolUse hooks check `/tmp/<gate>-reviewed-<SUBPROCESS_SESSION_ID>` — a *different* marker from the parent's.
4. The parent's marker `/tmp/<gate>-reviewed-<PARENT_SESSION_ID>` is never touched by the subprocess.
5. When the subprocess returns and the parent resumes, if >TTL seconds have passed since the parent's last PreToolUse check, the parent's marker has expired — even though the combined parent+subprocess work was continuous.

P107 observed this in an edit batch that exceeded 1800s. The 2026-04-23 fix (9a1f96c) extended TTL to 3600s. But a single `claude -p` subprocess orchestrating a multi-file refactor can easily exceed 3600s, and Agent-tool delegations with `run_in_background: true` followed by other work can too. The symptom returns at the new threshold.

## Symptoms

- Parent session's PreToolUse gate fires `permissionDecision: "deny"` after a long subprocess return, forcing re-delegation to architect + JTBD.
- Re-delegation cost: ~5 min wall-clock + ~2K tokens per affected slice, per gate library (architect, jtbd, style-guide, voice-tone, risk-scorer).
- python3-stdin-heredoc fallback (per briefing's hooks-and-gates entry) becomes common, which suggests the gate is being worked around rather than honouring the design intent.
- TTL knob becomes a tuning dial for "longest reasonable subprocess" — a proxy for an architectural question the gate design never answered.

## Workaround

Today:

- Increase TTL (P107's fix — 1800s → 3600s across all five gate libraries).
- Manually re-delegate to the relevant subagent when the gate denies after subprocess return.
- Use python3-stdin-heredoc to bypass the gate for known-safe writes (pattern-matches Bash command text, so HEREDOC content containing `git commit` can trip it — see briefing entry).

None of these address the root cause.

## Impact Assessment

- **Who is affected**: Any session that uses Agent-tool delegation, `claude -p` subprocess dispatch, or `run_in_background` tasks of non-trivial duration. With ADR-032's subprocess-boundary iteration pattern now canonical for AFK loops, this is the *default* operation mode for `/wr-itil:work-problems`.
- **Frequency**: Every AFK iteration at scale. Observed ~1 per 4 iterations in recent AFK runs; expected to rise as iteration durations grow.
- **Severity**: Moderate per occurrence, but systemic. Each re-delegation cycle burns wall-clock + context budget; repeated hits compound the effect on JTBD-001's under-60-second target.
- **Long-term drift**: Each hit that gets papered over with a TTL bump normalises the gap. Eventually TTL reaches "effectively infinite" and the gate stops enforcing recency, defeating the purpose of having a marker lifecycle at all.

## Root Cause Analysis

### Preliminary Hypothesis

The gate-marker design assumes **one session, one marker, serial tool calls**. It does not model subprocess boundaries.

Three fix-shapes to consider:

1. **Subprocess-completion refresh.** When a subprocess returns (Agent tool completion, `claude -p` exit), the parent's `PostToolUse` hook touches the parent's marker. This treats subprocess duration as "continuous work" for TTL purposes. Simple, preserves the marker-lifecycle invariant. Risk: a failed subprocess shouldn't extend the trust window.

2. **Inherited-marker subprocesses.** Subprocesses look up and touch the parent session ID's marker in addition to their own. Requires a way to pass the parent session ID into the subprocess environment (env var, `CLAUDE_PARENT_SESSION_ID`). Risk: subprocess can extend parent's trust beyond what the parent agent intended.

3. **Event-based invalidation instead of TTL.** Drop TTL entirely; invalidate the marker on ADR file hash change (already implemented for architect), JTBD file hash change, risk-policy file hash change, etc. Current code already does `STORED != CURRENT` drift detection — TTL becomes redundant if drift-based invalidation is reliable. Risk: a silent trust window of indefinite length if no drift fires.

Option 1 is the smallest change and preserves the invariant. Option 3 is the most architecturally clean but needs auditing of what currently depends on TTL-based expiry (e.g., the "session restart = fresh gate" expectation).

### Investigation Tasks

- [ ] Audit the five gate libraries (architect, jtbd, style-guide, voice-tone, risk-scorer) for the exact touch/check semantics; confirm they all share the bug.
- [ ] Audit the three subprocess dispatch paths (Agent tool, `claude -p` via iteration-workers, nested skill subprocesses) for whether they have access to the parent session ID.
- [ ] Confirm ADR-009 (gate-marker lifecycle) does not implicitly forbid subprocess-completion refresh, or if it does, amend it.
- [ ] Decide between Option 1 (subprocess-completion refresh), Option 2 (inherited marker), and Option 3 (drop TTL / drift-only) — or a hybrid.
- [ ] Behavioural test: construct an Agent-tool delegation that runs >TTL seconds and verify the parent's next PreToolUse check doesn't deny.

### Fix Strategy

**Shape**: Architecture + hook library.

**Target ADR**: `docs/decisions/009-gate-marker-lifecycle.proposed.md` — amendment for subprocess-boundary refresh semantics.

**Target files**: `packages/{architect,jtbd,style-guide,voice-tone,risk-scorer}/hooks/lib/*-gate.sh` (shared gate-helpers if applicable), plus matching PostToolUse hook extensions.

**Evidence**:
- Hook source `packages/architect/hooks/lib/architect-gate.sh:36,40` implements sliding-window refresh via `touch "$MARKER"` — confirming the design intent is "continuous work keeps the marker fresh".
- P107 observation (from the P107 ticket): markers expired mid-batch during a 12+ file write that took ~40 minutes — the individual tool calls *were* triggering the hook, but a subprocess inside that window was not.
- Commit 9a1f96c inflated TTL to 3600s; the fix closed P107 but the parent/subprocess session-ID asymmetry was not addressed in ADR-009's amendment.

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none)
- **Composes with**: P107 (the TTL-inflation symptom-treatment that this ticket roots), P086 (subprocess-boundary retro-on-exit — similar subprocess-boundary design concern), ADR-032 (subprocess-boundary iteration pattern — the design context for why this matters now).

## Related

- **ADR-009** (`docs/decisions/009-gate-marker-lifecycle.proposed.md`) — current gate-marker lifecycle; would need amendment for any fix-shape that changes TTL semantics.
- **ADR-032** (`docs/decisions/032-governance-skill-invocation-patterns.proposed.md`) — subprocess-boundary iteration pattern. This ticket is an operational consequence.
- **P107** (`docs/problems/107-architect-jtbd-edit-gate-markers-expire-mid-batch.closed.md`) — the symptom P107 fixed via TTL inflation. This ticket tracks the root cause.
- **P090** (`docs/problems/090-risk-scorer-commit-gate-ttl-expires-mid-session-forcing-manual-rescore.open.md`) — risk-scorer commit-gate expiry; same shape at a different gate layer.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — under-60-second target. Every re-delegation cycle eats into this budget.
