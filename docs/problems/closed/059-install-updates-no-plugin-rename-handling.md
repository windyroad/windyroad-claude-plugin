# Problem 059: `install-updates` has no awareness of plugin renames, leaves stale entries in sibling `.claude/settings.json`

**Status**: Closed
**Reported**: 2026-04-20
**Priority**: 6 (Medium) — Impact: Minor (2) x Likelihood: Possible (3)
**Effort**: L — rename-mapping table + detection logic + auto-migration (no second consent) + regression tests + ADR-030 Confirmation amendment narrowing the cross-project consent rule
**WSJF**: 0 (Verification Pending — see ADR-022)

## Fix Released

Released in working tree 2026-04-20 (AFK iter 5). Changes:

- NEW `.claude/skills/install-updates/rename-mapping.json` — source of truth; initial entry `wr-problem` → `wr-itil` per ADR-010 with forward-compat `skill-action: replace` field.
- EDIT `.claude/skills/install-updates/SKILL.md`:
  - Step 2: rename-mapping detection on `CURRENT_PLUGINS` (record `STALE_CURRENT`).
  - Step 3: per-sibling rename-mapping detection (record `STALE_SIBLING`).
  - NEW Step 6.5: auto-migrate ADR-documented stale entries within already-confirmed siblings (install new + remove stale settings.json key, no second AskUserQuestion).
  - Step 8: Auto-migrated stale entries report section, with explicit "No rename migrations applied this run" fallback per ADR-030 transparency contract.
  - References section: P059 + ADR-030 amendment cross-reference.
- NEW `.claude/skills/install-updates/test/install-updates-rename-detection.bats` — 8 doc-lint structural assertions (Permitted Exception per ADR-005).
- EDIT `docs/decisions/030-repo-local-skills-for-workflow-tooling.proposed.md` Confirmation: rename-mapping carve-out bullet (architect-flagged Q4 phrasing — explicitly names settings.json mutation as authorised). Reassessment Criteria: silent-rename-migration-surprise + second-consumer-of-rename-mapping triggers added.

Exercise evidence: `npm test` ran 380 assertions (was 372 — 8 new from rename-detection.bats). All pass. Direct bats run on the new file confirms all 8 green.

Architect review PASS (4 advisory items all addressed in the implementation). JTBD review PASS.

Awaiting user verification: confirm next `/install-updates` invocation in `addressr-mcp` (or any sibling with stale `wr-problem@windyroad`) auto-migrates the entry to `wr-itil` and surfaces it in the "Auto-migrated stale entries" section of the final report.

## Direction decision (2026-04-20, user — retro stop)

**Migration mode**: **Auto-migrate silently when the rename is ADR-documented**. The first AskUserQuestion (sibling targets, per ADR-030) still fires; once the user has confirmed a sibling, stale entries matching the rename-mapping table are migrated without a second AskUserQuestion. Final report lists what was auto-migrated (install + settings.json key removal) so the audit trail is intact. This trades a second consent gate against a faster session flow; the user's reasoning: an ADR-documented rename IS a deliberate collective decision, so re-asking per sibling would be redundant noise.

Implication for ADR-030:
- The Confirmation criterion "first action is AskUserQuestion listing every sibling project … requiring consent before any install, write, or network call" needs a carve-out: ADR-documented rename migrations within already-confirmed siblings do NOT require a second consent gate. The sibling-scoping consent still applies.
- The scope of Option 3's contract point 3 narrows from "all cross-project writes" to "cross-project writes whose target set is not yet confirmed OR whose action is not ADR-documented."
- Final report MUST surface auto-migrations explicitly so the silent-but-audited pattern is visible.

Options rejected (for posterity):
- **Flag + consent-gated auto-migrate**: extra prompt per session; sane but friction-heavy for a documented decision.
- **Flag only — never migrate**: maximum safety, minimum automation; loses the skill's value for renames.

## Description

`.claude/skills/install-updates/SKILL.md` refreshes every windyroad plugin enabled in a project's `.claude/settings.json`, but has no awareness of plugin **renames**. When a plugin is renamed and re-published under a new npm name (e.g. `@windyroad/problem` → `@windyroad/itil` per P010, 2026-04-16), projects that installed the old name still have `"wr-problem@windyroad": true` in their settings — and `/install-updates` happily treats that as an active plugin to refresh, offering to install a deprecated version.

Observed 2026-04-20 on the first invocation of `/install-updates`: `addressr-mcp` had `wr-problem@windyroad` enabled. The skill queried npm, found `@windyroad/problem@0.1.3` still exists (though it is the deprecated shim), and offered to install 0.1.0 → 0.1.3. The user's response: "wr-problem no longer exists. its wr-itil now." Manual migration followed: `claude plugin install wr-itil@windyroad --scope project` in `../addressr-mcp`, then Edit `.claude/settings.json` to remove the `wr-problem@windyroad` enabled key.

This class of defect will recur: ADR-010 documented the wr-problem → wr-itil rename; future renames (e.g. if wr-c4 is ever generalised to wr-diagrams, or wr-risk-scorer is split, or any other restructure) will leave stale enabled-plugin keys in sibling settings.json files that `/install-updates` silently refreshes against.

The skill also cannot bootstrap the new name. The ADR-030 contract says: "install-updates only refreshes what's already enabled; it does not bootstrap new installs." So even if the skill knew about the rename, it wouldn't install `wr-itil` in addressr-mcp — it would only flag.

## Symptoms

- `/install-updates` offers to install a deprecated plugin against stale enabled-plugin keys.
- `claude plugin list` shows a deprecated plugin as active in a sibling project long after the rename landed.
- A new plugin released under the new name is NOT installed by `/install-updates`, even in projects that had the old name enabled and would logically want the new one.
- The migration is a three-step manual dance (install new, edit settings.json, maybe delete cache) that no skill currently automates.

## Workaround

Manually per affected project:
1. `cd ../<project> && claude plugin install <new-name>@windyroad --scope project` (installs new plugin and adds its entry to `enabledPlugins`).
2. Edit `../<project>/.claude/settings.json` directly to remove the old `<old-name>@windyroad` enabled-plugin key. `claude plugin uninstall` refuses project-scope installs per BRIEFING line 17.
3. (Optional) The cache directory `~/.claude/plugins/cache/windyroad/<old-name>/` can stay — it's harmless but unused.

## Impact Assessment

- **Who is affected**: any project with a stale enabled-plugin key pointing at a renamed or deprecated windyroad plugin. Currently: `addressr-mcp` (now fixed as of 2026-04-20). Likely future exposure: every rename lands the same class of friction in every sibling project that had the old name.
- **Frequency**: once per rename × per affected sibling project. Infrequent but painful when it happens.
- **Severity**: Minor — the old plugin still works (and `/install-updates` doesn't break things), but the audit trail is wrong (settings show a non-existent plugin as active) and the new plugin doesn't get installed where it's wanted.
- **Analytics**: observed 2026-04-20 on `/install-updates`' first invocation.

## Root Cause Analysis

### Structural

The ADR-030 contract treats plugin renames as out of scope:

> **Not in scope (deliberately)**: Pruning obsolete plugins. If you uninstalled a plugin, this skill does nothing about it — it only re-installs what is currently enabled.

That carve-out is correct for manual uninstalls (the user's choice). But for **upstream-driven renames** (the publisher deprecates one name and canonicalises another), the skill has no mechanism to detect or respond. There is no rename-mapping table anywhere in the suite.

### Fix strategy

Two parts, both optional but both useful:

1. **Rename-mapping table**. A small JSON file (e.g. `.claude/skills/install-updates/rename-mapping.json`) listing known renames:
   ```json
   [
     { "from": "wr-problem", "to": "wr-itil", "since": "2026-04-16", "adr": "ADR-010" }
   ]
   ```
   The skill reads this table as part of Step 2/3's discovery. Any enabled-plugin key whose name is in the `from` column is flagged as **stale** in the report, with a migration recommendation naming the `to` package.

2. **Migration consent gate**. If the user opts in, the skill can (a) `claude plugin install <to>@windyroad --scope project`, (b) edit `.claude/settings.json` to remove the `<from>@windyroad` enabled-plugin key. This is a second consent gate (separate from the sibling-targets gate in Step 6) because editing settings.json is a different class of side effect from refreshing a cached plugin.

Both steps fit within ADR-030's Confirmation criteria — the consent gate + report pattern already exist. The new migration-consent gate is a new action class but follows the same ADR-013 Rule 1 pattern.

### Affected files

- `.claude/skills/install-updates/SKILL.md` — add rename-detection to Step 2/3, migration-consent gate between Step 6 and Step 7, stale-entry section in the final report (Step 8).
- `.claude/skills/install-updates/rename-mapping.json` — NEW, initial entry for wr-problem → wr-itil, documented as the source of truth.
- `.claude/skills/install-updates/test/install-updates-rename-detection.bats` — NEW, bats regression asserting the skill flags a stale `wr-problem@windyroad` against the mapping table.
- **ADR-030 Confirmation section** — add a bullet for rename-mapping-table detection and migration-consent gate.

Scope decision deferred: should the rename-mapping table live inside `/install-updates` (this skill's private data) or be promoted to a suite-wide convention (e.g. `packages/shared/plugin-renames.json` that any skill can read)? Argue for the latter when a second consumer appears (e.g. a `/migrate-renames` skill). For now, keep it local.

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20 in `addressr-mcp`; stale `wr-problem@windyroad` entry refreshed rather than flagged.
- [ ] Design rename-mapping JSON schema (from, to, since, adr, deprecation-notice).
- [ ] Seed the mapping with wr-problem → wr-itil (P010) as the initial entry.
- [ ] Add rename-detection to install-updates Step 2/3 discovery logic.
- [ ] Add migration-consent gate between Step 6 and Step 7 (separate AskUserQuestion for "migrate stale entries?").
- [ ] Edit settings.json to remove stale keys (direct edit per BRIEFING line 17 — `claude plugin uninstall` refuses project-scope).
- [ ] Update the final report (Step 8) with a "Stale entries" section surfacing detected renames.
- [ ] Add bats regression test.
- [ ] Update ADR-030 Confirmation criteria to include rename-mapping awareness.
- [ ] Consider whether the mapping table should be promoted to suite-wide scope (deferred to a second consumer appearing).

## Related

- **ADR-010** (closed, commit `010-rename-wr-problem-to-wr-itil`) — the rename that triggered this gap.
- **ADR-030** — governs the install-updates skill; this problem extends its Confirmation section.
- **P045** (open) — auto plugin install after governance release. Interacts at the edge: P045's eventual automated queue would also need rename-awareness; resolving P059 in install-updates may produce a reusable pattern P045 borrows.
- **`.claude/skills/install-updates/SKILL.md`** — primary fix target.
- **P058** — sibling ticket for a different install-updates bug (digit-containing plugin names under-matched). Same output, different concern; fixed separately per P016/P017.
- **BRIEFING.md** line 17 — `claude plugin uninstall` refuses project-scope; settings.json edits are manual. Informs the migration-consent implementation.
