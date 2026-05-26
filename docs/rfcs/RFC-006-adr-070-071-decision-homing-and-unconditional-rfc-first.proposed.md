---
status: proposed
rfc-id: adr-070-071-decision-homing-and-unconditional-rfc-first
reported: 2026-05-26
decision-makers: [Tom Howard]
problems: [P310, P251]
adrs: []
jtbd: []
stories: []
---

# RFC-006: Implement ADR-070 + ADR-071 — re-home RFC decisions to ADRs and make RFC-first unconditional

**Status**: proposed
**Reported**: 2026-05-26
**Problems**: P310, P251
**ADRs**: (none)
**JTBD**: (none)

## Summary

Implement the two ratified, born-confirmed sibling decisions ADR-070 (RFCs hold no independent decisions) and ADR-071 (every fix goes through an RFC — no atomic-fix carve-out, no effort threshold). The work re-homes RFC-005's genuine decisions out to the ADR ledger (so they enter the ADR-066 oversight net), repudiates the disavowed atomic-fix carve-out, reframes the JTBD-008/JTBD-101 carve-out language into the thin-RFC minimal-ceremony path, amends ADR-060's permissive line-97 clause + adds the unconditional fix-time I13 invariant, ships the ADR-052 enforcement test, and retro-fits a thin RFC for P260 so its held `@windyroad/itil` changeset can release under the new unconditional gate. This RFC dogfoods ADR-071: the decision-homing fix itself goes through an RFC.

## Driving problem trace

- **P310** (`docs/problems/open/310-rfcs-carry-independent-decisions-invisible-to-adr-066-oversight.md`) — RFCs carry independent decisions invisible to the ADR-066 human-oversight net. The atomic-fix carve-out reached RFC-005 `accepted` (F2/F7/I13) with no human ratification because the oversight detector greps only `docs/decisions/`. This RFC's decision-homing slices (1, 6) + the ADR-052 enforcement test (5) close the blind spot. ADR-070 is the governing decision.
- **P251** (`docs/problems/open/251-rfc-first-trace-invariant-not-enforced-fixes-start-without-rfc-story-map-or-jtbd-trace.md`) — RFC-first trace invariant not enforced at fix-time; fixes start without an RFC. This RFC's gate slice (4) + the carve-out repudiation (2) + the P260 retro-fit (7) make Problem→RFC unconditional at fix-time. ADR-071 is the governing decision.

## Scope

(deferred — populate at /wr-itil:manage-rfc accepted transition)

## Tasks

- [ ] (deferred — populate at /wr-itil:manage-rfc accepted transition)

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)
