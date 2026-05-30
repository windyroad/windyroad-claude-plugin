---
status: "proposed"
date: 2026-05-03
human-oversight: rejected-pending-supersede
supersede-ticket: P298
oversight-date: 2026-05-26
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-11-03
---

# Plugin-published artefacts use namespace-prefixed permalinks for internal IDs

## Context and Problem Statement

Every `@windyroad/*` plugin ships SKILL.md / agent / hook / CHANGELOG content to npm dense with internal cross-references — `ADR-014`, `JTBD-101`, `P137`, etc. These IDs resolve to entries in `docs/decisions/`, `docs/jtbd/`, and `docs/problems/` *inside the windyroad-claude-plugin source repo*. Adopter projects that install the plugin via Claude Code's marketplace mechanism do not have access to those trees.

Surveyed 2026-05-03: shipped artefact surfaces under `packages/<plugin>/` carry **2,880 internal-ID drift instances** across **81 files** in **13 packages** (counted by `check-internal-id-leaks.sh`). Reference density is severe — `manage-problem` SKILL.md alone carries 121 internal IDs in its prose body.

Failure modes for the adopter Claude Code session that loads such an artefact (in increasing severity, per P137 §Description):

1. **Adopter agent ignores the reference** — best case. The agent reads `"per ADR-014"`, cannot resolve it, treats as opaque token, proceeds with reduced contextual grounding.
2. **Adopter agent searches and surfaces "ADR not found"** — agent attempts to follow the reference, may surface a "missing decision" warning to the user, may halt or de-rank a step that depended on the cross-reference.
3. **Adopter agent resolves to UNRELATED ADR-014 in adopter's own tree** — most dangerous. Adopter projects may have their own `docs/decisions/014-something-completely-different.proposed.md`. Agent reads the wrong ADR and applies its semantics to the windyroad SKILL.md context. The agent's behaviour is now confidently wrong, anchored on a misleading decision document.

The plugin-user persona's load-bearing constraints — *low repo-context*, *no `node_modules/` archaeology*, *AI agent as primary readership* — match failure modes 2 and 3 verbatim. The asymmetry is stark: the source-side maintainer (who reads SKILL.md alongside `docs/decisions/`) doesn't see the failure mode at all, so dangling references accumulate without negative feedback inside the source repo.

P137 ticket lists 5 candidate strategies (A: strip, B: permalinks, C: namespace-prefix, D: disclaimer, E: build-step rewrite). This ADR codifies the chosen strategy — **namespace-prefix as primary + permalink as progressive enhancement** — and ships an advisory detector that surfaces drift before mechanical work begins. Phase 2 mechanical sweep follows the opportunistic-as-touched migration shape established by ADR-052.

The contract-first / measurement-second / rollout-third sequencing matches the ADR-051 / ADR-052 / ADR-053 / ADR-054 precedent landed this week.

## Decision Drivers

- **JTBD-302** (Trust That the README Describes the Plugin I Just Installed — plugin-user persona) — primary anchor. ADR-051 line 156 cites P137 as a sibling on the *semantic correctness axis* of adopter-facing content. JTBD-302's plugin-user constraints (low repo-context, no `node_modules/` archaeology, AI-agent-readership-amplifies-drift) are exactly what namespace-prefixed IDs protect.
- **P137** (this ADR's direct driver) — adopter-facing content quality on the semantic-correctness axis.
- **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — the affected persona by definition; every adopter Claude Code session that surfaces a windyroad SKILL.md or runs a windyroad hook is exposed to dangling references.
- **JTBD-101** (Extend the Suite with New Plugins — plugin-developer) — *secondary* persona served by Phase 4's CONTRIBUTING.md guardrail (deferred). Convention codification helps plugin-developer extend the suite without re-introducing dangling references.
- **JTBD-001** (Enforce Governance Without Slowing Down — solo developer) — the advisory detector runs read-only at retro time and adds no per-edit friction; "reviews complete in under 60 seconds" stays intact.
- **JTBD-006** (Progress the Backlog While I'm Away — AFK orchestrator) — silent-on-pass detector adds zero output to AFK loops when no drift exists.
- **ADR-038** (Progressive disclosure for governance tooling context) — parent pattern. Detector emits terse machine-readable lines, not prose; adopters expand on demand.
- **ADR-045** (Hook injection budget for PreToolUse/PostToolUse) — silent-on-pass discipline. Detector emits zero output when no shipped artefact carries bare tokens.
- **ADR-052** (Behavioural-tests-default for SKILL testing) — bats fixture asserts script *output*, not script source. Phase 2 mechanical sweep follows ADR-052's opportunistic-as-touched migration shape.
- **ADR-054** (SKILL.md runtime budget policy) — sibling adopter-context decision and source of the REFERENCE.md exclusion rule.
- **ADR-051** (JTBD-anchored README with drift advisory) — direct precedent for declarative-first ADR + advisory detector landed in the same week.
- **ADR-053** (Plugin maturity taxonomy) + **ADR-049** (Plugin script resolution via bin/ on PATH) — sibling adopter-context decisions in the 2026-04-28..2026-05-03 cluster.
- **ADR-013** Rule 6 (advisory-then-escalate fail-safe) — promotion-path precedent. Phase 1 ships advisory; promotion to blocking PreToolUse hook is a named reassessment trigger.

## Considered Options

The five candidate strategies from P137 §Root Cause Analysis. Options A, D, E rejected; Option C chosen with Option B as progressive enhancement.

1. **Option A — Strip all references** (rewrite `"per ADR-014"` as self-contained inline summary). Rejected: lossy. Strips institutional cross-references that windyroad maintainers rely on for source-side coherence. The cost of authoring inline summaries for 2880 instances is bigger than the cost of adding a 3-character prefix. Loses the ability to cross-reference the source repo's decisions tree even for curious adopters.

2. **Option B — Replace with GitHub permalinks** (rewrite `"per ADR-014"` as `"per [ADR-014](https://github.com/windyroad/agent-plugins/blob/main/docs/decisions/014-...)"`). Rejected as primary, **adopted as progressive enhancement**: permalinks alone do not disambiguate from adopter's own `ADR-014` because adopter agents pattern-match on the visible token, not the URL host. Failure mode 3 (adopter agent resolves to UNRELATED ADR-014 in their own tree) survives. However, permalinks layer cleanly on top of namespace prefix as `"per [WR-ADR-014](...)"` and let curious adopter agents follow the link to the source.

3. **Option C — Namespace-prefix all internal IDs** (rewrite `ADR-014` as `WR-ADR-014`, `JTBD-101` as `WR-JTBD-101`, `P137` as `WR-P137`). **Chosen**. Disambiguates at the token level: `WR-` reads as "Windy Road", composes with the `@windyroad/*` namespace already visible in adopter `package.json`, and signals to the adopter agent that the reference is external. Adopter agents that don't recognise the prefix safely treat it as opaque (failure mode 1, the benign one). Failure mode 3 is structurally impossible — `WR-ADR-014` cannot collide with adopter's bare `ADR-014`. Mechanical replacement is a 3-character prefix insertion; can be applied opportunistically as files are touched per ADR-052.

4. **Option D — Disclaimer at SKILL.md top** (one-paragraph header per shipped SKILL.md / agent / hook saying "internal IDs reference windyroad-claude-plugin source decisions"). Rejected: brittle. Requires the adopter agent to keep the disclaimer in working memory across long-context interactions; the ID-resolution failure mode happens during tool-result expansion, not during initial SKILL.md read. The disclaimer is far from the failure point in agent context. Also adds prose weight to every SKILL.md, conflicting with ADR-054's runtime budget.

5. **Option E — Build-step rewrite** (publish-time post-processor that converts internal IDs to namespace-prefixed permalinks; source stays human-readable for windyroad maintainers). Rejected: premature. Solves a problem that namespace-prefix-in-source solves at lower cost. Build-step infrastructure adds a new failure mode (publish-pipeline coupling), requires changesets workflow integration, and creates a divergence between source and shipped content that complicates debugging. Reassessable later if Phase 2 opportunistic sweep stalls.

## Decision

Adopt **Option C (namespace-prefix) as the structural rule**, with **Option B (permalinks) as progressive enhancement**, and ship an **advisory detector** that surfaces drift in the existing 2,880 instances. Mechanical sweep follows opportunistically per ADR-052.

### The namespace-prefix rule

In all `@windyroad/*` plugin-published artefacts, internal cross-references to windyroad-claude-plugin source IDs MUST be written in namespace-prefixed form:

| Internal source ID | Adopter-published form |
|---|---|
| `ADR-NNN` (where `docs/decisions/NNN-*.md` exists) | `WR-ADR-NNN` |
| `JTBD-NNN` (where `docs/jtbd/<persona>/JTBD-NNN-*.md` exists) | `WR-JTBD-NNN` |
| `PNNN` (where `docs/problems/NNN-*.md` exists) | `WR-PNNN` |

Optional progressive enhancement — wrap the prefixed ID in a permalink to the source-of-truth on `github.com/windyroad/agent-plugins`:

```markdown
per [WR-ADR-014](https://github.com/windyroad/agent-plugins/blob/main/docs/decisions/014-commit-discipline.proposed.md)
```

The bare `WR-ADR-014` token is sufficient for disambiguation. The permalink is a bonus for curious adopter agents.

### Scope — what gets prefixed

The rule applies to artefacts that ship to npm and surface in adopter Claude Code sessions:

- `packages/<plugin>/skills/<skill>/SKILL.md`
- `packages/<plugin>/agents/*.md`
- `packages/<plugin>/hooks/*.sh` (only in adopter-visible body content — deny-message strings, prose comments, README-citing block comments)
- `packages/<plugin>/CHANGELOG.md`
- `packages/<plugin>/README.md`

### Scope — what is excluded (NOT subject to the rule)

- **Source-side documents** under `docs/decisions/`, `docs/jtbd/`, `docs/problems/`, `docs/retros/`, `docs/briefing/`, `RISK-POLICY.md`, `CLAUDE.md` — these never ship to adopter context. Maintainer ergonomics dominate.
- **REFERENCE.md sibling files** under `packages/<plugin>/skills/<skill>/REFERENCE.md` — per ADR-054, REFERENCE.md is lazy-loaded maintainer-facing content, not adopter-runtime.
- **Docstring annotation lines** in scripts — lines beginning with `# @adr` / `# @jtbd` / `# @problem` (e.g. `# @adr ADR-014 (commit discipline)` in `check-skill-md-budgets.sh`). These are maintainer-facing structured comments above script bodies, never expanded into adopter agent context. Treating them as in-scope would force unreadable `# @adr WR-ADR-014` syntax that breaks the structured-annotation reading.
- **Source-tree `package.json`, lockfiles, `.changeset/` source markdown** — these don't ship as adopter-readable content. (The CHANGELOG entries that *result* from `.changeset/*.md` ARE in scope; the source `.changeset/*.md` files are not — they don't ship to npm.)
- **Already-published CHANGELOG entries** — historical npm releases (`@windyroad/itil@0.21.2` etc.) are immutable. Going-forward releases honour the rule; historical drift is acknowledged and out of scope. (Tracked as a non-blocking nice-to-have in P137 Phase 5.)
- **Going-forward changeset authoring discipline** — adjacent to P082 (no voice-tone or risk-scoring gate on commit messages). Not mandated by this ADR; tracked in P082's family.

### Phase 1 deliverables (this ADR ships these)

1. **This ADR** — codifies the rule + reassessment criteria.
2. **Advisory detector script** — `packages/retrospective/scripts/check-internal-id-leaks.sh`. Walks shipped-artefact surfaces, reports each file with bare (non-WR-prefixed) tokens. Silent-on-pass (no output when clean). Always exits 0 (advisory only). Mirrors the OVER / TOTAL signal vocabulary from sibling check-* scripts.
3. **Bin shim** — `packages/retrospective/bin/wr-retrospective-check-internal-id-leaks` per ADR-049 grammar.
4. **Behavioural bats fixture** — `packages/retrospective/scripts/test/check-internal-id-leaks.bats` per ADR-052 default. Asserts detector output on temp-fixture trees; asserts WR-prefixed content passes; asserts docstring annotations and REFERENCE.md siblings are excluded; asserts deterministic ordering.
5. **`@windyroad/retrospective` minor version bump** ships the detector to adopters.

### Phase 2 (deferred — opportunistic-as-touched per ADR-052)

Mechanical sweep across 2,880 drift instances proceeds opportunistically:
- When any SKILL.md / agent / hook / CHANGELOG entry is touched for any other reason, the touching change includes the WR-prefix for any internal IDs in the diff.
- No big-bang rewrite. Per-plugin slices may be carved out as separate problem tickets if/when an adopter incident forces prioritisation.
- The advisory detector measures progress: drift count drops as files are touched.

### Phase 3 (deferred — promotion to blocking)

Promote PostToolUse advisory → PreToolUse blocking gate when both criteria are met:
- Drift count drops to ≤ 100 instances across the monorepo (96.5% reduction from 2,880 baseline).
- Three consecutive monthly retros confirm no regression in drift count.

The promotion path mirrors ADR-052's PostToolUse-advisory → PreToolUse-blocking precedent.

## Reassessment Criteria

Re-evaluate this ADR when any of the following hold:

- **Drift count escalation**: if `drift_instances` rises above 2,880 (the 2026-05-03 baseline) for three consecutive `chore: version packages` releases without intervening sweep work, escalate per ADR-013 Rule 6 — the opportunistic-sweep model is failing to keep pace.
- **Drift count converges**: if `drift_instances` drops below 100 (the Phase 3 promotion threshold), promote the advisory to a blocking PreToolUse hook on the next reassessment.
- **Adopter-side incident**: any reported case of an adopter Claude Code session resolving a windyroad-source ID against an adopter-tree document of the same number — the structural protection failed and a stronger control (e.g. Option E build-step) needs reconsideration.
- **Convention drift**: if a sibling ADR introduces a non-WR namespace prefix (e.g. `WRTC-ADR-014` for "Windy Road Technology Consulting"), reconcile vocabulary or accept divergence as a documented exception.
- **Reassessment date**: 2026-11-03 (six months out, matching ADR-051..054 cadence).

## Confirmation

This decision is confirmed when:

1. **Detector script ships**: `packages/retrospective/scripts/check-internal-id-leaks.sh` is executable, behavioural-bats GREEN, and runs with exit code 0 on a clean fixture tree.
2. **Bin shim resolves on PATH**: `wr-retrospective-check-internal-id-leaks` exists in `packages/retrospective/bin/` per ADR-049 grammar and execs the underlying script.
3. **Baseline measured**: drift count at the time of this ADR's first release is recorded in the changeset body as the 2026-05-03 baseline.
4. **Retro Step 2b integration** (deferred to Phase 2 — Phase 1 ships the detector but does not yet wire it into `run-retro` Step 2b). Tracked under P137 Phase 2.
5. **Adopter validation** (deferred — depends on Phase 2 sweep). Validated when an adopter project running `npx @windyroad/retrospective@<post-Phase-2>` reports `drift_instances=0` against a clean install.

## Notes

### Why namespace-prefix instead of just-permalinks (architect Q1, A)

Permalinks alone don't solve failure mode 3. Adopter agents pattern-match on the visible token, not the URL host. `[ADR-014](https://github.com/windyroad/...)` still presents `ADR-014` as the human-readable token; an adopter project that has its own `ADR-014` will conflate them at the agent's pattern-match stage. Only a token-level disambiguator (`WR-`) closes the wrong-resolution failure path.

The `WR-` prefix is self-evident, composes with the `@windyroad/*` package namespace adopters already see in their `package.json`, and follows the same vocabulary the adopter encounters in their plugin install command (`npx @windyroad/itil`).

### Why detector lives in `@windyroad/retrospective` (architect Q1, B)

Cross-package advisory `check-*.sh` scripts are co-located in `packages/retrospective/scripts/` (currently 5 sibling check-* scripts: `check-ask-hygiene.sh`, `check-briefing-budgets.sh`, `check-readme-jtbd-currency.sh`, `check-skill-md-budgets.sh`, `check-tickets-deferred-cause.sh`). Adding `check-internal-id-leaks.sh` here keeps the cross-package advisory tooling in one place and matches the established home for retro-time aggregated checks.

`@windyroad/architect` is the home for the ADR-enforcement *agent + hook*, not aggregated retro tooling. ADR-discipline at edit-time vs. drift-detection at retro-time are different surfaces.

### Hybrid rejection criteria for Options A, D, E (architect Q1, C)

Stated explicitly in §Considered Options above. Option A (strip) is lossy — kills institutional cross-references; Option D (disclaimer) is brittle — requires sustained working memory in adopter agent; Option E (build-step) is premature — adds publish-pipeline coupling to solve a problem namespace + opportunistic-sweep solves at lower cost.

### Going-forward changeset authoring (architect Q1, D)

Out of scope for this ADR. P082 (no voice-tone or risk-scoring gate on commit messages) covers the source surface of changeset bodies + commit messages. ADR-055 codifies the *adopter-published* surface only. Going-forward changeset authoring discipline (so new changesets ship with WR-prefixed references rather than bare ones) is tracked under P082's family.

### Docstring `@adr` / `@jtbd` / `@problem` annotation lines (architect Q1, E)

Out of scope. Lines beginning `# @adr` / `# @jtbd` / `# @problem` are maintainer-facing structured comments above script function bodies — never expanded into adopter agent context (adopters read shipped SKILL.md prose and hook deny-message *bodies*, not `.sh` source comments). The detector regex skips these lines deliberately so the annotation grammar (which intentionally uses bare IDs as machine-readable structured tokens) keeps working.

### Cross-references to recent siblings

This ADR completes a cluster of adopter-context decisions landed 2026-04-28..2026-05-03:
- **ADR-049** — Plugin-bundled scripts invoked from SKILL.md resolve via `bin/` on `$PATH` (executable correctness axis of P151).
- **ADR-051** — JTBD-anchored README with drift advisory (currency axis of P152).
- **ADR-052** — Behavioural-tests-default for SKILL testing (test-discipline axis of P081 Layer A).
- **ADR-053** — Plugin maturity taxonomy (battle-hardening signal axis of P087).
- **ADR-054** — SKILL.md runtime budget policy (context-budget axis of P097).
- **ADR-055** — *this ADR* — namespace-prefixed internal IDs (semantic correctness axis of P137).

The cluster is unified by JTBD-302's "trust adopter-facing artefacts" frame across multiple correctness axes (executable / currency / semantic / battle-hardening / size).

## Cross-References

- `docs/problems/137-published-plugin-artifacts-reference-internal-ids-confuses-adopter-agents.open.md` (driver)
- `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md` (primary anchor)
- `docs/jtbd/plugin-user/persona.md` (affected persona)
- `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` (Phase 4 secondary)
- `docs/decisions/049-plugin-script-resolution-via-bin-on-path.proposed.md`
- `docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`
- `docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`
- `docs/decisions/053-plugin-maturity-taxonomy.proposed.md`
- `docs/decisions/054-skill-md-runtime-budget-policy.proposed.md`
- `docs/decisions/038-progressive-disclosure-for-governance-tooling-context.proposed.md`
- `docs/decisions/045-hook-injection-budget-for-pre-and-post-tool-use-hooks.proposed.md`
- `docs/decisions/013-structured-user-interaction.amended.md` (Rule 6 escalation precedent)
- `packages/retrospective/scripts/check-internal-id-leaks.sh` (Phase 1 detector)
- `packages/retrospective/scripts/test/check-internal-id-leaks.bats` (Phase 1 fixture)
- `packages/retrospective/bin/wr-retrospective-check-internal-id-leaks` (Phase 1 shim)
