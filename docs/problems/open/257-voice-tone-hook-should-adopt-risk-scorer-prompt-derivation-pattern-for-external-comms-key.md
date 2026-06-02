# Problem 257: voice-tone hook should adopt risk-scorer's prompt-derivation pattern for EXTERNAL_COMMS_VOICE_TONE_KEY

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

User-approved deviation-candidate from iter 8 + iter 10 of `/wr-itil:work-problems` session 6 (2026-05-18). The voice-tone evaluator hook (`packages/voice-tone/hooks/external-comms-mark-reviewed.sh`) reads the agent-emitted `EXTERNAL_COMMS_VOICE_TONE_KEY` literally — meaning the agent must emit a pre-computed 64-hex-char key in its verdict that matches what the gate computed. The risk-scorer hook (0.10.0) has already evolved to derive the key from the prompt structure via the shared `derive_external_comms_key_from_prompt` helper at `packages/shared/hooks/lib/external-comms-key.sh`.

This asymmetry between the two evaluator hooks is the recurring friction surface — agents calling the voice-tone evaluator end up fabricating placeholder hex keys (e.g. `5f7a2c1d...`, `6c8f3e7a...`), the hook validates them as 64-hex-format but they don't match the gate-computed key, the gate denies the Write, and the agent has to manually `touch` the correct-key marker to unblock.

**Evidence** (iter 8 + iter 10 of this session, 2026-05-18):
- Iter 8: voice-tone marker not auto-written despite agent PASS verdict; agent fabricated placeholder hex keys; manual `touch` of correct-key marker required to unblock both changeset writes.
- Iter 10: same friction at the multi-package changeset Write surface.
- Marketplace source (not yet released to voice-tone 0.5.0) has the `derive_external_comms_key_from_prompt` fallback per ADR-017 sync mechanism; cached version is stale.

**User direction** (verbatim, AskUserQuestion answer 2026-05-18 at session 6 loop-end Step 2.5): *"Approve + amend voice-tone hook (recommended) — Update packages/voice-tone/hooks/external-comms-mark-reviewed.sh to use the derive_external_comms_key_from_prompt helper (already in shared/hooks/lib/external-comms-key.sh per risk-scorer 0.10.0). This closes the asymmetry across both evaluator hooks."*

## Symptoms

- Voice-tone evaluator hook does not auto-write marker despite agent PASS verdict.
- Agents fabricate placeholder hex keys (64-char hex shape but wrong value) — hook validates format but rejects on key-derivation mismatch.
- Manual `touch /tmp/voice-tone-external-comms-reviewed-<correct-key>` required to unblock Writes.
- Same problem class as P166/P163 (hook-side sha256 derivation) at the voice-tone surface.

(symptoms section deferred to investigation)

## Workaround

Agent computes the gate-derived full-content sha256 manually and uses the correct value in marker `touch`. Documented in iter 9 + iter 10 prompts as "P198 changeset-author known-asymmetry" caveat.

## Impact Assessment

- **Who is affected**: every AFK iter that triggers a voice-tone evaluator check on a Write surface.
- **Frequency**: Likely (3) — fires on every changeset Write that voice-tone gates.
- **Severity**: (deferred to investigation) — initial: moderate (workaround works but slow).
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Read `packages/voice-tone/hooks/external-comms-mark-reviewed.sh` (current cached 0.5.0 + marketplace HEAD) to understand the current literal-key read path.
- [ ] Read `packages/shared/hooks/lib/external-comms-key.sh` to confirm `derive_external_comms_key_from_prompt` is the helper to call.
- [ ] Architect verdict on the amendment: replace literal-key read with helper-derived key, OR keep both paths with literal-as-fallback (transition support).
- [ ] Update `external-comms-mark-reviewed.sh` to use the helper.
- [ ] Behavioural bats coverage for the derived-key path (sibling to risk-scorer 0.10.0 fixtures).
- [ ] Per-package sync of `packages/voice-tone/hooks/lib/external-comms-key.sh` per ADR-017 if needed.
- [ ] Changeset for `@windyroad/voice-tone` patch.
- [ ] Compose with P166 / P163 cluster — may fold into their atomic cohort OR ship as standalone patch.

## Dependencies

- **Blocks**: (none — workaround keeps the channel functional)
- **Blocked by**: (none — fix is hook source change + helper invocation)
- **Composes with**: P166 / P163 (external-comms hook-side sha256 derivation cluster — same problem class, this is the voice-tone-side parallel), P198 (recurring marker-key-derivation friction surface), P256 (sibling fix at the SKILL prompt-template surface, this same session)

## Related

- `packages/voice-tone/hooks/external-comms-mark-reviewed.sh` — the surface to amend.
- `packages/shared/hooks/lib/external-comms-key.sh` — canonical helper containing `derive_external_comms_key_from_prompt`.
- `packages/risk-scorer/hooks/external-comms-mark-reviewed.sh` 0.10.0 — the reference implementation already using the helper.
- ADR-028 — external-comms risk-scorer gate.
- ADR-017 — shared code sync via per-package lib/ copies.
- P166 / P163 — sibling cluster currently vp-blocked due to negative evidence per P198.
- P198 — broader marker-key-derivation friction surface tracker.
- P256 — sibling fix at the SKILL prompt-template surface (this same session, surfaced together).

(captured via /wr-itil:capture-problem; expand at next investigation)
