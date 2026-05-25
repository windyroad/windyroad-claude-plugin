---
status: "proposed"
date: 2026-05-17
decision-makers: [Tom Howard]
consulted: [wr-architect:agent (YELLOW-with-adjustments; 4 adjustments folded in), wr-jtbd:agent (YELLOW-with-adjustments; 5 adjustments + 4 JTBD outcome amendments folded in)]
informed: [Windy Road plugin users, plugin-developer persona, plugin-user persona, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-11-17
---

# `@windyroad/*` plugin maturity presentation layer — `plugin.json` schema, prose-woven README badge, in-suite `wr-itil-plugin-maturity-list` display shim

## Context and Problem Statement

ADR-053 (Phase 1) pinned the five-band maturity taxonomy (Experimental / Alpha / Beta / Stable / Deprecated), the dual-location signal (canonical `plugin.json` `maturity:` field + rendered README header badge), the per-skill / per-agent / per-hook granularity + per-plugin worst-case rollup contract, the Bootstrapping clause (amendment 2026-05-04), and the abstract promotion / demotion criteria. ADR-058 (Phase 2) pinned the measurement mechanism: two read-only diagnostic scripts (`wr-itil-skill-invocations` transcript axis; `wr-itil-plugin-exercise-index` git axis) emitting NDJSON-per-surface / NDJSON-per-plugin to stdout under exit-0-always posture, ADR-035 privacy clauses, ADR-049 shim grammar, ADR-052 behavioural confirmation, ADR-023 performance contract. Phases 2a through 2e shipped between 2026-05-16 iter-2 and 2026-05-17 iter-7; the transcript-axis script's warm-cache wall-clock is now 4.04s median (under the 5s reassessment threshold by 19%).

ADR-053 §Decision Outcome explicitly named the canonical location (`plugin.json` `maturity:` field per surface; README header badge rendered) but deferred the **implementation-detail format** of the rendered surface to Phase 3 — the README badge syntax (markdown text vs shields.io URL vs inline SVG), the per-skill nested vs per-plugin rollup rendering, the question of whether to extend `marketplace.json`, and the question of whether `claude plugin list` extension is feasible without upstream Claude Code support. P087 Investigation Task line 128 names this gap explicitly. ADR-058 §Confirmation #9 explicitly notes that **band-mapping is Phase 3's responsibility consuming both axes' NDJSON** — Phase 2 emits the underlying signals; Phase 3 maps them to bands, writes the canonical field, and renders the adopter-facing badge.

ADR-063 carries Phase 3 of the P087 rollout. Phase 3 is the **presentation-layer contract**: it pins the `plugin.json` field schema, the README badge rendering format, the granularity / placement rules, the in-suite display surface, and the Phase 3 sub-iter shape (3a population script → 3b renderer + drift detector → 3c bats coverage). Phase 3 does NOT pin the implementation of those sub-iters — each is a sibling follow-on ticket. ADR-063 to Phase 3 sub-iters maps directly onto ADR-053 to ADR-058 (contract-first ADR, implementation-second sibling iters).

This Phase 3 distinction matters and is the focus of architect adjustment A3: ADR-063 Phase 3 = the presentation-layer rollout phase of the P087 cluster (ADR-053 / ADR-058 / ADR-063). It is distinct from **ADR-057 Phase 3** (the R6-gated load-bearing escalation), which remains deferred indefinitely per ADR-058 §Phase 4+ escalation gate (N=3 consecutive releases, M=5 surfaces drifted). Readers encountering "Phase 3" in either context should consult the surrounding ADR to disambiguate; the two are different cluster axes that happen to share the phase number.

The ecosystem of prior-art for "battle-tested / experimental / stable" signal across software ecosystems is mature and well-precedented. ADR-026 grounding requires citations; the prior-art survey informed each Considered Option:

- **npm `deprecate` flag** ([npm-deprecate CLI docs](https://docs.npmjs.com/cli/v10/commands/npm-deprecate)) — registry-side metadata, author self-report, binary signal, surfaces only on install. *Lesson*: author self-report alone produces binary signals that don't compose with five-band granularity; ADR-053 already rejected pure author self-report on RCA Option 3 grounds.
- **GitHub repository `archived`** ([GitHub archiving docs](https://docs.github.com/en/repositories/archiving-a-github-repository/archiving-repositories), [REST repos API](https://docs.github.com/en/rest/repos/repos)) — repo-level boolean field, exposed via REST `archived` attribute, surfaces as a banner. *Lesson*: a manifest-shaped metadata field has the cleanest consumer-side parsing path; this informs Decision Outcome §"`plugin.json` field schema".
- **Semantic versioning 0.x.x** ([semver.org §4](https://semver.org/#spec-item-4)) — version-number-itself-is-signal. *Lesson*: two-state signals don't carry enough information for adoption decisions; ADR-053's five-band rejection of three-band Option D1 already cited this.
- **Apache "Incubating" lifecycle** ([Apache Incubator Policy](https://incubator.apache.org/policy/incubation.html)) — mandatory `-incubating` infix in release filenames, mandatory DISCLAIMER file in every release, website branding restrictions, release artifacts hosted under `apache.org/dist/incubator/`. *Lesson*: **single-surface signals get ignored**; multi-surface enforcement (filename + DISCLAIMER + website + URL path) defeats the "I'll just not look at that one place" failure mode. This is the load-bearing precedent for ADR-063's dual-rendering (header rollup + per-surface column) — render in two places so the signal can't be silently bypassed.
- **TC39 proposal stages** ([TC39 Process Document](https://tc39.es/process-document/)) — five-plus bands (Stage 0/1/2/2.7/3/4), committee-decided, surfaced in GitHub repo metadata. *Lesson*: five-band-plus-fractional precedent (Stage 2.7 is interstitial) — but five-band-only with bootstrapping rule is sufficient; we do not need fractional bands.
- **MDN BCD `__compat.status`** ([BCD compat-data-schema](https://github.com/mdn/browser-compat-data/blob/main/schemas/compat-data-schema.md)) — three parallel booleans (`experimental`, `standard_track`, `deprecated`), MDN curator-decided, being replaced by Baseline. *Lesson*: parallel booleans don't compose; the BCD schema explicitly documents the migration away from this pattern. ADR-053's enum approach is precedent-aligned.
- **Rust unstable features** ([The Rust Unstable Book](https://doc.rust-lang.org/unstable-book/the-unstable-book.html)) — compiler refuses to compile unstable features on stable toolchain; the error IS the signal. *Lesson*: hard enforcement is appropriate when the runtime is in the producer's control; ADR-063 cannot hard-enforce because the consumer (adopter's Claude Code session) is outside our control. The Phase 3b advisory drift detector is the closest equivalent we can ship.
- **Python PEP 411 Provisional API** ([PEP 411](https://peps.python.org/pep-0411/)) — documentation-only signal, later marked "provisional status proved ineffective at preventing community reliance on unstable modules". *Lesson*: doc-only signals get ignored. ADR-063 must pin BOTH machine-readable canonical (`plugin.json` field, machine-parseable) AND human-readable rendered (README badge, human-eyeball) to avoid this failure mode.
- **Linux kernel CONFIG_EXPERIMENTAL removal** ([Linux 3.9 changelog](https://kernelnewbies.org/Linux_3.9), [CONFIG_EXPERIMENTAL Kconfig entry](https://cateee.net/lkddb/web-lkddb/EXPERIMENTAL.html)) — single global "experimental" flag removed in Linux 3.9 because distros enabled it by default, making the gate meaningless. Replaced by per-option "(EXPERIMENTAL)" title suffix + `drivers/staging/` filesystem convention. *Lesson*: single global flags get normalized away; per-surface granularity is what survives. ADR-053 §granularity contract is precedent-aligned with this lesson.
- **shields.io badge conventions** ([shields.io static badge docs](https://shields.io/badges/static-badge)) — external-image rendering, URL-shape `/badge/<label>-<message>-<color>`, optional `?cacheSeconds=`. *Trade-offs*: external dependency (shields.io uptime), cache window staleness, fails-broken offline. The Bootstrapping clause's required compound rendering ("Experimental (suite-bootstrap window; 796 invocations / 30d)") is hard to express in a static badge URL — URL-encoding the compound message produces an unreadable URL and the rendered badge truncates compound text at common badge widths.
- **VS Code extension `preview` boolean** ([VS Code extension manifest](https://code.visualstudio.com/api/references/extension-manifest), [vscode#162651](https://github.com/microsoft/vscode/issues/162651)) — `"preview": true` in `package.json`, rendered as a "Preview" tag in the marketplace UI. *Lesson*: this is the closest precedent for ADR-063 — a manifest field (analogous to our `plugin.json` `maturity:` field) consumed by a registry-side UI (analogous to `claude plugin list` / `/plugin browse`). vscode#162651 documents the bug where the badge inherits from the latest version rather than the version being viewed — an audit-trail / freshness failure that ADR-063's rich-record `evidence: {...}` + `computed_at` schema is designed to prevent.

Synthesis: the prior-art consensus favours **manifest-field-as-source-of-truth** (VS Code `preview`, GitHub `archived` REST attribute, MDN BCD `__compat.status`), **multi-surface rendering to defeat the single-surface ignorance failure mode** (Apache Incubating), **per-surface granularity over global flags** (Linux CONFIG_EXPERIMENTAL removal), **machine-readable + human-readable in parallel** (PEP 411 cautionary tale), **enum over parallel booleans** (BCD migration away from parallel-booleans), and **offline-resilient rendering over external-image dependencies** (shields.io trade-offs). All five inform ADR-063's Decision Outcome below.

## Decision Drivers

- **JTBD-302 (Trust That the README Describes the Plugin I Just Installed) — primary driver, Phase-3-active**. ADR-058 named JTBD-302 as TERMINAL driver Phase-3-active only — "JTBD-302 reactivates in Phase 3 when the rendered README badge surfaces the band designation". ADR-063 is that reactivation point. The plugin-user persona's "low context on repo internals; AI agent as primary interface" constraint forces the badge to land in the agent's value-model formation window (top of file, lead prose) so the agent expands maturity-aware context before forming a trust model. **Prose-weaving the rollup badge into the value-framing lead prose** (per the prose-weaving anti-pattern, carried forward to ADR-069 from superseded ADR-051) is the load-bearing JTBD-302 path; a standalone header block would reproduce the bolt-on `## Jobs to be Done` failure mode ADR-069 explicitly rejects.
- **JTBD-101 (Extend the Suite with New Plugins) — composition driver, two-surface split**. JTBD-101's hardening-prioritisation outcome (extended 2026-05-04 by ADR-058) is plugin-developer-facing — the developer queries Phase 2 NDJSON to know where to invest test effort. Phase 3 ADR-063 is plugin-user-facing — the adopter sees the rendered badge to know whether to depend on a surface. **Both surfaces serve JTBD-101 but at different reading times and to different audiences**. Phase 2 NDJSON is the dev-console surface; Phase 3 rendering is the install / compose-time surface. ADR-063 explicitly names this two-surface-two-audience split so future contributors do not collapse them into a single rendering pipeline.
- **JTBD-003 (Compose Only the Guardrails I Need) — composition driver**. Composition decisions are per-surface ("which skills should I install?"), so the per-skill column in the existing `## Skills` / `## How It Works` tables is the right granularity. Per-skill column adds one cell per row to a table adopters already scan — no new structural element. **Compound bootstrapping-clause rendering stays at the rollup**, not in the table cells, otherwise the table becomes a wall of parentheticals that defeats readability.
- **JTBD-201 (Restore Service Fast with an Audit Trail) — composition driver**. Tech-lead audit constraints favour the rich-record per-surface `plugin.json` shape (`{schema_version, band, computed_at, evidence: {invocations_30d, days_shipped, closed_tickets_window, breaking_change_age_days}}`) over a string-only shape. The audit trail belongs in the durable canonical record (plugin.json), not in the ephemeral Phase 2 NDJSON stdout. **Phase 2 NDJSON remains the transient computation surface; `plugin.json` `evidence:` is the durable trust surface** — different consumers, different lifetimes. JTBD-201's "hypotheses cite evidence" outcome reads naturally onto the rich-record audit value.
- **JTBD-007 (Keep Plugins Current Across Projects) — currency-pressure driver**. Phase 3b's drift detector compares rendered README badge against canonical `plugin.json` field; this is a third currency axis (code-currency, README-content-currency, maturity-band-currency) composing with ADR-069's inventory-currency commit-hook drift detector (narrowed from ADR-051's JTBD-ID anchor to skill-inventory-drift). **Different anchor (skill-inventory vs maturity record), different failure mode (inventory drift vs render drift), same detector pattern.** Sibling scripts under `packages/retrospective/scripts/check-*-currency.sh`.
- **Apache Incubating multi-surface-enforcement lesson**: render the band in BOTH plugin.json AND README so it cannot be silently bypassed. Single-surface signals get ignored.
- **PEP 411 documentation-only-fails lesson**: pin BOTH machine-readable (plugin.json) AND human-readable (README badge) so neither audience is denied the signal.
- **shields.io external-dependency trade-off**: the Bootstrapping clause's required compound rendering cannot be expressed in a static shields.io URL without producing an unreadable URL or a truncated badge; combined with the external-dep blast radius (shields.io uptime + cache staleness + offline-broken), **markdown text is the precedent-aligned choice**.
- **VS Code `preview` boolean precedent**: a manifest field (analogous to `plugin.json` `maturity:`) is the closest precedent we have for the consumer-side parsing path. The vscode#162651 "Preview badge inherits from latest version" bug informs the `computed_at` + `evidence:` design — a freshness-stamped audit-trail record prevents the same class of bug.
- **Linux CONFIG_EXPERIMENTAL removal lesson**: per-surface granularity over a single global flag; ADR-053 §granularity contract is precedent-aligned.
- **Prose-weaving anti-pattern (binding; carried forward to ADR-069 from superseded ADR-051)**: the bolt-on `## Jobs to be Done` tail-section is rejected as compliance theatre; the same pattern would apply to a bolt-on `## Maturity` section or a standalone header block. **Prose-weaving** is the load-bearing precedent: the maturity rollup is woven into the value-framing lead prose; per-skill bands are woven into the existing per-skill table rows.
- **ADR-053 §Bootstrapping clause Phase 3 rendering requirement (binding contract)**: the badge MUST present the band designation **adjacent to the underlying invocation count** during the bootstrapping window — "Experimental (suite-bootstrap window; 796 invocations / 30d)" not "Experimental". ADR-063 enforces this requirement in the prose-weaving target guidance below.
- **ADR-058 §Confirmation #8 schema-version precedent**: the rich-record `plugin.json` shape carries `schema_version: "1.0"` for additive-only schema evolution.
- **ADR-013 Rule 6 fail-safe + ADR-040 declarative-first (binding posture)**: Phase 3b drift detector is advisory-first, exit-0-always, signal-as-data on stdout. Promotion to release-blocking gate is ADR-057 Phase 3 (still deferred per ADR-058 §Phase 4+ N=3, M=5).
- **ADR-044 silent-framework carve-out (binding scope-limit)**: band recomputation by the Phase 3a population script is **mechanical, policy-resolved** per ADR-053 §promotion criteria + §Bootstrapping clause. The Phase 3a script MUST NOT call `AskUserQuestion` per band recompute. The carve-out is **scope-limited** — it does NOT cover (a) author-declared Deprecated band assignment, (b) `supersededBy:` pointer authoring, (c) Phase 4+ escalation gate threshold tuning. These remain AskUserQuestion-eligible per ADR-013 Rule 1. Spelling this out prevents the inverse-P078 trap (P132).
- **ADR-049 bin-shim grammar (binding)**: the new `wr-itil-plugin-maturity-list` shim follows the established `wr-<plugin>-<kebab-name>` grammar.
- **ADR-052 behavioural-tests-default (binding)**: Phase 3c bats coverage reads `plugin.json` and validates field shape behaviourally, not by structural-grep on README content.
- **ADR-002 per-plugin packages + ADR-003 marketplace-only distribution**: marketplace.json carries plugin name + description + source path only; adding a maturity field there would duplicate the canonical `plugin.json` record (violates ADR-053 §"Decision-anchored pressure stack alignment") with no offsetting benefit since the marketplace consumer (`/plugin install` browse UI) does not currently render extra fields. **Defer marketplace.json extension** with a reassessment trigger.
- **`claude plugin list` extension requires upstream**: Claude Code's `plugin list` output is hard-coded; the plugin side cannot extend it. **Defer to upstream feature request** alongside the per-skill-invocation analytics request already filed in P087. Ship `wr-itil-plugin-maturity-list` as the in-suite equivalent so adopters have a machine-readable rollup view without waiting on upstream.
- **ADR-057 cluster-rollout three-phase shape conformance**: ADR-063 is the Phase 3 of the P087 cluster (Phase 1 ADR-053 contract → Phase 2 ADR-058 measurement → Phase 3 ADR-063 presentation). ADR-057's "Phase 3" refers to the R6-gated escalation gate, which is a different axis and remains deferred. **The two Phase-3 axes are distinct** and ADR-063 explicitly contrasts them to prevent reader confusion.

## Considered Options

1. **Option F1 — String-only `maturity:` field in `plugin.json` per surface, no evidence record**. Simplest schema; smallest delta to existing `plugin.json` shape; least audit-trail value. Rejected — JTBD-201 audit-trail outcome and the vscode#162651 freshness-bug lesson both favour the rich-record. The schema cost is one nested object per surface; the audit-trail value is durable.
2. **Option F2 — Rich-record per-surface entry, string rollup on plugin root (chosen)**. Per-surface: `{schema_version: "1.0", band: "Experimental", computed_at: "<ISO>", evidence: {invocations_30d, days_shipped, closed_tickets_window, breaking_change_age_days}}`. Plugin root: `{schema_version: "1.0", band: "Experimental"}` (rollup is derived; no evidence record because the rollup is computed from constituent surfaces). Schema-version per ADR-058 §Confirmation #8 for additive-only evolution. Architect adjustment A1.
3. **Option F3 — Shields.io URL badge** (e.g. `![Maturity: Experimental](https://img.shields.io/badge/maturity-experimental-orange)`). Visual punch; rejected on (a) external-dep blast radius (shields.io uptime + cache-stale), (b) Bootstrapping clause compound rendering cannot be expressed cleanly in a static badge URL — URL-encoding "Experimental (suite-bootstrap window; 796 invocations / 30d)" produces an unreadable URL and the rendered badge truncates compound text, (c) ADR-002 boundary tension — every plugin README would carry an external dependency that adopter projects then inherit when they `cat node_modules/<plugin>/README.md`.
4. **Option F4 — Inline static SVG committed under `packages/<plugin>/assets/maturity-badge.svg`**. Zero external dep; visual punch. Rejected — generation infrastructure overhead (SVG renderer + per-band stylesheet); per-surface SVG explosion (one SVG per skill × 50+ surfaces); SVG updates on every band change means commits churn binary-shaped diff. No offsetting benefit over markdown text.
5. **Option F5 — Markdown text badge, prose-woven (chosen for rendering)**. Per the prose-weaving precedent (ADR-069, carried forward from superseded ADR-051). Rollup: woven into value-framing lead prose, e.g. *"`@windyroad/itil` (Experimental, suite-bootstrap window; 796 invocations / 30d) brings lightweight ITIL incident and problem management to your AI coding workflow..."* — marketing the persona's problem, not citing a JTBD ID per ADR-069. Per-skill: `Maturity` column in existing `## Skills` / `## How It Works` tables, band name only (no compound rendering — compound stays at rollup per Bootstrapping clause). Architect adjustment A4 + JTBD adjustment 3.
6. **Option F6 — Standalone header block** (e.g. `**Maturity:** Experimental` right after the H1). Reproduces the bolt-on `## Jobs to be Done` anti-pattern ADR-069 explicitly rejects (carried forward from superseded ADR-051). **Rejected**.
7. **Option F7 — Extend `marketplace.json` with a per-plugin `maturity:` field**. Duplicates canonical record (violates ADR-053 §"Decision-anchored pressure stack alignment"); the marketplace consumer does not currently render extra fields; YAGNI. **Defer with reassessment trigger** if upstream Claude Code begins surfacing maturity-like fields in marketplace browse UI.
8. **Option F8 — Extend `claude plugin list` output**. Not feasible without upstream Claude Code support. **Defer to upstream feature request**.
9. **Option F9 — Ship `wr-itil-plugin-maturity-list` bin shim as in-suite display surface (chosen as Phase 3 contract, NOT deferred)**. Architect adjustment A2. Consumes installed plugins' `plugin.json` `maturity:` field (per ADR-003 marketplace-cached read path); does NOT re-run Phase 2 NDJSON (Phase 2 is the writer's source, not the display surface's source). Output NDJSON-per-plugin under `schema_version: "1.0"` for consumer-stable contract. Composes with the eventual upstream `claude plugin list` extension when it ships — the upstream extension can adopt the same NDJSON shape.
10. **Option F10 — Defer the in-suite shim, wait for upstream**. Rejected — adopters lose the rollup view in the interim, and the upstream timeline is undefined.
11. **Option F11 — Skip Phase 3 entirely; let adopters consume Phase 2 NDJSON directly**. Rejected — Phase 2 NDJSON is dev-console surface, not adopter-install surface. JTBD-302 cannot be served by stdout output that adopters never invoke; the README badge IS the JTBD-302 surface.

## Decision Outcome

**Chosen options: F2 (rich-record per-surface + string rollup `plugin.json` schema) + F5 (markdown text badge, prose-woven) + F9 (in-suite `wr-itil-plugin-maturity-list` shim).** Marketplace.json extension (F7) and `claude plugin list` extension (F8) deferred with named reassessment triggers.

Phase 3 sub-iters land as ordered follow-on tickets: **3a (population script, writes `plugin.json` `maturity:` field from Phase 2 NDJSON) MUST precede 3b (README badge renderer + advisory drift detector)** because 3b needs canonical field data to render and to detect drift against. **3c (bats doc-lint coverage per plugin) ships alongside 3b or as a follow-on**. Each sub-iter is a sibling problem ticket captured under P087 follow-ons.

### Amendment 2026-05-18 (P0 hotfix)

**Forcing function**: Phase 3 retroactive rollout (commit d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins) wrote per-surface maturity records at top-level `plugin.json` keys (`skills:` / `agents:` / `hooks:` / `commands:`). Claude Code's plugin manifest validator rejects that shape: *"Validation errors: hooks: Invalid input, skills: Invalid input"*. The validator reserves those top-level keys for a specific event-keyed schema (NOT maturity records). All 11 affected plugins were unparseable by `claude plugin install` immediately after release. The bug was never live-validated by `claude plugin install` in CI; the Phase 3a bats fixtures asserted JSON shape but not installer acceptance.

**Schema relocation**: per-surface maturity records nest UNDER the top-level `maturity:` key at `plugin_doc.maturity.<kind>.<name>` (where `<kind>` ∈ {`skills`, `agents`, `hooks`, `commands`}). The nested record IS the maturity record directly — no inner `.maturity` envelope. The top-level `maturity:` key carries both the rollup (`schema_version`, `band`) AND the per-kind nested maps.

**Corrected schema** (replaces the §"`plugin.json` `maturity:` field schema" section that follows for canonical reference; **further amended by §Amendment 2026-05-18 (P269)** below to add `rollup_invocations_30d` + `bootstrapping` to the rollup):

```jsonc
{
  "name": "@windyroad/itil",
  "version": "0.35.2",
  "description": "...",
  "maturity": {
    "schema_version": "2.0",
    "band": "Experimental",
    "rollup_invocations_30d": 796,    // P269 amendment
    "bootstrapping": true,             // P269 amendment
    "skills": {
      "manage-problem": {
        "schema_version": "2.0",
        "band": "Beta",
        "computed_at": "2026-05-18T01:29:14Z",
        "evidence": {
          "invocations_30d": 100,
          "days_shipped": 32,
          "closed_tickets_window": 92,
          "breaking_change_age_days": null
        }
      }
    },
    "hooks": { "<name>": { ... } },
    "agents": { "<name>": { ... } },
    "commands": { "<name>": { ... } }
  }
}
```

**Schema version bump to "2.0"**: the path move is NOT additive per ADR-058 §Confirmation #8 (consumers reading the old path get nothing under the new shape; consumers reading the new path got nothing under the old). Major-version bump records the cut-over. The carve-out option (retain "1.0" on grounds that the old shape was never validator-accepted in production) was REJECTED because in-repo consumers (Phase 3b render + Phase 3c drift detector) DID parse it pre-hotfix; clean schema_version semantics matter more than the carve-out narrative.

**Updated confirmation criteria**:
- §Confirmation #10 (Phase 3a populate writes per-surface records): the writer MUST place per-surface records at `plugin_doc.maturity.<kind>.<name>` and never at top-level `<kind>:` keys. Bats fixture: `packages/itil/scripts/test/plugin-maturity-populate.bats` (17/17 green post-amendment).
- New §Confirmation #11 (Manifest validator compatibility): a `claude plugin install <plugin>@windyroad --scope project` against a freshly-published plugin MUST succeed. The Phase 3a bats coverage was insufficient — bats fixtures asserted JSON shape but not installer acceptance. Follow-on iter SHOULD add CI gate that runs `claude plugin install --dry-run` against each plugin pre-publish (P246 sibling-class — gate-the-actual-load-bearing-surface, not a proxy).
- New §Confirmation #12 (Schema version stamping): both rollup (`maturity.schema_version`) and per-surface (`maturity.<kind>.<name>.schema_version`) carry `"2.0"`. Re-runs of `wr-itil-plugin-maturity-populate` preserve any Deprecated-band overlays at the nested location (architect §I + ADR-053 #6 / #102 invariant).

### Amendment 2026-05-18 (P269 — rollup compound-evidence write)

**Forcing function**: this amendment restores compliance with **ADR-053 §Bootstrapping clause Phase 3 rendering requirement** (the binding contract that *"Phase 3 implementations that render a bare band during the bootstrapping window violate this clause and should be reverted"*). The §Amendment 2026-05-18 P0 hotfix above shipped the per-kind-nesting fix in the populate writer but did not extend the rollup payload to include the bootstrapping-window evidence that the Phase 3b renderer (`packages/itil/scripts/plugin-maturity-render.sh` line 144-147) requires. The renderer's compound-form predicate is AND-gated on **both** `bootstrapping` AND `rollup_invocations_30d`:

```python
bootstrapping = bool(maturity_record.get("bootstrapping"))
inv = maturity_record.get("rollup_invocations_30d")
if bootstrapping and isinstance(inv, int) and inv > 0:
    return f"*Maturity: {band} (suite-bootstrap window; {inv} invocations / 30d).*"
return f"*Maturity: {band}.*"
```

Pre-amendment, the populate writer emitted neither field on the rollup. Both `maturity_record.get(...)` calls returned `None`, the AND-gated predicate evaluated to `False`, and every plugin fell through to the bare-band form during the bootstrapping window — invisible-evidence rendering across all 12 plugins shipped pre-amendment.

**User direction at session 7 loop-end Step 2.5 routing (2026-05-18)**: amend the **populate writer** to emit both fields rather than amending the renderer to derive on-fly. The single-source-of-truth principle pins the bootstrapping-window evidence as a property of the populate-time snapshot (not as a render-time recomputation): the rollup snapshot travels with the published `plugin.json` so adopters who `npm install` get a frozen, auditable record rather than a rendering-time guess that might disagree with the bands derived alongside.

**Schema additions** (additive-within-2.0 per ADR-058 §Confirmation #8):

The rollup carries two new fields alongside the existing `{schema_version, band}` pair:

- **`rollup_invocations_30d: integer | null`** — sum of `invocations_30d` across non-null per-surface entries during the populate pass. `null` when ALL per-surface entries are the null sentinel (e.g. hook-only plugins; hooks are not transcript-observable per architect §C). Excluding null sentinels from the sum preserves the "not measurable" vs "measurably zero" honesty contract — a hook-only plugin reporting `0` would lie, whereas `null` correctly conveys "no countable surfaces."
- **`bootstrapping: bool`** — snapshot of the bootstrapping-window state at populate time, copied from the existing module-scope `bootstrapping_active` flag computed from `suite_oldest_days < 60` per ADR-053 §Bootstrapping clause auto-derivation. **Populate-time snapshot, not render-time recompute** — if the sunset fires between populate and render, the renderer trusts the snapshot. Snapshot-not-recompute matches the same precedent the `computed_at` field already establishes on per-surface records.

The §155 commentary *"Computing an aggregated `evidence:` record on the rollup would invent semantic content not present in any single surface"* still holds for the four-field `evidence:` dict. The two new fields are NOT a rollup `evidence:` block — they are deterministic-sum + window-state-snapshot derivations, not invented aggregations (no average / median / extrapolation). The rollup still defers to constituent surfaces for the full `evidence:` audit trail; the rollup gains only the two summary fields the renderer's compound predicate requires.

**Schema version semantics**: additive-within-2.0 per ADR-058 §Confirmation #8. Old consumers reading only `{schema_version, band}` continue to work (the new fields are ignored). New consumers reading the new fields get them where present. **Contrast with the §Amendment 2026-05-18 P0 hotfix above** — that amendment bumped `"1.0" → "2.0"` because the path-move was non-additive (old-path readers got nothing under the new shape and vice versa). The P269 amendment is the opposite shape — strictly additive — so it lives entirely within `"2.0"` without a major-version bump.

**Corrected rollup schema** (replaces the §"`plugin.json` `maturity:` field schema" §"Per plugin (root entry, rollup)" example that follows for canonical reference):

```jsonc
{
  "maturity": {
    "schema_version": "2.0",
    "band": "Experimental",
    "rollup_invocations_30d": 796,
    "bootstrapping": true,
    "skills":   { "<name>": { /* per-surface rich record */ } },
    "agents":   { "<name>": { /* per-surface rich record */ } },
    "hooks":    { "<name>": { /* per-surface rich record, null invocations */ } },
    "commands": { "<name>": { /* per-surface rich record */ } }
  }
}
```

**Confirmation criteria additions**:
- New §Confirmation #13 (P269 rollup compound-evidence write): the writer emits `rollup_invocations_30d = sum(non-null per-surface invocations_30d)` on the rollup, or `null` when ALL per-surface entries are null. The writer also emits `bootstrapping = bootstrapping_active` (boolean) on the rollup. Bats fixtures: `packages/itil/scripts/test/plugin-maturity-populate.bats` covers sum-of-non-null, null-when-all-hook, bootstrapping-true-during-window, bootstrapping-false-post-sunset.
- New §Confirmation #14 (Phase 3b AND-gated compound predicate): the renderer emits the compound form `*Maturity: <Band> (suite-bootstrap window; <N> invocations / 30d).*` iff `bootstrapping == true` AND `rollup_invocations_30d` is a positive integer; falls through to bare-band `*Maturity: <Band>.*` otherwise. Bats fixtures: `packages/itil/scripts/test/plugin-maturity-render.bats` covers compound-positive (window + integer), bootstrapping=true + null-invocations → bare-band (hook-only), bootstrapping=false + integer → bare-band (post-sunset).
- New §Confirmation #15 (Phase 3c doc-lint shape-when-present): the lint asserts `rollup_invocations_30d` is `int | null` and `bootstrapping` is `bool` when present on the rollup; tolerates absence for plugins that haven't been re-populated since the P269 amendment (shape-when-present semantics per §23-25 of `plugin-maturity-doc-lint.bats` header).

### `plugin.json` `maturity:` field schema

Per surface (skill / agent / hook / command / sub-skill entry):

```json
{
  "maturity": {
    "schema_version": "1.0",
    "band": "Experimental",
    "computed_at": "2026-05-17T14:32:01Z",
    "evidence": {
      "invocations_30d": 796,
      "days_shipped": 27,
      "closed_tickets_window": 5,
      "breaking_change_age_days": null
    }
  }
}
```

Per plugin (root entry, rollup):

```json
{
  "maturity": {
    "schema_version": "2.0",
    "band": "Experimental",
    "rollup_invocations_30d": 796,
    "bootstrapping": true
  }
}
```

The rollup carries `schema_version` + `band` (worst-case across constituent surfaces per ADR-053 §granularity contract), plus the two compound-rendering-evidence fields added by the §Amendment 2026-05-18 (P269) above: `rollup_invocations_30d` (sum of non-null per-surface `invocations_30d`; `null` when all-null, e.g. hook-only plugins) and `bootstrapping` (populate-time snapshot of the bootstrapping-window state). These two are deterministic-sum + window-state-snapshot derivations — they do NOT invent aggregated `evidence:` semantic content (no average / median / extrapolation). The rollup still defers to constituent surfaces for the full `evidence:` audit trail; only the two summary fields the renderer's compound-form AND-gated predicate requires are surfaced at the rollup.

`schema_version` is `"2.0"` post the §Amendment 2026-05-18 P0 hotfix path-move. The P269 compound-evidence addition is additive-within-2.0 per ADR-058 §Confirmation #8 — no further version bump required.

**Deprecated band carries an additional `supersededBy:` field** per ADR-053 §promotion criteria + ADR-010 precedent. The `supersededBy:` pointer is the only field on the maturity record that may be hand-authored; all other fields are written exclusively by the Phase 3a population script. Hand-edits to other fields are advisory-detectable by the Phase 3b drift detector and warrant follow-up.

### README badge rendering format

**Markdown text only**. No shields.io URL. No inline SVG.

**Plugin rollup**: prose-woven into the value-framing lead prose (typically the opening sentence of `## What It Does` or equivalent). Example shape:

```markdown
**`@windyroad/itil`** (Experimental, suite-bootstrap window; 796 invocations / 30d) serves [JTBD-201](../../docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md) by bringing lightweight ITIL service management to your AI coding workflow.
```

After the Bootstrapping clause lapses (anticipated 2026-06-06 per ADR-053 §Bootstrapping clause sunset criterion), the compound rendering simplifies to the band designation alone:

```markdown
**`@windyroad/itil`** (Beta) serves [JTBD-201](../../docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md) by bringing lightweight ITIL service management to your AI coding workflow.
```

The compound rendering during the bootstrapping window is mandated by ADR-053 §Bootstrapping clause Phase 3 rendering requirement and is the load-bearing JTBD-302 honesty signal — adopters see both the band (calibrated against the bootstrapping rule) and the visible-evidence (invocation count) so they can calibrate trust against substantive exercise level rather than the temporal-floor accident.

**Per-skill / per-agent / per-hook**: `Maturity` column in the existing `## Skills` / `## How It Works` tables. Band name only — no compound bootstrapping rendering in the table cells (compound stays at rollup; per-cell compound would produce a wall of parentheticals defeating readability). Example shape:

```markdown
| Skill | Purpose | Maturity |
|-------|---------|----------|
| `/wr-itil:manage-problem` | Create, update, and close problem tickets... | Experimental |
| `/wr-itil:mitigate-incident` | Record a mitigation attempt against an incident... | Experimental |
```

**Anti-patterns** (do NOT do this):

- A standalone `## Maturity` section as a tail appendage (reproduces the bolt-on anti-pattern — ADR-069, carried forward from superseded ADR-051).
- A header block like `**Maturity:** Experimental` immediately after the H1, before any prose framing (reproduces the same anti-pattern at the head of the document).
- An external shields.io badge URL (rejected per Option F3 trade-offs above).
- Compound rendering in per-skill table cells during the bootstrapping window (defeats table readability; compound stays at rollup).

### `wr-itil-plugin-maturity-list` bin shim contract

**Location**: `packages/itil/bin/wr-itil-plugin-maturity-list` (ADR-049 shim) → `packages/itil/scripts/plugin-maturity-list.sh` (canonical body, ergonomic + bats-testable).

**Read surface**: installed plugins' `plugin.json` files via the **marketplace-cached path** per ADR-003 (the `claude plugin install`-resolved path, not the source-tree path). The adopter invokes the shim; the shim discovers installed `@windyroad/*` plugins from the marketplace cache and reads each plugin's `plugin.json` `maturity:` field. The shim does NOT re-run Phase 2 NDJSON (Phase 2 is the writer's source; the shim is the display surface's source).

**Output**: NDJSON one record per surface, schema:

```json
{
  "schema_version": "1.0",
  "axis": "plugin-maturity-list",
  "plugin": "itil",
  "surface": "wr-itil:manage-problem",
  "kind": "skill",
  "band": "Experimental",
  "computed_at": "2026-05-17T14:32:01Z",
  "evidence": {
    "invocations_30d": 96,
    "days_shipped": 40,
    "closed_tickets_window": 5,
    "breaking_change_age_days": null
  }
}
```

Plus one record per plugin (rollup):

```json
{
  "schema_version": "1.0",
  "axis": "plugin-maturity-list",
  "plugin": "itil",
  "kind": "plugin-rollup",
  "band": "Experimental"
}
```

`schema_version: "1.0"` matches the `plugin.json` schema for consumer-stable contract per ADR-058 §Confirmation #8 precedent. The NDJSON shape is also the contract the eventual upstream `claude plugin list` extension can adopt; the in-suite shim is the forward-extension point.

**Exit code**: 0 always. Conditions producing zero output records (no installed `@windyroad/*` plugins, marketplace cache inaccessible, all installed plugins missing the `maturity:` field): print one comment line `# wr-itil-plugin-maturity-list: <reason>` to stderr, exit 0. ADR-013 Rule 6 fail-safe.

**No network primitive**: same negative-grep bats assertion as ADR-058 §Confirmation #3.

### Phase 3 sub-iter shape

Phase 3 ADR-063 pins contracts; Phase 3 sub-iters land as ordered follow-on tickets per ADR-014 commit grain:

- **Phase 3a — population script**: `packages/itil/scripts/plugin-maturity-populate.sh` (canonical body) + `packages/itil/bin/wr-itil-plugin-maturity-populate` (shim). Reads Phase 2 NDJSON output (`wr-itil-skill-invocations` + `wr-itil-plugin-exercise-index`), applies the ADR-053 promotion / demotion criteria + Bootstrapping clause, writes the `maturity:` field per surface and per plugin root in each `packages/<plugin>/.claude-plugin/plugin.json`. Idempotent — re-running produces no diff if signals are unchanged. ADR-044 silent-framework-action: no `AskUserQuestion` per band recompute. Bats coverage: behavioural per ADR-052 — synthetic NDJSON + synthetic plugin.json fixture → assert resulting `maturity:` field shape.
- **Phase 3b — README badge renderer + advisory drift detector**: `packages/itil/scripts/plugin-maturity-render.sh` (renderer; writes README badges from `plugin.json` field) + `packages/retrospective/scripts/check-plugin-maturity-drift.sh` (detector; advisory-first, exit-0-always, NDJSON-per-drift signal). Drift definition: README badge rendering does NOT match `plugin.json` `maturity:` field. Sibling to ADR-069's inventory-currency detector `check-readme-jtbd-currency.sh` (narrowed from ADR-051's JTBD-ID anchor to skill-inventory-drift). Different anchor (maturity record vs skill-inventory), same detector pattern. Bats coverage: behavioural — drift fixture, clean fixture, stale-band fixture.
- **Phase 3c — bats doc-lint per plugin**: per `packages/<plugin>/` a bats fixture asserts `plugin.json` carries a `maturity:` field on every top-level entry (skill / agent / hook / command / sub-skill) whose value matches the `{schema_version, band, computed_at, evidence}` shape; asserts the plugin root carries a `{schema_version, band}` rollup; asserts the rollup band equals the worst-case among constituent surfaces; asserts the README contains the prose-woven rollup badge matching the canonical record. ADR-052 behavioural.

Phase 3 sub-iters land as separate problem tickets captured under P087 follow-ons. **Ordering is binding**: 3a MUST precede 3b (3b needs canonical fields to render and detect drift against); 3c MAY ship alongside 3b or as a follow-on.

**ADR-057 Phase 3 (R6-gated load-bearing escalation) remains deferred** per ADR-058 §Phase 4+ escalation gate criterion (N=3 consecutive releases, M=5 surfaces drifted, drift non-decreasing across the three). ADR-063 Phase 3 (presentation-layer rollout) and ADR-057 Phase 3 (escalation gate) are distinct cluster axes that happen to share the phase number. The Phase 3b advisory drift detector emits the signal ADR-057 Phase 3 would eventually consume; ADR-057 Phase 3 fires iff M=5 drifted surfaces persist across N=3 consecutive releases. Until then, the drift detector remains advisory.

### ADR-044 silent-framework carve-out (scope-limited)

Phase 3a's band recomputation is **mechanical, policy-resolved** per ADR-053 §promotion criteria + §Bootstrapping clause. The Phase 3a script MUST NOT call `AskUserQuestion` per band recompute. This is a Category 4 silent-framework-action per the ADR-044 6-class authority taxonomy.

The carve-out is **scope-limited**. It does NOT cover:

- **Author-declared Deprecated band assignment** — Deprecated is the only band that is author-declared (per ADR-053 §promotion criteria); transitions into Deprecated band remain AskUserQuestion-eligible.
- **`supersededBy:` pointer authoring** — the only hand-editable field on the maturity record (per Deprecated band requirement); remains AskUserQuestion-eligible.
- **Phase 4+ escalation gate threshold tuning** — the (N=3, M=5) values per ADR-058 §Phase 4+ are policy decisions; tuning them remains AskUserQuestion-eligible.

Spelling these out prevents the inverse-P078 trap (P132) — agents over-generalising Rule 1 to "ask before deciding ANYTHING" silently undo the load-bearing UX investment of the mechanical-stage carve-out.

### Confirmation

Confirmation is staged across the Phase 3 sub-iters. ADR-063 (this ADR) needs no executable confirmation — the deliverable is the ADR itself. The remaining confirmations belong to Phase 3a / 3b / 3c:

1. (Phase 3a) `wr-itil-plugin-maturity-populate` is idempotent: bats seeds a fixture Phase 2 NDJSON output + a fixture `plugin.json` without `maturity:` field; runs the script twice; asserts the first run writes the expected `maturity:` field and the second run produces no diff. ADR-052 behavioural.
2. (Phase 3a) Synthetic NDJSON with `invocations_30d=796` + `days_shipped=27` + `closed_tickets_window=5` + `breaking_change_age_days=null` against a surface produces band `Experimental` during the bootstrapping window (per ADR-053 §Bootstrapping clause); after sunset (test fixture sets a date past 2026-06-06), produces band `Beta` (per ADR-053 §promotion criteria steady-state thresholds).
3. (Phase 3a) Phase 3a script does NOT invoke `AskUserQuestion` per band recompute (negative-presence behavioural assertion: process stdin / stderr captured during a fixture run is asserted to not contain any `<askuserquestion>` token).
4. (Phase 3b) `wr-itil-plugin-maturity-render` writes the prose-woven rollup badge to the value-framing lead paragraph of `packages/<plugin>/README.md` matching the canonical `plugin.json` band. Bats fixture: synthetic plugin.json + clean README → render produces expected output diff.
5. (Phase 3b) `check-plugin-maturity-drift.sh` advisory detector emits zero drift signal on clean fixture, one drift signal per drifted plugin on drift fixture. Exit code 0 always.
6. (Phase 3c) Per-plugin bats asserts `plugin.json` carries `maturity:` field per top-level entry; asserts rollup shape; asserts rollup band equals worst-case among constituents; asserts README prose-woven rollup matches canonical record.
7. (Phase 3c) `wr-itil-plugin-maturity-list` shim emits NDJSON one record per surface + one rollup record per plugin; `schema_version: "1.0"` on every record; exit code 0 always.
8. (Phase 3c) No-network-primitive bats assertion on `plugin-maturity-list.sh` + `plugin-maturity-populate.sh` + `plugin-maturity-render.sh` (negative-grep for `curl|wget|nc |fetch|http\.client|urllib`).
9. (Phase 3c) Schema-version contract: NDJSON output schema and `plugin.json` maturity record schema both equal `"1.0"`. Additive-only schema evolution per ADR-058 §Confirmation #8.
10. **Granularity contract** (binding): each top-level entry in a plugin's `plugin.json` (skill, agent, hook, command, sub-skill) carries its own `maturity:` field; the plugin root carries a rollup `maturity:` field whose value equals the worst-case band among constituent surfaces (Experimental ≻ Alpha ≻ Beta ≻ Stable; Deprecated is a separate axis overlay per ADR-053 §granularity contract).
11. **Anti-pattern check** (Phase 3c bats): asserts the README does NOT contain a standalone `## Maturity` section heading; asserts no shields.io URL in the README; asserts no compound bootstrapping rendering in per-skill table cells (compound stays at rollup).

### Granularity contract (binding)

Identical to ADR-053 §granularity contract; restated here for reader convenience without rewriting the canonical source. Each top-level entry in a plugin's `plugin.json` carries its own `maturity:` field. The plugin root entry carries a rollup `maturity:` field whose value equals the worst-case band across constituent surfaces. A plugin with no shipped surfaces carries no plugin-level `maturity:` field. Deprecated entries are elided from the rollup computation but retained on individual surface entries (a plugin whose only surfaces are Deprecated is itself Deprecated; otherwise Deprecated entries do not propagate to the rollup).

## Consequences

- **Positive (JTBD-302 served)**: adopters see the maturity band at the top of every plugin README via prose-woven rollup; AI agents reading `cat packages/<plugin>/README.md` expand maturity-aware context before forming a trust model. JTBD-302's Phase-3-reactivation point lands here.
- **Positive (JTBD-201 served)**: rich-record `evidence:` block in `plugin.json` provides durable audit-trail per surface; tech-lead auditing why `mitigate-incident` is Experimental sees the evidence inline at the canonical record without re-running Phase 2 NDJSON.
- **Positive (JTBD-101 two-surface served)**: plugin-developer persona's hardening-prioritisation outcome is served by Phase 2 NDJSON (dev-console surface); plugin-user persona's adoption-decision outcome is served by Phase 3 README badge + `plugin.json` (install / compose surface). Two surfaces, two audiences, two reading times.
- **Positive (JTBD-003 served)**: per-skill `Maturity` column in `## Skills` tables gives composers per-surface granularity at the natural reading surface without overloading the table.
- **Positive (JTBD-007 served)**: Phase 3b drift detector composes with ADR-069's inventory-currency commit-hook drift detector (narrowed from ADR-051's JTBD-ID anchor) — third currency axis (code-currency, README-content-currency, maturity-band-currency). Same detector pattern, different anchor.
- **Positive (multi-surface enforcement per Apache Incubating lesson)**: band rendered in BOTH `plugin.json` AND README — single-surface ignorance failure mode defeated.
- **Positive (machine + human readable per PEP 411 lesson)**: `plugin.json` is machine-parseable; README badge is human-readable; neither audience denied.
- **Positive (offline-resilient per shields.io trade-off avoidance)**: markdown text badge has zero external dependency; offline-render is identical to online-render; no shields.io uptime / cache-stale / offline-broken concerns.
- **Positive (`wr-itil-plugin-maturity-list` ships as in-suite display)**: adopters have a machine-readable rollup view across installed plugins without waiting on upstream Claude Code support. NDJSON shape is the forward-extension contract.
- **Positive (precedent established)**: ADR-053 → ADR-058 → ADR-063 is the third "Phase 1 contract; Phase 2 measurement; Phase 3 presentation" cluster (after ADR-051's JTBD anchoring — now superseded by ADR-069 — + ADR-052's behavioural-tests-default). The pattern is repeatable; future contributors authoring similar cluster ADRs have a template.
- **Negative (Phase 3 sub-iters still pending)**: ADR-063 ships only the contract. Adopter-visible Phase 3 outcomes (rendered badges, populated `plugin.json` fields, drift detector) land in Phase 3a / 3b / 3c sibling tickets. P087 stays Known Error until Phase 3c lands.
- **Negative (per-surface plugin.json shape grows)**: each top-level entry in every plugin's `plugin.json` grows by one nested object (`maturity: {schema_version, band, computed_at, evidence: {...}}`). Across 50+ surfaces this is non-trivial JSON volume. Mitigation: the audit-trail value is durable; the schema is additive-only within `schema_version: "1.0"`; the rich-record is precedent-aligned with VS Code's `preview` boolean evolution path (vscode#162651 documents the freshness-bug the rich record prevents).
- **Negative (drift potential across two rendered surfaces)**: README prose-woven rollup can drift from `plugin.json` canonical record; per-skill table cells can drift from per-surface `plugin.json` records. Mitigated by Phase 3b drift detector (advisory-first per ADR-013 Rule 6); escalation to release-blocking gate is ADR-057 Phase 3 (deferred per ADR-058 §Phase 4+ N=3, M=5).
- **Negative (marketplace.json defer leaves a gap)**: adopters discovering plugins via `/plugin browse` do not see maturity until they install the plugin and read the README. Mitigated by the in-suite `wr-itil-plugin-maturity-list` shim post-install. Reassessment trigger: if upstream Claude Code begins surfacing maturity-like fields in `/plugin browse`, extend marketplace.json.
- **Negative (`claude plugin list` defer leaves a rollup gap)**: adopters running `claude plugin list` do not see maturity in the default output. Mitigated by `wr-itil-plugin-maturity-list` shim. Reassessment trigger: upstream Claude Code per-plugin metadata field support.
- **Negative (Phase 3a script complexity)**: the band-mapping logic must implement ADR-053 §promotion criteria steady-state thresholds + §Bootstrapping clause interim rule + sunset-date conditional logic + per-category override hook (ADR-058 §Script contracts). Non-trivial; bats coverage must exercise all transition points.
- **Neutral (composition with the prose-weaving precedent)**: ADR-063's prose-weaving placement is the natural extension of the pattern ADR-069 carries forward from superseded ADR-051. The two ADRs ship to the same README header region (value-framing lead prose) on orthogonal axes (JTBD-derived value framing vs maturity badge). Adopters who only consume one ADR's signal still get value from each independently.
- **Neutral (Bootstrapping clause sunset)**: anticipated 2026-06-06 per ADR-053 §Bootstrapping clause. Phase 3a script must check the sunset date on every recompute; the compound rendering automatically simplifies post-sunset without ADR amendment.

## More Information

- **P087** — `docs/problems/known-error/087-no-maturity-signal-for-plugin-features.md` — driver ticket. Investigation Task line 128 names the presentation-layer scope gap this ADR fills.
- **ADR-053** — `docs/decisions/053-plugin-maturity-taxonomy.proposed.md` — Phase 1 contract. ADR-063 implements ADR-053 §Decision Outcome §"Chosen signal location" + §Bootstrapping clause §Phase 3 rendering requirement.
- **ADR-058** — `docs/decisions/058-plugin-maturity-measurement-mechanism.proposed.md` — Phase 2 contract. ADR-063 consumes Phase 2 NDJSON via Phase 3a writer; ADR-063 §schema_version follows ADR-058 §Confirmation #8 precedent; ADR-063 in-suite shim ships under same `packages/itil/bin/` location.
- **ADR-051** — `docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.superseded.md` — superseded by ADR-069. Originated the prose-weaving anti-pattern (rejects bolt-on tail sections) and the JTBD-ID commit-hook drift detector; both are carried forward by ADR-069 (prose-weaving live; hook narrowed to skill-inventory-drift).
- **ADR-069** — `docs/decisions/069-readme-markets-persona-problem-not-jtbd-id.proposed.md` — current home of the prose-weaving anti-pattern ADR-063 follows. Phase 3b drift detector is sibling to ADR-069's inventory-currency `check-readme-jtbd-currency.sh`.
- **ADR-057** — `docs/decisions/057-three-phase-declarative-first-cluster-rollout.proposed.md` — meta-shape. ADR-063 is the Phase 3 of the P087 cluster (ADR-053 / ADR-058 / ADR-063). **NOT to be conflated with ADR-057's own Phase 3** (R6-gated escalation gate), which remains deferred per ADR-058 §Phase 4+ escalation gate criterion.
- **ADR-049** — `docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md` — `wr-<plugin>-<kebab-name>` shim grammar binding `wr-itil-plugin-maturity-list` + `wr-itil-plugin-maturity-populate` + (renderer canonical script under scripts/).
- **ADR-013 Rule 6** — `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` — fail-safe posture. Phase 3b drift detector advisory-first, exit-0-always.
- **ADR-040** — declarative-first-then-enforce precedent. ADR-063 ships the presentation-layer contract; Phase 3b's advisory detector composes with the declarative-first pattern.
- **ADR-044** — `docs/decisions/044-decision-delegation-contract.proposed.md` — silent-framework-action carve-out for Phase 3a band recomputation. Scope-limited per Decision Outcome §"ADR-044 silent-framework carve-out".
- **ADR-052** — `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md` — Phase 3c bats coverage reads `plugin.json` + asserts shape behaviourally.
- **ADR-023** — `docs/decisions/023-wr-architect-performance-review-scope.proposed.md` — Decision Outcome template. ADR-063 inherits ADR-058's performance contract (transcript-axis 4.04s; git-axis 0.39s); no new runtime path introduced.
- **ADR-026** — agent output grounding. Ecosystem prior-art survey above cites per ADR-026; the Decision Drivers explicitly cite Apache Incubating + PEP 411 + Linux CONFIG_EXPERIMENTAL + VS Code preview + shields.io trade-offs as load-bearing inputs.
- **ADR-002** — monorepo per-plugin packages boundary. ADR-063 marketplace.json defer per ADR-002 (adding maturity to marketplace.json would duplicate canonical `plugin.json` record).
- **ADR-003** — marketplace-only distribution. `wr-itil-plugin-maturity-list` shim reads from marketplace-cached `plugin.json` path per ADR-003.
- **ADR-010** — skill-naming + deprecation-window. `supersededBy:` pointer on Deprecated band entries follows ADR-010 precedent.
- **ADR-014** — granular commits. ADR-063 lands as one commit; Phase 3a / 3b / 3c land as separate sibling commits under follow-on tickets.
- **ADR-021** — changesets for releases. ADR-063 ships under `@windyroad/itil` (and possibly `@windyroad/retrospective` for the drift detector when Phase 3b lands) minor bumps.
- **JTBD-302** — `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md` — primary driver; Phase-3-reactivation surface lands here. Amendment queued in Phase 3 follow-on (see below).
- **JTBD-101** — `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` — composition driver; two-surface-two-audience split. ADR-053 §Confirmation #4 "promotion criteria visible to contributors" outcome amendment queued in Phase 3 follow-on.
- **JTBD-007** — `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md` — currency-pressure composition. Maturity-band-currency-axis amendment queued in Phase 3 follow-on.
- **JTBD-003** — `docs/jtbd/solo-developer/JTBD-003-compose-guardrails.proposed.md` — composition driver. At-glance-stability outcome amendment queued in Phase 3 follow-on.
- **JTBD-201** — `docs/jtbd/tech-lead/JTBD-201-restore-service-fast.proposed.md` — composition driver; rich-record `evidence:` block serves the existing audit-trail outcomes without amendment.

### JTBD outcome amendments queued for Phase 3 follow-on

Per JTBD review (g): four JTBD outcome amendments are warranted by ADR-063's Phase 3 reactivation. Captured as scoped Phase 3 follow-on work (likely Phase 3b commit or separate JTBD-amendment commit):

1. **JTBD-302** — add desired-outcome bullet covering maturity-band visibility: *"(Amended in P087 Phase 3) I can see the maturity band (and, during the suite-bootstrap window, the compound evidence per ADR-053 §Bootstrapping clause Phase 3 rendering requirement) for every plugin and every per-skill surface from the README alone, without source archaeology under `node_modules/` and without invoking measurement scripts."* Cite ADR-053 + ADR-058 + ADR-063 as drivers.
2. **JTBD-007** — extend currency framing: add a sentence to the currency-tracks-code-currency bullet noting that maturity-band currency (recomputed by Phase 3a writer per ADR-044 silent-framework carve-out) is a third dimension of the same currency concern (code, README-content, maturity-band).
3. **JTBD-101** — extend hardening-prioritisation framing: add a desired-outcome bullet covering "promotion criteria are documented so contributors know the bar to clear when authoring a new skill or splitting an existing one" — this was deferred in ADR-053 §Confirmation #4 as a Phase 3 follow-up; Phase 3 is the trigger to land it.
4. **JTBD-003** — add desired-outcome bullet covering at-glance stability awareness: *"I can see at glance which surfaces in a plugin are stable enough to depend on without invoking measurement scripts."* Currently JTBD-003 has no maturity-aware outcome.

### Reassessment Triggers

This ADR is reassessed when ANY of the following occur:

- **Upstream Claude Code ships per-plugin maturity-like fields in `/plugin browse` UI**: extend `marketplace.json` to surface the maturity rollup in the browse UI before install; reassess Option F7 defer.
- **Upstream Claude Code ships per-plugin metadata field support in `claude plugin list` default output**: reassess Option F8 defer; consider deprecating `wr-itil-plugin-maturity-list` shim in favour of upstream rendering (or keeping the shim as a richer-output alternative).
- **Phase 3a population script's idempotency invariant breaks**: e.g. floating-point comparison in evidence record produces non-deterministic writes; revisit the rich-record schema (possibly round numeric values; possibly elide volatile sub-fields from the diff comparison).
- **Phase 3b drift detector accumulates persistent unfixed drift across N≥3 releases AND M≥5 surfaces drifted per ADR-058 §Phase 4+ escalation gate**: trigger the (still-deferred) ADR-057 Phase 3 R6-gated load-bearing escalation. Open a separate ADR to author the escalation gate at that time.
- **Bootstrapping clause sunset fires (anticipated 2026-06-06 per ADR-053 §Bootstrapping clause)**: verify Phase 3a script handles the sunset transition correctly; verify the compound rendering simplifies to band-only post-sunset; verify no `plugin.json` `maturity:` records carry stale bootstrapping-window evidence post-sunset.
- **The prose-weaving rendering proves brittle in practice** (e.g. plugin authors restructure value-framing prose in ways that break the renderer's anchor): reassess whether the renderer should accept structured anchors (HTML comment delimiters? markdown extensions?) or whether the prose-weaving should be hand-authored with the Phase 3b advisory drift detector catching divergence.
- **A second cluster of cross-cutting plugin-suite-observability presentation work emerges**: promote presentation-layer concerns into a new dedicated plugin / ADR family if the maturity surface ends up co-evolving with licence / vulnerability / dependency-currency surfaces.
- **Reassessment date 2026-11-17** — six-month review per the standard ADR cadence; verify the Phase 3 contract is still load-bearing after Phase 3a / 3b / 3c have shipped.
