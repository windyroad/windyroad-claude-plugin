---
status: "proposed"
date: 2026-06-02
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-09-02
---

# Highest-version-wins shim wrapper for plugin scaffold-template shims

> **DRAFT — substance pending ratification per ADR-074 / P339.** The headline option (Option A: shim wrapper resolves to highest-version sibling at invoke time) is user-directed per P343 Option 3. Substantive sub-decisions inside that direction (resolution algorithm, error handling, shim retroactivity, test strategy, and the interaction with sibling ADR-081) are queued in this iteration's `outstanding_questions` and remain un-pinned; no implementation builds on this ADR until the user pins them at the next interactive transition (`/wr-architect:review-decisions` drain or follow-on session).

## Context and Problem Statement

P343 (Known Error, promoted 2026-06-01) — `/install-updates` refreshes the global plugin cache but does NOT mutate the parent shell's `PATH`. Claude Code's session-init populates `PATH` with each plugin's `bin/` directory at the version current at that time, and `PATH` stays frozen for the lifetime of the session. Subsequent `/install-updates` calls add newer versions to the cache (e.g. `0.12.2`, `0.13.0`) but the older path (e.g. `0.11.0/bin`) remains first on `PATH`. Shim lookups continue to find the stale version first.

Empirical instance (session 9, 2026-05-31): `wr-architect-generate-decisions-compendium` resolved to `~/.claude/plugins/cache/windyroad/wr-architect/0.11.0/bin/...` even after `/install-updates` had refreshed to `0.12.2` and `0.13.0`. The 0.11.0 shim dispatched the pre-P334 unfixed script producing Unicode `…`, and CI test 2145 failed on every push for the entire session (~3hr release block + ~1hr user push-back + $130 agent budget).

P343 enumerated 5 candidate fixes; Option 5 (documentation amendment) shipped same-day. **Option 3 (highest-version-wins shim wrapper) is the structural fix this ADR records** — it closes the mid-session staleness window. Sibling ADR-081 closes the cold-start window via a SessionStart PATH-refresh hook; the two compose (this ADR runs at every shim invocation; ADR-081 runs once per session start).

P343 § Root Cause Analysis (lines 70–76) named Option 3 as "adopter-portable; bounded change in plugin scaffold templates (ADR-049 surface)" but explicitly deferred to a new ADR because **runtime resolution logic is being added to a contract that currently delegates resolution to `PATH` order** — a structural change that ADR-049 did not anticipate.

The framing question: **how should the shim resolve to the latest cached sibling at invoke time, and what is the failure mode when no cached siblings exist or directory names are malformed?**

## Decision Drivers

- **P343's structural fix without requiring user restart** — the workaround documented by P343's Option 5 ("Restart Claude Code REQUIRED") is high-friction during active work and conflicts with `/install-updates`' "safe to run any time" claim. Option 3 closes the structural gap so the workaround becomes the documentation-only fallback rather than the primary mitigation.
- **Adopter-portability** (ADR-002 / ADR-003 / JTBD-301) — the fix must work in any adopter project's marketplace cache layout without requiring upstream Claude Code internals to change. Option 2 from P343 ("single-versioned shim path via re-symlink at install time") was rejected as upstream-concern; Option 3 is in-repo.
- **ADR-049 surface alignment** — the shim wrapper is the natural extension of ADR-049's `bin/` on `$PATH` discipline. The canonical-body-in-`scripts/` + thin-wrapper-in-`bin/` shape (ADR-049 § Decision Outcome) already exists; this ADR replaces the **3-line wrapper body** with a **highest-version-wins resolver body** for one specific case: shims that dispatch into `scripts/`.
- **Cold-start vs mid-session coverage** — Option 4 (sibling ADR-081, SessionStart PATH refresh) covers cold-start cleanup but does NOT help mid-session shim invocations after `/install-updates` runs. Option 3 covers mid-session staleness by resolving at every invocation. The two are complementary, not substitutes.
- **Deterministic resolution under cache evolution** — the cache parent directory accumulates sibling version dirs over time (`0.7.0/`, `0.11.0/`, `0.12.0/`, `0.12.1/`, `0.12.2/`, `0.13.0/`). The wrapper must pick the highest-version sibling **at every invocation** so that any prior `/install-updates` refresh takes effect immediately on next shim use.
- **Failure mode that is safe rather than silent-correct-or-silent-wrong** — when the cache parent is unreadable, empty, or contains only malformed dir names, the wrapper must fail loud with a clear message rather than silently fall back to the running shim's own version (which would mask staleness — the exact P343 failure mode).
- **Adopter-side test coverage** — bats fixtures must run from a fresh-install marketplace cache without source-repo cohabitation (per ADR-049 / JTBD-301). The wrapper logic must be testable with synthetic fixture cache layouts (mkdir + chmod).

## Considered Options

1. **Option A — Shim wrapper resolves to highest-version sibling at invoke time (chosen by user direction; substantive sub-decisions pending).** Replace each plugin scaffold-template shim with a wrapper that walks `$(dirname "$0")/../../` (the cache parent dir), filters sibling directory names by semver shape, sorts highest-first, and `exec`s the resolved sibling's `scripts/<name>.sh`. Adopter-portable; bounded change in plugin scaffold templates.

2. **Option B — Plugin-install-time re-symlink (`<plugin>/bin → <plugin>/<latest>/bin`).** Move the resolution outside the shim and into the install path: every `claude plugin install` (and `/install-updates`) re-creates a `<plugin>/bin` symlink pointing at the highest-version `<plugin>/<version>/bin/`. The wrapper itself stays 3-line as today. **Rejected** per P343 § Root Cause Analysis: requires Claude Code plugin-install internals change (upstream concern); not in this repo's purview.

3. **Option C — `$PATH` mutation at SessionStart only (= sibling ADR-081 alone).** Rely entirely on ADR-081's SessionStart PATH refresh hook; do not change the shim wrapper at all. **Rejected as a substitute for Option A**: SessionStart fires once per session; mid-session `/install-updates` refreshes do NOT trigger a SessionStart, so PATH stays stale until the next session boundary. Session 9's exact failure mode (~3hr cost) is unaddressed. Option C remains valuable as a complement (ADR-081) but not as a substitute.

4. **Option D — Marker file `<plugin>/CURRENT` pointing at latest version dir.** Each `claude plugin install` writes (or updates) a `<plugin>/CURRENT` file containing the latest version string; the shim wrapper reads `CURRENT` to resolve. **Rejected**: adds a new file the install path must maintain consistently; same cache-coordination class as Option B but worse — the file can lag the actual installed dirs if install fails partway.

5. **Option E — Plugin registry file `<plugin>/registry.json`.** Each `claude plugin install` updates a JSON registry naming all installed versions + the "preferred" version. **Rejected**: heaviest-weight; introduces a JSON-parse dependency in every shim wrapper; same coordination class as Option D with more moving parts.

6. **Option F — `$PATH` mutation at every `/install-updates` invocation (in-skill `export PATH=...`).** Modify `/install-updates` SKILL.md Step 5 to emit `export PATH=...` ahead of the new version's `bin/`. **Rejected**: `export` from inside a SKILL bash invocation only mutates the subshell, not the parent Claude Code session; would have zero observable effect (empirically: P343's documented failure mode). The user-visible workaround is restart-only.

## Decision Outcome

> **PROPOSED — pending substance ratification per ADR-074.** User direction recorded the headline choice (Option A — "highest-version-wins shim wrapper") in P343 § Fix Strategy (2026-06-01). The substantive **sub-decisions inside Option A** (resolution algorithm, error handling shape, retroactive vs new-only shim updates, test strategy) are NOT pinned in this commit; they are queued as `outstanding_questions` for batched user surface at the next interactive transition. No implementation work builds on this ADR until those sub-decisions are pinned.

Chosen option: **"Option A — Shim wrapper resolves to highest-version sibling at invoke time"**, because it closes the mid-session staleness window that motivated P343 (the dominant cost driver of session 9), aligns with the existing ADR-049 `bin/` on `$PATH` surface, is adopter-portable without requiring upstream Claude Code changes, and composes cleanly with sibling ADR-081 (cold-start coverage). The other options either require upstream changes (B), cover only cold-start (C — which is exactly what ADR-081 records as a complement), introduce coordination files the install path must maintain (D, E), or have zero observable effect (F).

**Substantive sub-decisions queued as outstanding_questions** (NOT pinned by this commit):

- **(SQ-080-1) Resolution algorithm**: semver-sort (parse `MAJOR.MINOR.PATCH` and compare numerically) vs lexical dir-name sort (LC_ALL=C sort then tail -1). Semver-sort is correct under `0.10.0` vs `0.9.0` (lexical picks `0.9.0` wrongly); lexical is simpler and works for zero-padded version strings. Recommendation: **semver-sort** for correctness against the existing `0.x` corpus where double-digit minor versions are imminent.
- **(SQ-080-2) Error handling — no cached versions**: when the cache parent dir contains zero semver-shaped siblings (e.g. fresh install in flight, manual cache surgery), should the wrapper (a) fail loud with stderr message + exit 127, (b) silently fall back to the running shim's own version dir, or (c) emit a deprecation-style warning and proceed with its own version? Recommendation: **(a) fail loud** — option (b) is the P343 failure mode (silently uses stale version).
- **(SQ-080-3) Error handling — malformed dir names**: when the cache parent dir contains non-semver-shaped subdirs (e.g. git-source residuals, npm tarball cache artefacts, future format experiments), should the wrapper (a) skip non-semver names and use the highest semver sibling, (b) fail loud, or (c) include all names by lexical sort? Recommendation: **(a) skip non-semver, use highest semver sibling** — robust against cache evolution per `feedback_verify_cache_refresh_by_version_dir`.
- **(SQ-080-4) Shim retroactivity**: should the wrapper change land in (a) plugin scaffold template only (new plugins inherit; existing plugins keep 3-line wrapper until next plugin-developer-touched release), (b) plugin scaffold template + retroactive patch of all `@windyroad/*` plugins in this monorepo (one PR per plugin, ride the next minor cycle), or (c) plugin scaffold template + retroactive patch + emit a one-time `wr-architect:agent` Needs-Direction-style verdict for any plugin shim under `packages/*/bin/wr-<plugin>-*` that still uses the 3-line wrapper? Recommendation: **(b) scaffold template + retroactive patch**, because the P343 failure was on `wr-architect-generate-decisions-compendium` (an existing plugin's existing shim); leaving existing plugins on the 3-line wrapper means the structural fix doesn't actually close the failure mode in this monorepo. Per ADR-066 the retroactive patches each carry their own commits/release cycles.
- **(SQ-080-5) Test strategy**: bats fixtures should (a) build a synthetic cache layout via `mkdir -p` under a `TMP_CACHE` dir + invoke the wrapper with `CLAUDE_PLUGIN_CACHE=$TMP_CACHE` env override, OR (b) test against the real `~/.claude/plugins/cache/` (only on dev machines + skip in CI). Recommendation: **(a) synthetic cache** — adopter-portable per ADR-049 / JTBD-301; no host-state dependency.
- **(SQ-080-6) Interaction with sibling ADR-081**: at runtime, when ADR-081's SessionStart hook prepends the latest-version `bin/` ahead of the stale one AND this ADR's shim wrapper resolves at invoke time, **which takes precedence**? The wrapper-on-shim picks the highest-version sibling regardless of `PATH` order, so the runtime answer is "the wrapper's resolution wins". But this means ADR-081's PATH-prepend is effectively cosmetic when both ship — ADR-081 still has value for non-wrapped binaries (e.g. plugin scaffold scripts that aren't shim-wrapped) and as a safety net for any wrapper that fails. Recommendation: **both ship; the wrapper is authoritative for shim binaries; ADR-081 covers everything else** — document the relationship explicitly in both ADRs' Related sections (already done in capture).

## Consequences

### Good

- P343's mid-session staleness window closes structurally. After `/install-updates` runs, the very next shim invocation runs the newest cached code without requiring `PATH` mutation, session restart, or absolute-path invocation workaround.
- Adopter-portable per ADR-049 / ADR-002 / ADR-003 — no upstream Claude Code change required.
- Composes cleanly with sibling ADR-081 (cold-start coverage); two-layer defence in depth.
- The wrapper is a small, testable, single-file change per plugin (replace 3-line wrapper with N-line resolver). Bats fixtures exercise the resolution logic in isolation.
- Failure mode is loud (per SQ-080-2 recommendation): wrapper fails with exit 127 + stderr message when cache parent is empty or unreadable, surfacing the cache-state defect to the user immediately rather than silently masking it.
- Robust against cache evolution (per SQ-080-3 recommendation): non-semver siblings are skipped, so future cache layout experiments don't break the resolver.

### Neutral

- Each shim wrapper grows from 3 lines (ADR-049 baseline) to ~20-30 lines (resolver + error handling). The canonical script body in `scripts/<name>.sh` remains single-touch for body edits; only the wrapper body grows.
- The wrapper runs at every shim invocation, adding ~10ms of shell startup + `ls`-equivalent + version-sort overhead. Bounded; negligible in normal use; observable only in tight CI loops.
- Plugin scaffold template carries the wrapper template; existing plugins per SQ-080-4 (recommendation: retroactive patch) ride the next minor cycle each.

### Bad

- Wrapper resolution depends on the cache parent dir layout being stable and machine-readable. If Claude Code's plugin-install internals change the cache layout (e.g. flat `<plugin>/<version>-<hash>/` vs `<plugin>/<version>/`), every wrapper breaks until the resolver is updated. **Mitigation**: SQ-080-3's skip-non-semver tolerance handles minor format drift; major layout changes trigger a Reassessment (see Reassessment Criteria below).
- The wrapper is `bash`-only; if Claude Code's plugin scaffold ever needs to ship to a non-bash platform (e.g. cmd/pwsh-only Windows), the wrapper logic needs porting. **Mitigation**: existing ADR-049 surface is already `bash`-only; no regression vs status quo.
- Adds runtime resolution logic to a contract that currently delegates resolution to `PATH` order. Future ADR-049 amendments must keep both surfaces in mind. **Mitigation**: Related section in ADR-049 will gain a back-reference to this ADR once it ratifies.
- Resolution overhead is per-invocation. For shims called in tight loops (e.g. inside CI scripts), the ~10ms × N adds up. **Mitigation**: not currently observed in any plugin's hot path; if it surfaces, the wrapper can cache the resolved version in an env var for the lifetime of the subshell.

## Confirmation

This decision is honoured when:

1. **Behavioural bats test** (`packages/architect/bin/test/wr-architect-shim-wrapper.bats` or sibling-plugin equivalent) — synthetic cache layout under `TMP_CACHE` with version dirs `0.9.0/`, `0.10.0/`, `0.11.0/`, `0.12.2/`, `0.13.0/`; wrapper invocation resolves to the `0.13.0` sibling regardless of which dir contains the wrapper file itself. Per SQ-080-5.
2. **Semver-sort correctness** — bats fixture with dirs `0.9.0/`, `0.10.0/` confirms wrapper resolves to `0.10.0` (NOT `0.9.0` as lexical sort would). Per SQ-080-1.
3. **Empty-cache failure mode** — bats fixture with cache parent containing zero semver-shaped siblings → wrapper exits 127 with stderr message naming the cache parent. Per SQ-080-2.
4. **Malformed-dir tolerance** — bats fixture with siblings `0.13.0/`, `git-source/`, `pre-release-rc1/` → wrapper resolves to `0.13.0` (skipping non-semver). Per SQ-080-3.
5. **Retroactive coverage** — each `@windyroad/*` plugin in this monorepo's `packages/<plugin>/bin/wr-<plugin>-*` shim is updated to use the new resolver. Tracked by per-plugin commit/release cycles. Per SQ-080-4.
6. **Composition with ADR-081** — at runtime, when both ADR-080 wrapper + ADR-081 SessionStart hook are active, the wrapper's resolved version wins. Bats fixture confirms wrapper still works when `PATH` order is "stale-first" (simulating ADR-081-absent setup) and when `PATH` order is "latest-first" (simulating ADR-081-active setup). Per SQ-080-6.
7. **Plugin scaffold template carries the new wrapper shape** — scaffold-template files updated; new plugins generated via scaffold inherit the resolver-style wrapper.
8. **No regression in the failure mode P343 names** — empirical: after `/install-updates` lands a new version and the user invokes a shim in the same session, the shim runs the new code (NOT the stale `0.11.0` code). Validated by repeating P343's session-9 scenario after the wrapper lands.

## Pros and Cons of the Options

### Option A — Shim wrapper resolves to highest-version sibling at invoke time (chosen)

- Good: closes mid-session staleness window without session restart or upstream changes.
- Good: aligns with ADR-049 surface; canonical-body-in-`scripts/` preserved.
- Good: adopter-portable; bats-testable in isolation; failure mode is loud (per SQ-080-2).
- Good: composes with sibling ADR-081 without conflict.
- Neutral: each wrapper grows from 3 lines to ~20-30 lines.
- Neutral: ~10ms resolution overhead per shim invocation (bounded).
- Bad: depends on cache layout being stable; major Claude Code internal changes break the resolver (mitigated by Reassessment trigger).
- Bad: `bash`-only (no regression vs ADR-049 status quo).
- Bad: SQ-080-1 through SQ-080-6 substantive sub-decisions remain pending ratification; this ADR cannot move to `accepted` until pinned.

### Option B — Plugin-install-time re-symlink

- Good: zero runtime overhead; resolution moves to install time.
- Bad: requires Claude Code plugin-install internals change (upstream concern); not in this repo's purview.
- Bad: ships nothing until upstream lands the feature; P343 stays broken indefinitely.

### Option C — `$PATH` mutation at SessionStart only

- Good: bounded; reuses the existing ADR-040 SessionStart surface.
- Bad: does NOT close mid-session staleness — `/install-updates` mid-session continues to silently use stale `PATH` until next session boundary.
- Bad: session 9's exact failure mode (~3hr cost) is unaddressed.
- **Note**: this is a substitute-rejection, NOT a complement-rejection — ADR-081 records Option C as its chosen direction for cold-start coverage. ADR-080 + ADR-081 ship together, not one-instead-of-the-other.

### Option D — Marker file `<plugin>/CURRENT`

- Good: simple to read in the wrapper (one file read per invocation).
- Bad: adds a new file the install path must maintain consistently; partial install can leave `CURRENT` pointing at a missing dir.
- Bad: same upstream-coordination class as Option B but with more moving parts in the failure mode.

### Option E — Plugin registry file `<plugin>/registry.json`

- Good: maximally flexible (carries metadata beyond just "latest version").
- Bad: heaviest-weight; introduces JSON parse in every shim wrapper.
- Bad: same coordination class as Option D with more moving parts.

### Option F — `$PATH` mutation in `/install-updates` SKILL bash

- Good: smallest possible patch (one SKILL.md edit).
- Bad: empirically does not work — `export PATH=...` from inside a SKILL bash invocation only mutates the subshell, not the parent Claude Code session. Zero observable effect.

## Reassessment Criteria

Reassess if any of the following:

- Claude Code's plugin-install internals change the cache layout (e.g. flat `<plugin>/<version>-<hash>/` vs `<plugin>/<version>/`) — every wrapper breaks until the resolver is updated. Trigger immediate reassessment + emergency patch.
- Claude Code ships a `${CLAUDE_PLUGIN_LATEST_BIN}` env var (or equivalent) that the runtime populates with the highest-version `bin/` directory at session-init AND keeps current across in-session installs — the wrapper resolver could devolve back to the 3-line `exec` shape from ADR-049, with the env var providing what the wrapper currently walks for.
- A naming-collision incident is reported in the field where an adopter project's cache layout includes non-semver sibling dirs that the SQ-080-3 skip-non-semver heuristic miscategorises (e.g. valid extended semver `1.0.0-rc.1` skipped) — re-evaluate the skip heuristic.
- The ~10ms resolution overhead surfaces as a hot-path concern (CI loops, tight shells) — add subshell-lifetime caching to the wrapper.
- ADR-081 (sibling) is rejected at its own substance-ratification surface and SessionStart PATH refresh is NOT shipped — re-evaluate whether ADR-080's wrapper alone is sufficient (likely yes, but the ADR text + Related references need updating).
- ADR-049's `bin/` on `$PATH` surface is materially amended such that the canonical-body location moves out of `scripts/` — the wrapper's `exec "$(dirname "$0")/../scripts/<name>.sh"` shape breaks.

Default reassessment: 3 months from approval (2026-09-02).

## Related

- **P343** (Known Error) — driving problem ticket; Option 3 in P343 § Root Cause Analysis (lines 70–76). This ADR is the structural fix for P343's mid-session staleness window.
- **ADR-049** — `bin/` on `$PATH` with thin shim wrapper. This ADR amends ADR-049's canonical shim body shape from "3-line `exec`" to "highest-version-wins resolver `exec`" for shim wrappers that dispatch into `scripts/`. ADR-049's `wr-<plugin>-<kebab-script-name>` naming grammar is preserved.
- **ADR-081** (sibling, same iter) — SessionStart PATH refresh hook for plugin cache. P343 Option 4. Covers cold-start staleness; this ADR covers mid-session. The two compose; the wrapper is authoritative for shim binaries (SQ-080-6).
- **ADR-040** — SessionStart briefing surface. Sibling ADR-081 extends this surface.
- **ADR-002** — monorepo per-plugin packages. Adopter-portability promise.
- **ADR-003** — marketplace-only distribution. Confirms `bin/` ships through the marketplace cache.
- **ADR-014** — single commit per discrete unit of work. This ADR + its compendium README update ship as one commit.
- **ADR-066** — born-`proposed` marker model. This ADR ships without `human-oversight:` marker; ratification happens at `/wr-architect:review-decisions` drain once SQ-080-1 through SQ-080-6 are pinned.
- **ADR-074** — substance-confirm-before-build. Driving precedent for the DRAFT banner + outstanding_questions discipline used in this ADR's Decision Outcome.
- **JTBD-007** — Keep Plugins Current Across Projects. Primary persona job served by this ADR (per jtbd-lead verdict 2026-06-02). The persona pain "new release lands on npm but active sessions still run the old code" maps directly to P343's mid-session-staleness gap.
- **JTBD-006** — Progress the Backlog While I'm Away. Tertiary anchor: AFK loops require the next session to actually run released code; this ADR's wrapper makes that true for shim binaries in the same session.
- **JTBD-301** — Plugin-user persona's adopter-portability promise. The wrapper's bats fixtures must run from a fresh-install marketplace cache without source-repo cohabitation.
- **P045** — auto plugin install after governance release; sibling cache-management surface.
- **P106** — `claude plugin install` silent no-op when already installed; sibling cache-management surface.
- **P139** — `feedback_if_you_see_something_broken_fix_it`. P343 is exactly the class of defect this rule catches — silent staleness masked by `installed` reports.
- **P233** — post-release cache refresh in `/wr-itil:work-problems` Step 6.5; same shim-recency assumption.
