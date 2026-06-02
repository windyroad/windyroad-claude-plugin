# Problem 301: ADR-066/068 oversight-marker frontmatter writes trip the full architect+JTBD edit-gate each drain batch

**Status**: Open
**Reported**: 2026-05-25
**Priority**: 6 (Medium) — Impact: 2 (Minor — re-review round-trips slow the drain but don't break it; the markers still land) × Likelihood: 3 (Likely — every `/wr-architect:review-decisions` + `/wr-jtbd:confirm-jobs-and-personas` drain batch, plus every adopter running the drains; recurs ~per-batch on a multi-batch drain)
**Effort**: M — define a gate-light path for oversight-marker-only frontmatter writes to docs/decisions/ + docs/jtbd/ (the architect/JTBD enforce-edit hooks gain an exemption for a diff that adds only `human-oversight: confirmed` + `oversight-date`)
**WSJF**: 6/2 = **3.0** (Open multiplier 1.0)

## Description

Observed across the 2026-05-25 P283/ADR-066 ADR-oversight drain (15 batches, ~37 ADRs confirmed). Writing the `human-oversight: confirmed` + `oversight-date` marker is the **mechanical output of a decision the user just confirmed via AskUserQuestion** — it changes no decision content (orthogonal to `status:` per ADR-066). Yet each batch of marker-writes to `docs/decisions/*.proposed.md` tripped the **full architect + JTBD edit-gate**, whose markers expired/slid between batches, forcing a re-delegation round-trip:

- Batch 8 (ADR-020): blocked on architect review (`jtbd policy file changed since last review`).
- Batch 10 (ADR-004/025): blocked on architect review.
- (Plus the initial drain batches re-gated as the TTL slid.)

Each round-trip is two agent delegations (architect + JTBD) that both return PASS on a 2-line frontmatter addition — the review has nothing substantive to assess (the human already confirmed the decision; the marker is policy-authorised by ADR-066). The gate is doing real work for decision-CONTENT edits to ADRs, but the oversight-marker write is precisely the case where the content is unchanged.

## Symptoms

- Architect/JTBD enforce-edit gate fires on `docs/decisions/*.md` + `docs/jtbd/**/*.md` marker-only writes; markers (~3600s TTL, ADR-009) expire across a long drain so re-review fires several times per session.
- Each re-review is a no-op PASS (the diff adds only the two oversight-marker lines; no Decision Outcome / driver / option change).
- The architect's own verdicts this session repeatedly noted "trivial mechanical frontmatter addition … no decision-content change … PASS" — evidence the review has nothing to assess.

## Workaround

Re-delegate architect + JTBD per batch when the gate blocks (the round-trips this ticket is about). The gate correctly allows the write after the no-op review.

## Root Cause Analysis

### Investigation Tasks

- [ ] Decide the gate-light mechanism: the architect/JTBD enforce-edit hooks detect a diff that adds ONLY `human-oversight: confirmed` + `oversight-date: <date>` to frontmatter (no other line changed) and allow it without requiring a fresh review marker. The write is policy-authorised by ADR-066 (the human confirmed via AskUserQuestion; the marker records that confirmation).
- [ ] Guard against abuse: the exemption must be exact (only those two lines added, nothing else in the diff) so it can't be used to slip decision-content changes past the gate.
- [ ] Reconcile with ADR-066/068 (the drain is the authorised writer) + ADR-009 (marker lifecycle) + P029 (existing governance-doc gate exemptions).
- [ ] Consider whether `/wr-architect:review-decisions` + `/wr-jtbd:confirm-jobs-and-personas` should set a longer-lived drain-session marker so a multi-batch drain doesn't re-gate per batch.

## Dependencies

- **Blocks**: efficient operation of the ADR-066/068 oversight drains (and adopter drains).
- **Blocked by**: none.
- **Composes with**: ADR-066/ADR-068 (the drain mechanisms whose marker-writes this exempts), ADR-009 (gate marker lifecycle / TTL), P029 (governance-doc gate exemptions), the architect/JTBD enforce-edit hooks.

## Related

(captured 2026-05-25 during the P283/ADR-066 oversight drain retro)

- **ADR-066** + **ADR-068** — the oversight mechanisms; their marker-writes are the exemption target.
- **P283** / **P288** — the driving tickets.
- **ADR-009** — gate marker lifecycle (the TTL that expires mid-drain).
- `packages/architect/hooks/architect-enforce-edit.sh` + `packages/jtbd/hooks/jtbd-enforce-edit.sh` — the gate hooks to extend.
