---
status: "proposed"
date: 2026-04-20
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-07-20
---

# Repo-local skills for project-specific workflow tooling

## Context and Problem Statement

The Windy Road plugin suite distributes every skill through the marketplace under `packages/*/skills/` (ADR-002, ADR-003). This works for reusable, cross-project skills, but some workflow tooling is project-specific enough that it does not belong in a published plugin.

The concrete trigger (2026-04-20): after a governance release loop shipped three plugin updates (`@windyroad/itil@0.7.2`, `@windyroad/architect@0.4.1`, `@windyroad/jtbd@0.6.0`), the user needed to install the new versions into the current project AND into five sibling projects (`../addressr`, `../addressr-react`, `../addressr-mcp`, `../bbstats`, `../windyroad`). The manual per-project `cd … && claude plugin install …` loop is repetitive, error-prone, and not something to add to a published plugin — it is specific to this machine's directory layout and the user's multi-project workflow. The solo-developer persona explicitly lists this as a pain point ("plugin-version drift across sibling projects on the same machine").

Three related architectural concerns were flagged during design:

1. **No precedent for repo-local skills**: ADR-003's Confirmation criteria reference "No `.claude/skills/` … created in the project" in the context of rejecting the `skills` npm package's symlink workaround. The suite's canonical answer to "where do skills live?" has been `packages/*/skills/` — marketplace only.
2. **Cross-project side effects**: a skill that writes to sibling projects' `.claude/` directories inverts ADR-004's project-isolation model ("install here, use here"). No existing ADR covers consent, dry-run, or downgrade semantics for cross-project tooling invoked from a single repo.
3. **Relationship to P045**: P045's 2026-04-20 direction decision picks "deferred install on next session start" as the target state, with auto-restart of active sessions explicitly rejected. A user-invoked end-of-session install shortcut sits between the status quo (manual per-project cd loop) and P045's target (automated queue + startup-check).

## Decision Drivers

- **Discoverability via `/` autocomplete** — project-specific workflow tooling should not be hidden as a `scripts/*.sh` file. ADR-011 and ADR-015 already favour skill-wrapping over raw scripts for user-facing workflows.
- **Consent for cross-project writes** — per ADR-013's structured-interaction principle, the user should see which sibling projects will be touched before any install runs.
- **Marketplace distribution (ADR-002, ADR-003) remains the default** — repo-local skills are an exception for genuinely project-specific tooling, not a new parallel channel for reusable skills.
- **`.claude/skills/` is the Claude Code convention** for project-local skills — the runtime already resolves them via `/<name>` autocomplete without any plugin prefix.
- **P045's direction decision** opens space for a manual stopgap. This ADR recognises that stopgap as a legitimate, ADR-backed pattern rather than an unblessed side door.
- **Solo-developer persona constraint** — plugin-version drift across siblings is a documented pain point (persona update 2026-04-20). The consent gate preserves the persona's "don't let agents silently write to my sibling projects" expectation.

## Considered Options

### Option 1: Repo-local skill at `.claude/skills/install-updates/SKILL.md` (chosen)

Skill lives under `.claude/skills/` in this repo. Not distributed via marketplace. Invoked as `/install-updates` (no plugin-prefix). First action is `AskUserQuestion` confirming which sibling projects to include. Second action refreshes marketplace cache and installs updates. Third action reports a per-project × per-plugin status table.

**Pros**:
- Discoverable via `/` autocomplete.
- Closes the manual-loop friction without re-purposing the marketplace.
- Respects ADR-004's project-isolation intent via explicit consent.
- Fits the P045 stopgap role cleanly — narrows P045's remaining scope to the automated queue.

**Cons**:
- Introduces a second skill distribution model (repo-local alongside marketplace).
- ADR-003's Confirmation wording appears to conflict (addressed via same-commit amendment).

### Option 2: Publish as a marketplace plugin (e.g. add to `@windyroad/itil`)

Publish the skill via the marketplace under `packages/itil/skills/install-updates/`. Downstream consumers get the skill automatically.

**Pros**:
- Single distribution channel (marketplace only).
- No ADR-003 wording tension.

**Cons**:
- The skill reaches into sibling directories specific to this user's local filesystem layout. A published version would either be useless to other users (their layouts differ) or would require so much configuration to make portable that it would no longer be an end-of-session convenience.
- Forces generic abstractions for a workflow that is deliberately opinionated about this repo's sibling arrangement.

**Rejected** — the portability tax outweighs the single-channel benefit.

### Option 3: Shell script under `scripts/`

Write `scripts/install-updates.sh`. The user runs it directly.

**Pros**:
- No ADR implications (scripts are an established pattern: `sync-install-utils.sh`, `sync-plugin-manifests.mjs`).
- Simplest to implement.

**Cons**:
- Not discoverable via `/` autocomplete — the user has to remember the path.
- ADR-011 and ADR-015 both favour skill-wrapping over raw scripts when the entrypoint is user-facing.
- Cross-project consent gating via `AskUserQuestion` is not a natural fit for a bash script (would need to re-invoke Claude).

**Rejected** — discoverability and consent-gating needs favour a skill.

## Decision Outcome

**Chosen: Option 1 — repo-local skill with source-of-truth at `scripts/repo-local-skills/<skill-name>/` and resolution-layer symlinks at `.claude/skills/<skill-name>/`**, with the following contract for any future repo-local skill in this project:

1. **Source-of-truth location**: `scripts/repo-local-skills/<skill-name>/SKILL.md` (with optional `REFERENCE.md` and `test/`). All editing targets this path.
   **Resolution-layer location**: `.claude/skills/<skill-name>/` is a directory of relative symlinks pointing into the source-of-truth — one symlink per file (`SKILL.md`, `REFERENCE.md`, `test/`). Claude Code resolves `/<skill-name>` autocomplete via the symlinks. The architect / JTBD / style-guide / voice-tone gates fire on the source path under their normal rules; the symlink targets are write-once (one architect approval at creation; subsequent edits go through the source path under normal review). See "Symlink contract" below.
2. **Scope**: project-specific workflow tooling that would not be useful in a published plugin. If a skill's logic is re-usable, publish it via the marketplace instead.
3. **Cross-project side effects** (when applicable): the skill's first action MUST be an `AskUserQuestion` listing every sibling project it detected and requiring the user to confirm the set before any install, write, or network call. A dry-run option must appear in the same call. **[RETIRED for `install-updates` 2026-05-25 — see "Amendment 2026-05-25" below. `install-updates` no longer writes to any sibling tree (the plugin install cache is global/shared), so the cross-project-write risk this gate guarded no longer exists. The consent gate, dry-run option, and P120 consent cache are removed for `install-updates`. This contract clause survives as the general rule for any FUTURE repo-local skill that genuinely writes to sibling project trees.]**
4. **No hooks**: repo-local skills do NOT install hooks. Hook scripts go in published plugins (ADR-009 gate-marker lifecycle, ADR-014 commit ordering) where they are versioned and tested.
5. **No CHANGELOG** required — repo-local skills are versioned by the repo's own git history, not by changeset.
6. **Bats tests optional**: doc-lint bats tests are welcome but not required. If present, they live under `scripts/repo-local-skills/<name>/test/` (the source-of-truth path) and are wired into `npm test` via the existing `bats --recursive` glob. Tests SHOULD run independent of symlink resolution so they pass on platforms where symlink creation is restricted (Windows without Developer Mode, sandboxed CI).

The `install-updates` skill is the first instance of this pattern and serves as the worked example. ADR-003's Confirmation wording (no installer-created entries under `.claude/skills/`) accommodates user-and-agent-authored symlinks pointing into `scripts/repo-local-skills/` — the symlink shape is governed by this ADR.

### Symlink contract (P139, 2026-04-28 amendment)

Repo-local skills carry per-edit gate-overhead when their source-of-truth lives under `.claude/skills/` because the architect / JTBD / style-guide / voice-tone PreToolUse hooks fire on every edit (P139 evidence: two architect re-runs to land a single SKILL.md trim). Relocating the source-of-truth outside `.claude/` and replacing the in-`.claude/skills/` content with symlinks converts this **per-edit** cost into a **per-relocation** cost:

- The symlink creation itself is a one-time operation reviewed by the architect (a single approval per file added to a repo-local skill).
- Subsequent edits target the source path under `scripts/repo-local-skills/` and follow the **normal review process** — architect / JTBD / style-guide / voice-tone gates fire on the source path under their normal rules. No exclusion exists for `scripts/repo-local-skills/` (verified during P139).
- Claude Code's `/<skill-name>` autocomplete continues to resolve via the symlink at `.claude/skills/<skill-name>/SKILL.md`, so user-facing discoverability (the ADR-030 Decision Driver) is unchanged.

**Symlink shape rules**:

- **Relative symlinks only.** Absolute paths break across clones, work trees, and any future repository move. The relative path from `.claude/skills/<name>/<file>` to `scripts/repo-local-skills/<name>/<file>` is `../../../scripts/repo-local-skills/<name>/<file>` (and `../../../../` for files under `test/`).
- **Per-file symlinks (not directory-level), with one allowed exception.** Each `SKILL.md` and `REFERENCE.md` is its own symlink so adding a new top-level file to a repo-local skill requires explicit symlink creation reviewed by the architect — preventing surprise additions to `/<name>` autocomplete. The `test/` directory MAY be a single directory-level symlink because adding a new bats file there is a routine TDD action that does not affect skill discoverability.
- **Source-of-truth files are regular files, never symlinks.** Avoid loops or chained resolution.

**Known degradation — Windows symlink permissions**:

On Windows, symlink creation requires either Developer Mode enabled or `core.symlinks=true` in the local git config (the Git for Windows installer asks during setup). On a contributor machine without those, `git clone` materialises the entries under `.claude/skills/<name>/` as regular files containing the symlink target text — `/<skill-name>` autocomplete will not work because Claude Code reads the file content as if it were a SKILL.md. The source-of-truth path under `scripts/repo-local-skills/<name>/` continues to work for editing and `bats` testing. If the symlink resolution must work on a contributor's Windows machine, they enable Developer Mode + `git config core.symlinks true`, then re-clone or run `git checkout -f`. This is the only documented failure mode of the relocation.

## Relationship to P045 and ADR-020

- **ADR-020 (auto-release)** covers the release side. **P045** tracks the install side. **This ADR** provides the pattern for P045's manual stopgap — it does not close P045.
- P045's direction decision (2026-04-20) explicitly selects "deferred install on next session start" as the target. The `install-updates` skill is a **user-invoked stopgap** that runs at end-of-session, not an automated queue. When P045's queue mechanism is built, the skill becomes redundant (or evolves into a manual override).
- P045 is updated in the same commit as this ADR to note the skill's role as interim tooling.

## Consequences

### Good

- **Discoverable tooling**: `/install-updates` shows up in autocomplete; no path-memorisation tax.
- **Project-isolation respected**: consent gate (`AskUserQuestion` with detected siblings) keeps the user in the loop for cross-project writes.
- **Pattern established**: future project-specific workflow needs have a canonical place (`.claude/skills/`) and a canonical contract.
- **Marketplace remains the default**: nothing changes for reusable skills. Repo-local is explicitly the exception.
- **Closes a real friction**: the 2026-04-20 manual loop touched 5 siblings × 3 plugins = 15 install invocations. The skill collapses this to one.
- **Serves a documented persona pain point**: solo-developer's "plugin-version drift across siblings" pain point (persona update 2026-04-20) has a first-class tool.

### Neutral

- **Two distribution models to teach** (marketplace for reusable; repo-local for project-specific). Mitigated by the Decision Driver "Marketplace distribution remains the default" — repo-local is a recognised exception.
- **Cross-project traversal**: the consent gate makes the exception explicit on every invocation.
- **ADR-003 same-commit amendment**: narrow Confirmation wording rather than supersede — ADR-003's intent (no installer-created `.claude/skills/`) is preserved.

### Bad

- **Discoverability vs. isolation tension**: other users of this repo may see `/install-updates` in autocomplete and invoke it without understanding the cross-project reach. Mitigation: the consent gate fires on every invocation.
- **No per-skill version pinning**: repo-local skills do not go through the changeset release pipeline. Mitigation: repo-local skills are small, project-specific, and versioned by git history.
- **Second distribution channel**: future maintainers must decide "ship this as a marketplace skill vs. a repo-local skill?" Mitigation: the Scope clause in the contract names the test — is the logic re-usable?

## Confirmation

- `scripts/repo-local-skills/install-updates/SKILL.md` exists as the source-of-truth and is the first repo-local skill.
- `.claude/skills/install-updates/SKILL.md`, `REFERENCE.md`, and `test/` are relative symlinks pointing into `scripts/repo-local-skills/install-updates/` (e.g. `SKILL.md → ../../../scripts/repo-local-skills/install-updates/SKILL.md`).
- `bats scripts/repo-local-skills/install-updates/test/` passes (tests run against the source-of-truth path independent of symlink resolution).
- Architect and JTBD PreToolUse hooks fire on edits to `scripts/repo-local-skills/<name>/` (verified: no `scripts/` carve-out in `packages/architect/hooks/architect-enforce-edit.sh` or `packages/jtbd/hooks/jtbd-enforce-edit.sh`). Style-guide, voice-tone, and risk-scorer hooks use file-type matching not path exclusion, so they fire based on content independent of location.
- ~~The skill's first action is an `AskUserQuestion` listing detected sibling projects and requiring consent before any install runs.~~ **[RETIRED 2026-05-25 — superseded by "Amendment 2026-05-25" below. `install-updates` is now a single global-cache refresh run from the current project with no sibling-tree write and no consent gate.]**
- ~~A dry-run preview option is available in the same consent call.~~ **[RETIRED 2026-05-25 — superseded by "Amendment 2026-05-25". No consent call exists, so there is no dry-run option within it; the skill is safe to run directly because it makes no cross-project tree write.]**
- The skill reports a per-project × per-plugin table (version-before, version-after, status) at completion.
- The skill does NOT install hooks.
- No CHANGELOG entry is created for the skill; the skill is versioned by repo git history.
- ADR-003's Confirmation criterion on `.claude/skills/` is amended in the same commit to point at this ADR.
- **Consent cache carve-out (P120, 2026-04-25 amendment)** **[RETIRED 2026-05-25 — superseded by "Amendment 2026-05-25" below. With the consent gate itself retired for `install-updates`, the consent cache it optimised has no decision content to cache; the `.claude/.install-updates-consent` marker is no longer read or written.]**: the "first action is consent gate" rule narrows to "consent gate as first action UNLESS a per-project consent cache (`.claude/.install-updates-consent`) exists AND its cached scope matches the current sibling set. When the cache hits, the gate is skipped per ADR-013 Rule 5 (policy-authorised silent proceed) — the cached on-disk consent IS the policy authorisation. When the cache misses or mismatches, the gate fires as today (cache-miss-with-stale-cache surfaces the previous answer as `(Recommended)` in the question body). The match rule is **set equality** of the cached `scope` against the detected sibling set from Step 3 — same names, ignoring order. A plugin-list change in any sibling does NOT invalidate the cache (the cache governs project membership in the install plan, not plugin selection); cache invalidation has no time component on a stable workspace. Dry-run access is preserved via two equivalent escape hatches: `INSTALL_UPDATES_RECONFIRM=1 /install-updates` envvar silences the cache for one invocation, or `rm .claude/.install-updates-consent && /install-updates` deletes the cache file; both restore the user to the gate-with-dry-run path. Cache file shape, invalidation rules, and the parallel-pattern note vs. ADR-034's `.claude/.auto-install-consent` live in `REFERENCE.md` → "Consent cache (P120)". The two markers are independent — presence of one does not imply the other.

## Amendment 2026-05-25 — install-updates narrowed to global-cache refresh (consent gate retired)

**Status: in effect (ADR remains `proposed`).** This amendment narrows the `install-updates` worked example; it does NOT change the general repo-local-skill contract for any future skill that genuinely writes to sibling project trees.

### What changed

`install-updates` is narrowed to a **single global-cache refresh run from the current project**. The sibling-project discovery loop, the per-sibling `claude plugin install --scope project` loop, the `AskUserQuestion` consent gate (Decision Outcome point 3), the dry-run option, the P120 consent cache (`.claude/.install-updates-consent`), and the P061 sibling-cap fallback are all **retired** for this skill.

### Why the consent gate is retired (the risk it guarded no longer exists)

The original consent gate existed to satisfy Decision Driver "Consent for cross-project writes" and to mitigate the concern recorded in Context point 2: *"a skill that writes to sibling projects' `.claude/` directories inverts ADR-004's project-isolation model."*

The user-confirmed architectural fact (2026-05-25) dissolves that premise: the plugin **install cache is global/shared** across all projects on the machine — `~/.claude/plugins/cache/windyroad/<key>/<version>/` is a single copy of the plugin code, not a per-project copy. Refreshing it from the current project (uninstall + reinstall, to defeat the P106 install-no-op) advances the active version for **every** project that enables those plugins. There is **no per-project cache and no sibling-project tree write** — so there is no cross-project side effect to discover, list, or consent to. The consent gate guarded a write that no longer occurs; it is removed rather than preserved as dead ceremony.

User direction (verbatim, 2026-05-25, via `AskUserQuestion`): *"it just needs to refresh. That will impact all the sibling projects that use it. There isn't another viable option. So just do that."*

### Effect on this ADR's clauses

- **Decision Outcome point 3** — retired for `install-updates` (annotated inline above). Survives as the general rule for any future repo-local skill that genuinely writes to sibling trees.
- **Confirmation** — the "first action is an `AskUserQuestion` listing detected sibling projects" and "dry-run preview option" criteria are retired/superseded (annotated inline above). The P120 consent-cache carve-out is likewise retired (the cache has no decision content once the gate is gone).
- **Symlink Contract (P139), source-of-truth location, no-hooks, no-CHANGELOG, scope-test, marketplace-default** — all preserved unchanged.

### New `install-updates` confirmation criteria (replacing the retired ones)

- The skill runs a single global-cache refresh from the current project; it makes no sibling-project tree write and asks no questions.
- It refreshes the marketplace cache, compares each enabled `wr-*` plugin's npm latest against the cached version, and uninstall+reinstalls (P106) with bounded retry + rollback (P112) only those that are behind.
- It is safe to run non-interactively (subagent / AFK loop) — there is nothing to gate.
- It reports a per-plugin before/after/status table and a restart note.

### Trade-off recorded

This removes the "agents silently write to my sibling projects" guardrail named in Decision Driver "Solo-developer persona constraint" — but the guardrail is moot because no sibling write occurs. The remaining cross-project effect (a global-cache version advance) is exactly the user-desired outcome (JTBD-007), is reported in the final table, and does not take effect in already-running sibling sessions until they restart (the existing P045 restart note covers this).

### Related

- ADR-059 amendment 2026-05-25 retires the coupled `install-updates` Step 6.5 risk-register bootstrap auto-trigger (verdict A6); bootstrap survives on-demand via `/wr-risk-scorer:bootstrap-catalog`.
- ADR-047 install-updates coupling fully dissolved (stale-ref cleanup note 2026-05-25).

## Follow-ups (non-blocking for this ADR)

- **P045 status update**: P045 ticket body is updated in this commit to note that `install-updates` is the manual stopgap until P045's automated queue lands.
- **Second repo-local skill**: if a distinct second repo-local skill is proposed, re-read this ADR and decide whether the single-ADR pattern still fits or whether a lightweight per-skill ADR is needed.

## Reassessment Criteria

- **P045's automated queue lands** → re-evaluate whether `install-updates` is still needed (may graduate into a manual override for the queue, or retire entirely). Action: amend this ADR's Decision Outcome section or supersede.
- **Second repo-local skill emerges** → extract any shared pattern (detection, consent-gate, reporting) into a helper at `scripts/repo-local-skills/lib/` if the duplication is non-trivial. Action: amend this ADR to document the shared helper and update the contract's point 1-6 accordingly.
- **Cross-project traversal incident** (consent gate failed to prevent an unintended cross-project write) → strengthen the gate (per-sibling confirmation, rollback mechanism) and document the incident. Action: amend this ADR's Confirmation section to require the new gate, and file a follow-up problem ticket for the root cause.
- **Symlink resolution breaks** (Claude Code update, filesystem change, Windows-without-Developer-Mode contributor encountering it) → document the regression, fall back to dual-write of source content into both paths if persistent, or abandon the relocation. Action: amend this ADR's Symlink Contract section, and file a follow-up problem ticket for the root cause. Naming this trigger keeps the JTBD-006 / persona-discoverability constraint honest in future reviews.
