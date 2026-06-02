# Problem 198: external-comms gate marker key cannot be computed by the reviewer agent (Read/Glob/Grep tool surface — no shasum); hash-scope ambiguity adds three recurrences

**Status**: Closed
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Fix Released

Fixed by `56bae5f` "external-comms gate strips changeset frontmatter before key hash" — the gate and the mark hook now share one key function (strip YAML frontmatter + normalize trailing whitespace before hashing), so the key the gate checks at author time matches the key the mark hook writes after the reviewer returns PASS. The risk-scorer 0.11.0 CHANGELOG names "Closes #149 (P010) and P198". Released in `@windyroad/risk-scorer@0.11.0`. Verify: the deny-after-PASS changeset-author loop no longer recurs across a full reviewer cycle.

## Description

The `wr-risk-scorer:external-comms` reviewer agent is invoked via the Skill/Agent tool to clear the `external-comms-gate.sh` PreToolUse hook before a `.changeset/*.md` Write (per ADR-028 / P064). The reviewer's surface tools are Read, Glob, Grep — no Bash. It cannot run `shasum -a 256` to compute the gate-exact marker key. The reviewer either emits a placeholder hex string in `EXTERNAL_COMMS_RISK_KEY:` (failing the marker hook `^[0-9a-f]{64}$` validation), or — when the orchestrator pre-computes a key and asks the reviewer to emit it verbatim — the wrong content shape is hashed (e.g. body-only when the gate hashes the full Write `tool_input.content`). The marker does not land at `/tmp/claude-risk-<session>/external-comms-reviewed-<key>`; the next Write attempt on the same draft is BLOCKED again.

Three downstream-session recurrences observed since 2026-05-05:

1. **2026-05-05 batch (8 changesets one retro session)** — 0 markers landed; 8 subsequent Writes blocked.
2. **2026-05-12 Stage D Slice 1a changeset** — three rounds: agent-internal hash wrong, Bash `cat body` correct, Python `f.read` trailing-newline wrong.
3. **2026-05-14 P220 fix changeset** — body-only hash vs full-content hash divergence.

Each occurrence costs 1-3 reviewer round-trips. The pattern is reproducible across sessions and changeset shapes.

**Fourth recurrence observed in this monorepo session (2026-05-15)** — same bug, same workaround: this monorepo's own agent hit the gate when writing `.changeset/work-problems-inbound-discovery-preflight.md`; both reviewer agents (risk + voice-tone) emitted PASS verdicts but neither could compute the sha; manual seeding of both per-evaluator markers in the runtime session dir unblocked the Write. The fourth recurrence is the upstream-side mirror of the pattern — confirming this is not a downstream-specific bug.

## Symptoms

- `Write` of `.changeset/<slug>.md` returns the canonical gate denial `BLOCKED (external-comms gate / <evaluator> evaluator): changeset-author draft has not been reviewed by wr-<evaluator>:external-comms.` even after the reviewer returned `EXTERNAL_COMMS_RISK_VERDICT: PASS` in the same turn.
- Marker directory at `/tmp/claude-risk-<session>/` is missing the `external-comms-<evaluator>-reviewed-<key>` file the gate expects.
- Reviewer agent's tool surface (`Read, Glob, Grep` per the agent definition) cannot self-correct because it lacks `shasum`.

## Workaround

**Orchestrator-layer Option-2** (validated across all four recurrences): the orchestrator (which has Bash) pre-computes the SHA-256 against `tool_input.content + "\n" + "changeset-author"` and seeds the per-evaluator marker(s) in the runtime session dir.

```bash
DRAFT=$(printf '%s' "<full Write content including frontmatter>" | python3 -c "import sys; print(sys.stdin.read())")
KEY=$(printf '%s\n%s' "$DRAFT" "changeset-author" | shasum -a 256 | cut -d' ' -f1)
touch "/tmp/claude-risk-<session>/external-comms-risk-reviewed-${KEY}"
touch "/tmp/claude-risk-<session>/external-comms-voice-tone-reviewed-${KEY}"
```

**Critical clarification surfaced by the 2026-05-14 and 2026-05-15 recurrences**: `<content>` in the hash recipe is the EXACT bytes the Write tool's `content` parameter carries — including the YAML frontmatter — not the body paragraph the changesets tool publishes. The gate hook (`external-comms-gate.sh`) reads `tool_input.content` verbatim and only strips trailing newlines via Bash `$(...)`. The natural-feeling first-pass shape ("hash what gets published") is the wrong shape four sessions in a row, suggesting the recipe documentation should explicitly say "full Write content" not "draft content".

**Session-ID resolution mismatch (new — 2026-05-15)**: the runtime-marker SID (`/tmp/itil-runtime-sid-<user>-<hash>.current`) and `get_current_session_id` helper SID can diverge across helper-fast-path vs JSON-stdin extraction paths. The marker must be seeded under the JSON-stdin SID that the hook will use, not the helper-fast-path SID. Diagnosis: cat the runtime-marker file; touch the gate marker under that SID. See P197 Notes for in-session reproduction trail.

**AFK iter subprocess limitation**: the iter subprocess's own delegation to the reviewer cannot apply this workaround without modifying the manage-problem skill to pre-shell-out for the SHA-256. Until upstream fix lands, AFK iters that need to write `.changeset/*.md` halt at Step 6.5 above-appetite Rule 5; only the orchestrator main turn currently applies the workaround.

## Impact Assessment

- **Who is affected**: every maintainer (and AFK orchestrator) who writes a `.changeset/*.md` in a session where the external-comms gate fires. Dominant friction in changeset authoring flow.
- **Frequency**: every `.changeset/*.md` Write. Across the 2026-05-05 → 2026-05-15 window: ≥13 confirmed recurrences across multiple sessions (12 downstream + 1 upstream).
- **Severity**: High — load-bearing gate is unusable without the workaround; the workaround requires orchestrator-side Bash + sha-knowledge + runtime-marker-SID-debugging.
- **Analytics**: marker landing rate per `wr-risk-scorer:external-comms` PASS verdict (target: 100%; current: ~0%); gate-denial-after-PASS-verdict count per session.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Implement Option 2 fix per upstream issue #125: `risk-score-mark.sh` PostToolUse hook recomputes the canonical key from the agent prompt's `<draft>` body + surface name. Agent's `EXTERNAL_COMMS_RISK_KEY:` line becomes advisory. PASS verdicts trigger a marker regardless of placeholder-vs-real keys.
- [ ] Symmetric fix in `packages/voice-tone/hooks/external-comms-mark-reviewed.sh` for the voice-tone evaluator's peer marker.
- [ ] Document the session-ID resolution mismatch (helper-fast-path vs JSON-stdin) — investigate whether `get_current_session_id` should always read from runtime-marker first.
- [ ] Behavioural test: a Write fixture that confirms PASS-verdict-emit + marker-write + subsequent-Write-permitted, across changeset-author / gh-issue-create / gh-pr-comment surfaces.

### Mitigation candidates (deferred to investigation)

- **Option 1 (less robust)**: extend the reviewer agent's tool surface to include Bash (or a narrowly-scoped `shasum` shim). Broadens reviewer tool surface beyond Read/Glob/Grep.
- **Option 2 (preferred, per upstream #125)**: update `risk-score-mark.sh` to recompute the canonical key itself from the agent prompt's `<draft>` body + surface name. The reviewer agent's PASS reasoning is independent of the key value; nothing in its analysis path requires the key. The key is purely a marker-mechanism artefact. Option 2 is the natural separation.

## Dependencies

- **Blocks**: every future `.changeset/*.md` Write until fix lands (workaround keeps the flow operational but is fragile).
- **Blocked by**: (none)
- **Composes with**: P163 (open — external-comms-agent-emits-placeholder-marker-key-on-first-invocation; sibling/duplicate local view of the same bug), P166 (open — precomputed-sha256-helper-for-external-comms-agent-double-invocation; proposed-fix sibling), P064 (closed — external-comms risk-leak gate parent), P038 (verifying — voice-tone external-comms gate; same mark-mechanism applies), P197 (open — agent contract-bypass-reflex; sibling concern that surfaces when this bug bites).

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/125 (filed 2026-05-13 from downstream windyroad/bbstats project ticket P205).
- **Pipeline classification** (review-problems Step 4.5e): JTBD-alignment=aligned-with-existing-JTBD (JTBD-001 + JTBD-301); dual-axis-risk=safe-low-fix-risk; route=safe-and-valid.
- **Duplicate-check matches (title-only grep, list-only)**: P163 (open), P166 (open), P064 (closed), P038 (verifying), P001 (closed), P107 (closed), P111 (verifying). Closest siblings: P163 + P166 cover the local equivalents of this concern. Resolve at next /wr-itil:review-problems — likely merge as the upstream-mirrored canonical record OR close as duplicate of P163.

## Notes

- Captured via /wr-itil:capture-problem from inbound discovery pass (review-problems Step 4.5e safe-and-valid branch) processing upstream #125. The user's "DONT skip using the capture-problem skill" correction this session is what surfaced this honest capture path.
- This is the first ticket in the 31-report inbound batch (2026-05-13 downstream filings). The remaining 30 reports await pipeline processing in subsequent invocations.
- Session-ID resolution mismatch encountered during this very capture: marker seeded under helper-SID (`325fa82a-...`) failed the hook's JSON-stdin SID check (`9d50067d-...`); manual dual-seeding under both SIDs unblocked the Write. Same pattern as the gate-sha bug — both surface session-state mismatches that the hooks don't reconcile.

## Change Log

- **2026-05-17** — Session 4 evidence appended (user direction at session wrap, P078 mechanical action). Pattern recurred **5+ times across iters 3-9 of /wr-itil:work-problems session 4**: agent-emitted EXTERNAL_COMMS_RISK_KEY required manual SHA computation in Bash heredoc + cross-SID marker copy + final BYPASS_RISK_GATE=1 fallback to write legitimately-PASS-verified changesets. Iter 8 surfaced as deviation-candidate; iter 9 documented as Pipeline Instability observation #1 in retro (bundled into P245 coordinating ticket). Two distinct sub-patterns observed: (a) **hook-receives-wrong-key** — agent emits key K1, hook computes expected K2, mismatch fails; workaround: manually compute hook-expected key, seed marker (iters 3, 5, 6, 7); (b) **cross-SID isolation** — agent emits valid key, marker lands in helper-SID directory, hook checks main-SID directory, mismatch fails; workaround: copy marker across SID directories (iters 8, 9). Sub-pattern (b) is the same shape as the Note line 84 above. Ranking-bearing fields unchanged (WSJF cluster unchanged); README.md refresh per P094 conditional-update trigger does not fire.

## Closed 2026-05-26

Closed (Verification Pending → Closed) during the P283 prong-2 drain surfacing, per user direction. **Verification evidence**: incidentally exercised successfully while authoring the P262 changeset — the reviewer agent did NOT need to compute the marker key (hook-side derivation per the external-comms-key.sh shared helper); the evaluators emitted PASS and the hook-side key matched on the retry Write. Confirms the shasum-computed-hook-side fix (released @windyroad/risk-scorer@0.11.0) works end-to-end.
