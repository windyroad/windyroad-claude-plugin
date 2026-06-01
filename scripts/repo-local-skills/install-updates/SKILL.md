---
name: install-updates
description: Refresh the windyroad marketplace cache and re-install any updated `@windyroad/*` plugins. Runs a single global-cache refresh from the current project — because the plugin install cache is global/shared across projects, this advances the active version for every project that enables those plugins. Run at end-of-session after a release loop so every active project picks up the new code on next session start. Repo-local skill per ADR-030.
allowed-tools: Read, Bash, Grep, Glob
---

# /install-updates

Refresh every windyroad plugin touched by recent releases in one skill invocation — a single global-cache refresh run from the current project. Interim stopgap for P045.

**Why current-project-only is sufficient: the plugin install cache is global.** The install cache at `~/.claude/plugins/cache/windyroad/<key>/<version>/` is shared across all projects on this machine — there is no per-project copy of the plugin code. Refreshing it from the current project (uninstall + reinstall, to defeat the P106 install-no-op) advances the active version for EVERY project that enables those plugins. No sibling-project tree is written, so there is no cross-project side effect to discover or consent to. (Historical note: earlier versions ran a per-sibling install loop behind an `AskUserQuestion` consent gate; both were retired 2026-05-25 once the global-cache fact was confirmed — see ADR-030 amendment 2026-05-25.)

See `REFERENCE.md` in this directory for marketplace-resolution semantics, the uninstall+install rationale, edge cases, and scope exclusions.

## When to invoke

- End of a release-loop session (after `npm run release:watch` publishes `@windyroad/*` packages).
- After noting a plugin bump in another session's commit log.
- Safe to run any time — it only refreshes the global cache for already-enabled plugins; it makes no cross-project tree write.

## Steps

### 1. Refresh the marketplace cache

```bash
claude plugin marketplace update windyroad
```

Marketplace resolves from the remote GitHub repo, not the local working tree — push before running. See REFERENCE.md → "Marketplace resolution semantics".

### 2. Discover the current project's installed windyroad plugins

```bash
CURRENT_PLUGINS=$(grep -oE '"wr-[a-z0-9-]+@windyroad"' .claude/settings.json 2>/dev/null \
  | sed 's/"//g; s/@windyroad//' | sort -u)
```

These are the plugin keys (`wr-<short>`) to check for updates. The skill refreshes only what is already enabled — it does not bootstrap new installs.

### 3. Determine which plugins have new npm versions

For each unique plugin key (`wr-<short>`):

```bash
# Plugin/marketplace side uses the wr- prefix; the npm package omits it.
# Strip the prefix to obtain the npm package name:
#   plugin_key="wr-itil"      → npm_name="@windyroad/itil"
#   plugin_key="wr-architect" → npm_name="@windyroad/architect"
npm_name="@windyroad/${plugin_key#wr-}"
npm view "$npm_name" version
```

Naming convention (ADR-002): `wr-<short>` on the plugin/marketplace side, `@windyroad/<short>` on the npm side, same `<short>` as the source directory under `packages/`.

**Empty `npm view` output with exit 0 means the package name is wrong — NOT that the package is private.** `@windyroad/*` packages are public on the npm registry (e.g. <https://www.npmjs.com/package/@windyroad/itil>). If every plugin returns empty, the skill is using the wrong naming transformation — stop and fix before concluding "nothing to install," otherwise Step 4 will silently skip real updates.

Compare against `~/.claude/plugins/cache/windyroad/${plugin_key}/` (the cache directory uses the plugin key `wr-<short>`, not the npm name). Re-install only when npm latest > highest cached version. `claude plugin list` version strings may be stale — compare against cache dir names.

### 4. Install

Uninstall first to force a fresh download — `claude plugin install` silently no-ops when the plugin is already installed, so updates never land (P106 / BRIEFING "Plugin Distribution"). The uninstall+install chain is not atomic: if uninstall succeeds and install fails, the plugin is gone (P112). Wrap the install side in bounded retry + rollback so a transient failure cannot silently remove a plugin.

```bash
# install_with_retry_rollback <plugin> <target> <prior_version>
# Refresh a single plugin in a project scope with retry + rollback safety.
# Uninstall first (P106 workaround for install silent-no-op), retry the
# install 3× with exponential backoff (1s, 2s, 4s), and on exhaustion
# refresh the marketplace cache + one rollback install attempt.
# Prints one of: installed | restored | lost
install_with_retry_rollback() {
  local plugin="$1" target="$2" prior="${3:-unknown}"
  local key="wr-$plugin@windyroad"
  (cd "$target" && claude plugin uninstall "$key" --scope project) || true
  local attempt delay=1
  for attempt in 1 2 3; do
    if (cd "$target" && claude plugin install "$key" --scope project); then
      echo "installed"
      return 0
    fi
    if [ "$attempt" -lt 3 ]; then
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done
  # All retries exhausted. Rollback path: refresh the marketplace cache
  # and attempt one more install — distinct from retry because the cache
  # has been refreshed, maximising the chance a different outcome lands.
  # Prior version (${prior}) is captured for reporting; marketplace
  # resolves to latest, so "restored" here means the plugin is present,
  # not necessarily at the pre-refresh version.
  claude plugin marketplace update windyroad >/dev/null 2>&1 || true
  if (cd "$target" && claude plugin install "$key" --scope project); then
    echo "restored"
    return 0
  fi
  echo "lost"
  return 1
}

# restore_settings_on_loss <snapshot> <settings_file> [<lost_plugin>...]
# P259 defensive recovery. Restore the pre-loop .claude/settings.json snapshot
# iff at least one plugin ended `lost` (all retries + the marketplace-refresh
# rollback exhausted — the plugin is now absent from settings.json because the
# Step-4 uninstall removed its enabledPlugins entry and no install re-added it).
# SAFE for plugins that refreshed successfully in the SAME run: the
# enabledPlugins map carries NO version pin — the version advance lives in the
# global cache (~/.claude/plugins/cache/...), not in settings.json — so a
# successful refresh's entry is byte-identical before and after the loop, and a
# full-file restore re-adds the lost plugin(s) without regressing any success.
# ASSUMES enabledPlugins has no per-run-mutated field; if a future Claude Code
# release adds version pinning here, switch to a surgical re-add of the lost
# keys only. Prints "restored <plugins>" or "no-restore".
restore_settings_on_loss() {
  local snapshot="$1" settings="$2"; shift 2
  local lost=("$@")
  if [ "${#lost[@]}" -gt 0 ] && [ -n "$snapshot" ] && [ -f "$snapshot" ]; then
    cp "$snapshot" "$settings"
    echo "install-updates: restored .claude/settings.json from pre-loop snapshot — lost plugin(s): ${lost[*]}" >&2
    echo "restored ${lost[*]}"
    return 0
  fi
  echo "no-restore"
  return 0
}

declare -A PROJECT_STATUS
# PLUGINS_TO_UPDATE is a bash array (NOT a space-separated string) for
# cross-shell portability — see P133. Plain `for x in $VAR` word-splits
# under bash but iterates ONCE under zsh (zsh does not word-split unquoted
# variables by default), silently masking lost plugins as one bogus
# joined-name install. Array form + quoted `"${ARR[@]}"` expansion behaves
# identically under bash and zsh.
TARGET_DIR="$PWD"
PLUGINS_TO_UPDATE=(itil retrospective risk-scorer tdd)

# P259: snapshot the project's plugin-enablement state BEFORE the
# uninstall+install loop. The uninstall side of each refresh immediately
# removes the plugin's enabledPlugins entry; if every install attempt AND the
# marketplace-refresh rollback then fail (e.g. a broken manifest already
# published — the 2026-05-18 P0), the plugin is left absent and the project
# silently loses enablement (the cascade that gutted settings from 13 plugins
# to 2). The snapshot lets an exhausted `lost` outcome be undone below. A
# working-tree `cp` (not `git checkout HEAD`) captures the exact pre-run state,
# including any uncommitted settings.json edits and the untracked-file case.
SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
SETTINGS_SNAPSHOT=""
if [ -f "$SETTINGS_FILE" ]; then
  SETTINGS_SNAPSHOT="$(mktemp -t install-updates-settings.XXXXXX)"
  cp "$SETTINGS_FILE" "$SETTINGS_SNAPSHOT"
fi

for plugin in "${PLUGINS_TO_UPDATE[@]}"; do
  PROJECT_STATUS["$plugin"]=$(install_with_retry_rollback "$plugin" "$TARGET_DIR" "${PRIOR_VERSION[$plugin]}")
done

# P259: restore-on-exhausted-loss. Collect plugins that ended `lost` and
# restore the pre-loop snapshot if any are present, so a broken-manifest
# cascade can no longer gut .claude/settings.json. No-op when nothing was lost
# (empty array → zero trailing args → restore_settings_on_loss prints
# "no-restore"). Quoted `"${lost_plugins[@]}"` expansion is bash/zsh-portable
# per P133 and expands an empty array to zero args under both shells.
lost_plugins=()
for plugin in "${PLUGINS_TO_UPDATE[@]}"; do
  [ "${PROJECT_STATUS[$plugin]}" = "lost" ] && lost_plugins+=("$plugin")
done
restore_settings_on_loss "$SETTINGS_SNAPSHOT" "$SETTINGS_FILE" "${lost_plugins[@]}"
[ -n "$SETTINGS_SNAPSHOT" ] && rm -f "$SETTINGS_SNAPSHOT"
```

`--scope project` always (ADR-004). The refresh runs in the current project (`TARGET_DIR="$PWD"`); because the install cache is global, a single current-project refresh advances the active version for every project that enables the plugin. Capture per-install exit status. Do not abort the batch on a single failure — report and continue. A `lost` status means the install could not be landed within the retry + rollback budget. The post-loop snapshot restore (P259) re-adds the lost plugin's `.claude/settings.json` enablement so the project is not left gutted — but the plugin code is still un-refreshed; the user must re-run after the upstream cause (e.g. a broken manifest) is hotfixed. If the snapshot itself is unavailable (settings.json untracked and no snapshot captured), recover the enablement manually with `git checkout HEAD -- .claude/settings.json` (settings.json is git-tracked in this repo).

Shell snippets in this skill use bash-array form (`ARR=(a b c)` + `"${ARR[@]}"`) instead of unquoted-variable iteration (`for x in $VAR`). The array form is portable across bash and zsh; unquoted iteration is bash-only and silently iterates once under zsh — see P133 (`docs/problems/133-...md`).

### 5. Final report

```
| Surface | Before | After | Status |
|---------|--------|-------|--------|
| wr-itil | 0.7.1 | 0.7.2 | ✓ installed |
| wr-jtbd | 0.5.0 | 0.5.0 | ✓ restored (rollback) |
| wr-tdd  | 0.4.0 | —     | ✗ lost (rollback failed) |
```

Status vocabulary (P112): `✓ installed` — install landed first or within retry budget. `✓ restored (rollback)` — all retries exhausted; marketplace-cache refresh + one rollback install succeeded. `✗ lost (rollback failed)` — retries and rollback both failed; plugin is absent from the project and the user must reinstall manually. `✗ failed` — pre-install step (e.g. uninstall) errored, plugin left in original state.

Then `### Next step` — **"Restart Claude Code REQUIRED to use the refreshed plugin code via shims in the current session."** Without restart, shim invocations (e.g. `wr-architect-generate-decisions-compendium`) may still resolve to the PREVIOUS plugin version's `/bin` directory and run OLD code — the global cache refresh advances `~/.claude/plugins/cache/windyroad/<plugin>/<version>/` but does NOT mutate the parent shell's `$PATH`. PATH was frozen at session-init from cache state at that time; subsequent `/install-updates` calls add new versions to cache but leave the stale `<plugin>/<old-version>/bin` first on PATH, so shim lookups continue to find the old version (P343). Workaround for the current session without restart: invoke shims by absolute path of the desired version (`~/.claude/plugins/cache/windyroad/<plugin>/<latest>/bin/<shim-name>`). Auto-restart was explicitly rejected per P045 direction 2026-04-20.

## Non-interactive fallback

This skill is safe to run non-interactively (e.g. inside a subagent or an AFK loop): it makes no cross-project tree write and asks no questions, so there is nothing to gate. Run it directly — it refreshes the global cache for the current project's enabled plugins and reports what it refreshed (the Step 5 table). If `npm view` or the marketplace refresh fails for a plugin, report and skip that plugin without aborting the batch.

## References

- **ADR-030** — repo-local skills (governing). Amended 2026-05-25 — consent gate / sibling-discovery retired (global cache means no cross-project tree write to consent to).
- **ADR-003 / ADR-004** — marketplace distribution / project-scope only.
- **ADR-002** — `wr-<short>` ↔ `@windyroad/<short>` naming transform (`npm view` package-name derivation).
- **P106** — `claude plugin install` silent no-op when already installed; `uninstall + install` is the refresh pattern.
- **P112** — non-atomic uninstall+install; bounded retry + marketplace-refresh-rollback safety (`install_with_retry_rollback`).
- **P133** — bash-array portability (`ARR=(...)` + `"${ARR[@]}"`; never unquoted `for x in $VAR`).
- **P139 / ADR-030 Symlink Contract** — source-of-truth at `scripts/repo-local-skills/install-updates/`; `.claude/skills/install-updates/` carries relative symlinks. Edit the source path only.
- **P092** — npm package-name gap; empty `npm view` output means wrong name, not private package.
- **P098 / ADR-038** — SKILL+REFERENCE progressive-disclosure split applied here.
- **P045** — auto plugin install after governance release. This skill is the manual stopgap until P045's automated queue lands.
- **P343** — `/install-updates` refreshes the global plugin cache but does not mutate the parent shell's `$PATH`; mid-session shim invocations may continue running the previous version. Step 5 "Next step" prose documents the limitation; structural fixes (highest-version-wins shim wrapper, SessionStart PATH-refresh hook) deferred as ADR-class follow-ups.
- **Risk-register bootstrap moved out of this skill.** The Step 6.5 bootstrap auto-trigger (ADR-059 verdict A6) was retired 2026-05-25 — see ADR-059 amendment 2026-05-25. Bootstrap a `docs/risks/` register from `.risk-reports/` on demand via `/wr-risk-scorer:bootstrap-catalog` (the A4 surface).

Rationale, edge cases, scope exclusions, and per-step BRIEFING references: `REFERENCE.md`.
