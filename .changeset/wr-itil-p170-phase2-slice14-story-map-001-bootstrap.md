---
"@windyroad/itil": minor
---

P170 Phase 2 Slice 14 — STORY-MAP-001 bootstrap HTML scaffold at `docs/story-maps/in-progress/STORY-MAP-001-rfc-framework-phase-1-bootstrap.html` per ADR-060 § Phase 2 encoding amendment 2026-05-12. Plus the unblock path: `docs/VOICE-AND-TONE.md` + `docs/STYLE-GUIDE.md` policy files authored to close the empirical block documented at P170 line 297.

**Unblock path applied** (line 297 option a — author the policy files + delegate one-time review):
- `docs/VOICE-AND-TONE.md` (new, ~115 lines) — voice + tone policy with banned-pattern list + word-list + HTML-content rules. wr-voice-tone:agent PASS verdict 2026-05-12 → /tmp/voice-tone-reviewed-${SESSION_ID} marker set.
- `docs/STYLE-GUIDE.md` (new, ~90 lines) — story-map HTML style rules (layout-only embedded `<style>`, prohibited inline `style=""` on data-bearing elements, class-name vocabulary, data-attribute vocabulary, colour + typography guidance). wr-style-guide:agent PASS verdict 2026-05-12 → /tmp/style-guide-reviewed-${SESSION_ID} marker set.

With both markers set, voice-tone + style-guide enforce-edit hooks pass on `*.html` writes under `docs/story-maps/` for this session. STORY-MAP-001 HTML landed without rejection.

**STORY-MAP-001 scaffold** (~125 lines HTML):
- `<meta>` block: story-map-id=STORY-MAP-001, status=in-progress, problems=P170, rfcs=RFC-001/RFC-002/RFC-003, jtbd=JTBD-008/001/006/101, adrs=ADR-060, reported=2026-05-12.
- Embedded `<style>` block with layout-only rules (CSS Grid + custom-property `--cols` per `docs/STYLE-GUIDE.md`).
- Three backbone ribs:
  - Phase 2 framework code (this session): 7 STORY-NNN slices (STORY-001 .. STORY-007) with `data-story-id` + `data-rfc=RFC-003` + `data-status=done` attributes.
  - Phase 2 story-map skills (in-flight): 4 STORY-NNN placeholders (STORY-008..011) for Slices 3-6.
  - Phase 1 RFC tier (prior sessions, reference only): RFC-001 + RFC-002 links.
- No inline `style=""` on data-bearing elements per `docs/STYLE-GUIDE.md` prohibition + ADR-060 line 433.

**Partial scope**: full B1-B10 backbone + T1-T11 task lattice migration from `docs/plans/170-rfc-framework-story-map.md` deferred — the plans file represents pre-Phase-2 thinking and will be superseded by extracted bootstrap stories in a follow-on session. This slice ships the HTML scaffold + the slice-grain decomposition that the framework actually ran on.

Markdown + HTML edits (HTML unblocked via the policy-file authoring path).
