---
status: proposed
rfc-id: adr-078-phase-1-architect-on-edit-compendium-entries
reported: 2026-06-02
decision-makers: [Tom Howard]
problems: [P337]
adrs: [ADR-078, ADR-077]
jtbd: []
stories: []
---

# RFC-014: ADR-078 Phase 1 — architect-on-edit compendium entries

**Status**: proposed
**Reported**: 2026-06-02
**Problems**: P337
**ADRs**: ADR-078, ADR-077
**JTBD**: (none)

## Summary

ADR-078 Phase 1 — implement architect-on-edit LLM-authored compendium entries via PostToolUse hook + readme-pairing pre-commit hook + retire the current programmatic generator (and its drift gate + refresh-discipline hook) + cadence-driven migration of the 43 non-canonical ADRs + ADR-077 confirmation-criteria amendment.

This RFC scopes the implementation arc for the ADR-078 decision (Option 9 — architect-on-edit, ratified 2026-05-31 with `human-oversight: confirmed`). The decision itself is settled; this RFC sequences and tracks the multi-commit work that delivers it. Substance of each story is intentionally deferred — populate Scope / Tasks at `/wr-itil:manage-rfc <NNN> accepted` transition.

## Driving problem trace

- **P337** (Open) — Decisions compendium omits Decision Outcome for 57% of ADRs. The generator's `get_chosen` regex (`packages/architect/scripts/generate-decisions-compendium.sh:115`) matches only plain-prefix `Chosen option:` tags; 43/75 ADRs render with no decision content. Defeats ADR-077's load-surface goal for the majority of entries. ADR-078 Phase 1 replaces the programmatic extractor with architect-on-edit authored entries — this RFC is that replacement's delivery vehicle.

## Scope

(deferred — populate at /wr-itil:manage-rfc accepted transition)

Anticipated story decomposition (per P337 § Fix Strategy, awaiting STORY captures at acceptance):

- Story A — implement + test `packages/architect/hooks/architect-compendium-update-entry.sh` (PostToolUse hook + `claude -p` subprocess invocation + architect agent invocation + README Edit application + staging).
- Story B — implement + test `packages/architect/hooks/architect-readme-pairing-check.sh` (pre-commit hook asserting every commit that edits `docs/decisions/*.md` body also edits `docs/decisions/README.md`).
- Story C — retire `packages/architect/scripts/generate-decisions-compendium.sh` as load-bearing primary path + retire `packages/architect/scripts/test/generate-decisions-compendium.bats` test 2145 (idempotency / drift gate). Backstop window per ADR-078 guidance.
- Story D — retire `packages/architect/hooks/architect-compendium-refresh-discipline.sh` PreToolUse refresh-discipline hook (gated on Story A landing — Option 9 makes drift structurally impossible).
- Story E — amend ADR-077 confirmation criteria (b), (g), (h) per ADR-078 § "Architectural relationship between body and README under Option 9".

Story IDs to be minted at `/wr-itil:manage-rfc 014 accepted` via `/wr-itil:capture-story` invocations (one per story, with ordered `--stories` flag refresh on this RFC's frontmatter at that time).

JTBD anchors (per jtbd-lead verdict 2026-06-02): primary JTBD-001 (Enforce Governance Without Slowing Down — Phase 1's hooks enforce compendium currency per-edit); secondary JTBD-008 (Decompose a Fix Into Coordinated Changes — capture-time scoping surface). Populate `jtbd: [JTBD-001, JTBD-008]` at acceptance.

## Tasks

- [ ] (deferred — populate at /wr-itil:manage-rfc accepted transition)

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)

- **P337** — driving problem ticket; § Fix Strategy enumerates the 5-story anticipated decomposition.
- **ADR-078** — ratified architectural decision (Option 9, human-oversight: confirmed 2026-05-31); this RFC is its delivery vehicle.
- **ADR-077** — the compendium ADR; confirmation criteria (b), (g), (h) scheduled for amendment in Story E.
- **ADR-060** — Problem-RFC-Story framework; this RFC scopes a multi-commit fix per JTBD-008.
- **P339** — substance-confirm-before-build prior occurrence on the same ADR-078 (lineage; informs how this RFC's stories should land — each at architect-confirmed substance before implementation).
