---
"@windyroad/itil": minor
---

P170 Phase 2 Slice 7 — `/wr-itil:capture-story` lightweight aside skill for capturing INVEST-shaped story tickets at `docs/stories/draft/STORY-NNN-<slug>.md` per ADR-060 Phase 2 amendment 2026-05-12 (lines 220-307 — story tier spec + skill description line 291).

Mirrors `/wr-itil:capture-rfc` shape with extensions for the story-tier's stricter trace-mandate:

- Positional argument grammar: `<problem-trace> <jtbd-trace> <description>` — BOTH mandatory at capture-time (I6 + I9 hard-block per ADR-060 lines 248 + 251).
- Optional `--rfc RFC-<NNN>` and `--story-map STORY-MAP-<NNN>` flags — I7 + I8 enforce at `accepted` transition only, not at capture (per ADR-060 line 291).
- Inline `max(local, origin) + 1` STORY-NNN ID allocation (ADR-019 collision-guard inline path per Slice 3 design review architect option a).
- Single `Refs: STORY-<NNN>` trailer per ADR-060 line 307 single-trailer vocabulary; capture-vs-implementation discrimination owned by manage-story (Slice 8) on commit-subject prefix.
- Inline reverse-trace `## Stories` section refresh on driving problem + JTBD + RFC files via the existing Slice 2a/2b helpers; NO refresh on story-map HTML files (manually-authored data-attribute traces — architect amend finding 2).
- Deferred `docs/stories/README.md` refresh per the established capture-rfc precedent.
- Deny-log path `logs/story-capture-denials.jsonl` for I6 + I9 deny cases (sibling to `logs/rfc-capture-denials.jsonl`).

12-test behavioural bats fixture (per ADR-052) at `packages/itil/skills/capture-story/test/capture-story-behavioural.bats` covering: SKILL.md presence + canonical name; next-ID formula (empty / local-only / collision-on-origin / local-higher); reverse-trace helper "Stories" section-name acceptance on problem + JTBD + RFC helpers; NON-acceptance on story-tier helper (story-maps are HTML); frontmatter shape conformance to ADR-060 lines 220-228; landing path `docs/stories/draft/`. All 12 tests green.

Architect AMEND verdict 2026-05-12 closed: finding 1 (single-trailer vocabulary) + finding 2 (no story-map inline refresh) both applied verbatim; findings 3-5 (advisory) integrated. JTBD PASS verdict 2026-05-12.

Ships BEFORE capture-story-map (Slice 3 / 4) due to voice-tone-hook-on-HTML blocker. Structurally permitted per ADR-060 line 291 — story-map trace optional at capture; I8 enforce only at `manage-story <NNN> accepted` transition. When Slices 3-6 ship the story-map skills (post-marketplace-release-cycle for hook exemption globs from Slice 2.5), `manage-story <NNN> accepted` will validate I8 against the then-existing story-map corpus.
