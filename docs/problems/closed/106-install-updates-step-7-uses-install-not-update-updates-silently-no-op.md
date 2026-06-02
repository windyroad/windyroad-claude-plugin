# Problem 106: `/install-updates` Step 7 uses `claude plugin install` which silently no-ops when a plugin is already installed — updates never actually land

**Status**: Open
**Reported**: 2026-04-22
**Priority**: 20 (High) — Impact: Major (4) x Likelihood: Almost certain (5)
**Effort**: S
**WSJF**: (20 × 1.0) / 1 = **20.0**

> Observed 2026-04-22 while running `/install-updates` after this session's `@windyroad/itil@0.17.2`, `@windyroad/architect@0.5.1`, `@windyroad/jtbd@0.7.1`, and `@windyroad/retrospective@0.8.0` releases. Step 7 called `claude plugin install wr-<plugin>@windyroad --scope project` across 24 project/plugin combos. **Every invocation printed `✔ Plugin "wr-<plugin>@windyroad" is already installed (scope: project)` and exited 0 — no cache refresh, no version pull.** Post-run verification showed `~/.claude/plugins/cache/windyroad/wr-<plugin>/` still had only the pre-release versions (0.17.0 / 0.5.0 / 0.7.0 / 0.6.0). The skill's entire stated purpose — "refresh every windyroad plugin install touched by recent releases" — silently failed. Worked around by switching to `claude plugin uninstall <plugin> --scope project` followed by `claude plugin install <plugin> --scope project`, which forces a fresh download.

## Description

`/install-updates` Step 7 is documented as:

```bash
for plugin in $PLUGINS_TO_UPDATE; do
  (cd "$TARGET_DIR" && claude plugin install "wr-$plugin@windyroad" --scope project)
done
```

The Claude Code CLI's `plugin install` command treats an already-installed plugin at any cached version as "nothing to do" and exits successfully without contacting the marketplace / npm to check whether a newer version is available. Consequence: every project that already has `wr-retrospective` (for example) at 0.6.0 stays on 0.6.0 forever as far as `plugin install` is concerned. The marketplace cache refresh in Step 1 (`claude plugin marketplace update windyroad`) updates the marketplace index but does NOT refresh individual plugin caches.

**This defeats the skill's core contract.** Every `/install-updates` invocation across this session's 6 projects × 4 changed plugins = 24 calls reported success but did nothing. The skill cannot be relied on until this is fixed.

`claude plugin update <plugin>` exists as a sibling command but rejects project-scoped installs: `"Failed to update plugin ... Plugin ... is not installed at scope user"`. That command works only for user-scoped installs — but ADR-004 mandates project-scope for all windyroad plugins, so `update` is unavailable for this skill's use case.

**The working pattern is `uninstall + install`**: `claude plugin uninstall wr-<plugin>@windyroad --scope project` followed by `claude plugin install wr-<plugin>@windyroad --scope project` forces a fresh download of the latest marketplace-resolved version. Tested this session across 6 × 4 = 24 combos: every one refreshed cleanly.

## Symptoms

- `/install-updates` Step 7 reports `✔ ... is already installed (scope: project)` on every call when the plugin already exists, regardless of whether a newer version is available on npm.
- `~/.claude/plugins/cache/windyroad/wr-<plugin>/` stays on the old version after the skill completes.
- No error, no warning — the user reads the "✓ installed" status in the Step 8 report and believes the new code is live.
- **User-visible consequence** (this session): after releasing `@windyroad/retrospective@0.8.0` with the new `SessionStart` briefing hook, `/install-updates` reported success but the cache stayed on 0.6.0. A session restart would have loaded the OLD plugin — the new hook would not fire.

## Workaround

Manual: after `/install-updates` runs, check cache versions against npm latest:

```bash
for plugin in itil architect jtbd retrospective risk-scorer voice-tone style-guide tdd c4 wardley connect; do
  cached=$(ls ~/.claude/plugins/cache/windyroad/wr-$plugin/ 2>/dev/null | sort -V | tail -1)
  latest=$(npm view "@windyroad/$plugin" version 2>/dev/null)
  [ "$cached" != "$latest" ] && echo "STALE: wr-$plugin cache=$cached latest=$latest"
done
```

For any STALE entries, run `claude plugin uninstall <plugin>@windyroad --scope project` then `claude plugin install <plugin>@windyroad --scope project` in the affected project. Repeat per sibling.

## Impact Assessment

- **Who is affected**: Every `/install-updates` invocation in every windyroad-plugin adopter project, plus this repo. Every session that follows a release without a manual cache-refresh workaround runs old plugin code while believing it's running new code.
- **Frequency**: Every release cycle (~1–5× per week in an active development session).
- **Severity**: Major. Directly defeats the skill's sole purpose and silently ships old code into production sessions. P045's entire interim-stopgap framing assumed Step 7 actually installed; with this defect, no release this session would have reached adopter caches without the manual workaround.
- **Analytics**: This session 2026-04-22: 24 install calls, 0 actual version refreshes. 100% silent no-op rate pre-workaround.

## Root Cause Analysis

### Confirmed Root Cause

`claude plugin install <plugin>` treats plugin-key presence (at any version) as the install predicate, not version currency. There is no flag documented in `claude plugin install --help` to force a version refresh (`--force`, `--reinstall`, `--update` not present). The skill's Step 7 therefore fires a no-op on every subsequent release.

`claude plugin update <plugin>` does exist and is documented as "Update a plugin to the latest version (restart required to apply)" but rejects project-scoped plugins with `"Plugin ... is not installed at scope user"`. The `update` subcommand appears to be user-scope-only in the current Claude Code CLI.

### Investigation Tasks

- [x] Confirm `claude plugin install` is a no-op on already-installed plugin keys regardless of version. Confirmed 2026-04-22 (24/24 no-op across this session's run).
- [x] Confirm `claude plugin update` rejects project scope. Confirmed 2026-04-22 (24/24 rejected with "not installed at scope user").
- [x] Confirm `uninstall + install` forces cache refresh. Confirmed 2026-04-22 (24/24 successful refresh using this pattern).
- [ ] Check whether a `--force` or `--reinstall` flag was added in a newer Claude Code CLI version that would simplify the workaround.
- [ ] Consider filing an upstream ticket against Claude Code CLI for `plugin update --scope project` support, so a single command path works for the windyroad ADR-004 project-scope mandate.

### Fix Strategy

Amend `.claude/skills/install-updates/SKILL.md` Step 7:

```bash
for proj_plugin in $PLUGINS_TO_UPDATE_PER_PROJECT; do
  TARGET_DIR=...
  plugin=...
  (cd "$TARGET_DIR" && claude plugin uninstall "wr-$plugin@windyroad" --scope project) || true
  (cd "$TARGET_DIR" && claude plugin install   "wr-$plugin@windyroad" --scope project)
done
```

The `|| true` on uninstall guards against the first-time install case where there's nothing to uninstall. Capture per-install exit status as before; report per-project per-plugin outcome in Step 8's table.

Also amend the Step 4 "Determine which plugins have new npm versions" check to compare `~/.claude/plugins/cache/windyroad/wr-<plugin>/` max version against `npm view @windyroad/<plugin> version` — **this session's run did this comparison but Step 7 didn't act on the result correctly**. Once Step 7 is fixed, the Step 4 comparison drives the decision (skip the uninstall+install pair when cached == latest).

Bats coverage: exercise Step 7 against a fixture repo where the plugin is pre-installed at an older version; assert the cache version increments after invocation.

## Dependencies

- **Blocks**: (none directly — but blocks every `/install-updates` run's actual effectiveness)
- **Blocked by**: (none — Claude Code CLI behaviour is a given; workaround is available today)
- **Composes with**: P045 (auto plugin install after governance release)

## Related

- **P045** — auto plugin install after governance release. This skill is the manual stopgap until P045's automated queue lands; P106 fixes the stopgap.
- **P058** — install-updates regex misses digit-bearing plugin names (sibling defect in an earlier Step).
- **P059** — install-updates no plugin rename handling (now closed; amendment covers rename migration in Step 6.5).
- **P061** — install-updates Step 6 grouping fallback for siblings > 3 (sibling UX fix).
- **ADR-004** — project-scope install mandate. The reason `claude plugin update` (user-scope-only) isn't usable here.
- **ADR-030** — repo-local skill convention governing `/install-updates`.
