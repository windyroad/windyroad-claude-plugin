# Problem 137: Plugin-published artifacts (SKILL.md, hooks, agents) reference internal ADR/JTBD/P-IDs that adopter projects can't resolve — confuses and misleads adopter agents

**Status**: Verification Pending
**Reported**: 2026-04-28
**Priority**: 20 (Very High) — Impact: Significant (4) x Likelihood: Almost certain (5)
**Effort**: XL — cross-package audit + structural-decision ADR + mechanical replacement across all `@windyroad/*` plugins (SKILL.md files, hook scripts, agent definitions, README badges, all reference ADR-NNN / JTBD-NNN / P-NNN heavily). Requires net-new ADR codifying the resolution strategy (strip / replace-with-prose / permalink / namespace-prefix) before mechanical work can begin.

**WSJF**: (20 × 1.0) / 8 = **2.5**

> Surfaced 2026-04-28 by user during a `/wr-itil:work-problems` AFK loop: *"create a problem ticket for the plugin code and published artifacts referenceing ADRs by ID, that plugin users will not have access to. This is a big issue because they may have their own ADRs and these references could very easily confuse and mislead agents."* Every published `@windyroad/*` plugin ships SKILL.md / hook / agent files dense with `ADR-NNN` / `JTBD-NNN` / `P-NNN` references that resolve correctly only in the windyroad-claude-plugin source repo. In adopter projects those IDs either do not resolve (best case — agent ignores) or resolve to UNRELATED decisions in the adopter's own `docs/decisions/` (worst case — agent applies wrong semantics).

## Description

Every plugin in this monorepo ships source artifacts to npm that downstream adopter projects install via Claude Code's plugin marketplace mechanism. The shipped artifacts include:

- **SKILL.md files** — every skill's prose body cites internal decisions extensively. Examples from this very session: `manage-problem` SKILL.md cites `ADR-013`, `ADR-014`, `ADR-022`, `ADR-032`, `ADR-038`, `ADR-042`, `P035`, `P036`, `P040`, `P057`, `P062`, `P063`, `P076`, `P083`, `P084`, `P094`, `P109`, `P118`, `P119`, `P122`, `P124`, `P126`, `JTBD-001`, `JTBD-006`, `JTBD-101`, `JTBD-201` — and that is one skill among dozens.
- **Hook scripts** — shell scripts under `packages/*/hooks/` reference ADRs and P-tickets in their docstrings, deny-message bodies, and inline comments.
- **Agent definitions** — agent persona files cite ADRs as the basis for their delegation rules.
- **Plugin READMEs** — package-level READMEs link "see ADR-NNN for rationale" patterns.
- **Changeset bodies and CHANGELOG entries** — once published to npm, every `chore: version packages` commit body and resulting CHANGELOG.md cite ADRs / P-IDs.

These IDs are scoped to **this project's** `docs/decisions/` (ADR-NNN), `docs/jtbd/` (JTBD-NNN), and `docs/problems/` (P-NNN) trees. Adopter projects that install `@windyroad/itil` or any sibling plugin do NOT have access to those trees. The shipped SKILL.md / hooks / agents that the adopter's Claude Code session reads are full of dangling references.

**Failure modes** (in increasing severity):

1. **Adopter agent ignores the reference** — best case. The agent reads "per ADR-014" but cannot resolve ADR-014 in adopter's project; treats it as opaque token; proceeds with whatever context it can derive from surrounding prose. Workflow continues but the agent operates with reduced contextual understanding of WHY the SKILL.md prescribes what it does.
2. **Adopter agent searches and surfaces "ADR not found"** — agent attempts to follow the reference (`Read docs/decisions/014-*.md` or `Glob docs/decisions/`), finds nothing, may surface a "missing decision" warning to the user, may halt or de-rank a step that depended on the cross-reference.
3. **Adopter agent resolves to UNRELATED ADR-014 in adopter's own tree** — most dangerous. The adopter project may have its own `docs/decisions/014-something-completely-different.proposed.md`. Agent reads the wrong ADR and applies its semantics to the windyroad SKILL.md context. The agent's behavior is now confidently wrong, anchored on a misleading decision document.

The user's words capture the core risk: *"these references could very easily confuse and mislead agents."*

## Symptoms

- Every shipped SKILL.md carries dozens of `ADR-NNN` / `JTBD-NNN` / `P-NNN` tokens. Spot-check: `manage-problem` SKILL.md (the skill the user invoked to capture THIS ticket) contains 14 distinct ADR references, 11 distinct P-references, and 4 distinct JTBD-references in its prose body — every one of which is dangling in any adopter project.
- Every shipped hook script under `packages/*/hooks/` carries inline comments and deny-message bodies citing ADRs/P-tickets.
- Every shipped agent definition under `packages/*/agents/` cites ADRs as the basis for its delegation contract.
- CHANGELOG.md entries (which ship to npm and surface in adopter `node_modules/`) cite ADRs/P-IDs for every release.
- The npm package's tarball preserves all of the above — there is no build step that strips or rewrites these references on publish.
- An adopter session running `/wr-itil:manage-problem` would have the SKILL.md text expanded into the adopter's agent context. The adopter's agent sees `"per ADR-014"` and has three failure modes (above) to choose between. None are good.

## Workaround

None at the source level — the artefacts ship as-authored. Adopter-side workarounds:

- Adopter could maintain a manual "windyroad-internal IDs are not my IDs — ignore them" mental model for its agent. Brittle, not enforceable.
- Adopter could clone windyroad-claude-plugin as a sibling submodule so the references resolve. Heavyweight, defeats the plugin model.
- Adopter could namespace-prefix its own ADRs (`PROJECT-ADR-014` instead of `ADR-014`) to avoid collisions. Solves the "wrong-resolution" failure but doesn't help with "reference is dangling". Also requires the adopter to rename their entire decisions directory, which is invasive.

None of these are reasonable. The fix has to be at the source — the published artifacts must not surface references the adopter cannot resolve.

## Impact Assessment

- **Who is affected**: The **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — explicitly defined as "Low context on repo internals; Claude Code as the likely entry point; many plugin-users are themselves using AI agents". Every adopter project that installs any `@windyroad/*` plugin. As of 2026-04-28: 11 plugins on npm (`itil`, `architect`, `jtbd`, `retrospective`, `risk-scorer`, `style-guide`, `voice-tone`, `tdd`, `c4`, `wardley`, `connect`). Every adopter Claude Code session that surfaces a windyroad SKILL.md or runs a windyroad hook is exposed. Plugin-user's persona constraints ("low context on repo internals" + "AI agent as their primary interface") are *verbatim* the conditions that turn dangling references into failure modes 2 and 3.
- **Frequency**: Every session in every adopter project, every time a shipped SKILL.md is loaded into agent context, every time a hook fires with an ADR-citing deny-message body. Effectively **every** adopter agent invocation of a windyroad-shipped artefact.
- **Severity**: Significant — installed plugins degrade adopter developer workflow per RISK-POLICY Impact-4 verbatim ("hooks fire incorrectly, skills fail to load"). The "fire incorrectly" branch is the relevant one here: the hook fires correctly mechanically but its deny-message points at decisions the adopter cannot read, so the deny-message's rationale is opaque or worse, misleading.
- **Likelihood**: Almost certain — known gap, no controls in place, every shipped file has these references. Matches RISK-POLICY Likelihood-5 verbatim ("Known gap, no controls in place, or previously observed failure mode").
- **Analytics**: 2026-04-28 session evidence: this very iter chain (P124 + P096 + P064) generated commits + CHANGELOG entries citing internal ADRs. The `@windyroad/itil@0.21.2` release published this morning (2026-04-28) carries "ADR-045", "P096 Phase 3", "P124 Phase 2", "P062", "P094" references in its CHANGELOG.md and surrounding commit messages — all of which are now on npm and will surface in every adopter `npm install` of that version.
- **Concrete user-cited evidence (2026-04-28)**: the user selected line 8 of `.changeset/wr-itil-p124-phase-2-zsh-portability.md`: *"per ADR-037 + P081"*. That changeset was consumed by the release process and its content was inlined into `packages/itil/CHANGELOG.md` at lines 11, 164, and 246 — three distinct CHANGELOG entries each carrying the bare token *"per ADR-037 + P081"*. All three are now on npm in `@windyroad/itil@0.21.2`. An adopter installing this version sees "per ADR-037 + P081" in their `node_modules/@windyroad/itil/CHANGELOG.md` with no way to resolve either reference — ADR-037 doesn't exist in their `docs/decisions/` (or worse, exists but means something different); P081 doesn't exist in their `docs/problems/` (or worse, exists but means something different). The bare prose offers zero context for what either ID stands for. This is **Failure Mode 1 minimum** (adopter agent ignores the reference and treats it as opaque) up to **Failure Mode 3 maximum** (adopter agent resolves to UNRELATED ADR-037 / P081 in the adopter's own tree and applies wrong semantics) — the failure mode is non-deterministic from the source's perspective.

## Root Cause Analysis

### Investigation Tasks

- [ ] **Audit the reference surface**: enumerate every `ADR-NNN` / `JTBD-NNN` / `P-NNN` reference across all `packages/*/` shipped artefacts (SKILL.md, hooks, agents, scripts, README, CHANGELOG). Likely tooling: `grep -rE '\b(ADR|JTBD|P)-?[0-9]+\b' packages/*/ | wc -l` for the gross count; deeper categorisation (deny-message vs prose vs comment) for the strategy decision.
- [ ] **Decide the resolution strategy** — needs an ADR. Candidate options:
  - Option A — **Strip all references**: rewrite every `"per ADR-NNN"` as `"per [policy on X]"` with a self-contained one-line summary inline. Largest mechanical effort; most adopter-friendly result.
  - Option B — **Replace with permalinks**: rewrite every `"per ADR-NNN"` as `"per [policy on X](https://github.com/windyroad/agent-plugins/blob/main/docs/decisions/NNN-...)"`. Mechanical fix; adopter agents can follow the link if curious. Requires permalink stability (releases must not break links).
  - Option C — **Namespace-prefix**: rewrite every `ADR-NNN` as `WR-ADR-NNN` (windyroad-prefixed). Disambiguates from adopter ADRs but doesn't help adopter agents resolve the reference. Smallest mechanical effort; weakest fix.
  - Option D — **Disclaim at SKILL.md top**: add a one-paragraph disclaimer at the top of every shipped SKILL.md / agent / hook body that "internal ADR/JTBD/P-IDs reference windyroad-claude-plugin source decisions; adopter projects can find them at https://github.com/windyroad/agent-plugins/...". Smallest effort; adopter agent has to read the disclaimer every time and keep it in working memory. Brittle.
  - Option E — **Build-step rewrite**: introduce a publish-time post-processor that converts internal IDs to permalinks (Option B mechanically applied at publish, source stays human-readable). Highest implementation cost, but keeps source readable for windyroad maintainers and adopter-friendly for end-users. Requires changesets workflow integration.
- [ ] **Run the architect on the strategy decision** — this is an ADR-level decision (multiple tradeoffs, cross-package implications, build-pipeline impact). The ADR should be created BEFORE any mechanical replacement work begins.
- [ ] **Carve out per-plugin slices** — once the strategy is decided, split the mechanical work into per-plugin sub-tickets so each can ship as a separate `@windyroad/<plugin>@x.y.z` release. The whole-monorepo audit + replacement is XL; per-plugin slices are L or M.
- [ ] **Behavioural test**: bats fixture that loads a SKILL.md and asserts no dangling `ADR-NNN` / `JTBD-NNN` / `P-NNN` token survives the chosen strategy's rewrite (or in Option D, asserts the disclaimer is present at file head).
- [ ] **Document the convention** in CONTRIBUTING.md so future contributors don't reintroduce dangling references.

### Preliminary hypothesis

The reference convention was authored under a single-repo monorepo mental model where every contributor reads from the same `docs/decisions/` tree. The plugin-distribution mental model (publish to npm, install in adopter projects) was added later via the `@windyroad/*` package shape, but the SKILL.md / hook / agent reference style was never adapted.

This is a **convention gap**, not a bug — every individual reference is correct in isolation. The aggregate effect (a published artefact dense with dangling IDs) only becomes visible when you imagine the adopter's agent loading the file. The maintainer experience (reading SKILL.md alongside `docs/decisions/`) hides the failure mode.

The convention gap also extends to:
- Commit messages (visible in adopter `git log` of `node_modules/<package>`)
- CHANGELOG.md (visible in adopter's installed package directory, surfaces in `npm view`)
- Changeset bodies (which become CHANGELOG.md content)

A complete fix touches all of these surfaces, not just the SKILL.md surface.

## Fix Strategy

**Phase 1 — Strategy ADR** (small; gates Phases 2+):

- New ADR codifying the resolution strategy. Architect-led decision: read the audit output, weigh the tradeoffs from Options A–E above, propose the chosen strategy with explicit rejection criteria for the others.
- Output: `docs/decisions/NNN-plugin-published-id-references.proposed.md`. Block all Phases 2+ until this ADR is `proposed` (does not need to be `accepted` — the proposed status is enough to ground mechanical work).

**Phase 2 — Audit** (small; cross-cuts, single tool run):

- Run the audit script and produce a structured inventory: per-file count + categorisation (deny-message vs prose vs CHANGELOG vs comment vs README).
- Land the inventory as `docs/<inventory-name>.md` so per-plugin slices can use it as a worklist.

**Phase 3 — Per-plugin mechanical sweep** (one sub-ticket per plugin, M or L each):

- Carve out as separate problem tickets (one per `@windyroad/*` plugin). Each sub-ticket:
  1. Reads the audit inventory
  2. Applies the strategy decision from Phase 1's ADR
  3. Updates SKILL.md / hooks / agents / README in that plugin
  4. Adds bats coverage asserting no dangling references survive
  5. Ships as a `@windyroad/<plugin>@x.y.z` release with the rewrite

**Phase 4 — Convention guardrail** (small):

- Add a CONTRIBUTING.md section codifying the convention so future contributions don't re-introduce dangling references.
- Optional: add a CI lint that flags new dangling references in PRs (mirror the bats coverage from Phase 3 at the PR-level).

**Phase 5 — Backfill historical CHANGELOGs** (M, optional):

- Decide whether to rewrite historical CHANGELOG.md entries at npm publish-time (via Option E build-step) or accept that already-published versions carry dangling references. If the build-step is adopted, future releases auto-rewrite; historical versions stay as-is.

**Out of scope**:
- Renaming the windyroad source-side IDs themselves (the IDs work fine inside this repo's mental model). Phase 1's ADR addresses only the *published-artefact* surface.
- Adopter-side detection logic (e.g., a hook that scans incoming SKILL.md for dangling references). Adopters can adopt this as a custom guardrail if they want; it's not the source's responsibility.

## Dependencies

- **Blocks**: (none yet — the ADR/audit/per-plugin slices will be carved out as new tickets that link back here)
- **Blocked by**: (none — Phase 1 strategy ADR can proceed standalone; the strategy choice gates Phases 2+)
- **Composes with**: P082 (no voice-and-tone or content-risk-scoring gate on commit messages — same surface concern, different angle: P082 is about commit message AUTHORING discipline, P137 is about ID-reference SEMANTIC correctness in shipped commit messages), P064 (no risk-scoring gate on external comms — same external-surface concern, different scoring axis), P135 (decision-delegation contract — about ADR-013 over-application, tangentially related ADR-discipline space), P136 (ADR-044 alignment audit — sibling cross-package audit pattern, different rule), P097 (SKILL.md mixes runtime steps with maintainer-facing rationale — the maintainer-rationale dimension overlaps; both Phase 1's ADR and P097's eventual fix should coordinate so we don't rewrite the same SKILL.md prose twice).

## Related

- **P082** (`docs/problems/082-no-voice-tone-or-risk-gate-on-commit-messages.open.md`) — adjacent surface: commit messages ship to adopter `git log` and inherit the same dangling-reference failure mode for any `P-NNN` / `ADR-NNN` they cite. P137's Phase 5 should consider whether commit-message rewriting falls in P137's scope or P082's.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.known-error.md`) — adjacent surface: outbound communications (npm CHANGELOG, GitHub Release notes) inherit the same failure mode. P137's Phase 5 should compose with P064's outbound-comms gate work.
- **P097** (`docs/problems/097-skill-md-runtime-size-mixes-policy-with-runtime-steps.open.md`) — direct overlap on SKILL.md surface. Both tickets target SKILL.md content but at different cuts (P097: split runtime/maintainer prose; P137: rewrite IDs in whatever prose remains). Sequence matters — pick one to land first; the second's rewrite incorporates the first's structure.
- **P135** (`docs/problems/135-decision-delegation-contract-master.open.md`) — meta-relationship: P135 is about agent over-application of ADR-013 Rule 1 to framework-resolved decisions. Both tickets touch ADR-discipline. Not blocking either way.
- **P136** (`docs/problems/136-adr-044-alignment-audit-master-ticket.open.md`) — sibling pattern: cross-package audit + per-plugin sweep shape. P137's Phase 2 audit script can mirror P136's audit tooling.
- **P099** (`docs/problems/099-briefing-md-grows-unbounded-via-run-retro-appends-violating-progressive-disclosure.verifying.md`), **P134** (`docs/problems/134-...open.md`) — adjacent accumulator-bloat surface. Different concern but shares the "shipped artefact misbehaves outside its source context" frame.
- **P055** (`docs/problems/055-no-standard-problem-reporting-channel.closed.md`), **P065** (`docs/problems/065-no-skill-scaffolds-intake-files-in-downstream-projects.verifying.md`), **P100** (`docs/problems/100-plugins-do-not-auto-surface-their-artifacts-forcing-manual-claude-md-pointers.closed.md`) — adopter-experience surface tickets. P137 is the "internal references leak to adopter context" sibling in this family.
- **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — **primary persona affected** (per JTBD review 2026-04-28). The persona's documented constraints — "Low context on repo internals" + "Claude Code as the likely entry point" + "many plugin-users are themselves using AI agents" — match P137's failure modes 2 and 3 verbatim. The adopter IS the plugin-user by definition (they are consuming, not authoring).
- **JTBD gap flagged** — the plugin-user persona currently has only **JTBD-301** (`docs/jtbd/plugin-user/JTBD-301-report-problem-without-pre-classifying.proposed.md`, "Report a Problem Without Pre-Classifying It"), which covers the *reporting* surface but NOT the *artefact-trust* surface that P137 exposes. There is no documented JTBD covering "trust that installed plugin artefacts resolve cleanly in my project context". Phase 1's strategy ADR MUST coordinate with adding a sibling JTBD under plugin-user persona (provisional title: *"Trust That Installed Plugin Artefacts Resolve Cleanly In My Project Context"*) before mechanical work begins, OR P137 itself can spawn the JTBD as a Phase 1 deliverable. Either path is acceptable; the gap must be closed before Phases 2+.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`, "Extend the Suite with New Plugins") — **secondary persona served**: plugin-developer is the *cause-side* persona (the one authoring the dangling references). Phase 4's CONTRIBUTING.md guardrail directly serves JTBD-101 by codifying the convention so future contributors don't re-introduce dangling references. The convention guardrail's value lands on plugin-developer's "extend the suite without regressing existing reliability" outcome.
- ~~JTBD-001~~ (`docs/jtbd/solo-developer/JTBD-001-enforce-governance-without-slowing-down.proposed.md`) — **NOT a fit** (per JTBD review 2026-04-28). JTBD-001 is about automatic policy enforcement on edits in <60s — its desired outcomes ("every edit reviewed against policy", "no manual step") don't match P137's failure mode (adopter agents loading SKILL.md and resolving dangling `ADR-014`). Conflating "solo-developer adopting a plugin" with "plugin-user persona" silently merges two distinct personas; the adopter is plugin-user by definition.
- 2026-04-28 session: surfaced by user mid-`/wr-itil:work-problems` iter 3; orchestrator's main-turn captured per ADR-013 Rule 1 (interactive surface).

## Fix Released — Phase 1 (2026-05-03 iter 17)

Phase 1 of the namespace-prefixed-permalinks strategy shipped via `@windyroad/retrospective` minor bump (changeset `p137-internal-id-leak-advisory`). Concretely:

- **ADR-055** (`docs/decisions/055-plugin-published-namespace-prefixed-internal-ids.proposed.md`) — codifies the resolution strategy. Adopt **Option C (namespace-prefix `WR-ADR-NNN` / `WR-JTBD-NNN` / `WR-PNNN`) as the structural rule** with **Option B (GitHub permalinks) as progressive enhancement**. Rejects Option A (strip — lossy), Option D (disclaimer — brittle), Option E (build-step — premature). Completes the 6-ADR adopter-context cluster (ADR-049/051/052/053/054/055) unified by JTBD-302's "trust adopter-facing artefacts" frame.

- **Advisory detector** — `packages/retrospective/scripts/check-internal-id-leaks.sh`. Diagnose-only, silent-on-pass per ADR-045. Walks `packages/<plugin>/skills/<skill>/SKILL.md`, `packages/<plugin>/agents/*.md`, `packages/<plugin>/hooks/*.sh`, `packages/<plugin>/CHANGELOG.md`. Reports `OVER <plugin>/<file> bare_count=<N>` lines + `TOTAL packages=<N> with_leaks=<M> drift_instances=<K>` summary. Exit 0 always (advisory only). Excludes REFERENCE.md siblings (per ADR-054) and `# @adr|@jtbd|@problem` docstring annotation lines.

- **Bin shim** — `packages/retrospective/bin/wr-retrospective-check-internal-id-leaks` per ADR-049 grammar.

- **Behavioural bats fixture** — `packages/retrospective/scripts/test/check-internal-id-leaks.bats` per ADR-052 default. 23 tests, all GREEN. Asserts script *output* on temp-fixture trees, never script source content. Coverage: bare-ID detection across all 4 surfaces, WR-prefix exclusion, docstring-annotation exclusion, REFERENCE.md exclusion, deterministic ordering, count accuracy, TOTAL summary aggregation, error path.

- **Baseline measurement** (2026-05-03): `TOTAL packages=13 with_leaks=81 drift_instances=2880`. This is the reassessment-anchor count for Phase 2 opportunistic sweep progress.

**What's deferred (Phase 2)**:

- Mechanical sweep across 2,880 drift instances proceeds opportunistically per ADR-052 migration shape — no big-bang rewrite. When any SKILL.md / agent / hook / CHANGELOG entry is touched for any other reason, the touching change includes the WR-prefix for any internal IDs in the diff.

- Per-plugin slices may be carved out as separate problem tickets if/when an adopter incident forces prioritisation.

- Promotion to blocking PreToolUse hook (Phase 3) when `drift_instances ≤ 100` and three consecutive monthly retros confirm no regression.

**What's verifiable now**:

- The detector runs against the live repo and returns `TOTAL packages=13 with_leaks=81 drift_instances=2880` — the baseline matches the ADR's recorded value.
- The detector runs against a clean fixture tree (the bats `setup`) and returns no output, confirming silent-on-pass.
- ADR-055 codifies the rule, the rejection criteria for Options A/D/E, and the reassessment criteria. Architect + JTBD reviews PASSED.

**Verification path for the user**: read ADR-055, run `packages/retrospective/scripts/check-internal-id-leaks.sh .` from the repo root, confirm baseline output matches the ADR-recorded `drift_instances=2880`, confirm the bats fixture passes (`node_modules/.bin/bats packages/retrospective/scripts/test/check-internal-id-leaks.bats`).

**Composes with**: ADR-049 (executable correctness — sibling `bin/`-on-PATH ADR), ADR-051 (currency — sibling JTBD-anchored README ADR), ADR-052 (test-discipline — sibling behavioural-tests-default ADR), ADR-053 (battle-hardening — sibling maturity-taxonomy ADR), ADR-054 (size — sibling SKILL.md runtime budget ADR). Six ADRs forming the adopter-context cluster, all anchored on JTBD-302's plugin-user persona.
