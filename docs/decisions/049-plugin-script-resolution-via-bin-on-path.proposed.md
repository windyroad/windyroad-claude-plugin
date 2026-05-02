---
status: "proposed"
date: 2026-05-02
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-08-02
---

# Plugin-bundled scripts invoked from SKILL.md resolve via `bin/` on `$PATH`

## Context and Problem Statement

Several published `@windyroad/*` skill SKILL.md files (5 invocation sites identified by grep on 2026-05-02 in `@windyroad/itil` and `@windyroad/retrospective`) contain `bash packages/<plugin>/scripts/<name>.sh ARG` invocations as load-bearing steps. When an adopter project installs the plugin via the Claude Code marketplace and the agent invokes the skill, the SKILL.md prose is expanded into the agent's context. The agent reads the bash command and dispatches it via the Bash tool — which runs in the **adopter's project root**, not the plugin's cache directory. The path `packages/<plugin>/scripts/<name>.sh` never resolves in an adopter tree, so the bash command exits non-zero with `No such file or directory` and the SKILL.md control flow halts before the skill produces any user value.

This is the driver of P151 (Published skills reference repo-relative script paths — adopter `bash` invocations hard-fail at Step 0). A normative rule is needed so future SKILL.md authors do not re-introduce the same plugin-boundary leak.

The Claude Code marketplace cache structure places plugin contents under `~/.claude/plugins/cache/<owner>/<plugin>/<version>/`, and the runtime adds each installed plugin's `bin/` directory to `$PATH`. Empirically verified 2026-05-02: the agent's Bash tool sees 12+ windyroad plugin `bin/` directories on `$PATH` plus 2 official plugins. Any executable placed in a plugin's `bin/` directory is discoverable by name at SKILL.md bash-invocation time, in adopter sessions and source-repo dev sessions alike. The `${CLAUDE_PLUGIN_ROOT}` env-var alternative was empirically ruled out — it is unset at SKILL.md bash-invocation time (interpolation only fires for `hooks.json` command strings, not skill bash dispatches).

## Decision Drivers

- **Adopter sessions must work without source-repo cohabitation**: every published skill must function from a fresh-install marketplace cache in an arbitrary adopter project root. This is the core plugin distribution promise (JTBD-301 — Plugin-user persona reading published skills with low context on repo internals).
- **No upstream Claude Code feature dependency**: the fix should land using mechanisms that exist today; waiting on a `${CLAUDE_PLUGIN_ROOT}` env-var feature ships nothing.
- **Author ergonomics — keep canonical script body editable in one place**: maintainers should not edit shim wrappers; the canonical script remains under `packages/<plugin>/scripts/<name>.sh` so existing `packages/<plugin>/scripts/test/*.bats` test invocations stay correct.
- **Portability across Windows + npm-pack tarballing + marketplace installer**: shim wrappers (3-line `exec` redirects) are portable across all distribution paths in a way symlinks are not.
- **Grep-ability + naming-grammar across the plugin suite**: a uniform naming convention (`wr-<plugin>-<kebab-script-name>`) lets future audits spot non-conforming invocations with a single grep, and the next plugin author who needs a shim sees the pattern in a single ADR (JTBD-101 — Plugin-developer persona's "clear patterns, not reverse-engineering" outcome).
- **Behavioural CI lint catches regressions before adopter sessions**: a grep-as-lint test asserting no published `SKILL.md` contains `bash <repo-relative-path>` closes the loop at CI rather than in adopter sessions.

## Considered Options

1. **Option A — `${CLAUDE_PLUGIN_ROOT}` env-var resolution in SKILL.md bash**: rewrite invocations as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"`. **Empirically ruled out 2026-05-02**: the var is unset at SKILL.md bash-invocation time. Hooks see `${CLAUDE_PLUGIN_ROOT}` because Claude Code interpolates it when expanding `hooks.json` command strings BEFORE invoking the hook; skill bash invocations do not go through that interpolation path.
2. **Option B — Inline the script logic directly into SKILL.md**: paste the ~150 LOC body of `reconcile-readme.sh` (and similar scripts) into the SKILL.md as a heredoc. Bloats SKILL.md, composes adversely with P097 (SKILL.md size pressure / runtime-vs-maintainer content mixed). Architect verdict: "non-starter for a 150 LOC body."
3. **Option C — Skill-resolved path via marketplace metadata token**: would require a Claude Code feature request. Option D works without an upstream change; defer to upstream feature if it ships later.
4. **Option D — `bin/` on `$PATH` with thin shim wrapper (chosen)**: keep canonical script body under `packages/<plugin>/scripts/<name>.sh`; add a thin shim wrapper at `packages/<plugin>/bin/wr-<plugin>-<kebab-script-name>` whose body is `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"`. SKILL.md invocations replace `bash packages/<plugin>/scripts/<name>.sh ARG` with `wr-<plugin>-<kebab-script-name> ARG`. The shim resolves on `$PATH` via the marketplace install path; the script body remains testable under its existing bats path.
5. **Option E — Plugin-script bundling as agent-side helpers**: bundle scripts as Skill tool actions instead of bash invocations. Architect verdict: "duplicates the `bin/` mechanism without adding value."

## Decision Outcome

Chosen option: **"Option D — `bin/` on `$PATH` with thin shim wrapper"**, because it works today (no upstream feature dependency), preserves canonical-body editability under `packages/<plugin>/scripts/`, ships portably across Windows + npm-pack + marketplace installer paths, and aligns with the existing precedent in `packages/itil/bin/check-deps.sh` (which already publishes via the marketplace `bin/` on `$PATH` mechanism).

Sibling to ADR-002 (monorepo per-plugin packages — already establishes `bin/` as the published entry-point surface), ADR-003 (marketplace-only distribution — confirms `bin/` ships through the marketplace cache), and ADR-017 (shared-code-sync pattern — precedent for the canonical-body + thin-wrapper shape).

**Normative rule**: Plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths.

**Naming convention**: `wr-<plugin>-<kebab-script-name>` — fixed grammar so the next plugin author needs zero guesswork. Concretely:

- `<plugin>` is the **full plugin name** as published in `packages/<plugin>/.claude-plugin/plugin.json`'s `name` field (e.g. `itil`, `retrospective`). Do NOT abbreviate; the bin namespace MUST match the published plugin name 1:1 so audit-grep walks `packages/<plugin>/bin/wr-<plugin>-*` deterministically.
- `<kebab-script-name>` is the canonical script's stem with `.sh` stripped, kebab-cased (e.g. `reconcile-readme`, `measure-context-budget`).
- The shim file has **no `.sh` extension** — it is a `$PATH`-resolved CLI command, not an internally-invoked script (matches Unix convention `git`, `node`, `npm`; distinct from `bin/check-deps.sh` which is internally-invoked by other hooks via direct file path).
- Examples: `wr-itil-reconcile-readme`, `wr-itil-check-problems-readme-budget`, `wr-retrospective-measure-context-budget`.

**Shim shape** (3 lines):

```bash
#!/usr/bin/env bash
exec "$(dirname "$0")/../scripts/<name>.sh" "$@"
```

The shim resolves the canonical script body relative to its own location, so it works under any cache layout (development tree, npm-pack tarball, marketplace install). The shim file is executable (`chmod +x`); the canonical script under `scripts/` retains its existing executable bit.

## Consequences

### Good

- Adopter sessions running affected skills (`/wr-itil:manage-problem`, `/wr-itil:work-problems`, `/wr-itil:reconcile-readme`, `/wr-retrospective:run-retro`, `/wr-retrospective:analyze-context`) succeed at Step 0 without source-repo cohabitation. The hard-fail in P151 is closed.
- Future SKILL.md authors have a single rule to follow: invoke published scripts by their `wr-<plugin>-<kebab-script-name>` name, never by repo-relative path.
- The behavioural grep-as-lint test catches regressions at CI (one grep over `packages/*/skills/*/SKILL.md` for `bash packages/`) rather than in adopter sessions.
- Aligns with ADR-002 / ADR-003 — `bin/` is already the published entry-point surface; this ADR formalises script invocation as the second use case.
- Discoverability for plugin-developer persona (JTBD-101 — "clear patterns, not reverse-engineering"): naming grammar + ADR + grep-as-lint give a future contributor the shape, the rationale, and the regression catch in three places.

### Neutral

- Three new shim files per published script (one per script). Each is 3 lines and trivially portable. No author-time editing required after creation.
- Naming convention couples the plugin name into the bin-wrapper name (`wr-itil-*`, `wr-retrospective-*`). If a plugin is renamed, the bin wrappers must be renamed too. This is an acceptable trade-off — plugin renames are rare, grep-able, and the rename window is the one moment a contributor expects coordinated edits across the plugin's surface anyway.

### Bad

- Adds a third location for the script-invocation surface: canonical body in `scripts/`, shim wrapper in `bin/`, invocation site in `SKILL.md`. **Editing a script's body remains single-touch (`scripts/<name>.sh`)**; **renaming a script becomes three-touch** (`scripts/`, `bin/`, every `SKILL.md` invocation). This is an explicit trade-off — the plugin-developer persona's job (JTBD-101) prioritises structural correctness over minimising touch-points, and the grep-as-lint catches any drift between the three surfaces. Drift between the three is possible but caught by the grep-as-lint at CI.
- Adopter projects that have an executable named `wr-itil-reconcile-readme` (or similar) on their `$PATH` outside the plugin cache would shadow the shim. The `wr-<plugin>-` prefix is intended to make this collision unlikely; if a collision is observed in the field, the bin name can be made more specific in a future amendment (e.g. `wr-windyroad-<plugin>-<name>`).

## Confirmation

This decision is honoured when:

1. **Behavioural grep-as-lint test passes**: a bats test under `packages/shared/test/` (cross-plugin scope per established precedent — `external-comms-gate-canonical.bats`, `plugin-manifest-sync.bats`) asserts that no published `packages/*/skills/*/SKILL.md` contains the pattern `bash +packages/<plugin>/(scripts|hooks)/<name>\.(sh|py|bats|js|ts)` as a load-bearing invocation. The test fails CI on regression. P151's Confirmation criterion folds into this same test.
2. **Each affected SKILL.md uses the bin-wrapper invocation**: `wr-itil-reconcile-readme`, `wr-itil-check-problems-readme-budget`, `wr-retrospective-measure-context-budget` (etc.) replace `bash packages/<plugin>/scripts/<name>.sh` at every dispatch site.
3. **Each shim is executable and resolves via `$PATH` in marketplace-installed sessions**: optional smoke test asserts `command -v wr-<plugin>-<kebab-script-name>` succeeds when the plugin is installed via the marketplace cache.
4. **Documentation-only references in SKILL.md prose** that name a `packages/<plugin>/scripts/<name>.sh` path also use the bin-wrapper name where adopter agents might attempt to dispatch them. Pure literary references that are not load-bearing may keep the canonical path as a maintainer hint, BUT MUST NOT appear under a heading that the agent would interpret as an invocation step.
5. **`bin/` already declared in `files` array of `packages/<plugin>/package.json`**: verified for `@windyroad/itil` and `@windyroad/retrospective` 2026-05-02; future plugins MUST include `bin/` in their `files` array if they publish shim wrappers.

## Pros and Cons of the Options

### Option A — `${CLAUDE_PLUGIN_ROOT}` env-var resolution

- Good: zero new files; SKILL.md change only.
- Bad: empirically ruled out — env var unset at skill bash-invocation time.

### Option B — Inline script logic in SKILL.md

- Good: zero new files.
- Bad: ~150 LOC scripts inflate SKILL.md beyond runtime/maintainer-content separation (P097); bats coverage of the inline logic is no longer possible without extraction; future maintenance edits cross context layers (skill prose vs script logic).

### Option C — Skill-resolved path via marketplace metadata token

- Good: cleanest if upstream Claude Code ships such a token.
- Bad: not available today; would block the P151 fix on an upstream feature.

### Option D — `bin/` on `$PATH` with thin shim (chosen)

- Good: works today; canonical body editable in `scripts/`; portable across Windows + npm-pack + marketplace installer; aligns with ADR-002 / ADR-003 precedent; grep-as-lint catches regressions.
- Good: existing `packages/itil/bin/check-deps.sh` precedent already proves the mechanism in production — no novel infrastructure introduced.
- Neutral: 3-line shim per script; no author burden after creation.
- Bad: adds a third location for the script-invocation surface; rename becomes three-touch (drift caught by grep-as-lint, not by structural impossibility).

### Option E — Plugin-script bundling as agent-side helpers

- Good: would unify with the Skill tool surface.
- Bad: duplicates the `bin/` mechanism without adding value (architect verdict).

## Reassessment Criteria

Reassess if any of the following occur:

- Claude Code ships a `${CLAUDE_PLUGIN_ROOT}` env var (or equivalent) that is correctly populated at SKILL.md bash-invocation time. At that point, the env-var path may become preferable to the shim because it removes the third surface (`bin/` shim files) entirely.
- A naming-collision incident is reported in the field where an adopter project's `$PATH` shadows a `wr-<plugin>-<kebab-script-name>` shim. The naming convention may need to become more specific (e.g. `wr-windyroad-<plugin>-<name>`) in a future amendment.
- The grep-as-lint test pattern needs to evolve (e.g. to cover non-bash invocations such as `python3 packages/<plugin>/scripts/<name>.py`, or repo-relative directory traversals like `for d in packages/*/hooks; do ...`). Extend the lint pattern at that point rather than abandoning the rule. Sibling concern in `packages/retrospective/skills/analyze-context/SKILL.md` lines 56-67 noted by architect — tracked separately.
- A second plugin needs to host the cross-cutting bats test (e.g. a future `wr-publish-lint` plugin). At that point, promote the bats from `packages/shared/test/` to whichever plugin owns published-skill-contract enforcement.

## Related

- ADR-002 — monorepo per-plugin packages (establishes `bin/` as the published entry-point surface).
- ADR-003 — marketplace-only distribution (confirms `bin/` ships through the marketplace cache).
- ADR-017 — shared-code-sync pattern (precedent for canonical-body + thin-wrapper shape).
- ADR-038 — progressive disclosure (related — repo-relative path leakage is a context-budget issue at the adopter session boundary).
- P151 — Published skills reference repo-relative script paths (the driver problem this ADR addresses).
- P137 — Plugin-published artifacts reference internal ADR/JTBD/P-IDs (sibling concern; semantic references vs P151's executable references; both leak windyroad-internal artifacts through the plugin boundary).
- P097 — SKILL.md runtime vs maintainer content mixed (composes-with on the "inline the script logic" candidate fix shape).
- JTBD-301 — Plugin-user persona's primary job (driven by adopter sessions reading published skills with low repo-internal context).
- JTBD-101 — Plugin-developer persona's "clear patterns, not reverse-engineering" outcome (driver of the fixed naming-grammar requirement).
