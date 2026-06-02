# Problem 163: `wr-risk-scorer:external-comms` agent emits placeholder marker key on first invocation when prompt doesn't direct shasum computation

**Status**: Closed
**Reported**: 2026-05-04
**Priority**: 6 (Medium) — Impact: Moderate (3) x Likelihood: Possible (2)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

**WSJF**: (6 × 1.0) / 2 = **3.0**

> Captured 2026-05-04 by `/wr-itil:work-problems` AFK loop iter 7 surfacing pass per user direction "capture all four now". Sibling finding from iter 1 P154 commit gate cycle. See P166 for the related double-invocation cost finding (same surface, same agent).

## Description

The `wr-risk-scorer:external-comms` subagent (per ADR-028 / P064) is invoked at outbound prose risk-leak gate time on every changeset / release / PR-comment surface. The PostToolUse hook expects the agent to emit `EXTERNAL_COMMS_RISK_VERDICT: PASS` with a `marker_key=<sha256-hex>` so the gate can write `/tmp/claude-risk-${SID}/external-comms-reviewed-<sha>` and unblock subsequent identical-content invocations.

Observed iter 1 P154 (and recurring iter 3 P156, iter 4 P157, iter 6 P159, this iter's move-to-holding commit): on first invocation, the agent emits a **placeholder** key string instead of computing `sha256(draft+'\n'+surface)`. PostToolUse hook rejects non-hex keys; the gate stays denied. Workaround: the orchestrator (or invoking agent) computes the sha256 in Bash, re-prompts the agent with the precomputed key explicitly named, agent emits PASS with that key, hook accepts, gate unlocks.

Affects every changeset / release / PR-comment / commit-message review path. Each gate cycle pays the double-invocation cost (~$0.05 per gate per agent fire — see P166).

## Symptoms

- Gate cycles see two `wr-risk-scorer:external-comms` agent fires where one should suffice.
- First fire's verdict carries placeholder/non-hex marker key; second fire (with explicit precomputed key) carries valid key.
- Pattern observed across 5+ commits this AFK loop (P154, P156, P157, P159, c326106 move-to-holding).

## Workaround

Invoking agent precomputes `sha256` in Bash, includes it in the agent prompt explicitly. Single fire then suffices. See iter 1 / iter 3 / iter 4 / iter 6 retro notes for the workaround's exact mechanic.

## Impact Assessment

- **Who is affected**: Plugin-developer authoring changesets / release commits / PR comments. Every commit-gate cycle currently pays the double-fire cost.
- **Frequency**: Every commit-gated surface. ~5+ instances per AFK loop.
- **Severity**: Moderate — workaround works; cost is per-cycle, not catastrophic.
- **Likelihood**: Possible — pattern is repeatable; each new contributor following SKILL.md instructions hits it on first attempt.

## Root Cause Analysis

(Deferred to investigation.)

Hypothesis: the agent's SKILL.md instructs it to compute the sha256 but the agent's tool surface (per ADR-028) does not include Bash, so the computation is impossible inside the agent — the agent emits a placeholder it expects the orchestrator to override. The contract mismatch is between SKILL.md-stated behaviour ("compute sha256(...)") and tool-surface reality ("no Bash available").

### Investigation Tasks

- [ ] Investigate root cause — confirm hypothesis re tool-surface mismatch.
- [x] **Decide fix shape**: ~~(a) grant Bash to the agent~~, (b) move sha256 computation to PostToolUse hook, (c) document explicit-precompute pattern. **User direction 2026-05-13** picked **(a) grant agent Bash for sha256 only** (during `/wr-itil:work-problems` Step 6.75 halt Step 2.5b surfacing — Q2 answer). Narrow tool grant: agent runs `shasum -a 256` via Bash; preserves agent-side key computation. Bundle with TMPDIR-variance fix per Q3 answer — shared helper handles both root causes.
- [ ] Architect review on the chosen direction (grant-Bash-for-sha256-only) — sibling to ADR-028 / P064. Narrow-tool-grant precedent: confirm whether ADR-028's "no Bash" constraint admits a sha256-only subset, or requires amendment.
- [ ] Implement: amend `packages/risk-scorer/agents/external-comms.md` allowed-tools + agent prompt; the agent must `Bash(shasum:*)` (or equivalent narrow grant) and `printf '%s\n%s' "$DRAFT" "$SURFACE" | shasum -a 256 | cut -d' ' -f1` to emit the canonical key.
- [ ] TMPDIR-variance bundle (Q3): shared `${TMPDIR:-/tmp}` resolution helper consumed by ALL gate hooks (external-comms + sibling per-gate marker writers) so PostToolUse and PreToolUse resolve to the SAME path on macOS. Observed 2026-05-04 (P124-sibling — same UUID-stale class, different surface) and 2026-05-13 P185 iter 2 retro (3 distinct dirs per session_id). Per the iter 2 retro's "Pipeline Instability" entry on TMPDIR.
- [ ] Behavioural bats: agent emits sha256 key matching gate-side computation; TMPDIR helper resolves identically across PostToolUse hook and PreToolUse gate; previously-noted manual-marker workaround in `hooks-and-gates-archive.md` becomes obsolete.

## Fix Strategy

**Direction (user 2026-05-13)**: Grant `wr-risk-scorer:external-comms` agent narrow Bash access (`shasum` only) so it computes the canonical sha256 key itself, eliminating the placeholder-key class. Bundle with TMPDIR-variance fix (shared `${TMPDIR}` resolution helper) so PostToolUse marker writes land where PreToolUse gates look. Together they retire the manual-pre-bind workaround documented in `hooks-and-gates-archive.md`.

**Direction reversal (2026-05-16)**: superseded in favour of P166's hook-side-compute path (fix shape (b) per the original investigation enumeration). The (b) approach closes both P163 AND P166 in one go where (a) only addressed P163, and preserves ADR-013 Rule 2 ("scoring/analysis agents remain pure output-only — tools stay [Read, Glob]") instead of eroding it with a narrow-Bash grant precedent. Architect verdict on the reversal: PROCEED. See ADR-028 amendment 2026-05-16 for the contract change.

The narrow-Bash + TMPDIR-helper plan is no longer needed — the PostToolUse hook now derives the marker key directly from the prompt's `SURFACE: <name>` + `<draft>...</draft>` structure (single shared helper `packages/shared/hooks/lib/external-comms-key.sh`). The agent emits only `EXTERNAL_COMMS_<EVAL>_VERDICT` + optional `_REASON` on FAIL — no key field, no Bash dependency, single fire per gate cycle. Both P163 and P166 close in the same commit per ADR-014.

## Fix Released

Released 2026-05-16 in the same commit as P166. The placeholder-key class is eliminated by removing the agent's key-emit responsibility entirely — the hook computes the canonical sha256 from observable prompt structure. Backward-compat fallback to the agent-emitted KEY line preserved for one release cycle to cover cached-old-prompt rollover. Awaiting user verification: confirm the next changeset commit-gate cycle does not exhibit the placeholder-key class (single-fire path lands the marker directly).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P064 (parent — external-comms gate), P166 (sibling — precomputed-sha256 helper for the double-invocation cost), ADR-028 (external-comms agent surface), ADR-013 Rule 5 (policy-authorised gate)

## Related

- ADR-028 (`docs/decisions/028-external-comms-risk-scoring.proposed.md`) — parent decision; agent surface contract.
- P064 (`docs/problems/064-no-risk-scoring-gate-on-external-comms.verifying.md`) — parent problem; held in changesets-holding awaiting dogfood evidence.
- P166 (this loop's iter 4 sibling finding — precomputed-sha256 helper).
- iter retros: `docs/retros/2026-05-03-p154-iter.md`, `docs/retros/2026-05-03-p156-iter.md`, `docs/retros/2026-05-03-p157-iter.md`, `docs/retros/2026-05-04-p159-iter.md`.

## Change Log

- **2026-05-04** — Opened by orchestrator's main turn at end of `/wr-itil:work-problems` AFK loop iter 7 per user direction "capture all four now". Skeleton ticket; investigation deferred.
- **2026-05-13** — Updated by orchestrator's main turn at end of `/wr-itil:work-problems` Step 6.75 halt (Step 2.5b surfacing Q2 + Q3 answers). User direction selected fix shape (a) grant agent narrow Bash for sha256; bundled with TMPDIR-variance fix per Q3. Investigation Tasks updated to reflect direction; Fix Strategy section populated. Adjacent friction empirically observed iter 1 + iter 2 of the current session (every changeset-author Write costs 1 extra round-trip; iter 2 retro hit it explicitly when it could not commit its own retro files until orchestrator-side manual marker pre-bind worked the issue).
- **2026-05-16** — Fix-strategy reversal. Original 2026-05-13 direction (option a — grant agent narrow Bash) superseded in favour of option b (hook-side compute) per architect + JTBD review under P166. Option b closes both P163 and P166 simultaneously while preserving ADR-013 Rule 2's "agents stay [Read, Glob] only" discipline. Implementation landed in same commit as P166 transition: shared helper `packages/shared/hooks/lib/external-comms-key.sh` derives sha256 from agent prompt's `SURFACE:` + `<draft>` structure; PostToolUse mark hooks consume the helper; agent surface contract no longer requires `EXTERNAL_COMMS_<EVAL>_KEY`. ADR-028 amendment 2026-05-16 documents the reversal explicitly. Transitioned to Verification Pending — awaiting user dogfood confirmation that the placeholder-key class is eliminated.

## Closed 2026-05-26

Closed (Verification Pending → Closed) during the P283 prong-2 drain surfacing, per user direction. **Verification evidence**: incidentally exercised successfully while authoring the P262 changeset — the external-comms evaluators emitted PASS with NO agent-side key computation (the agent no longer emits or computes the marker key), and the hook-side `sha256(DRAFT + '\n' + SURFACE)` derivation matched on the retry Write. Confirms the P166 option-b hook-side-compute fix (which closed P163's reversal) works end-to-end.
