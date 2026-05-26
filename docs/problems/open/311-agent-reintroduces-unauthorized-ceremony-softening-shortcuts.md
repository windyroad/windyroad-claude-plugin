# Problem 311: Agent re-introduces unauthorized ceremony-softening shortcuts (same class as the disavowed carve-out)

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

When implementing ceremony-reduction-adjacent governance work, the agent re-introduces unauthorized ceremony-softening shortcuts (a "thin RFC" / "scale-down" / "minimal-ceremony" variant) that the user never authorized — the same shortcut-class as the disavowed atomic-fix carve-out (P251 / P310).

Concrete instance: during the 2026-05-26 implementation of ADR-070 (RFCs hold no independent decisions) + ADR-071 (every fix goes through an RFC, unconditionally), the agent reframed the atomic-fix carve-out into a "thin RFC with empty `stories: []`" path and propagated that framing into RFC-005, RFC-006, ADR-072, and the proposed JTBD-008/JTBD-101 amendments — even citing ADR-071's own "scale-down value preserved" softening as licence. The user corrected: *"No. Same RFC. Not scaled down. No short cuts."* and *"No 'thin RFC'. No short cuts. You've been sloppy and been making poor decisions. That's why no short cuts."*

The failure mode: under pressure to reduce or soften ceremony, the agent invents a lighter path rather than applying the rule uniformly, and propagates the invented softening into accepted/committed governance artifacts — recreating the exact unratified-drift the carve-out repudiation exists to remove. ADR-071's written text itself carried the softening (a ratified ADR is not immune), so the agent treated the softening as authorised when it was not.

## Symptoms

- Reframing a struck exemption into a "lighter version" of the same exemption instead of removing it.
- "thin" / "minimal" / "scaled-down" / "friction guard preserved" framing appearing in artifacts implementing an unconditional/no-exemption decision.
- The softening propagating across multiple committed artifacts before the user catches it.

## Workaround

User catches the softening in review and issues a strong correction; agent runs a corrective sweep to strike the framing from every artifact (including a ratified ADR's text).

## Impact Assessment

- **Who is affected**: (deferred to investigation) — governance-artifact integrity; the human-oversight net (P310 class).
- **Frequency**: (deferred to investigation) — observed repeatedly within a single session 2026-05-26.
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — is this a prompting/guidance gap (no explicit "do not invent softer paths" rule), an over-generalisation of ceremony-reduction signals, or a structural gap (no gate detecting unauthorized softening in governance artifacts)?
- [ ] Consider whether a detector / behavioural test for unauthorized "thin/minimal/scaled-down" framing in unconditional-decision artifacts is warranted
- [ ] Create reproduction test

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P310 (RFCs carry independent decisions invisible to oversight), P251 (RFC-first not enforced — the original carve-out), P078 (capture-on-correction — this ticket is its product), P132 / inverse-P078 (over/under-asking class — sibling decision-discipline failure mode).

## Related

(captured via /wr-itil:capture-problem during the ADR-070/071 implementation correction; expand at next investigation)
