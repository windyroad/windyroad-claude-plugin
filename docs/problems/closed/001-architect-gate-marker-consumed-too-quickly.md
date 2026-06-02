# Problem 001: Architect Gate Marker Consumed Too Quickly

**Status**: Closed
**Reported**: 2026-04-14
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)

## Description

The architect gate marker gets consumed or expires between tool calls within a single prompt turn, requiring the architect agent to be re-invoked multiple times for what is logically a single review cycle. This adds latency and token cost to every session that involves multiple file edits.

## Symptoms

- After one architect review, the first Edit/Write succeeds but subsequent edits in the same turn are blocked with "BLOCKED: Cannot edit ... without architecture review"
- The developer must re-invoke the architect agent before each additional edit, even though the architectural context hasn't changed
- Sessions with 4+ file edits require 2-3 architect agent invocations per prompt turn

## Workaround

Batch all Write/Edit calls together after a single architect review. If the marker expires mid-turn, re-invoke the architect agent with a brief prompt referencing the prior review.

## Impact Assessment

- **Who is affected**: All developers using the architect plugin
- **Frequency**: Every session with multiple file edits
- **Severity**: Medium — adds ~30-60s and token cost per re-invocation
- **Analytics**: N/A

## Root Cause Analysis

### Confirmed Root Cause (2026-04-15)

The **Stop hook** (`packages/architect/hooks/architect-reset-marker.sh`) removes the marker at the end of every assistant response:

```bash
rm -f "/tmp/architect-reviewed-${SESSION_ID}"
rm -f "/tmp/architect-reviewed-${SESSION_ID}.hash"
```

Claude Code's `Stop` event fires when the assistant finishes responding. So every new user prompt requires a fresh architect review — even when no architectural context has changed.

The same pattern exists in **all 5 review plugins**:
- `architect/hooks/architect-reset-marker.sh`
- `jtbd/hooks/jtbd-reset.sh`
- `voice-tone/hooks/voice-tone-reset-marker.sh`
- `style-guide/hooks/style-guide-reset-marker.sh`
- `risk-scorer/hooks/...-reset.sh`

The user-facing symptom ("multiple re-reviews per prompt turn") is slightly inaccurate — it's actually "re-review every prompt (every assistant response)". Still painful in the same way.

### The conflict

The gate library (`architect-gate.sh::check_architect_gate`) already implements TTL + drift detection:

- **TTL**: 30 min (`ARCHITECT_TTL=1800`), sliding window (`touch "$MARKER"` on each check)
- **Drift detection**: hash of `docs/decisions/*.md`; mismatch invalidates marker

These two controls are sufficient to determine when re-review is genuinely needed:
- TTL expiry → obvious stale review
- Drift (decisions changed) → needs re-review for new context
- Neither → review is still valid

The Stop reset hook **overrides** this design, forcing re-review on every turn regardless of TTL or drift.

This conflicts with JTBD-001's documented outcome: *"Reviews complete in under 60 seconds so they don't break flow."* Re-reviewing on every prompt routinely blows past 60s.

### Fix Strategy (requires ADR)

**Proposed: remove the Stop reset hooks across all 5 plugins.** Rely on TTL + drift detection (and per-plugin drift-tracked files like `docs/jtbd/`, `docs/VOICE-AND-TONE.md`, etc.).

Because this change affects 5 plugins and is a meaningful behaviour shift, it needs an ADR. Options to document:

1. **Always reset on Stop** (status quo) — safest, most overhead
2. **TTL + drift only** (no Stop reset) — lowest friction, relies on drift detection being comprehensive
3. **Hybrid** — reset some marker types (e.g., ephemeral verdicts) but keep the long-lived review markers

Recommendation: Option 2. The TTL is 30 minutes, plenty of time for most dev sessions. Drift detection already catches the actual invalidation condition (policy files changed).

### Investigation Tasks

- [x] Investigate whether PostToolUse hook deletes marker — no, only Stop hook does
- [x] Check if drift detection triggers on decision files written in same session — works correctly (`architect-refresh-hash.sh` updates stored hash post-write)
- [x] Determine if marker is single-use by design — no, it's session-per-response by design via Stop hook
- [x] Confirm TTL + drift would handle the case — yes, both are already implemented
- [x] ADR-009 written and committed
- [x] Implemented Option 2: removed Stop reset hooks + hooks.json entries from all 5 plugins (architect, jtbd, voice-tone, style-guide, risk-scorer)
- [x] Existing BATS tests continue to pass (113/113) — gate lifecycle now relies solely on TTL + drift

## Related

- `packages/architect/hooks/lib/architect-gate.sh` — gate logic with TTL and drift detection
- `packages/architect/hooks/architect-mark-reviewed.sh` — PostToolUse marker creation
- `packages/architect/hooks/architect-refresh-hash.sh` — PostToolUse hash refresh
