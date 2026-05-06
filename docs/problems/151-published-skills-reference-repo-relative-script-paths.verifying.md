# Problem 151: Published skills reference repo-relative script paths — adopter `bash` invocations hard-fail at Step 0

**Status**: Verification Pending
**Reported**: 2026-05-02
**Priority**: 20 (Very High) — Impact: Significant (4) x Likelihood: Almost certain (5)
**Effort**: L — ADR-049 codifying plugin-bundled-script resolution via `bin/` on `$PATH` + thin shim wrappers + mechanical edits across 5 SKILL.md files in 2 plugins + path-resolution tests + grep-as-lint behavioural test (per architect ADR-049 Confirmation criterion).

**WSJF**: (20 × 2.0) / 4 = **10.0**
**Type**: technical

> Surfaced 2026-05-02 by user during a `/wr-itil:work-problems` AFK loop iter 1: *"some of the published skills (like manage-problem) references files in this repo (like packages/itil/scripts/reconcile-readme.sh), which users of the plugins CANNOT ACCESS because they are repo paths not plugin paths"*. Sibling concern to P137 (internal-ID leakage) but a distinct failure mode — P137 is degraded-semantics (adopter agent ignores or mis-resolves an `ADR-NNN` token); this ticket is **hard runtime failure** (the bash command exits with `No such file or directory` and the skill cannot proceed past Step 0).

## Description

Several published `@windyroad/*` skill SKILL.md files contain `bash packages/<plugin>/scripts/<name>.sh ...` invocations as load-bearing steps. When an adopter project installs the plugin via the Claude Code marketplace and the agent invokes the skill, the SKILL.md prose is expanded into the agent's context. The agent reads the bash command and dispatches it via the Bash tool — which runs in the **adopter's project root**, not the plugin's cache directory. The path `packages/<plugin>/scripts/<name>.sh` never resolves in an adopter tree, so the bash command exits non-zero with `No such file or directory` and the SKILL.md control flow halts before the skill produces any user value.

This is distinct from P137 (Plugin-published artifacts reference internal ADR/JTBD/P-IDs that adopter projects can't resolve). P137 is about **semantic references** to decision documents — the worst case is wrong-resolution to an adopter's unrelated ADR with the same number. P151 is about **executable references** to scripts — the worst case is hard failure on every invocation, blocking the skill at its preflight step. Neither is a substitute for the other; both leak windyroad-internal references through the plugin boundary, but they require different fixes (P137 needs a strip/replace/permalink decision for prose IDs; P151 needs a path-resolution decision for runtime-invoked scripts).

## Symptoms

- An adopter running `/wr-itil:work-problems` halts immediately at Step 0: the orchestrator dispatches `bash packages/itil/scripts/reconcile-readme.sh docs/problems`, the path does not exist in the adopter's working tree, bash returns exit 127 with `No such file or directory`, and the SKILL.md exit-code routing halts the loop with a `parse error` classification (Exit 2 branch in Step 0's exit-code routing) — even though the underlying issue is a missing FILE, not a parse error.
- An adopter running `/wr-itil:manage-problem <NNN> known-error` halts at Step 0 with the same hard failure before it can read the ticket, run the duplicate-grep, or apply any transition.
- An adopter running `/wr-itil:reconcile-readme` halts at Step 1 with the same failure when it tries to invoke `bash packages/itil/scripts/reconcile-readme.sh docs/problems`.
- An adopter running `/wr-retrospective:run-retro` Step 2c (context-budget measurement) halts when it dispatches `bash packages/retrospective/scripts/measure-context-budget.sh "${CLAUDE_PROJECT_DIR:-.}"` — the env-var argument resolves to the adopter's project root, but the SCRIPT PATH is repo-relative and does not exist.
- An adopter running `/wr-retrospective:analyze-context` halts at Step 2 for the same reason.
- The CHANGELOG / release notes for `@windyroad/itil` and `@windyroad/retrospective` describe these skills as functional, but a fresh-install adopter cannot exercise them past their first script invocation.

## Workaround

None at the source level — the artefacts ship as-authored. Adopter-side workarounds (none reasonable; documented for completeness):

- Adopter could clone `windyroad-claude-plugin` as a sibling submodule so the repo-relative paths resolve. Heavyweight, defeats the plugin model, requires the adopter to maintain a copy of the entire monorepo for what should be a single-plugin install.
- Adopter could symlink `packages/itil/scripts/` and `packages/retrospective/scripts/` from the plugin marketplace cache into their project root. Brittle (cache version changes invalidate the symlink), uses adopter directory namespace for plugin-internal layout, and the symlinks themselves leak `packages/itil/...` into the adopter's git status.
- Adopter could manually transcribe the script's bash logic into their own working tree at the right path. Defeats plugin distribution; requires the adopter to read the published script source and copy it; doesn't survive plugin updates.
- Adopter could disable the affected skills entirely. Loses the value the plugin was installed for.

None of these are reasonable. The fix has to be at the source — the published artifacts must reference scripts via a path that resolves in adopter projects. **Known Error fix path: ADR-049 + bin/ shim relocation (see Root Cause Analysis below).**

## Impact Assessment

- **Who is affected**: The **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — every adopter project that installs `@windyroad/itil` or `@windyroad/retrospective`. As of 2026-05-02 those are two of the most actively published `@windyroad/*` plugins. The plugin-user persona's defining constraints (low context on repo internals; AI agent as the primary interface) are *exactly* the conditions that turn the hard-fail into an opaque dead-end — the adopter sees `bash: No such file or directory: packages/itil/scripts/reconcile-readme.sh` and has no path forward without spelunking the plugin's source repo.
- **Frequency**: Every invocation of an affected skill in any adopter project. Affected skill list (5 SKILL.md files identified by grep on 2026-05-02):
  - `packages/itil/skills/manage-problem/SKILL.md:189` — Step 0 README reconciliation preflight.
  - `packages/itil/skills/work-problems/SKILL.md:89` — Step 0 README reconciliation preflight.
  - `packages/itil/skills/reconcile-readme/SKILL.md:44` — Step 1 diagnose-only script invocation.
  - `packages/retrospective/skills/run-retro/SKILL.md:179` — Step 2c context-budget measurement.
  - `packages/retrospective/skills/analyze-context/SKILL.md:45` — Step 2 context-budget measurement.
- **Severity**: Significant — installed plugins fail to function for adopters per RISK-POLICY Impact-4 verbatim ("hooks fire incorrectly, skills fail to load"). The "skills fail to load" branch applies: the SKILL.md loads, the agent reads its body, but the first script invocation hard-fails before any user-facing output is produced. From the adopter's perspective the skill is broken.
- **Likelihood**: Almost certain — known gap, no controls in place. Matches RISK-POLICY Likelihood-5 verbatim ("Known gap, no controls in place, or previously observed failure mode"). Every fresh-install adopter session running an affected skill hits this at Step 0.
- **Analytics**: Direct grep evidence (2026-05-02): `grep -rn -E "bash +packages/[a-z]+/(scripts|hooks)/[a-z-]+\.(sh|py|bats|js|ts)" packages/*/skills/*/SKILL.md` returns the 5 lines above. Two scripts referenced: `packages/itil/scripts/reconcile-readme.sh` (3 invocation sites) and `packages/retrospective/scripts/measure-context-budget.sh` (2 invocation sites). No mitigations in the SKILL.md preambles ("if the script is missing, fall back to ..." — no such branch exists today; the SKILL.md exit-code routing treats missing-file as a parse error per Step 0's Exit 2 branch).
- **Concrete user-cited evidence (2026-05-02)**: this very session — orchestrator's Step 0 of `/wr-itil:work-problems` ran `bash packages/itil/scripts/reconcile-readme.sh docs/problems` and exited 0 because **this session is in the source repo**. An adopter running the same skill from `~/Projects/their-app/` would have hit `bash: packages/itil/scripts/reconcile-readme.sh: No such file or directory` (exit 127). The user surfaced the issue mid-loop after observing the published-skill prose and recognising the path leak.

## Root Cause Analysis

### Confirmed Root Cause (2026-05-02 investigation)

Published SKILL.md files were authored against the source-repo working tree where `packages/<plugin>/scripts/<name>.sh` is the natural path. No build step or path-resolution layer rewrites these references when the plugin is published to npm and installed into an adopter's marketplace cache. The same applies to documentation-only references to `packages/itil/scripts/check-problems-readme-budget.sh` (manage-problem SKILL.md lines 465, 477) — those don't hard-fail because they aren't dispatched as bash, but they mislead any adopter agent that tries to follow the reference.

The Claude Code plugin marketplace cache structure (verified 2026-05-02) places plugin contents under `~/.claude/plugins/cache/<owner>/<plugin>/<version>/`. So `packages/itil/scripts/reconcile-readme.sh` is physically present at `~/.claude/plugins/cache/windyroad/wr-itil/0.23.1/scripts/reconcile-readme.sh`. The source-repo path and the cache-resolved path share the trailing `scripts/<name>.sh` but the leading prefix differs.

### Resolution Strategy — Candidate 5 (bin/ on $PATH + thin shim wrapper)

**Selected strategy** (architect concurrence 2026-05-02 — ADR-049 to codify):

The Claude Code marketplace runtime adds `~/.claude/plugins/cache/<owner>/<plugin>/<version>/bin/` to `$PATH` for every installed plugin. Empirically verified 2026-05-02 — the agent's Bash tool sees 12+ windyroad plugin `bin/` directories on `$PATH`, plus 2 official plugins. Any executable placed in a plugin's `bin/` directory is therefore discoverable by name at SKILL.md bash-invocation time, in adopter sessions and source-repo dev sessions alike.

**Fix shape**:

- Keep canonical script body under `packages/<plugin>/scripts/<name>.sh` (preserves existing bats test invocation path under `packages/<plugin>/scripts/test/`).
- Add a thin shim wrapper at `packages/<plugin>/bin/wr-<plugin>-<name>` (no `.sh` extension; matches `bin/check-deps.sh` precedent — actually keep `.sh` for consistency? — architect-concurred shape uses 3-line shim: `#!/usr/bin/env bash` + `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"`). Portable across Windows, npm-pack tarballing, and marketplace installer paths in a way symlinks are not (architect explicitly preferred shim over symlink for portability).
- Update affected SKILL.md invocations: `bash packages/itil/scripts/reconcile-readme.sh ARG` → `wr-itil-reconcile-readme ARG`. Same for `measure-context-budget.sh` in retrospective.
- Naming: `wr-<plugin>-<verb-noun>` prefixed entries (e.g. `wr-itil-reconcile-readme`, `wr-retro-measure-context-budget`). Avoids collision with adopter binaries; mirrors the skill-namespace convention (`wr-itil:*`, `wr-retrospective:*`); preserves grep-ability across the suite.
- ADR-049 codifies the rule normatively: "Plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths." Sibling ADRs: ADR-002 (monorepo per-plugin packages — already establishes `bin/` as the published entry-point surface), ADR-003 (marketplace-only distribution — confirms `bin/` ships through the marketplace cache), ADR-017 (shared-code-sync pattern — precedent for the canonical-body + thin-wrapper shape).
- ADR-049 Confirmation criterion: a behavioural grep-as-lint test (bats) asserting that no published `SKILL.md` contains `bash <repo-relative-path>` invocations. Catches the next regression at CI rather than in adopter sessions.

### Ruled-out / deprioritised candidates

- **C1 — `${CLAUDE_PLUGIN_ROOT}` env-var resolution**: RULED OUT. Empirically verified UNSET at SKILL.md bash-invocation time (2026-05-02 — `env | grep ^CLAUDE_` returns only `CLAUDE_CODE_ENTRYPOINT/EXECPATH/SSE_PORT`; `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DIR` both unset). Hooks DO see `${CLAUDE_PLUGIN_ROOT}` because Claude Code's runtime interpolates the token when expanding `hooks.json` command strings BEFORE invoking the hook — but skill bash invocations don't go through that interpolation path. The preliminary hypothesis ("a sibling env var for skills is plausible") was wrong; no such env var is exported.
- **C2 — Inline the script logic directly into SKILL.md**: deprioritised. `reconcile-readme.sh` is ~150 LOC; inlining bloats SKILL.md and composes adversely with P097 (SKILL.md size pressure / runtime-vs-maintainer content mixed). Architect verdict: "non-starter for a 150 LOC body."
- **C3 — Skill-resolved path via marketplace metadata token**: not available today — would require a Claude Code feature request. C5 works without an upstream change.
- **C4 — Plugin-script bundling as agent-side helpers**: architect verdict — "duplicates the `bin/` mechanism without adding value."

### Investigation Tasks

- [x] Confirm whether `$CLAUDE_PLUGIN_DIR` / `${CLAUDE_PLUGIN_ROOT}` (or any equivalent env var) is exported by Claude Code's runtime at SKILL.md bash-invocation time. **Result: NO** — neither is exported (verified 2026-05-02 in source-repo session via `env | grep CLAUDE_`). Eliminates Candidate 1.
- [x] If no env var exists, pivot to one of the alternative resolution strategies. **Result: discovered Candidate 5 (bin/ on $PATH) empirically; architect concurred 2026-05-02.**
- [x] Architect review — codify the chosen resolution strategy as an ADR. **Result: ADR-049 to be drafted (deferred from this iter — architect concurred on shape; drafting is a separate work item).**
- [ ] Draft ADR-049 codifying `bin/` + shim resolution rule (sibling to ADR-002 / ADR-003 / ADR-017 / ADR-024 / ADR-036 — plugin-boundary class).
- [ ] Add `bin/wr-<plugin>-<name>` shim wrappers for `reconcile-readme.sh`, `check-problems-readme-budget.sh` (itil), `measure-context-budget.sh` (retrospective).
- [ ] Mechanical replacement across the 5 SKILL.md invocation sites identified by grep + any others discovered during the audit (also update the documentation-only references at manage-problem SKILL.md lines 465, 477).
- [ ] Behavioural bats per ADR-005 + ADR-049 Confirmation criterion — grep-as-lint asserting no published `SKILL.md` contains `bash <repo-relative-path>`. Catches regressions at CI.
- [ ] Optional: behavioural test asserting each `bin/wr-<plugin>-<name>` is on `$PATH` when the plugin is installed (smoke check that the shim is actually executable in marketplace-installed sessions).

## Dependencies

- **Blocks**: (none — but adopter usability of `@windyroad/itil` and `@windyroad/retrospective` is materially improved when this lands)
- **Blocked by**: (none — independent of P137 even though they compose; either can land first)
- **Composes with**: P137 (Plugin-published artifacts reference internal ADR/JTBD/P-IDs — same plugin-boundary leakage class, different failure mode); P097 (SKILL.md size pressure — affects "inline the script logic" candidate fix); P065 / P066 / P137 family (intake / publishing surface)

## Related

- P137 (`docs/problems/137-published-plugin-artifacts-reference-internal-ids-confuses-adopter-agents.open.md`) — sibling concern; semantic references vs. P151's executable references; both leak windyroad-internal artifacts through the plugin boundary.
- P097 (`docs/problems/097-skill-md-runtime-vs-maintainer-content-mixed.open.md`) — composes-with on the "inline the script logic" candidate fix shape.
- `packages/itil/skills/manage-problem/SKILL.md` — Step 0 README reconciliation preflight, line 189.
- `packages/itil/skills/work-problems/SKILL.md` — Step 0 README reconciliation preflight, line 89.
- `packages/itil/skills/reconcile-readme/SKILL.md` — Step 1 diagnose-only script invocation, line 44.
- `packages/retrospective/skills/run-retro/SKILL.md` — Step 2c context-budget measurement, line 179.
- `packages/retrospective/skills/analyze-context/SKILL.md` — Step 2 context-budget measurement, line 45.
- `packages/itil/skills/manage-problem/SKILL.md` lines 465, 477 — documentation-only references to `packages/itil/scripts/check-problems-readme-budget.sh`; not dispatched as bash but still mislead adopter agents that try to read the script.

## Fix Released

Fix landed 2026-05-02 in iter 3 of the AFK `/wr-itil:work-problems` loop. Single commit per ADR-014 / ADR-022 fold-fix:

- **ADR-049** (`docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md`) codifies the rule: plugin-bundled scripts invoked from SKILL.md MUST resolve via `bin/` on `$PATH`, never via repo-relative paths. Naming grammar `wr-<plugin>-<kebab-script-name>` is fixed. Architect concurrence + JTBD alignment recorded; sibling to ADR-002 / ADR-003 / ADR-017.
- **Three new shim wrappers** under `packages/<plugin>/bin/` (3-line `exec "$(dirname "$0")/../scripts/<name>.sh" "$@"` body, executable, no `.sh` extension): `wr-itil-reconcile-readme`, `wr-itil-check-problems-readme-budget`, `wr-retrospective-measure-context-budget`.
- **Five SKILL.md invocation sites updated** to use the bin-wrapper name: `manage-problem` Step 0 L189, `work-problems` Step 0 L89, `reconcile-readme` Step 1 L44, `run-retro` Step 2c L179, `analyze-context` Step 2 L45. Plus two documentation references at `manage-problem` L465 / L477 rewritten to name the bin-wrapper while preserving the maintainer-side canonical-path hint.
- **Cross-plugin grep-as-lint bats** at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` (8 tests) — green post-fix, fails CI on any future regression.
- **Changeset entries** for `@windyroad/itil` (patch) and `@windyroad/retrospective` (patch).
- **Sibling concern follow-up**: P153 opened for `packages/*/hooks` glob loops in `analyze-context` SKILL.md L56-67 (different failure mode — silent zero-byte degradation rather than hard fail; tracked separately to keep this commit's lint pattern precise).

In-session exercise evidence: the new `wr-itil-reconcile-readme` shim was driven against `docs/problems/` and exited 0 (clean); all 8 bats tests at `packages/shared/test/no-repo-relative-script-paths-in-skills.bats` are green; the published SKILL.md invocation surface contains zero `bash packages/<plugin>/(scripts|hooks)/...` patterns.

Adopter-side verification path: install `@windyroad/itil` and `@windyroad/retrospective` in a fresh project (no source-repo cohabitation), run `/wr-itil:work-problems` and `/wr-retrospective:analyze-context`, observe Step 0 succeeds via the `wr-itil-reconcile-readme` and `wr-retrospective-measure-context-budget` bin-resolved commands. Awaiting user verification.
