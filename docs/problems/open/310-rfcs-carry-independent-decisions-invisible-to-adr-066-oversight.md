# Problem 310: RFCs carry independent decisions invisible to the ADR-066 human-oversight net

**Status**: Open
**Reported**: 2026-05-26
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

RFCs carry independent decisions that are invisible to the ADR-066 human-oversight net — unratified decisions drift into accepted RFCs (and the JTBDs they cite) without the user's agreement.

**Concrete evidence (the disavowed carve-out):** the "atomic-fix carve-out" (*Effort ≤ M may skip RFC ceremony; Effort ≥ L requires RFC trace*) reached `RFC-005` **accepted** status as decisions F2/F7/I13, and is anchored in `JTBD-008` (lines 21/26/44) + `JTBD-101`, with **no human ratification**. The user explicitly disavowed it 2026-05-26: *"I did not agree to a atomic-fix carve-out"* and *"Each problem may ONLY be fixed via an RFC"*.

**Root cause:** `ADR-060` line 97 permits RFCs to carry decision content that is NOT ADR-captured — *"An RFC's internal decomposition ... does NOT create ADRs by default; ADRs created during RFC execution capture decisions with scope outside the RFC's own boundary."* Meanwhile `ADR-066`'s unoversighted-decision detector only greps `docs/decisions/`. So a decision living in `docs/rfcs/` is **structurally invisible** to the oversight mechanism designed to catch exactly this — the RFC tier is an unratified-decision blind spot.

**User-ratified direction (2026-05-26, via AskUserQuestion):** RFCs hold NO independent decisions; every choice among ≥2 viable options is an ADR (inherits the ADR-064 confirm gate + ADR-066 born-confirmed oversight marker). Pure sequencing/decomposition of *already-decided* work stays in the RFC (retain ADR-060 line 97's protective half; delete its permissive half). No "Considered Options / Alternatives Rejected" block in an RFC body — contested choices reference the governing ADR(s). The machine-detectable tell: an RFC body containing a rejected-alternatives block with no matching `adrs:` reference is a decision masquerading as scope.

## Symptoms

- Unagreed decisions reach `accepted` RFC status (RFC-005 F2/F7/I13 atomic-fix carve-out).
- The carve-out propagated into JTBD-008/JTBD-101 by citation, compounding the drift.
- ADR-066's `review-decisions` drain + nudge + detector never surface RFC-embedded decisions (grep scope = `docs/decisions/` only).

## Workaround

(deferred to investigation — interim: human review of accepted RFCs for embedded decisions)

## Impact Assessment

- **Who is affected**: maintainers relying on the human-oversight net to catch unratified governance decisions (P283/P288 sibling-class).
- **Frequency**: (deferred to investigation)
- **Severity**: (deferred to investigation — governance-correctness class)
- **Analytics**: 1 confirmed drift instance (RFC-005 atomic-fix carve-out), user-disavowed.

## Root Cause Analysis

ADR-060 line 97 (permissive clause) + ADR-066 detector scope (`docs/decisions/` only) jointly create the RFC-decision blind spot. See Description.

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Author new ADR amending ADR-060 (delete line-97 permissive half; keep protective half; ≥2-viable-options test; no Considered-Options block in RFCs)
- [ ] Retrofit RFC-005's F1–F7 decisions out to ADR(s); reduce RFC-005 to scope + decomposition + traces
- [ ] Strike the atomic-fix carve-out from JTBD-008 (lines 21/26/44) + JTBD-101
- [ ] Drop "Considered Options / Alternatives Rejected" from the RFC template + capture-rfc/manage-rfc skills
- [ ] Add behavioural test (ADR-052): no RFC body has a rejected-alternatives block without a matching `adrs:` reference
- [ ] Create reproduction test

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P251 (RFC-first trace not enforced at fix-time — the sibling no-carve-out direction); the lift-auto-decisions-to-human class (P283 ADRs, P288 JTBDs, P300/P302)

## Related

- **P251** — RFC-first trace invariant not enforced at fix-time; the user's "every problem fixed only via an RFC, no carve-out" direction strengthens P251's resolution. RFC-005 is P251's RFC and the carrier of the disavowed carve-out.
- **P283** — architect should AskUserQuestion when recording a new decision (ADR oversight); same lift-auto-decisions-to-human class at the ADR surface.
- **P288** — new JTBDs/personas need human-oversight confirmation; same class at the JTBD surface.
- **ADR-060** — the framework this amends (line 97 permissive clause is the root cause).
- **ADR-064 / ADR-066** — the confirm + oversight machinery that all-decisions-are-ADRs inherits for free.
- **RFC-005** (`docs/rfcs/RFC-005-...accepted.md`) — carries the disavowed carve-out (F2/F7/I13); to be retrofitted.
- **JTBD-008 / JTBD-101** — anchor the carve-out; to be amended.
- Captured via /wr-itil:capture-problem 2026-05-26 (P078 capture-on-correction); driver for a new ADR amending ADR-060.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-006 | accepted | Implement ADR-070 + ADR-071 — re-home RFC decisions to ADRs and make RFC-first unconditional |
