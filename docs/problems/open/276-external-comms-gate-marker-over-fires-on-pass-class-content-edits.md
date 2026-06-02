# Problem 276: external-comms gate marker over-fires on PASS-class content edits (P073 surface)

**Status**: Open
**Reported**: 2026-05-19
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

Two `wr-risk-scorer:external-comms` re-reviews fired during session 8 iter 2 (P269) work — once for changeset frontmatter expansion, once for a "12 → 11 plugins" single-numeral edit. Both reviews returned PASS unconditionally. ~20s + token spend per re-review on edits the gate cannot meaningfully assess.

The content-hash marker derivation (P073 surface) considers any change to the affected file as a marker invalidation, triggering a fresh review-cycle. For edits that are syntactically minor and semantically PASS-class (whitespace normalisation, single-numeral updates, frontmatter shape expansion), the re-review cost exceeds the value the gate adds.

**Proposed fix shape**: amend the content-hash marker derivation to either (a) normalise whitespace + single-numeral edit-distance before hashing OR (b) provide a re-review affordance for trivial post-PASS tweaks.

## Symptoms

(deferred to investigation)

## Workaround

User explicit direct or agent manual affordance. Friction.

## Impact Assessment

- **Who is affected**: any maintainer + AFK orchestrator iter that touches changeset frontmatter or docs/problems/README.md inline during a multi-commit iter.
- **Frequency**: ~2 per AFK iter where iter touches gated content surfaces; cost ~20s + tokens per re-review.
- **Severity**: (deferred to investigation) — initial: low.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Investigate root cause — read P073 SHA-based marker derivation
- [ ] Survey value-add of re-review for genuinely different content vs whitespace/numeral edits
- [ ] Create reproduction test

## Dependencies

- **Composes with**: P073 (content-hash marker derivation), P166 + P163 + P198 (external-comms gate marker friction cluster), ADR-028 (external-comms voice-tone gate)

## Related

(captured 2026-05-19 from /wr-itil:work-problems session 8 iter 2 (P269) deviation-approval queue, user-directed via AskUserQuestion at Step 2.5)

- P073 — content-hash marker derivation parent
- P166, P163, P198 — sibling external-comms gate friction
- ADR-028 — external-comms voice-tone gate
