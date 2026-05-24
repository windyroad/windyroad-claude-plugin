# Risk Catalogue

Memory aid for the risk-scorer agent: known risk classes + recogniser patterns + control-application tables + per-action modulators. Reading the catalogue at scoring time saves re-deriving them and reduces the chance of forgetting a class previously surfaced.

The catalogue is **recogniser-shaped**: each entry is optimised for the scorer's slug-match-and-paste path. Entries describe how to recognise the class on a commit's diff, which controls fire and what their band-reduction is, how to modulate likelihood for the specific action, and what the residual lands at when controls fire-and-pass.

## How the scorer uses this

1. **Recognise**: walk the diff against the slug-match quick-reference table below. Any path-pattern or diff-content-keyword match → consider the matched entry.
2. **Apply controls**: for each candidate entry, read its `## Controls` table. Identify which controls fire on THIS action; band-reduce per the table.
3. **Modulate**: adjust likelihood per the entry's `## Per-action modulators` table; composition is **max-pessimistic** (most pessimistic adjustment wins).
4. **Score**: residual = inherent_impact × (catalogue_residual_likelihood + max_pessimistic_modulator).

## Residual semantics

Catalogue residuals reflect "**controls firing-and-passing**" — i.e. the per-action lens, matching how the pipeline scorer empirically computes residual on a real action that triggered the class. This is the residual that reconciles with `.risk-reports/` outputs.

A second reading exists: `RISK-POLICY.md` `## Control Composition` strict path-counting (1/2/3+ independent paths → 1/2/3 bands). Where the two diverge, the entry calls it out (R001 has the explicit caveat). The strict reading is more conservative; the per-action reading is what the gates and scorer actually achieve.

An above-appetite catalogue residual is a real signal: even when controls fire-and-pass, the typical instance still sits above appetite. That's where additional controls (or stronger control class) are genuinely needed.

## Slug-match quick-reference

Single-pass lookup for "given this action's diff, which catalogue entries should I consider?":

| Path pattern / surface | Diff-content keywords | Triggers |
|------------------------|----------------------|----------|
| `.changeset/*.md`, `packages/*/CHANGELOG.md`, `gh issue/pr/api`, `npm publish` | revenue / pricing / client-name / user-count; financial figures with business context | **R001** |
| `*/README.md`, `*/SKILL.md`, `*/REFERENCE.md`, `docs/decisions/*`, `docs/jtbd/*`, `docs/problems/README.md`, `CLAUDE.md`, `RISK-POLICY.md` | sort-spec / tie-break / render / lifecycle suffix; ADR/JTBD/P-NNN moves | **R002** |
| `packages/*/hooks/*.sh`, `*/hooks.json`, `packages/*/hooks/lib/*.sh`, `packages/*/hooks/test/*.bats` | PreToolUse / PostToolUse / permissionDecision / additionalContext / hookSpecificOutput | **R003** |
| (state-shape) gitStatus shows ambient files in `.claude/`, `.afk-run-state/`, `/tmp/*-marker-*` | `git add -A`, `git add .`, broad-glob `git add` | **R004** |
| `.changeset/*.md`, `docs/changesets-holding/*.md` | bump-class declarations; multi-slice references | **R005** |
| `packages/*/skills/*/SKILL.md`, `packages/*/agents/*.md`, `packages/*/package.json` `files` array, `packages/*/bin/*` | `bash packages/...`; bare `ADR-NNN`/`JTBD-NNN`/`P-NNN` without `@windyroad/<plugin>:` prefix; `"files": [` array changes | **R006** |
| (prose-context) recent conversation, commit messages, ticket bodies, CLAUDE.md MANDATORY rules | "only safe if", "don't release X until", "paired with", "depends on" | **R007** |
| (any Edit/Write target — content-shape, not path-shape) | AWS / PEM / GitHub-token / Cloudflare / Netlify patterns; `api_key=` / `auth_token=` / `secret_key=` with high-entropy values | **R008** |
| `packages/*/{skills,agents,hooks,scripts}/**/*` (broadest source surface) | branch logic / regex / numeric thresholds / exit codes / signature changes | **R009** (catch-all when no specialisation matches) |
| `.changeset/*.md` declaring `patch` AND diff includes SKILL.md / agent.md / hook prose change | `: patch` declaration with semantic content shift; AskUserQuestion call shape change; Step removal/reorder in SKILL.md | **R010** |

## Stage applicability cross-index

| Risk | commit | push | release | external-comms |
|------|--------|------|---------|----------------|
| R001 | yes | yes | yes | **primary** |
| R002 | **primary** | yes | yes | no |
| R003 | yes | yes | **primary** | no |
| R004 | **primary** | yes | yes | no |
| R005 | yes | **primary** | yes | no |
| R006 | yes | yes | **primary** | no |
| R007 | yes | yes | **primary** | yes |
| R008 | **primary** | yes | yes | no |
| R009 | yes | yes | yes | no |
| R010 | yes | yes | **primary** | no |

"primary" = the layer where the risk first matters most. Use to prioritise enumeration when scoring per-layer (Layer 1 / Layer 2 / Layer 3 cumulative).

## Specialisation hierarchy

R009 (functional defects) is the bedrock catch-all. Several entries are specialisations:

```
R009 (functional defects in shipped behaviour)
├── R002 (documentation / index / cross-reference drift)
├── R003 (hook regression cascade)
├── R005 (release coordination drift)
├── R006 (publish-boundary divergence)
└── R010 (semver / backward-compat violation)
```

**Routing rule**: when a defect maps to a specialisation, score under the specialisation (its controls + modulators are sharper). R009 is the residual class for any defect that doesn't slot into one of the specialisations.

R001 + R008 are confidentiality classes (different surfaces). R004 is a state-leak class. R007 is a check, not a defect class.

## Entries

| ID | Class | Inherent | Residual | Status |
|----|-------|----------|----------|--------|
| [R001](R001-confidential-disclosure-in-outbound-prose.active.md) | Confidential / business-metric disclosure in outbound prose | 12 (High) | 3 (Low) | within ✓ |
| [R002](R002-documentation-and-index-drift.active.md) | Documentation / index / cross-reference drift across docs | 12 (High) | 6 (Medium) | above |
| [R003](R003-hook-regression-shipped-to-adopters.active.md) | Hook regression / behaviour change ships to adopters | 16 (High) | 4 (Low) | at appetite |
| [R004](R004-ambient-unstaged-state-in-commits.active.md) | Ambient unstaged state included in commits | 6 (Medium) | 2 (Very Low) | within ✓ |
| [R005](R005-release-coordination-changeset-drift.active.md) | Release-coordination / changeset queue drift | 9 (Medium) | 3 (Low) | within ✓ |
| [R006](R006-published-package-vs-source-tree-divergence.active.md) | Published-package references source-tree-only paths and IDs | 20 (Very High) | 8 (Medium) | above |
| [R007](R007-user-stated-preconditions-paired-capability.active.md) | User-stated preconditions / paired-capability check | 12 (High) | 4 (Low) | at appetite |
| [R008](R008-credentials-in-committed-files.active.md) | Credentials / secrets in committed files | 15 (High) | 5 (Medium) | above |
| [R009](R009-functional-defects-in-shipped-behaviour.active.md) | Functional defects in shipped plugin behaviour (bedrock) | 16 (High) | 8 (Medium) | above |
| [R010](R010-semver-or-backward-compatibility-violation.active.md) | Semver / backward-compatibility violation on plugin contracts | 12 (High) | 4 (Low) | at appetite |
| [R011](R011-load-bearing-commit-hook-first-release-blast-radius.active.md) | Load-bearing commit-hook first-release blast radius | — | — | pending review |
| [R012](R012-rfc-chain-atomicity-precondition-breach.active.md) | RFC-chain atomicity / precondition breach | — | — | pending review |
| [R013](R013-rfc-001-chain-atomicity-paired-capability-unmet.active.md) | RFC-001 chain atomicity / paired capability unmet | — | — | pending review |
| [R014](R014-release-pressure-wip-limit-controls-not-firing.active.md) | Release-pressure / WIP-limit controls not firing | — | — | pending review |
| [R015](R015-new-hook-first-landing-without-dogfood-window.active.md) | New hook first-landing without dogfood window | — | — | pending review |
| [R016](R016-release-batch-r009-skill-prose-concentration-above-appetite.active.md) | Release-batch R009 skill-prose concentration above appetite | — | — | pending review |
| [R017](R017-skill-prose-class-bats-deferred-residual-above-appetite.active.md) | Skill-prose class / bats-deferred residual above appetite | — | — | pending review |
| [R018](R018-r009-bedrock-functional-defect-class-floor-medium.active.md) | R009 bedrock functional-defect class floor medium | — | — | pending review |
| [R019](R019-external-comms-hook-source-without-dogfood-window.active.md) | External-comms hook source without dogfood window | — | — | pending review |
| [R020](R020-new-hook-shipped-without-dogfood-window-bash-gate-class.active.md) | New hook shipped without dogfood window (Bash gate class) | — | — | pending review |
| [R021](R021-new-user-facing-surface-no-dogfood-window.active.md) | New user-facing surface — no dogfood window | — | — | pending review |
| [R022](R022-phase-3a-shipped-ahead-of-held-phase-2-dependencies.active.md) | Phase 3a shipped ahead of held Phase 2 dependencies | — | — | pending review |
| [R023](R023-release-coordination-changeset-drift-phase-3a-ahead-of-phase-2.active.md) | Release-coordination changeset drift (Phase 3a ahead of Phase 2) | — | — | pending review |
| [R024](R024-risk-catalog-empty-no-baseline-controls-documented.active.md) | Risk catalog empty / no baseline controls documented (obsolete — superseded by R001-R010 bootstrap) | — | — | pending review |

> **Pending-review queue**: R011-R024 were auto-scaffolded by the Phase 2b drain on 2026-05-17 from `.afk-run-state/risk-register-queue.jsonl` (14 slugs accumulated since Phase 1 bootstrap). Each entry carries ADR-026 sentinels for ungrounded scoring fields and `Status: Active (auto-scaffolded — pending review)` for downstream human curation. Per ADR-056 §"Bad consequences" reassessment criterion #2 — several entries (R011, R015, R019, R020, R021 in the no-dogfood-window class; R012, R013 in the RFC-chain-atomicity class) are semantic duplicates from slug-drift across pipeline runs; curation will merge during review.

## Where we need more controls (above-appetite entries)

| ID | Residual | Why above appetite + next mitigation milestone |
|----|----------|------------------------------------------------|
| **R002** | 6 (Medium) | Some drift sub-classes (ADR-vs-ADR; sort-spec across N render-block sites) have only retro-time advisory coverage. P161 generalisation pattern adds load-bearing detectors; would drop residual to 1 → score 3 / Low. |
| **R006** | 8 (Medium) | Controls (ADR-049 shim, ADR-055 prefix, P154 detector) are mostly **advisory at retro time, not blocking at commit time**. Production evidence: `@windyroad/itil@0.23.2 → 0.24.0` shipped 5 broken-shim versions before catch. Phase-2 promotion to commit-blocking drops residual to 1 → score 4 / Low. |
| **R008** | 5 (Medium) | Impact 5 (Severe) caps residual at 5 even with Likelihood 1 (Rare). No additional detection control will drop residual below 5. Treatment: post-incident rotation-runbook readiness for WHEN-not-IF. |
| **R009** | 8 (Medium) | Bedrock class — defect-free is impossible. Coverage gaps real (skill-prose surfaces don't get behavioural-tested; ~50 legacy structural bats accepted-until-touched per ADR-052 Migration). Phase-2 retrofit + harness-maturity (P012) drop residual incrementally; floor ~6 stays. |

## Adding to the catalogue

Identifying a new class during scoring? Author it via `/wr-risk-scorer:create-risk` (interactive) or `/wr-risk-scorer:create-risk --slug <slug>` (orchestrator-driven from an ADR-056 hint).

The entry shape (per-entry sections to author): description; recogniser (path patterns + diff keywords + anti-patterns); stage applicability; inherent risk per `RISK-POLICY.md`; controls table with "if absent for THIS action" column; per-action modulators (composition: max-pessimistic); residual; watch-out; see-also. Refer to existing entries as templates — R001 / R003 are the canonical examples.

The catalogue is self-pruning: when a class stops surfacing in `.risk-reports/` (controls have made it rare), retire its entry by renaming `R<NNN>-<slug>.md` to `R<NNN>-<slug>.retired.md`. Git history preserves prior content.
