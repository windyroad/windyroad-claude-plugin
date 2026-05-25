---
status: "proposed"
date: 2026-05-03
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-11-03
---

# `@windyroad/*` plugin / skill / agent / hook maturity taxonomy

## Context and Problem Statement

P087 surfaces a credibility gap in the `@windyroad/*` plugin suite's adopter-facing presentation: every plugin's README reads as if the plugin were uniformly mature, regardless of how much real-world exercise the surface has actually had. As the user framed it (2026-04-21):

> the readme files give no indication of how robust or battle hardened each skill plugin feature is. For instance the mitigate-incident skill has never been used in anger, but the run-retro skill and manage-problem skill and the architect controls have been used hundreds if not thousands of times. How might we determine this?

Empirical state at the time this ADR was authored: `@windyroad/itil@0.15.0` ships sixteen-plus skills. Among them, `manage-problem` has shipped several hundred resolved tickets through this repo alone; `run-retro` has executed dozens of retros across this AFK loop; `wr-architect:agent`, `wr-jtbd:agent`, and `wr-risk-scorer:pipeline` fire on every edit in every project that installs them. By contrast, the recently-split `mitigate-incident`, `restore-incident`, `close-incident`, and `link-incident` skills (split out of `manage-incident` in `@windyroad/itil@0.15.0`) carry 600+ green bats apiece but **zero real-world invocations**. An adopter scanning the suite cannot distinguish well-exercised guardrails from newly-shipped-but-unproven splits — both render identically in the README, in `claude plugin list` output, and in the marketplace listing.

This is not a single-plugin bug. It is a design-level gap in the suite's content convention: there is no agreed-upon taxonomy for "how battle-tested is this surface?", no agreed-upon location for the signal to live, and no agreed-upon promotion/demotion criteria. Every new plugin inherits the gap; every existing plugin masks its own maturity. Adoption decisions — particularly under JTBD-302 (Trust That the README Describes the Plugin I Just Installed) and JTBD-007 (Keep Plugins Current Across Projects), where the reader has no internal-repo context to fall back on — are made blind.

The fix decomposes into three layers that should ship in distinct phases per the established staged-landing pattern (P047):

1. **Taxonomy + promotion criteria + signal location** (this ADR — Phase 1, advisory). Defines the bands, what each band means, what objective signals (in the abstract) move a surface between bands, and where the band designation is recorded canonically vs rendered.
2. **Measurement mechanism** (Phase 2, separate ADR). Pins the concrete sources for the objective signals — session-transcript parsing for invocation counts, commit-history heuristics, problem-ticket aggregation, breaking-change-window detection — and the script(s) that compute them. P087's Direction Decision (2026-04-21) already records the user-approved approach: combine `/insights` (existing Claude Code command), session-transcript parser (new skill), and commit-history heuristic, with the maturity badge **derived** from those signals rather than self-reported.
3. **Retroactive assessment + README integration** (Phase 3, mechanical rollout). Apply Phase-2 measurement to every existing plugin / skill / agent / hook, write the resulting band into the canonical location, and surface it in each plugin's README header alongside the JTBD-derived value framing (ADR-069, superseding ADR-051).

This ADR carries Phase 1. Pinning taxonomy + promotion criteria + signal location now — without committing to a specific measurement source — lets Phase 2 be authored with concrete prototyping evidence (P087 Investigation Tasks 3 + 4) rather than ahead-of-the-data guessing.

## Decision Drivers

- **JTBD-302 (Trust That the README Describes the Plugin I Just Installed) — co-primary driver**. JTBD-302 explicitly cites P087 as a sibling on the *maturity-label axis* of adopter-facing content quality. The plugin-user persona has no repo-internals context to calibrate trust; the README must carry the maturity signal directly. Without it, JTBD-302 cannot be served.
- **JTBD-007 (Keep Plugins Current Across Projects) — secondary driver**. Maturity is a temporal currency signal — promotion/demotion criteria measure exercise over time. Composes with ADR-051's currency-pressure extension from code-currency to README-content-currency.
- **JTBD-003 (Compose Only the Guardrails I Need) — secondary driver**. Composition decisions ("which guardrails should I install?") require knowing which surfaces are stable enough to depend on. No signal forces defensive over-compose or accidental under-compose.
- **JTBD-101 (Extend the Suite with Clear Patterns) — composition driver**. A future contributor authoring a new `@windyroad/*` plugin or splitting an existing one (P071 precedent) needs ONE place that says "this is the bar for promotion from Experimental to Alpha; here is what Stable means". This ADR is that place. JTBD-101's documented outcome list does not currently cover "promotion criteria visibility"; an extension to that outcome list is recorded as a Phase-3 follow-up below — Phase 1 is the ADR; Phase 3 is the JTBD update + README rollout.
- **JTBD-201 (Restore Service Fast with an Audit Trail) — composition driver**. Audit confidence depends on knowing the runtime-exercise level of each guardrail the audit relies on. Uniform presentation undermines audit confidence.
- **Tension between conservative-band-count and clear-band-count drivers**. JTBD-003 favours more bands (more granular signal → more informed under-compose); JTBD-101 favours fewer-but-clearer bands (less surface area for contributors to reason about). The five-band strawman from P087 (Experimental / Alpha / Beta / Stable / Deprecated) splits the difference at the conventional software-lifecycle granularity. This tension is acknowledged here so that future iterations of the taxonomy weigh both axes when proposing changes.
- **Signal must be objective and computable, not author self-report**. P087 RCA Option 3 (explicit author-maintained badge) was rejected on its own — owners drift, "everything becomes Beta forever", or "everything becomes Stable to avoid friction". The chosen direction is **derived signal**: bands are computed from observable evidence and written by tooling; commits do not hand-edit the canonical band field.
- **Advisory-first per ADR-013 Rule 6 fail-safe**. Phase 1 ships nothing executable and gates nothing. Phase 2's measurement scripts will exit 0 and emit signal as data on stdout. Phase 3 escalation to a CI assertion only fires if accumulated unfixed drift across N consecutive releases meets ADR-013 Rule 6 escalation criteria. Mirrors the trajectory in ADR-051 for JTBD anchoring.
- **Decision-anchored pressure stack alignment**. Per ADR-051's framing, every gate in the suite cross-checks edits against a canonical source of truth. The maturity field needs the same shape: a single canonical record per surface, a single rendering convention, a single computation source. Splitting the canonical record across multiple files (e.g. README header AND a separate `docs/maturity/` file) creates two truths and is rejected.
- **Composition with ADR-069 (JTBD-derived README marketing; supersedes ADR-051)**. ADR-069 markets each README to its primary persona's problem, derived from the JTBD (no ID citation; names WHAT PROBLEM the plugin solves). The maturity badge signals HOW BATTLE-TESTED the surface's serving of those jobs is. The two are **orthogonal**: maturity is per-plugin / per-skill / per-agent / per-hook, NOT per-job. The badge sits in the README header alongside the JTBD-derived value framing, not nested inside individual job sections.
- **Granularity matches the user's framing**. P087's framing names per-skill comparisons (`mitigate-incident` vs `manage-problem`). Per-skill / per-agent / per-hook resolution is mandatory; per-plugin is a derived rollup (worst-case band of constituent surfaces). Anything coarser masks the precise gap P087 surfaces.
- **`bin/`-on-PATH grammar for Phase 2 scripts (ADR-049)**. When measurement scripts ship in Phase 2, they MUST follow the established `wr-<plugin>-<kebab-name>` shim grammar so adopters can invoke them in adopter contexts.

## Considered Options

1. **Option D1 — Three bands (Experimental / Stable / Deprecated)**: minimal surface, easy retroactive assessment. Rejected — collapses the meaningful "shipped but not-yet-exercised" vs "exercised under load but still pre-1.0" distinction that P087's framing rests on.
2. **Option D2 — Five bands (Experimental / Alpha / Beta / Stable / Deprecated) (chosen)**: matches the P087 strawman and the conventional software-lifecycle vocabulary. Each band has a clear admission criterion in objective signals (days-shipped, invocation count, resolved problem-ticket count, breaking-change-free window). Splits the JTBD-003 vs JTBD-101 tension acceptably.
3. **Option D3 — Continuous score (0.0–1.0)**: emit a numeric exercise index rather than a band. More information-dense; harder for adopters to reason about ("is 0.62 enough?"). Rejected — defeats the on-the-tin readability the badge is meant to provide. The continuous score MAY appear as a Phase-3 supplementary signal beneath the banded badge, but the band is the load-bearing surface.
4. **Option D4 — Self-reported author badge**: per-plugin owner picks the band. Rejected on RCA Option 3 grounds (drift, no enforcement, every band collapses to "Beta").
5. **Option D5 — Canonical record in `plugin.json` `maturity:` field per skill/agent/hook entry, README header badge as rendered surface (chosen for signal location)**: dual-location with one canonical source. The `plugin.json` field is machine-readable, lives where adopters already read plugin metadata, is computed-and-written by Phase-2 tooling (not hand-edited), and has audit-trail value via git history. The README badge is rendered for human-eyeball consumption alongside the JTBD anchor.
6. **Option D6 — Generated `docs/maturity/<plugin>.md` per plugin**: extra surface, extra file format, no offsetting benefit. Rejected.
7. **Option D7 — Compute on the fly with no stored canonical value**: every reader recomputes from session transcripts + git log. Cheapest to ship; no audit trail; readers without local session history (e.g. fresh `claude plugin list` invocations) get zero signal. Rejected.

## Decision Outcome

**Chosen taxonomy: five-band (Experimental / Alpha / Beta / Stable / Deprecated)** per Option D2.

**Chosen signal location: dual-location with one canonical truth** per Option D5. Canonical: a `maturity:` field per skill/agent/hook/plugin entry in each plugin's `plugin.json` (computed by Phase-2 tooling; commits do not hand-edit). Rendered: a maturity badge in each plugin's README header, sited in the same header region as the JTBD-derived value framing from ADR-069 (superseding ADR-051) but above (or beside) it — orthogonal axis, not nested.

**Chosen granularity: per-skill / per-agent / per-hook, with per-plugin rollup**. Each surface has its own band. The plugin-level rollup is the worst-case band across constituent surfaces (so a plugin containing one Experimental skill carries the Experimental rollup at the plugin header, regardless of how many Stable skills it also exposes). Adopters who care only about the rollup get a simple signal; adopters making composition decisions can drill into the per-skill bands.

**Chosen Phase-1 advisory posture per ADR-013 Rule 6**: this ADR ships only the taxonomy + promotion criteria + signal location. No script, no hook, no CI assertion. Phase 2 (separate ADR) pins measurement mechanism. Phase 3 ships retroactive assessment and README integration. Phase 4+ may escalate to a gate per ADR-013 Rule 6 criteria.

### Promotion / demotion criteria (objective-signal-shaped)

The criteria are stated in terms of **what is measured**, not **how it is measured** — Phase 2 will pin the concrete sources. Each band's admission rule applies to a single skill / agent / hook surface; the plugin-level rollup is computed downstream.

- **Experimental** — surface shipped within the last fourteen days, OR fewer than ten observed invocations across all session transcripts on the host, OR fewer than three resolved problem tickets that cite the surface's source files. Default band for any newly-shipped split or newly-authored skill/agent/hook. Carries a "do not depend on this in production-critical paths" implication for the adopter.
- **Alpha** — surface has been shipped between fourteen and sixty days, with between ten and one hundred observed invocations, with three to ten resolved problem tickets, and has had at least one breaking change in the window. Signals "exercised but the API or behaviour is still settling".
- **Beta** — surface has been shipped between sixty and one hundred eighty days, with between one hundred and one thousand observed invocations, with ten or more resolved problem tickets, and no breaking changes in the last thirty days. Signals "exercised under load; API stable but not yet battle-hardened across diverse contexts".
- **Stable** — surface has been shipped one hundred eighty or more days, with one thousand or more observed invocations, sustained low rate of new ticket creation (indicator of diminishing novelty), and no breaking changes in the last ninety days. Signals "depend on this; semantic-versioning contract is real".
- **Deprecated** — author-declared; the canonical `plugin.json` entry carries a `supersededBy:` pointer (consistent with ADR-010's deprecation-window precedent for skill splits). Signals "use the supersedor; this surface will be removed at a future minor or major bump".

Thresholds are tunable per surface category (AFK orchestrators accumulate invocations fast; ADR-creation skills accumulate slowly; runtime gate hooks fire on every edit and saturate the invocation thresholds within days). Phase 2 will pin per-category overrides where the strawman thresholds prove a poor fit. Surfaces below their category's threshold floor on any axis sit in the lower band — bands are AND-gated, not OR-gated, on the upper-bound criteria.

Demotion follows the symmetric rule: a surface that accrues a fresh breaking change drops one band; a surface whose ticket-creation rate spikes above the band's tolerated novelty floor drops one band. Demotions are computed from the same objective signals as promotions; they are not author-declared.

### Bootstrapping clause (amendment 2026-05-04, P087 Phase 2 prototype-driven)

The strawman thresholds above are calibrated against a steady-state suite. They cannot apply to the suite as it stands at the time of this ADR's authoring: the `windyroad-claude-plugin` monorepo's first commit is dated 2026-04-07, meaning the OLDEST surface in the suite is twenty-seven days shipped — below the sixty-day Beta admission floor on every axis. Applying the steady-state thresholds today would deterministically place every surface in **Experimental**, regardless of how heavily exercised the surface is in real-world use. Phase 2 prototype runs against thirty days of session-transcript history confirm the empirical mismatch: `wr-architect:agent` saw 796 invocations and `wr-jtbd:agent` saw 638 invocations (substantially exceeding the Beta-band invocation floor), yet both surfaces score zero days_shipped past the bootstrapping floor.

The Bootstrapping clause governs the interim regime:

- **Until the suite-oldest surface crosses sixty days shipped**, every surface in every `@windyroad/*` plugin is band-assigned **Experimental** by default. The interim rule supersedes the steady-state thresholds for the purpose of band admission only — the underlying signals (invocations_30d, days_shipped, closed_tickets, breaking_change_age) are still measured and emitted by Phase 2 tooling for transparency.
- **Provisional Alpha promotion within the bootstrapping window**: a surface MAY be promoted to **Alpha** during the bootstrapping window if it meets BOTH of these conditions: (a) at least one hundred invocations observed in the last thirty days of session-transcript history; (b) at least fourteen days shipped (i.e. older than the Experimental "shipped within the last fourteen days" criterion). No further promotion (Beta / Stable) is reachable during the bootstrapping window — those bands require steady-state-threshold sixty-day or one-hundred-eighty-day floors that the suite cannot satisfy.
- **Sunset criterion**: the Bootstrapping clause lapses automatically the day the suite-oldest surface crosses sixty days shipped (anticipated 2026-06-06, sixty days after 2026-04-07). On lapse, the steady-state thresholds in the section above govern unconditionally; no further amendment is required for the lapse itself. Surfaces that were band-assigned under the bootstrapping rule are recomputed under the steady-state rule on first invocation of the Phase 2 measurement scripts after the lapse date.
- **Phase 3 rendering requirement (binding on Phase 3)**: when Phase 3 renders the maturity badge for a surface band-assigned during the bootstrapping window, the badge MUST present the band designation **adjacent to the underlying invocation count**, e.g. "Experimental (suite-bootstrap window; 796 invocations / 30d)" rather than a bare "Experimental" badge. The composite rendering preserves JTBD-302 honesty — adopters see both the band (calibrated against the bootstrapping rule) and the visible-evidence signal (invocation count) so they can calibrate trust against the substantive exercise level rather than the temporal-floor accident. Phase 3 implementations that render a bare band during the bootstrapping window violate this clause and should be reverted.
- **Author-override carve-out NOT introduced**: the Bootstrapping clause does NOT permit per-plugin author override of the band designation. The interim rule is mechanical and applies suite-wide; preserving the "no author self-report" principle from RCA Option 3.

This clause is an in-place amendment to Phase 1 (this ADR) rather than a separate ADR because the band-admission contract is the load-bearing contract this ADR owns. Splitting the bootstrapping rule into a separate ADR would create a second canonical source for band-admission semantics, contradicting the "single canonical record" framing in the Decision Drivers paragraph above. Phase 2 measurement tooling (ADR-058) implements the rule; Phase 2 owns implementation, Phase 1 owns contract.

### Confirmation

Confirmation is staged across the three phases. Phase 1 (this ADR) needs no executable confirmation — the deliverable is the ADR itself. The remaining confirmations belong to Phase 2 and Phase 3:

1. (Phase 2) Measurement scripts ship under each plugin's `bin/` directory following the `wr-<plugin>-<kebab-name>` grammar (ADR-049) and emit per-surface band designations as machine-readable output (JSON or NDJSON to stdout) without writing to disk. Phase 2 is exercise-the-signal, not commit-the-signal.
2. (Phase 3) Bats coverage per plugin asserts that every skill/agent/hook in `plugin.json` carries a `maturity:` field whose value is one of the five recognised bands plus an optional `supersededBy:` pointer when the band is `Deprecated`. Behavioural test (ADR-052), not a structural-grep on the README — the test reads `plugin.json`, validates the field's presence and shape across surfaces, and asserts the rollup band on the plugin entry equals the worst-case across constituent surfaces.
3. (Phase 3) Each plugin's README header contains a rendered maturity badge that resolves the canonical `plugin.json` value. Drift between the rendered badge and the canonical field is detected by an advisory script (sibling to the ADR-051 JTBD-drift detector) — exit 0 always; signal as data on stdout.
4. (Phase 3) The JTBD-101 desired-outcome list is extended with a bullet covering "promotion criteria are documented so contributors know the bar to clear when authoring a new skill or splitting an existing one" — this ADR is the cited source for that outcome.
5. (Phase 4+) Escalation from advisory to CI assertion follows the ADR-013 Rule 6 criterion: if accumulated drift across N consecutive releases (initial proposal: three) goes unfixed, the advisory script is promoted to a release-blocking gate. The criterion is identical to ADR-051's escalation contract for JTBD anchoring.
6. No commit hand-edits the `maturity:` field in `plugin.json`. The field is written exclusively by Phase-2 measurement tooling. Manual override is permitted only for `Deprecated` band assignment (the only author-declared band) and for the `supersededBy:` pointer on Deprecated entries.

### Granularity contract

The granularity rule is load-bearing for the precision the signal carries:

- Each top-level entry in a plugin's `plugin.json` (skill, agent, hook, command, sub-skill) carries its own `maturity:` field.
- The plugin's root entry in `plugin.json` carries a `maturity:` field whose value equals the worst-case band among its constituent surfaces (Experimental dominates Alpha dominates Beta dominates Stable; Deprecated is a separate axis that overlays — a plugin whose only Deprecated surfaces are also its only surfaces is itself Deprecated; otherwise Deprecated entries are elided from the rollup computation but retained on individual surface entries).
- A plugin with no shipped surfaces (e.g. `@windyroad/agent-plugins` if it ships no top-level skills) carries no plugin-level `maturity:` field — the field is required only when there is at least one constituent surface.

## Consequences

- **Positive**: adopters distinguish well-exercised surfaces from newly-shipped splits at glance — JTBD-302 served. Composition decisions under JTBD-003 carry an objective signal. Contribution decisions under JTBD-101 carry a documented bar. Audit decisions under JTBD-201 carry a runtime-exercise level per guardrail. The taxonomy provides a stable contract for Phase 2 measurement work to ship against.
- **Positive**: the ADR establishes a precedent — taxonomy ADRs that pin contracts before measurement infrastructure is built — that future cross-cutting governance work can compose with. ADR-051 + ADR-053 pair cleanly: JTBD anchor (what jobs) + maturity badge (how exercised) form the core of each plugin's adopter-facing content contract.
- **Negative**: Phase-1-only delivery means the gap P087 surfaces is not yet closed in adopter-visible terms. Adopters reading READMEs between Phase 1 (this ADR landing) and Phase 3 (rendered badges + canonical fields populated) will see no behavioural change. P087 remains in Known Error status until Phase 3 ships.
- **Negative**: the band-thresholds in this ADR are strawmen. Phase 2 prototyping (P087 Investigation Tasks 3 + 4) may surface that the conventional software-lifecycle thresholds are a poor fit for AFK-orchestrator surfaces or for runtime gate hooks; Phase 2's measurement-mechanism ADR will need to ship per-category overrides. The risk is that the strawmen settle in by inertia and aren't tuned.
- **Negative**: per-skill / per-agent / per-hook granularity makes retroactive Phase 3 assessment expensive — each surface needs an independent measurement run, not just one per plugin. The cost is bounded but real (≥50 surfaces across the suite).
- **Negative**: dual-location (canonical `plugin.json` + rendered README badge) introduces drift potential. Mitigated by: (a) Phase 3 advisory drift detector (sibling to ADR-051's), (b) the README badge being a derived rendering of the canonical value (not independently authored), (c) Phase 4+ escalation to a CI gate if drift accumulates.
- **Negative**: the ADR is the third "Phase 1 ADR pins direction; Phase 2+ ships infrastructure" pattern in the suite (after ADR-051's JTBD-anchored READMEs and ADR-052's behavioural-tests-default). The pattern is repeatable but each instance accrues a Phase-2-and-3 backlog. P087 stays Known Error and the Phase 2 + Phase 3 ADRs are blocking dependencies; the residual must be tracked.
- **Neutral**: composition with ADR-051 is orthogonal — neither ADR rewrites the other; both ship to the same README header region. Adopters who only use one plugin still get value from each ADR independently.

## More Information

- P087 — `docs/problems/087-no-maturity-signal-for-plugin-features.open.md` — source ticket; user direction recorded in the "Direction decision (2026-04-21)" section is the load-bearing input to this ADR.
- ADR-069 — `docs/decisions/069-readme-markets-persona-problem-not-jtbd-id.proposed.md` (supersedes ADR-051) — sibling ADR on the adopter-facing-content axis (JTBD-derived README marketing); maturity badge composes with the JTBD-derived value framing in the README header.
- ADR-013 — `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — Rule 6 fail-safe applies; Phase 1 advisory; Phase 4+ gate escalation criterion.
- ADR-049 — `docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md` — `wr-<plugin>-<kebab-name>` shim grammar binds Phase 2 measurement scripts.
- ADR-022 — `docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md` — precedent for status-as-suffix lifecycle; this ADR deliberately does not use file-suffix encoding because plugin/skill surfaces are directories rather than single files.
- ADR-010 — `docs/decisions/010-skill-naming-and-deprecation-window.proposed.md` — precedent for `supersededBy:` pointer on `Deprecated` entries.
- ADR-047 — `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md` — staged-landing pattern (Phase 1 / Phase 2 / Phase 3).
- ADR-052 — `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md` — Phase 3 confirmation tests are behavioural (read `plugin.json`, validate field values, assert rollup invariants), not structural grep on README content.
- JTBD-302 — `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md` — co-primary driver.
- JTBD-007 — `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md` — secondary driver.
- JTBD-003 — `docs/jtbd/solo-developer/JTBD-003-compose-guardrails.proposed.md` — secondary driver.
- JTBD-101 — `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` — composition driver; outcome-list extension recorded as Phase 3 follow-up.
- JTBD-201 — `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` — composition driver.
- P047 — `docs/problems/047-install-updates-overrides-adopter-governance-files.*.md` — staged-landing precedent referenced for the three-phase rollout.
- P078 — `docs/problems/078-assistant-does-not-offer-problem-ticket-on-user-correction.*.md` — capture-on-correction policy that surfaced P087 originally (user observation in AFK iter-7 retro).
