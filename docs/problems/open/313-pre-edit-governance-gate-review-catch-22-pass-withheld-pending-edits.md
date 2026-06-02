# Problem 313: Pre-edit governance-gate catch-22 — review agent withholds PASS because edits "aren't applied yet", but the gate blocks the edits

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 4 (Medium) — Impact: 2 x Likelihood: 2 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The architect / JTBD edit-gates fire BEFORE a project-file edit (they are PreToolUse gates demanding a PASS marker before the Write). But the review agents reason as if reviewing ALREADY-APPLIED changes: when handed a PRE-EDIT plan, they withhold PASS because "the edits aren't applied yet / the residual state is still live", which is exactly the state a pre-edit gate guarantees. The gate blocks the edits; the reviewer wants the edits done first → catch-22. The only escape is re-running the agent with explicit "this is a PRE-EDIT gate; not-yet-applied is expected and MUST NOT be treated as an issue" framing.

Observed twice in the 2026-05-26 ADR-070/071 implementation session (Step 2b repeat-work signal — category 5):

1. **Architect, RFC-006 write**: the first architect review returned `ISSUES FOUND` (five plan-completeness items + one Needs-Direction). The `architect-mark-reviewed` hook did not set the marker (verdict-grep saw "ISSUES FOUND" — P181 class), so the RFC-006 Write was blocked. After resolving the items, a SECOND architect review framed as a clean re-review returned PASS and unblocked the write. Round-trip cost: one extra full architect delegation.
2. **JTBD, slice-2 README write**: after the JTBD policy files (JTBD-008/101) were amended, the jtbd marker invalidated ("jtbd policy file changed since last review"). The re-review returned `ISSUES FOUND` whose substance was *"the residual carve-out framing is still live in the corpus … the plan itself is correctly aligned — once items 1-5 land this re-review will PASS"* — i.e. it withheld PASS solely because the about-to-be-made edits were not yet on disk. A THIRD review, framed explicitly as "PRE-EDIT alignment gate — not-yet-applied is expected, do not treat it as an issue", returned PASS.

This is distinct from P181 (the verdict-grep hook treating an "ISSUES FOUND" substring as blocking) and P303 (the multi-decision-file hash-drift deadlock): here the review AGENT itself chooses to withhold PASS on a pre-edit review, because its prompt has no "pre-edit / proposed-change" review mode where not-yet-applied state is the expected baseline.

## Symptoms

- A pre-edit architect/JTBD review returns ISSUES FOUND / FAIL whose sole substance is "the change isn't applied yet" or "the old state is still present."
- The edit-gate stays locked because the marker requires PASS, but PASS requires the edit, which the gate blocks.
- Workaround: re-invoke the agent with an explicit "this is a pre-edit gate; the proposed change is not yet on disk by design; classify alignment of the PROPOSAL, do not fail on not-yet-applied" preamble.

## Workaround

Re-run the gate agent with an explicit pre-edit-review framing preamble (used successfully for both architect and jtbd this session). Costs one extra delegation round-trip per gate.

## Impact Assessment

- **Who is affected**: any session making project-file edits that trip the architect/JTBD pre-edit gates, especially after a same-session policy-file edit invalidates a marker.
- **Frequency**: Possible — fires when the first review surfaces real items OR when a policy-file edit invalidates the marker mid-session.
- **Severity**: Minor-Moderate — recoverable via re-run, but each occurrence is a wasted full agent delegation + the agent may keep failing until the framing is explicit.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Decide where the fix lives: (a) the gate-review agent prompts gain an explicit "pre-edit / proposed-change review mode — not-yet-applied is the expected baseline, classify the PROPOSAL not the disk state"; or (b) the orchestrating skill/hook passes a "pre-edit" signal the agent honours; or (c) the mark-reviewed hook distinguishes "PASS-once-applied" from "FAIL".
- [ ] Compose with P181 (verdict-grep) + P303 (deadlock) — same gate surface, different facets.

## Dependencies

- **Composes with**: P181 (architect verdict-grep fragility), P303 (multi-decision-file architect deadlock), P215/P216/P226 (gate drift-relock), ADR-064 (architect Needs-Direction verdict shape), ADR-066/ADR-068 (oversight markers — JTBD-policy edits invalidate the jtbd marker).

## Related

(captured via /wr-retrospective:run-retro Step 2b pipeline-instability scan, 2026-05-26 ADR-070/071 implementation session — repeat-work category, observed on both architect and jtbd gates; expand at next investigation)
