# /install-updates — Reference

Deep context for the `/install-updates` skill. Load on demand when the runtime steps in `SKILL.md` do not give you enough to act. Progressive-disclosure companion per ADR-038 pattern applied to skill bodies (reference implementation of the pattern P097 is expected to generalise).

## Contract (per ADR-030)

- **Repo-local skill.** Not published. Lives in `.claude/skills/install-updates/` and is versioned by repo git history.
- **First action is a consent gate.** `AskUserQuestion` lists every sibling project this skill detected, with a dry-run option. No install runs before user confirmation.
- **Installs use `claude plugin install <pkg>@windyroad --scope project`.** Never global scope (ADR-004).
- **Does NOT restart Claude Code.** ADR-013 Rule 6 governs non-interactive behaviour; P045's 2026-04-20 direction decision explicitly rejected auto-restart. User restarts on their own cadence.

## Marketplace resolution semantics (Step 1)

Per BRIEFING: "The marketplace resolves from the remote GitHub repo, not the local working tree. You cannot install a new plugin until changes are pushed and `claude plugin marketplace update windyroad` pulls the latest."

Workflow implication: run the full release pipeline (`push:watch` + `release:watch`) BEFORE invoking `/install-updates`. Installing from an unpushed working tree silently resolves against the last-published version.

## Uninstall+install refresh pattern (P106)

`claude plugin install` is a silent no-op when the plugin is already installed at any version, so updates never land via `install` alone. The working refresh pattern for project-scoped plugins is `uninstall + install` — `claude plugin uninstall --scope project` does work for project-scope, contrary to earlier assumptions, and forces a fresh marketplace download on the subsequent install. SKILL.md Step 6 wraps this in a retry+rollback so a transient install failure cannot silently lose the plugin (P112).

## Consent cache (P120)

The Step 6 consent gate has zero decision content for steady-state solo-developer + stable-sibling-set workflows — the answer is invariably `All N projects (Recommended)` and the round-trip is friction. The cache file `.claude/.install-updates-consent` records the user's prior explicit answer so subsequent invocations can skip the gate when the answer is provably equal.

### Cache file shape

Per-project, gitignored, machine-local. JSON:

```json
{
  "scope": ["addressr-mcp", "addressr-react", "addressr", "bbstats", "windyroad"],
  "cached_at": "2026-04-25T13:33:05Z"
}
```

- `scope` — sorted list of sibling project names confirmed in the prior consent gate. Current project is implicitly in scope (ADR-004 — the project the skill lives in is always installed); not part of the cache.
- `cached_at` — ISO timestamp the cache was written (informational; cache invalidation is event-driven, not time-based).
- Empty `scope: []` is valid and stable — encodes the user's prior `Current project only` answer.

### Match rule

The match rule is **set equality** of the cached `scope` against the detected sibling set from Step 3. Same names, ignoring order. A new sibling appearing or an existing sibling disappearing invalidates the cache (re-prompt with previous answer surfaced as `(Recommended)`).

### Invalidation rules

- **Sibling-set change** — invalidate. The user's prior answer is over a different question; surface it as `(Recommended)` in the re-prompt and let them confirm or adjust.
- **Plugin-list change** (a sibling enables a new windyroad plugin) — DO NOT invalidate. The cache governs which projects to install in, not which plugins to install. Step 4 already discovers the per-plugin install plan against the post-cache sibling set.
- **No time-based expiry**. Consent doesn't have a half-life on a stable workspace. The cache is invalidated by event (sibling-set change) or explicit user action (file deletion / `INSTALL_UPDATES_RECONFIRM=1`).

### Governing rule (ADR-013 Rule 5)

Cache-hit skip-gate is a Rule 5 (policy-authorised silent proceed) case, NOT Rule 6 (non-interactive fail-safe). The cached on-disk consent IS the policy authorisation — Rule 5 explicitly authorises silent proceed when a stable user authorisation is on file. Rule 6 governs cases where AskUserQuestion is unavailable; that is unrelated to the cache hit.

### Architectural precedent (ADR-034)

ADR-034's `.claude/.auto-install-consent` per-project marker for the SessionStart auto-install surface is the parallel pattern. The two markers are independent — presence of one does not imply the other:

- `.claude/.auto-install-consent` (ADR-034) authorises the SessionStart hook to invoke `/install-updates` in the background when outdated `@windyroad/*` plugins are detected.
- `.claude/.install-updates-consent` (P120) caches the answer to `/install-updates`'s own Step 6 sibling-set consent gate.

The first authorises *whether* `/install-updates` runs at all; the second caches *which siblings* it touches when it does run.

### Escape hatches (preserve dry-run access)

The cache-hit path skips the gate entirely; `Dry-run` is a gate option and becomes unreachable on the steady-state path. Two equivalent escape hatches restore access:

- `INSTALL_UPDATES_RECONFIRM=1 /install-updates` — envvar silences the cache for one invocation; gate fires with previous answer surfaced.
- `rm .claude/.install-updates-consent && /install-updates` — delete the cache file; gate fires as first-run.

Both routes return the user to the dry-run option; neither breaks the cache permanently (the next normal invocation re-writes the cache after a successful run).

## Consent gate shape — the P061 fallback (Step 5)

ADR-030 requires that the consent gate list every detected sibling. `AskUserQuestion` caps `maxItems` at 4.

- **Siblings ≤ 3** — one option per sibling + dry-run = ≤ 4 options. Fits cleanly.
- **Siblings > 3** — the per-sibling options don't fit. Fallback: four bucketed options with every detected sibling named in the question body text (the cap applies to options, not to the question description, so ADR-030's "list every sibling" requirement is satisfied via the question body).

The `Other — provide custom text` affordance lets the user name a free-form subset (e.g. "addressr, bbstats"); the skill parses against the detected set.

Either shape satisfies ADR-030 Confirmation criteria (first action; lists all detected siblings; dry-run present; user retains subset authority).

## Edge cases

- **No windyroad plugins in current project.** Skip steps 2-6, report "nothing to install here" but still run on confirmed siblings if any found.
- **No siblings with windyroad plugins.** Skip the consent gate's sibling options; offer only the dry-run option. Current project is still installed without a consent gate (ADR-004 scope — it's the project the skill lives in).
- **Cache dir missing for a plugin.** The plugin was never installed locally. Skip it — `install-updates` only refreshes what's already enabled; it does not bootstrap new installs.
- **`npm view` fails.** Plugin may not be published yet or network is down. Report and skip that plugin; do not block other plugins.
- **Version-string staleness.** `claude plugin list` may show stale version strings (BRIEFING line 34). Always compare against `~/.claude/plugins/cache/windyroad/<plugin>/` directory names, not `list` output.
- **Plugin name vs npm package name mismatch.** Plugin name / marketplace cache key = `wr-<short-name>`; npm package = `@windyroad/<short-name>` (no `wr-` prefix). `npm view` returns empty (exit 0) for wrong names — treat empty output as "verify the name" (P092).

## Non-interactive fallback details (ADR-013 Rule 6)

When `AskUserQuestion` is unavailable (running inside a subagent without that tool, or a test harness):

1. Emit a dry-run table of intended installs.
2. Note that the user must re-run interactively to complete.
3. Do NOT install anything.

The fallback preserves ADR-030's "no install without consent" invariant even when the structured interaction path is blocked.

## Not in scope (deliberately)

- Updating non-windyroad plugins (`anthropics/skill-creator`, `claude-plugins-official`). Out of scope.
- Restarting Claude Code. User restarts on their own cadence (P045 direction 2026-04-20).
- Global-scope installs (`--scope user`). ADR-004: project-scope only.
- Pruning obsolete plugins. If you uninstalled a plugin manually, this skill does nothing about it — it only re-installs what is currently enabled.

## ADR cross-references

- **ADR-030** — governing decision; Confirmation criteria apply here.
- **ADR-003** — marketplace distribution (Confirmation amended in the same commit as ADR-030 to permit this skill).
- **ADR-004** — project-scoped plugin install.
- **ADR-013 Rule 6** — non-interactive fallback pattern.
- **ADR-038** — progressive disclosure for governance tooling context. This split implements the pattern at the SKILL.md level.
- **P045** — auto plugin install after governance release; interim manual stopgap.
- **P061** — sibling-count > 3 `AskUserQuestion` `maxItems` fallback.
- **P092** — `wr-` prefix mismatch between plugin name and npm package name.
- **P098** — SKILL+REFERENCE split pattern applied here.
- **BRIEFING.md** — marketplace resolution semantics, version-string staleness, `plugin install` vs `plugin update` distinction.
