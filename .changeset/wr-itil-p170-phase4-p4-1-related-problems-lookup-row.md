---
"@windyroad/itil": patch
---

P170 Phase 4 P4.1: `update-jtbd-references-section.sh` extension — adds a fourth `Related problems` lookup-table row (alongside `RFCs`, `Story Maps`, `Stories`) so JTBD files can auto-maintain a `## Related problems` reverse-trace section sourced from problem-ticket frontmatter `jtbd:` arrays. Per ADR-060 § Phase 3 + Phase 4 in-scope amendment (2026-05-13) P4.1 (architect finding A4 + JTBD finding F5). Lookup-table row addition only — no new helper, no per-section-name branching (structural test asserts). Adds `SECTION_ID_PREFIX` cell to render `P<NNN>` for problem rows. `extract_status_md` extends to fall back to body `**Status**:` lines when frontmatter `status:` absent (preserves Story/RFC frontmatter compat). 7-test behavioural bats fixture green; full itil/scripts suite 229/229 green. Held per ADR-042 / P162 atomic-cohort discipline — Phase 3 + Phase 4 ship as a single graduation cohort once end-of-chain user verification fires.
