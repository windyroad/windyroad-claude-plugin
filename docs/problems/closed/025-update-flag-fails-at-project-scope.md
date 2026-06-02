# Problem 025: --update flag fails for project-scoped plugins

**Status**: Closed
**Reported**: 2026-04-16
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost Certain (5)
**Effort**: S
**WSJF**: 30.0 — (15 × 2.0) / 1

## Description

The `--update` flag on all per-plugin npm installers (e.g. `npx @windyroad/risk-scorer --update`) fails with "Plugin not found" because `updatePlugin` in `packages/shared/install-utils.mjs` calls `claude plugin update ${pluginName}` — without the `@windyroad` marketplace suffix and without `--scope project`. The Claude SDK defaults to user scope, but all plugins are installed at project scope, so the lookup fails every time.

Discovered during the P020 release session when reinstalling the three newly-updated assessment-skills packages.

## Symptoms

```
Checking for updates for plugin "wr-risk-scorer" at user scope…
✘ Failed to update plugin "wr-risk-scorer": Plugin "wr-risk-scorer" not found
  FAILED: wr-risk-scorer
```

- `npx @windyroad/risk-scorer --update` fails
- `npx @windyroad/architect --update` fails
- `npx @windyroad/jtbd --update` fails
- Same failure for all other per-plugin packages (itil, c4, tdd, etc.)
- The command that **does** work: `claude plugin update "wr-risk-scorer@windyroad" --scope project`

## Workaround

Manually run `claude plugin update "<plugin-name>@windyroad" --scope project` for each plugin that needs updating.

## Impact Assessment

- **Who is affected**: All users of any per-plugin installer that uses the `--update` path. Affects the solo-developer and plugin-developer personas — this is the standard upgrade path.
- **Frequency**: Every time a user runs `npx @windyroad/<pkg> --update` after a release.
- **Severity**: High — the documented update path is completely broken. Users either learn the manual workaround or stay on outdated versions, missing new skills.
- **Analytics**: Observed directly this session — P020 release required three manual `claude plugin update` commands with the correct flags.

## Root Cause Analysis

`updatePlugin` in `packages/shared/install-utils.mjs` (~line 65):

```js
export function updatePlugin(pluginName) {
  return run(`claude plugin update ${pluginName}`, pluginName);
}
```

Two bugs:
1. **Missing marketplace suffix**: The working command is `claude plugin update "wr-risk-scorer@windyroad"`. The bare `wr-risk-scorer` form is not found because Claude SDK looks up `wr-risk-scorer` as a standalone plugin name, not a marketplace-qualified one.
2. **Missing `--scope project`**: All windyroad plugins are installed at project scope (default in `installPlugin`). The `update` command defaults to user scope, so it never finds them even with the correct name.

Compare with `installPlugin` which correctly uses:
```js
`claude plugin install ${pluginName}@${MARKETPLACE_NAME} --scope ${scope}`
```

`updatePlugin` has neither the `@${MARKETPLACE_NAME}` suffix nor the `--scope` parameter.

### Investigation Tasks

- [x] Reproduce the failure (`npx @windyroad/risk-scorer --update` → "Plugin not found")
- [x] Identify the incorrect command in `updatePlugin` (missing suffix + scope)
- [x] Confirm the working command (`claude plugin update "wr-risk-scorer@windyroad" --scope project`)
- [x] Locate the fix point: `packages/shared/install-utils.mjs` `updatePlugin` function

### Fix Strategy

1. Add `scope` parameter to `updatePlugin(pluginName, { scope = "project" } = {})`
2. Change the run command to: `` `claude plugin update "${pluginName}@${MARKETPLACE_NAME}" --scope ${scope}` ``
3. Thread `scope` from `updatePackage` → `updatePlugin` (read it from `flags.scope` like `installPackage` does)
4. Update all per-plugin `install.mjs` files if they override `updatePackage` — check `packages/*/bin/install.mjs`

Single file change; no hook or agent changes needed.

## Fix Released

Deployed in commit `9a468ec`. Fix applied to all 13 `install-utils.mjs` copies (shared + 12 per-package `lib/`) and all 12 `bin/install.mjs` entry points. Awaiting user verification that `npx @windyroad/<pkg> --update` works correctly.

## Related

- `packages/shared/install-utils.mjs` — `updatePlugin` function (~line 65), `updatePackage` (~line 97)
- `packages/risk-scorer/bin/install.mjs`, `packages/architect/bin/install.mjs`, etc. — per-plugin callers
- P003: `docs/problems/003-plugin-installs-stack.closed.md` — prior installer bug (closed)
- Discovered during P020 release session
