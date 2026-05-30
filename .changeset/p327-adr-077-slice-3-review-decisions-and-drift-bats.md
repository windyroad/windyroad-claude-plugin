---
"@windyroad/architect": patch
---

ADR-077 Slice 3 — close the two remaining Confirmation items deferred from Slice 2 (commit 9832593).

**(f) `/wr-architect:review-decisions` integration.** New Step 4.5 + amended Step 5 stage list: after the drain's Confirm/Amend/Reject writes land, regenerate `docs/decisions/README.md` via `wr-architect-generate-decisions-compendium` and stage it with the batch. Mirrors the regen + stage-with-commit pattern shipped in Slice 2 for `/wr-architect:create-adr` Step 5 and `/wr-architect:capture-adr` Step 4.5. Defer-only batches skip the refresh. Confirm projects the `human-oversight: confirmed` badge; Amend refreshes the substance projection (primary drift surface this closes); Reject/supersede projects the `rejected-pending-supersede (P<NNN>)` badge per P316.

**(g) CI drift-detection bats.** New `packages/architect/scripts/test/generate-decisions-compendium.bats` (13 behavioural tests). Asserts: the committed `docs/decisions/README.md` matches generator output for the current ADR bodies (load-bearing CI drift gate); generator idempotency on a fixture set; `--check` exit 1 on mutated ADR body + missing compendium; two-section split (in-force vs historical) honours `status:` frontmatter; deterministic header (no timestamp); per-entry shape; oversight badge + P316 rejected-pending-supersede badge projection. Defence-in-depth in case `architect-compendium-refresh-discipline.sh` fails open or is bypassed.

Closes P327 (ADR bodies dominate session token usage) at the load-bearing slice — ADR-077 Confirmation items (a)–(j) all green. Token-load reduction (~40× on the routine architect-agent compliance path) now defended at three layers: skill-time regen (primary), PreToolUse commit hook (safety net), CI drift bats (audit trail).
