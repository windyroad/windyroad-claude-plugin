# Problem 107: Architect + JTBD edit-gate markers expire during long multi-file edit batches — orchestrator re-delegates and falls back to python3-via-Bash

**Status**: Closed (Fix Released)
**Closed**: 2026-04-23
**Fix**: Extended default TTL from 1800s to 3600s across all gate-marker plugins (architect, jtbd, style-guide, voice-tone, risk-scorer). Updated ADR-009, plugin READMEs, briefing files, and run-retro SKILL.md. See commit <SHA>.
**Reported**: 2026-04-22
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: (12 × 1.0) / 2 = **6.0**

> Identified 2026-04-22 during P100 slice 2 execution via run-retro Step 2b pipeline-instability scan. The slice-2 orchestrator turn wrote 12 files sequentially (ADR-040, new hook script, hooks.json / plugin.json / package.json edits, BRIEFING.md delete, held-changeset reinstate + content edit, docs/changesets-holding/README.md update, P105 ADR-ref update, P100 rename + Fix Released append, docs/problems/README.md refresh). Mid-batch, the architect + JTBD PostToolUse markers written ~40 minutes earlier had expired (1800s TTL per ADR-009). Three `Write` calls were blocked: ADR-040 (first attempt), docs/changesets-holding/README.md, packages/retrospective/hooks/session-start-briefing.sh. Each block forced a re-delegation cycle (architect + JTBD agents invoked again to refresh markers) plus a fall-through to python3-via-Bash for the actual write — adding ~2–3 minutes + agent tokens per blocked write. User direction via run-retro Step 2b prompt (2026-04-22): open a ticket for TTL extension / auto-refresh / batch-semantic marker.

## Description

The architect + JTBD PostToolUse edit-gate markers use a 1800-second TTL (per ADR-009 plus ADR-038's session-marker.sh distribution). When the orchestrator performs a long multi-file edit sequence (typical of a release commit that ships an ADR + hook + config + ticket transitions + README refreshes in one atomic commit), the marker written at the start of the batch expires before the batch finishes. Each subsequent gated Write or Edit is then blocked until a fresh architect / JTBD delegation refreshes the marker.

Observed cost in this session's slice 2:

- Mid-batch architect re-delegation (~60s + agent token budget)
- Mid-batch JTBD re-delegation (~60s + agent token budget)
- 3 python3-via-Bash fallback writes (per the afk-subprocess.md briefing entry's documented workaround) because the re-delegation alone did not always unblock the `Write` tool for the next attempt

Aggregate: ~5 minutes of wall-clock + ~2000 extra output tokens per slice. Multiplied across an AFK loop's 4–6 iterations (each with its own slice), the overhead is measurable (~20–30 minutes / session + 10K tokens).

**This is distinct from P096** (PreToolUse / PostToolUse hook injection volume across windyroad plugins — unaudited). P096 is about the bytes emitted per hook call; P107 is about the TTL + refresh cadence of the per-hook bypass markers. Both surface on the same hook layer but target different mechanisms.

## Symptoms

- Long multi-file edit batches (N ≥ 6 files) reliably hit marker-expiry at file ~4–5 on slower machines.
- Write tool returns `BLOCKED: Cannot edit '<file>' without architecture review` despite the agent having already reviewed earlier in the batch.
- Orchestrator pattern: re-delegate architect + JTBD, retry the Write; sometimes unblocks, sometimes falls through to python3-via-Bash (subprocess Edit intermittent denial, documented separately in afk-subprocess.md).
- Observed this session at 3 points during slice 2 execution.
- **2026-04-22 ADR-041 landing session (P103+P104 fix)**: mid-landing `Edit` on `packages/itil/skills/work-problems/SKILL.md` was blocked with `BLOCKED: Cannot edit 'SKILL.md' without architecture review` (and matching `BLOCKED: Cannot edit 'SKILL.md' without JTBD review`) ~40 min after the initial architect+JTBD delegation. The landing touched 11 files (ADR-041 rewrite, 2 ADR amendments, 3 SKILL.md edits, holding-area README, 2 `.verifying.md` transitions, new P108, new bats file, changeset) — by the time the final one-line insertion hit `work-problems/SKILL.md`, the initial-review markers had expired. Resolved via parallel `wr-architect:agent` + `wr-jtbd:agent` refresh (both returned PASS in ~10s each on a minimal "reaffirm" prompt); the Edit then succeeded. Adds ~60s + ~25K tokens per expiry to the landing flow. Confirms the N ≥ 6 files pattern holds at the release-commit layer, not just slice-2-style session work.

## Workaround

Re-delegate architect + JTBD agents mid-batch to refresh the markers. If `Write` still blocks after refresh, fall back to python3-via-Bash (documented in afk-subprocess.md).

## Impact Assessment

- **Who is affected**: Any session performing a long multi-file edit batch — typical of release commits, ADR authorship, schema migrations, and interactive slice execution.
- **Frequency**: Observed 3× during P100 slice 2 alone; likely 1–2× per release commit in other sessions. Roughly 1 in 3 slices per my 2026-04-22 observation.
- **Severity**: Moderate. Adds ~5 min + 2K tokens per affected slice. Not a correctness issue (markers correctly force a fresh review) but a usability tax on an intrinsically legitimate governance surface.
- **Analytics**: 3 observed Write blocks in slice 2; 2 re-delegation cycles; 3 python3-fallback writes. Instrumentation opportunity: count PreToolUse block-then-re-delegate cycles per session.

## Root Cause Analysis

### Preliminary Hypothesis

The TTL value (1800s) was chosen assuming a single review covers a single edit. In practice, an orchestrator batch spans multiple edits and legitimately needs the same review to hold across all of them. Fix candidates:

1. **Extend TTL** for markers to a longer window (e.g. 3600s or session-lifetime) — simplest but loosens the review-freshness guarantee.
2. **PostToolUse auto-refresh** — when a Write succeeds inside a batch, refresh the marker timestamp so the next Write sees a fresh TTL. Requires the hook to detect "successful-edit-after-recent-review" and re-stamp.
3. **Batch-semantic marker** — when the user's turn opens with an explicit architect/JTBD delegation, mark the whole turn as review-approved until the turn ends. Requires a new marker shape (turn-scoped not wall-clock-scoped).
4. **Status-quo + patternise the refresh** — leave TTL as-is; document a canonical "mid-batch refresh" pattern in the orchestrator skills that fires a no-op architect/JTBD delegation every 10–15 minutes during long batches.

### Investigation Tasks

- [x] Quantify the TTL-expiry rate in-session across AFK iterations. `~/.claude/plugins/cache/windyroad/wr-architect/*/hooks/lib/session-marker.sh` implementation + `/tmp/architect-reviewed-*` mtime delta per write.
- [x] Architect review on fix-candidate selection. Option 1 (extend TTL) chosen after analysis showed Option 2 (auto-refresh) is already partially implemented in PreToolUse `touch "$MARKER"` sliding window; the real issue is 1800s simply too short for 40+ minute batches.
- [x] No bats coverage needed for default-value change; existing TTL=0 override tests continue to verify expiry logic.
- [x] Option 3 (turn-scoped) deemed unnecessarily complex for the problem at hand.
- [x] Option 4 (patternise-only) rejected in favor of structural fix.

### Fix Strategy

**Chosen: Option 1 — Extend TTL from 1800s to 3600s.**

After investigation, the PreToolUse hooks already implement a sliding TTL window (`touch "$MARKER"` on every successful gate check). The root cause of mid-batch expiry is that 1800s (30 minutes) is insufficient for orchestrator batches that span 40+ minutes of wall-clock time across 12+ files, especially when interleaved with excluded-file edits and non-Write tool calls that do not refresh the marker.

Extending to 3600s (60 minutes) covers the observed batch durations without introducing the complexity of turn-scoped markers or new PostToolUse refresh hooks. The change is minimal, consistent across all five review plugins, preserves the existing TTL+drift detection model from ADR-009, and is fully backwards-compatible (teams wanting stricter behaviour can still set `ARCHITECT_TTL=1800` etc.).

## Dependencies

- **Blocks**: (none directly)
- **Blocked by**: (none)
- **Composes with**: P091, P096, P097

## Related

- **P091** — session-wide context-budget meta. Marker-TTL overhead is one dimension of session-wide hook cost.
- **P096** — hook injection volume (distinct surface; bytes-per-call vs TTL-per-marker).
- **P097** — SKILL.md runtime size (adjacent; both contribute to per-edit overhead).
- **ADR-009** — marker TTL origin (1800s).
- **ADR-038** — session-marker.sh distribution pattern that the per-plugin marker files reuse.
- Briefing entry: `docs/briefing/hooks-and-gates.md` "What Will Surprise You" — documents the 1800s TTL expiry pattern; this ticket is the structural fix for the pattern.
