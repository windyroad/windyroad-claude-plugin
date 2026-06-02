---
status: "proposed"
date: 2026-06-02
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-09-02
---

# SessionStart PATH refresh hook for plugin cache

> **DRAFT — substance pending ratification per ADR-074 / P339.** The headline option (Option A: SessionStart hook recomputes `PATH` from current cache state at every session start) is user-directed per P343 Option 4. Substantive sub-decisions inside that direction (hook scope, PATH mutation semantics, interaction with sibling ADR-080 shim wrapper, failure mode, interaction with `.claude/settings.json` env config) are queued in this iteration's `outstanding_questions` and remain un-pinned; no implementation builds on this ADR until the user pins them at the next interactive transition.

## Context and Problem Statement

P343 (Known Error, promoted 2026-06-01) — `/install-updates` refreshes the global plugin cache but does NOT mutate the parent shell's `PATH`. Claude Code's session-init populates `PATH` with each plugin's `bin/` directory at the version current at session start, and `PATH` stays frozen for the lifetime of the session. The **next session's** `PATH` is computed afresh at session-init — but only from whatever Claude Code's plugin manager elects to put on the path, which empirically remains keyed to the version that was "first installed" rather than the highest currently in cache (P343 § Root Cause Analysis lines 60–67).

Empirical instance (session 9, 2026-05-31): the session that started 2026-05-30 had `0.11.0/bin` on `PATH`. `/install-updates` advanced the cache to `0.12.2` and then `0.13.0`. The next session also started with `0.11.0/bin` first on `PATH` (rather than the latest `0.13.0`). Only a manual deep restart with cache surgery cleared the stale entry — the "next session" path is itself sticky.

P343 enumerated 5 candidate fixes; Option 5 (documentation amendment) shipped same-day. Sibling ADR-080 records Option 3 (highest-version-wins shim wrapper) for mid-session staleness. **Option 4 (SessionStart PATH refresh hook) is the structural fix this ADR records** — it closes the cold-start window so the next session after `/install-updates` actually starts with the latest version's `bin/` first on `PATH`.

P343 § Root Cause Analysis (lines 73–76) named Option 4 as "bounded but new hook; would recompute PATH from current cache state at every session start. Doesn't help mid-session refreshes but eliminates the stale-PATH-on-next-session pattern. Requires ADR for hook scope + per-plugin PATH-mutation semantics."

ADR-040 already establishes a SessionStart surface (the retrospective plugin's briefing hook). This ADR extends that surface with a second, complementary hook in `@windyroad/architect` (or a new dedicated location — see SQ-081-1 below) that recomputes `PATH` from current cache state.

The framing question: **how should the hook discover and prepend latest-version `bin/` directories for every enabled `@windyroad/*` plugin, what should its failure mode be when cache state is unreadable or malformed, and how does it interact with sibling ADR-080's shim wrapper at runtime?**

## Decision Drivers

- **P343's cold-start staleness window** — even after `/install-updates` advances the cache and the user restarts Claude Code, the next session's `PATH` empirically keeps the older version first. This ADR's hook is the structural fix for that cold-start mode.
- **ADR-040 SessionStart surface alignment** — there is an established hook lifecycle for boot-time prose injection (`SessionStart` with `matcher: "startup"`). The same lifecycle event is the right host for a PATH-mutation hook. No new hook surface needed.
- **Adopter-portability** (ADR-002 / ADR-003 / JTBD-301) — the hook must work from a fresh-install marketplace cache in any adopter project root without requiring upstream Claude Code internals to change.
- **Sibling ADR-080 composition** — when both ADRs are active, the runtime behaviour must be well-defined: shim wrapper resolves at invoke time (ADR-080); SessionStart hook prepends latest-version `bin/` ahead of stale ones at session boot (this ADR). Together they provide defence in depth (ADR-080 for shim binaries; ADR-081 for non-wrapped binaries + safety net).
- **Coverage of non-wrapped binaries** — not every plugin scaffolds binaries with a wrapper. Scripts that adopters call directly by name (e.g. `wr-itil-reconcile-readme` — currently a 3-line ADR-049 wrapper, not yet a highest-version wrapper) benefit from `PATH`-ordering correctness regardless of whether ADR-080's wrapper has been retroactively applied to them.
- **Per-plugin opt-out** — adopters may pin a specific plugin version for compatibility reasons (e.g. ADR-066 in-progress amendments require a specific architect version). The hook must support a per-plugin opt-out so PATH-pinning still works for those plugins.
- **Loud failure mode, not silent-pass** — if the cache parent is unreadable or has zero `@windyroad/*` plugins enabled, the hook must emit a clear diagnostic on stderr rather than silently leaving `PATH` untouched (the silent-pass case is exactly P343's failure mode).
- **One-time per session boot** — the hook fires at `SessionStart` matcher `"startup"`; does NOT re-fire on `resume`/`clear`/`compact` (would risk mid-session PATH thrash with unclear semantics for in-flight subprocesses).
- **Adopter-side test coverage** — bats fixtures must run against a synthetic cache layout (per ADR-049 / JTBD-301), not the host's `~/.claude/plugins/cache/`.

## Considered Options

1. **Option A — SessionStart hook recomputes `PATH` from current cache state at every session start (chosen by user direction; substantive sub-decisions pending).** A new hook script (location TBD per SQ-081-1) registers on the `SessionStart` lifecycle event with `matcher: "startup"`; walks `~/.claude/plugins/cache/windyroad/*/`, picks the highest-version sibling per plugin, prepends that version's `bin/` to `PATH` ahead of any stale entries; emits a one-line summary on stderr listing the resolved versions for visibility.

2. **Option B — Periodic PATH refresh via `UserPromptSubmit` hook with once-per-session marker.** Fire on every user prompt; suppress after first via marker. Rejected per ADR-040 § "What is reused from ADR-038": `SessionStart` is the semantically correct event — the PATH-refresh is a boot-time artifact, not a prompt-time governance gate. `UserPromptSubmit` with suppression is redundant when `SessionStart` provides the right lifecycle natively.

3. **Option C — Hook on `SessionStart` matcher `"startup"` + `"resume"` + `"clear"` + `"compact"`.** Refresh `PATH` on every session lifecycle event, not just `"startup"`. Rejected: mid-session `PATH` mutation risks confusing in-flight subprocesses; the `"resume"` semantics in particular imply continuity, which a `PATH` swap would break. ADR-040 reserves the matcher-less variant for genuinely-always-run cases (like `check-deps.sh`); PATH mutation is not one.

4. **Option D — Hook only on the windyroad-claude-plugin project, not adopter projects.** Constrain the hook to fire only when `${CLAUDE_PROJECT_DIR}` matches this monorepo. Rejected: defeats adopter-portability; adopters in arbitrary projects ALSO need the cold-start fix. P343 is an adopter-class failure mode, not a windyroad-internal-only one.

5. **Option E — Bash profile / rc-file mutation as a one-time install action.** During `/install-updates`, edit the user's `~/.zshrc` / `~/.bashrc` to prepend the cache paths. Rejected: mutates user dotfiles (broad blast radius); ADR-049 / ADR-002 distribution promise is via marketplace, not via shell-config injection.

6. **Option F — Defer to Claude Code's plugin manager to fix the `PATH` ordering at install time.** Upstream concern; same class as P343 Option 2. Ships nothing until upstream lands a feature.

## Decision Outcome

> **PROPOSED — pending substance ratification per ADR-074.** User direction recorded the headline choice (Option A — SessionStart hook recomputes `PATH` from current cache state at session start) in P343 § Fix Strategy (2026-06-01). The substantive **sub-decisions inside Option A** (hook scope, PATH mutation semantics, interaction with sibling ADR-080, failure mode, settings.json interaction) are NOT pinned in this commit; they are queued as `outstanding_questions` for batched user surface at the next interactive transition. No implementation work builds on this ADR until those sub-decisions are pinned.

Chosen option: **"Option A — SessionStart hook recomputes `PATH` from current cache state at every session start"**, because it closes the cold-start staleness window that P343 documents, reuses the established ADR-040 SessionStart surface without inventing a new lifecycle event, is adopter-portable without requiring upstream Claude Code changes, and composes cleanly with sibling ADR-080 (mid-session coverage). The other options either use the wrong lifecycle event (B, C), defeat adopter-portability (D), mutate user dotfiles (E), or ship nothing (F).

**Substantive sub-decisions queued as outstanding_questions** (NOT pinned by this commit):

- **(SQ-081-1) Hook host plugin**: should the hook live in (a) `@windyroad/architect` (the plugin most associated with the cache-management problem domain), (b) `@windyroad/retrospective` (already hosts the SessionStart briefing hook per ADR-040 — natural-sibling location), (c) a new `@windyroad/cache-discipline` plugin dedicated to plugin-cache hygiene, or (d) installable independently per plugin (each plugin ships its own PATH-refresh hook for itself)? Recommendation: **(b) `@windyroad/retrospective`** — extending the existing ADR-040 surface keeps the SessionStart hook count low (each new hook adds session-init latency); the hook iterates over all enabled `@windyroad/*` plugins regardless of which plugin hosts it.
- **(SQ-081-2) Hook scope — all `@windyroad/*` plugins or per-plugin opt-in**: should the hook refresh `PATH` for (a) every `@windyroad/*` plugin found in `~/.claude/plugins/cache/windyroad/`, (b) only plugins explicitly enabled in `.claude/settings.json`, or (c) only plugins explicitly opted-in via an env var? Recommendation: **(a) every `@windyroad/*` plugin** — fires the structural fix universally; `.claude/settings.json` enabled-set could be empty in fresh adopter installs.
- **(SQ-081-3) PATH mutation semantics — prepend, replace, or dedupe**: when the hook computes the latest-version `bin/` directories, should it (a) prepend ahead of all existing `PATH` entries (existing stale entries remain, but resolution finds latest first), (b) replace existing stale entries (remove `0.11.0/bin` if `0.13.0/bin` is now prepended), or (c) dedupe to keep only the latest version's `bin/` per plugin? Recommendation: **(a) prepend** — minimal mutation; existing stale entries don't hurt because the prepended latest is found first; preserves user/adopter-customised `PATH` ordering for non-plugin entries.
- **(SQ-081-4) Interaction with sibling ADR-080**: documented in ADR-080 SQ-080-6 — both ship; the wrapper is authoritative for shim binaries; this hook covers non-wrapped binaries + safety net for any wrapper that fails. Recommendation: **both ship; document the relationship explicitly in Related sections of both ADRs** (already done in capture).
- **(SQ-081-5) Failure mode — loud-fail vs silent-skip**: when the cache parent `~/.claude/plugins/cache/windyroad/` is unreadable, empty, or contains only malformed sibling dir names, should the hook (a) fail loud with stderr message + non-zero exit (block session start), (b) emit a diagnostic on stderr + exit 0 (degraded mode — session starts normally with stale PATH), or (c) silently exit 0 (no signal)? Recommendation: **(b) degraded-mode-warn** — blocking session start (option a) is too aggressive for a hygiene hook; silent (option c) is the exact P343 failure mode that this ADR closes elsewhere. The diagnostic surfaces the cache-state defect without blocking workflow.
- **(SQ-081-6) Per-plugin pin override**: should the hook respect a per-plugin `WR_PIN_<PLUGIN>=<version>` env var (or equivalent `.claude/settings.json` key) that pins a specific version regardless of what's latest in cache? Recommendation: **yes, support both env var and settings.json key** — adopters with compatibility needs (e.g. ADR-066 in-progress amendments) can pin without disabling the hook entirely.
- **(SQ-081-7) `.claude/settings.json` interaction**: the existing settings.json may carry env-var overrides (per ADR-040 § install-updates patterns). Should the hook (a) read settings.json directly for per-plugin pins, (b) rely solely on env vars set elsewhere, or (c) ignore settings.json entirely and require env vars? Recommendation: **(a) read settings.json + accept env-var overrides** — settings.json is the conventional adopter-config surface; env vars are the ad-hoc override surface.

## Consequences

### Good

- P343's cold-start staleness window closes structurally. The next session after `/install-updates` runs starts with the latest-version `bin/` first on `PATH`.
- Reuses ADR-040 SessionStart surface; no new hook lifecycle invented.
- Adopter-portable per ADR-049 / ADR-002 / ADR-003 — no upstream Claude Code change required.
- Composes cleanly with sibling ADR-080 (mid-session coverage); two-layer defence in depth.
- Coverage for non-wrapped binaries: every shim in every enabled `@windyroad/*` plugin's latest `bin/` is reachable via `PATH` regardless of whether ADR-080's wrapper has been retroactively applied to that specific shim.
- Per-plugin pin override (per SQ-081-6 recommendation) supports compatibility-pinned plugins without disabling the hook entirely.
- Loud-degraded failure mode (per SQ-081-5 recommendation) surfaces cache-state defects without blocking workflow.

### Neutral

- Adds ~50ms of session-init latency for the hook's cache walk + PATH manipulation. Bounded; not observable in normal use.
- The hook iterates over all `@windyroad/*` plugins on every session start; the iteration cost scales linearly with the number of installed plugins (currently 12+).
- Adopter projects gain a PATH-mutation hook fired on every session start. Transparent: the hook emits a one-line summary on stderr listing the resolved versions for visibility.

### Bad

- PATH-mutation at SessionStart is invisible to non-shell-aware tooling that caches `PATH` differently. If Claude Code's runtime caches `PATH` before the hook fires, the mutation has no effect. **Mitigation**: depends on Claude Code's SessionStart hook timing semantics; needs empirical confirmation at implementation time. If timing is wrong, ADR-080's shim wrapper remains the load-bearing fix.
- Settings.json interaction (per SQ-081-7) adds a parse dependency to the hook. The retrospective plugin's existing SessionStart hook (`session-start-briefing.sh`) does not currently parse settings.json. **Mitigation**: keep the parse minimal (one `jq -r` or `awk` extract for the pin map); fail loud if settings.json is malformed.
- The hook does NOT help mid-session `/install-updates` refreshes — that gap is exactly what sibling ADR-080's shim wrapper covers. Two ADRs are needed for full coverage. **Mitigation**: explicitly documented in both ADRs' Related sections.
- Mutation semantics (per SQ-081-3 recommendation: prepend) leaves stale entries on `PATH`. A future `which`/`type`-style inspection by the user would show both the latest and the stale entries, which can be confusing. **Mitigation**: the hook's stderr summary names the resolved version explicitly; user inspection of `PATH` is rare in normal use.
- Universally-firing hook (per SQ-081-2 recommendation: all `@windyroad/*` plugins) adds session-init latency proportional to plugin count. **Mitigation**: in practice ~50ms total; reassessment trigger fires if it exceeds 250ms.

## Confirmation

This decision is honoured when:

1. **Hook fires at SessionStart "startup"** — bats fixture (or empirical test) confirms the hook script is invoked exactly once per session at startup; does NOT fire on `"resume"`, `"clear"`, or `"compact"`.
2. **PATH prepended with latest-version `bin/` directories** — synthetic cache layout under `TMP_CACHE` with version dirs `0.9.0/`, `0.11.0/`, `0.13.0/` for plugin X; hook invocation results in `TMP_CACHE/windyroad/X/0.13.0/bin` appearing FIRST in `PATH` (ahead of any stale `0.11.0/bin` entry). Per SQ-081-3.
3. **All `@windyroad/*` plugins covered** — synthetic cache with multiple plugins; hook prepends latest-version `bin/` for each plugin found. Per SQ-081-2.
4. **Per-plugin pin override honoured** — bats fixture with `WR_PIN_ARCHITECT=0.11.0` env var; hook prepends `0.11.0/bin` for architect even though `0.13.0` exists in cache. Per SQ-081-6.
5. **Settings.json pin override honoured** — `.claude/settings.json` with `wr.plugins.architect.pin=0.11.0`; hook respects the pin. Per SQ-081-6 / SQ-081-7.
6. **Loud-degraded failure mode** — synthetic cache with empty `~/.claude/plugins/cache/windyroad/`; hook emits stderr diagnostic naming the empty cache; exits 0 (session start proceeds with PATH untouched). Per SQ-081-5.
7. **Composition with ADR-080** — at runtime, when both ADR-080 wrapper + ADR-081 hook are active, the wrapper's resolved version wins for shim binaries; this hook's prepended PATH covers non-wrapped binaries. Both ADRs' Related sections document the precedence rule.
8. **No regression in P343 cold-start failure mode** — empirical: after `/install-updates` lands a new version, the next session starts with the new version first on `PATH` (NOT the stale `0.11.0`). Validated by repeating P343's session-9 cold-start scenario after the hook lands.
9. **Hook registered in `packages/<host-plugin>/hooks/hooks.json`** — SessionStart entry with `matcher: "startup"` targeting the new script. Host plugin per SQ-081-1.
10. **Adopter-portable bats coverage** — fixtures run from a fresh-install marketplace cache without source-repo cohabitation. Per ADR-049 / JTBD-301.

## Pros and Cons of the Options

### Option A — SessionStart hook recomputes `PATH` at session start (chosen)

- Good: closes cold-start staleness window structurally.
- Good: reuses ADR-040 SessionStart surface (no new lifecycle event).
- Good: adopter-portable; bats-testable in isolation; loud-degraded failure mode.
- Good: composes with sibling ADR-080 for full mid-session + cold-start coverage.
- Good: per-plugin pin override (SQ-081-6) handles compatibility pinning without disabling the hook.
- Neutral: ~50ms session-init latency; scales linearly with plugin count.
- Neutral: leaves stale `PATH` entries (prepend semantics) — user `which`/`type` inspection sees both.
- Bad: depends on Claude Code's SessionStart hook timing — if runtime caches `PATH` before hook fires, mutation has no effect (empirical confirmation needed at implementation).
- Bad: settings.json parse dependency (SQ-081-7).
- Bad: SQ-081-1 through SQ-081-7 substantive sub-decisions remain pending ratification.

### Option B — `UserPromptSubmit` hook with once-per-session marker

- Good: ADR-038 pattern; familiar shape.
- Bad: wrong lifecycle event (`UserPromptSubmit` is for prompt-time governance, not boot-time artifact). Per ADR-040 § "What is reused from ADR-038".
- Bad: requires a marker hook (session-marker.sh) — extra moving part; `SessionStart matcher: "startup"` is the natural-once-per-session lifecycle.

### Option C — Hook on multiple SessionStart matchers (`startup` + `resume` + `clear` + `compact`)

- Good: maximally fresh PATH state at every lifecycle event.
- Bad: mid-session `PATH` mutation risks confusing in-flight subprocesses; `"resume"` semantics imply continuity.
- Bad: incurs hook overhead on every session lifecycle event, not just boot.

### Option D — Hook on windyroad-claude-plugin project only

- Good: scoped to the plugin source repo.
- Bad: defeats adopter-portability (ADR-002 / ADR-003 / JTBD-301). Adopters need the cold-start fix too.

### Option E — Bash profile / rc-file mutation

- Good: zero per-session overhead (mutation happens at install time).
- Bad: mutates user dotfiles (broad blast radius); ADR-049 / ADR-002 distribution promise is via marketplace, not shell-config injection.
- Bad: dotfile mutation across users / systems is hostile to non-bash shells, dotfile managers, and reproducible-environment setups.

### Option F — Defer to upstream Claude Code

- Good: cleanest if upstream ships the fix.
- Bad: not available today; same class as P343 Option 2; ships nothing until upstream lands a feature.

## Reassessment Criteria

Reassess if any of the following:

- Claude Code ships a runtime feature that recomputes `PATH` from cache state at session start (or supports a `${CLAUDE_PLUGIN_CACHE_PATH_REFRESH}` directive) — the hook can devolve back to no-op + the upstream feature becomes load-bearing.
- The hook's session-init latency exceeds 250ms (currently estimated ~50ms) — investigate batch resolution or caching the resolved set across sessions.
- Per-plugin pin overrides (SQ-081-6) fire frequently enough that the hook's "prepend latest" semantics surface as friction (e.g. user constantly setting `WR_PIN_*` to roll back) — reassess whether the default should be "pin to install-time version" with opt-in latest-prepend.
- Claude Code's SessionStart hook timing semantics change (e.g. hooks fire AFTER `PATH` is cached by the runtime) — the hook's mutation has no effect; ADR-080's shim wrapper becomes load-bearing alone.
- Sibling ADR-080 is rejected at its own substance-ratification surface — re-evaluate whether ADR-081 alone is sufficient for the P343 failure mode (it is NOT for mid-session staleness; ADR-080 + ADR-081 are both load-bearing for full coverage).
- The settings.json parse dependency (SQ-081-7) becomes a source of brittleness (malformed settings.json blocks session start) — extract the parse into a shared library; harden against malformed input.
- A naming collision in the cache parent (e.g. an adopter installs a non-windyroad-published `@windyroad/*` plugin from a fork) — the hook needs a publisher-namespace check beyond just the `windyroad` cache dir.

Default reassessment: 3 months from approval (2026-09-02).

## Related

- **P343** (Known Error) — driving problem ticket; Option 4 in P343 § Root Cause Analysis (lines 73–76). This ADR is the structural fix for P343's cold-start staleness window.
- **ADR-040** — Session-start briefing surface. This ADR extends ADR-040's SessionStart surface with a second, complementary hook (PATH refresh in addition to briefing injection). The matcher `"startup"` is the same lifecycle event.
- **ADR-080** (sibling, same iter) — Highest-version-wins shim wrapper for plugin scaffold-template shims. P343 Option 3. Covers mid-session staleness; this ADR covers cold-start. The two compose; the wrapper is authoritative for shim binaries; this hook covers non-wrapped binaries + safety net (SQ-080-6 / SQ-081-4).
- **ADR-049** — `bin/` on `$PATH` with thin shim wrapper. The PATH-mutation in this ADR composes with ADR-049's `bin/` discipline — the hook puts the latest version's `bin/` first on `PATH`; ADR-049's shim grammar resolves correctly from there.
- **ADR-002** — monorepo per-plugin packages. Adopter-portability promise.
- **ADR-003** — marketplace-only distribution. Confirms hooks ship through the marketplace cache.
- **ADR-014** — single commit per discrete unit of work. This ADR + its compendium README update ship as one commit.
- **ADR-066** — born-`proposed` marker model. This ADR ships without `human-oversight:` marker; ratification happens at `/wr-architect:review-decisions` drain once SQ-081-1 through SQ-081-7 are pinned.
- **ADR-074** — substance-confirm-before-build. Driving precedent for the DRAFT banner + outstanding_questions discipline used in this ADR's Decision Outcome.
- **JTBD-007** — Keep Plugins Current Across Projects. Primary persona job served by this ADR (per jtbd-lead verdict 2026-06-02). The persona pain "new release lands on npm but active sessions still run the old code" maps directly to P343's cold-start gap; JTBD-007's outcome "Restarting Claude Code is surfaced as the final step so the new code is loaded" — this hook makes that restart actually load new code.
- **JTBD-006** — Progress the Backlog While I'm Away. Tertiary anchor: AFK loops require the next session to actually run released code; this hook ensures session-start PATH is fresh.
- **JTBD-001** — Enforce Governance Without Slowing Down. Tertiary anchor: SessionStart PATH refresh is automatic and silent; no user prompt; no extra step in the release loop.
- **JTBD-301** — Plugin-user persona's adopter-portability promise. The hook's bats fixtures must run from a fresh-install marketplace cache without source-repo cohabitation.
- **P045** — auto plugin install after governance release; sibling cache-management surface.
- **P106** — `claude plugin install` silent no-op when already installed; sibling cache-management surface.
- **P139** — `feedback_if_you_see_something_broken_fix_it`. P343 is exactly the class of defect this rule catches — silent staleness masked by `installed` reports.
- **P233** — post-release cache refresh in `/wr-itil:work-problems` Step 6.5; same shim-recency assumption.
