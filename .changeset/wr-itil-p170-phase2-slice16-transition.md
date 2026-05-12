---
"@windyroad/itil": minor
---

P170 Phase 2 Slice 16 — P170 transition Known Error → Verification Pending per ADR-022. Phase 2 framework code is fully shipped this session; the ticket moves to the Verification Queue awaiting forward-dogfood validation post-marketplace-release.

**This transition completes P170 Phase 2 SHIP.** All 14 Phase 2 slices done (counting Slice 12 folded into Slices 3+7; Slices 14 + 15 marked partial with explicit deferred follow-up trails):

- Slice 0 (prior) — ADR-060 HTML encoding amendment
- Slice 1 (prior) — docs/story-maps + docs/stories scaffold
- Slice 2a (prior) — update-problem-references-section.sh
- Slice 2b (prior) — 3 sibling reverse-trace helpers
- Slice 2.5 (this session) — Hook exemption globs (4 enforce-edit hooks)
- Slice 3 (this session) — capture-story-map skill
- Slice 4 (this session) — manage-story-map skill
- Slice 5 (this session) — reconcile-story-maps trio
- Slice 6 (this session) — list-story-maps skill
- Slice 7 (this session) — capture-story skill
- Slice 8 (this session) — manage-story skill
- Slice 9 (this session) — reconcile-stories trio
- Slice 10 (this session) — list-stories skill
- Slice 11 (this session) — RFC frontmatter stories: extension
- Slice 12 (folded) — collision-guard inline per Slice 3+7
- Slice 13 (this session) — working-the-problem traversal rewrite
- Slice 14 (this session) — STORY-MAP-001 HTML bootstrap + voice-tone + style-guide policy files
- Slice 15 (this session, partial) — RFC-003 capture + 7 bootstrap stories
- Slice 16 (this commit) — P170 transition Known Error → Verification Pending

**Transition mechanics**:
- `git mv docs/problems/known-error/170-...md docs/problems/verifying/170-...md`
- Status field edited to `Verification Pending`
- New `## Fix Released` section listing the 10-commit chain across this session
- `docs/problems/README.md` refreshed: P170 row removed from WSJF Rankings; new row added to Verification Queue
- Prior line-3 fragment (P165 transition) rotated to `docs/problems/README-history.md` per P134; new fragment names P170 + Phase 2 framework code completion

**Verification gate per ADR-022**: forward-dogfood post-marketplace-release. Verify on next session by running:
1. `/wr-itil:capture-story-map P<NNN> JTBD-<NNN> <description>` writes fresh STORY-MAP-NNN HTML without rejection (the Slice 2.5 hook exemption globs need to be released first; the in-session VOICE-AND-TONE.md + STYLE-GUIDE.md policy-file unblock path covered the session itself).
2. `/wr-itil:capture-story P<NNN> JTBD-<NNN> <description>` writes STORY-NNN markdown; I6 + I9 hard-block fires on missing traces.
3. `/wr-itil:manage-story <NNN> accepted` enforces I7+I8+I10.
4. `/wr-itil:work-problem <NNN>` traverses Problem → Fix Strategy → RFC → stories: → next not-done story per Slice 13.

On verification PASS: transition Verification Pending → Closed.

Partial-scope explicit follow-ups deferred:
- Slice 14: full B1-B10/T1-T11 backbone migration from `docs/plans/170-rfc-framework-story-map.md` (the plans file stays as planning artefact by reference)
- Slice 15: full bootstrap stories extraction + RFC-001/RFC-002 frontmatter stories: backfill (their work shipped + verified independently; backfill is retroactive documentation)
