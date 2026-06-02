# Problem 256: assess-external-comms SKILL.md Step 3 prompt template must instruct that <draft> wraps FULL file content (frontmatter + body) for Write-surfaced drafts

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

User-approved deviation-candidate from iter 8 of `/wr-itil:work-problems` session 6 (2026-05-18). The agent's `assess-external-comms` SKILL.md Step 3 prompt template does not explicitly instruct that `<draft>` MUST wrap the FULL file content (frontmatter + body) for Write-surfaced drafts (changeset-author class).

The external-comms-gate hook computes `sha256(draft + surface)` where `draft` is read from the Write tool's `tool_input.content` — i.e. the FULL file content including frontmatter. The agent's draft submission to the evaluator MUST match the same content the Write tool will receive, otherwise the body-only-key vs gate-derived-full-content-key mismatch causes the gate to deny the Write.

**Evidence** (iter 8 of this session, 2026-05-18):
- Required 3 retry cycles on changeset 1 + 2 retry cycles on changeset 2 because the agent's first `<draft>` submissions contained body-only content while the gate computed the key over the full Write payload (frontmatter + body).
- Computed body-only key `651c66565e2a3a95f54e84cf94f11dc5d15855e80c0ad45de3fa014baff7dfb9` did not match gate-derived full-content key `16d63599b44671e07f9ca7795b8fd6965e0fadbe2e4c1e8fc2cb538fc407fe25`.
- Same friction surfaced in iter 10's `p087-phase-3-retroactive-rollout.md` changeset Write.

**User direction** (verbatim, AskUserQuestion answer 2026-05-18 at session 6 loop-end Step 2.5): *"Approve + amend SKILL.md (recommended) — Update assess-external-comms SKILL.md Step 3 prompt template to explicitly instruct that <draft> MUST wrap FULL file content (frontmatter + body) for Write-surfaced drafts."*

## Symptoms

- Agents invoking `wr-risk-scorer:assess-external-comms` for changeset Writes (or other Write-surfaced drafts) submit body-only `<draft>` content and hit the gate's key-mismatch denial.
- The retry-cycle workaround (re-invoke with full-content draft) costs ~30s + 1 agent call per retry; accumulates 3-5x per affected Write across an iter.
- Likely overlaps with P166/P163 cluster (external-comms hook-side sha256 derivation) — both surfaces are about the same key-derivation contract.

(symptoms section deferred to investigation — above are verbatim observations from iter 8 + iter 10 of session 6)

## Workaround

Agent ensures `<draft>` wraps FULL file content (frontmatter + body) when calling `wr-risk-scorer:assess-external-comms` for Write-surfaced drafts. Documented in iter 9 + iter 10 prompts as "P198 changeset-author known-asymmetry" caveat.

## Impact Assessment

- **Who is affected**: every AFK iter that ships a changeset Write through the external-comms gate. Frequency: ~5 retries per iter that touches a changeset (observed iter 8 + iter 10).
- **Frequency**: Likely (3) — fires on every changeset Write in iters that follow the documented workaround pattern; reduces to Rare once SKILL.md amendment lands.
- **Severity**: (deferred to investigation) — initial: moderate (cost-of-business, but bounded).
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Read `packages/risk-scorer/skills/assess-external-comms/SKILL.md` Step 3 to understand the current prompt template shape.
- [ ] Architect verdict on the amendment: explicit `<draft> MUST wrap FULL file content (frontmatter + body)` instruction OR a derive-from-Write-tool-input approach.
- [ ] Cross-reference P166/P163 cluster — does this ticket compose with their fix, or is it independent? Architect verdict on whether to fold into the P166/P163 cohort or ship standalone.
- [ ] Update SKILL.md Step 3 prompt template; behavioural bats coverage for the new instruction.
- [ ] Changeset for `@windyroad/risk-scorer` patch (SKILL prose change).

## Dependencies

- **Blocks**: (none — workaround keeps the channel functional)
- **Blocked by**: (none — fix is SKILL.md prose + bats)
- **Composes with**: P166 / P163 (external-comms hook-side sha256 derivation cluster), P185 (capture-problem derive-first dispatch — sibling-pattern at a different SKILL surface)

## Related

- `packages/risk-scorer/skills/assess-external-comms/SKILL.md` — the surface to amend.
- `packages/voice-tone/hooks/external-comms-gate.sh` — computes the key the agent's `<draft>` must match.
- ADR-028 — external-comms risk-scorer gate.
- ADR-013 Rule 5 — policy-authorised silent-proceed (the gate-pass shape).
- P166 / P163 — sibling-cluster at the hook-side sha256 derivation surface.
- P198 — sibling at the broader marker-key-derivation friction surface.
- P257 — sibling fix at the voice-tone hook surface (this same session, surfaced together).

(captured via /wr-itil:capture-problem; expand at next investigation)
