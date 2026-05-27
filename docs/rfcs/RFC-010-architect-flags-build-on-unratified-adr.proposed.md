---
status: proposed
rfc-id: architect-flags-build-on-unratified-adr
reported: 2026-05-27
decision-makers: [Tom Howard]
problems: [P318]
adrs: [ADR-074, ADR-066, ADR-064]
jtbd: []
stories: []
---

# RFC-010: Architect flags changes built on an unratified ADR

**Status**: proposed
**Reported**: 2026-05-27
**Problems**: P318
**ADRs**: ADR-074 (build-upon contract — generalises enforcement surface 1), ADR-066 (oversight marker + orthogonal-axis design), ADR-064 (verdict types)

## Summary

Close the residual P315 foreground gap: the architect agent (and `/wr-architect:review-design`) review every project file edit + plan but do NOT flag a change that builds on an **unratified** ADR (one lacking `human-oversight: confirmed`). Wire that check into the architect's review at the broadest, always-on surface.

Key framing (user correction 2026-05-27): the trigger is the **oversight marker**, NOT `proposed` status. Building on a ratified ADR (even `status: proposed`) is fine; only marker-less (unratified, non-superseded) dependencies flag. Census 2026-05-27: 61/65 ratified, 4 unratified — near-silent in steady state.

## Driving problem trace

- **P318** — architect review doesn't flag build-on-unratified-ADR; only the ITIL propose-fix surface (RFC-008) does, leaving ad-hoc foreground edits/plans uncovered.

## Scope

- **`agent.md`**: add issue type **[Unratified Dependency]** + the review instruction — when a change/plan explicitly **cites or implements** an ADR, the architect Greps that ADR's frontmatter for `human-oversight: confirmed` (the agent has Grep, not Bash — it cannot run `wr-architect-is-decision-unconfirmed`, so it performs the equivalent marker-grep). If absent AND the ADR is not `*.superseded.md` → emit **ISSUES FOUND / [Unratified Dependency]** with action "ratify ADR-NNN via `/wr-architect:review-decisions` before this lands." Status-agnostic; never key on `proposed`.
- **`review-design/SKILL.md`**: note the [Unratified Dependency] check applies to plan review.
- **Bound** to explicit cite/implement (not transitive dependence). Near-zero unratified set keeps noise negligible regardless.
- **Test**: structural doc-lint that `agent.md` carries the [Unratified Dependency] type + the marker-grep instruction (structural-permitted per ADR-052 Surface 2, P176 — the agent verdict is prompt-driven, not behaviourally testable until the skill-invocation harness lands; mirrors the existing `architect-needs-direction-verdict.bats` precedent).

Out of scope: the ITIL propose-fix guard (RFC-008, already shipped — this generalises it to the architect surface); re-deciding the marker-vs-status framing (settled by the user).

## Tasks

- [x] **T0 DONE** — recorded **enforcement surface 3** as a thin Amendment 2026-05-27 to ADR-074's Decision Outcome (architect verdict ISSUES FOUND on [Undocumented Decision] — surface 3 is a genuinely new surface; substance user-pinned same-session so born-confirmed, not Needs-Direction).
- [x] **T1 DONE** — `agent.md`: added `[Unratified Dependency]` issue type + the "When to flag" instruction. Grep-based (agent has Read/Glob/Grep, no Bash) read-only equivalent of `is-decision-unconfirmed.sh`: frontmatter-scoped, case-insensitive + trailing-ws-tolerant marker match, `*.superseded.md` skip, keyed on the marker NOT `status:`, explicit-cite-only (inverse-P078 over-fire guard).
- [x] **T2 DONE** — `review-design/SKILL.md`: noted the [Unratified Dependency] check is in-scope for plan review (the agent owns it; no extra prompt wiring).
- [x] **T3 DONE** — `architect-unratified-dependency-verdict.bats` (5 structural assertions, `tdd-review: structural-permitted (justification: P176)` header per ADR-052 Surface 2). 12 architect-verdict bats GREEN.

**Implementation status (2026-05-27): COMPLETE.** Architect PASS on the resolved plan (ADR-074 surface-3 amendment + frontmatter-scoped/superseded-skip grep fidelity + structural-permitted test header). JTBD PASS.

## Commits

(maintained automatically — RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

- **P318** — driving problem.
- **ADR-074** — this extends enforcement surface 1 (architect verdict) from new-decision-recording to build-on-existing-unratified.
- **ADR-066** — orthogonal status/oversight axes + the "unconfirmed = marker absent + not superseded" definition.
- **RFC-008** — built the predicate + the ITIL propose-fix guard; this is the architect-surface generalisation.

(captured via /wr-itil:capture-rfc; design settled by the user's proposed-vs-unratified correction. Advance via /wr-itil:manage-rfc.)
