---
status: "superseded"
date: 2026-05-04
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: []
reassessment-date: 2026-08-04
amended: 2026-05-04
amendment-driver: P159
superseded-date: 2026-05-25
superseded-by: [069-readme-markets-persona-problem-not-jtbd-id]
---

# `@windyroad/*` plugin READMEs anchor on JTBD job IDs with load-bearing commit-hook + prose-woven framing

> **Superseded by [ADR-069: Plugin READMEs market to their primary persona's problem](069-readme-markets-persona-problem-not-jtbd-id.proposed.md)** (2026-05-25, driver P294).
> The user rejected this ADR's core mechanism during the P283/ADR-066 oversight drain: *"The intention was not for the README to cite the JTBDs. The idea is that based on the JTBD, the README could market the plugin to the persona and the problem it solves for them. The current approach fails that miserably."*
> **Superseded:** Option D2 (README MUST cite a JTBD ID) + the bolt-on `## Jobs to be Done` section + the JTBD-ID commit-gate. ADR-069 narrows that gate to skill-inventory-drift only.
> **Carried forward to ADR-069 as live precedent** (citations to these resolve to ADR-069): **(a)** the prose-weaving anti-pattern (bolt-on tail-section rejected; framing woven into lead prose), and **(b)** the load-bearing-from-the-start-for-drift-class driver (gate mechanical/structurally-bounded drift at commit time). ADR-069 remains an exemplar of (b) — it keeps a load-bearing commit gate, now scoped to skill-inventory-drift. References elsewhere (e.g. ADR-060, P161) to (b) as originating here remain valid via this note.

> **Amendment 2026-05-04 (P159)**: Phase 1's advisory-only consumption surface (retro-time signal, exit-0 always) was identified as too late for the most common drift class — contributor adds a skill/hook/agent and forgets the README; the offending commit doesn't touch README.md so a retro-time consumer sees the drift only after it has shipped. The amended Phase 1 ships the load-bearing-from-the-start variant: a PreToolUse:Bash hook on `git commit` that runs the existing detector against the post-commit working tree and denies the commit when `drift_instances > 0`. The advisory script remains; retro Step 2b wiring (P158) survives as a backup advisory. Concurrently, the **Recommended Section Structure** clause is rewritten: the bolt-on `## Jobs to be Done` section is rejected as an anti-pattern (the section becomes compliance theatre that absolves the lead prose of doing the job-framing); JTBD framing should instead be **woven into the existing What It Does / Skills / How It Works prose** where adopters are already reading. See the amended Recommended Section Structure clause below for prose-weaving target guidance + persona-primacy preservation + anti-pattern citation.

## Context and Problem Statement

The project has a dense pressure stack for keeping CODE in sync with documented decisions and contracts: `wr-architect:agent` enforces architecture compliance, `wr-jtbd:agent` enforces JTBD alignment, `wr-risk-scorer:pipeline` scores commit/push/release risk, the TDD enforcement hook gates implementation edits on red/green test state, the changeset-discipline hook (P141) gates `git commit` on changeset coverage, and `manage-problem` Step 0 reconciliation halts on README-vs-inventory drift. Every commit goes through gates that catch divergence early.

There is no equivalent stack for **doc-content drift**. The documentation that ships to npm under each `@windyroad/*` package — package-level READMEs, top-level project README, plugin marketplace listing copy — has no analogous gate, no analogous detector, no analogous advisory script. It is hand-maintained, drift-prone, and currently relies entirely on memory + occasional manual review. Empirical state on 2026-05-03: `@windyroad/itil` ships 16+ skills but the README documents 2; `@windyroad/retrospective` ships 2+ skills but the README documents 1; cross-cutting hooks and agents added across iters of the AFK loop (changeset-discipline, correction-detect, ADR-049 bin-shim grep-as-lint) are entirely absent from package READMEs. Drift count across 12 plugin READMEs at the time this ADR was authored: at least 12 instances of inventory drift and 0 instances of JTBD anchoring.

This is the driver of P152 (No pressure or nudge for documentation currency). The user's framing of the fix shape is load-bearing: *"leverage the JTBD pages so we can help the reader understand the value through the jobs it helps them do"*. JTBD framing is not just internal-persona accounting; it is the lens through which an adopter (human or AI agent) can quickly see "this skill exists because of THESE jobs". The plugin-user persona (`docs/jtbd/plugin-user/persona.md`) is defined by "low context on repo internals; AI agent as primary interface" — exactly the audience that benefits most from job-framed value description rather than raw capability enumeration.

The pressure-stack architecture in this project is **decision-anchored**: every gate cross-checks new edits against a canonical source of truth (`docs/decisions/`, `docs/jtbd/`, `RISK-POLICY.md`). For doc-content drift, the missing piece is no canonical source of truth that the README content must conform to. A README is hand-authored prose; without an anchor, even a hook firing on README edits has nothing to gate against.

The solution shape: **JTBD job files become the canonical source of truth for README narrative**. Per ADR-008's `docs/jtbd/<persona>/JTBD-NNN-<title>.<status>.md` layout, every JTBD job has a stable identifier (`JTBD-NNN`) with a known persona, status, and content. Anchoring README narrative on JTBD IDs makes drift detectable: the detector can grep for `JTBD-\d{3}` in the README, cross-reference the cited IDs against the current `docs/jtbd/` tree, and flag stale citations, missing anchors, or inventory drift between SKILL.md / hooks / agents and the README's coverage of them.

A normative rule is needed so future plugin authors do not author drift-prone READMEs, and a Phase 1 advisory detector is needed so the existing READMEs surface their drift to retros and release candidates without blocking CI on day one (per the established Phase 1 / Phase 2 trajectory in P099 / P134 / P145 / P148).

## Decision Drivers

- **Plugin-user persona's "low context on repo internals; AI agent as primary interface" constraint** (`docs/jtbd/plugin-user/persona.md`): adopters cannot verify README claims by reading source under `node_modules/`. The README's currency must be detectable without `node_modules/` archaeology. **JTBD-302 (Trust That the README Describes the Plugin I Just Installed)** names this job explicitly — primary driver.
- **Currency-pressure expansion from code to doc-content (JTBD-007)**: JTBD-007 (Keep Plugins Current Across Projects) currently frames currency as code-currency ("did the install pick up the latest code?"). This ADR extends the same persona's currency concern to README-content-currency. JTBD-007's scope is being **extended** (not reframed); JTBD-007 is a co-primary driver alongside JTBD-302.
- **Job-framed value description over raw capability enumeration**: per the user's framing of P152, READMEs that lead with "what jobs this plugin helps you do" outperform READMEs that lead with "what skills this plugin exposes" for an audience that doesn't already know which skills they need. The persona docs already use job-framing; READMEs should compose with that vocabulary.
- **Stable canonical anchor required for drift detection**: a hook firing on a README edit needs SOMETHING to gate against. JTBD job IDs (per ADR-008's per-job-file layout) are the project's most stable + most semantically-load-bearing identifier — more stable than skill names (P071 split precedent), more semantically-rich than ADR IDs (which describe decisions, not jobs).
- **Advisory-first per ADR-013 Rule 6 fail-safe** (original Phase 1 design — superseded as primary 2026-05-04 by P159 amendment, retained as backup): the detector script emits drift signal as data on stdout; exit code is always 0; no gate fires. The script + retro Step 2b wiring (P158) survive as a backup signal; the load-bearing-from-the-start commit-hook (added in the amendment, see new driver below) is the primary surface.
- **Load-bearing-from-the-start for drift class** (added 2026-05-04 by P159 amendment): drift detectors that catch *mechanical, detectable, structurally-bounded* divergence between code and docs are a different class from design-question / policy detectors. The advisory-then-escalate gradualism (ADR-040 / ADR-013 Rule 6 / P099 / P134 / P145 / P148) optimises for "give the rule time to socialise before it gates" — but for drift-class detection that gradualism re-creates the failure mode the detector exists to solve. The most common drift mode is "contributor adds a skill/hook/agent and forgets the README", which ships in a commit that does not touch README.md; an advisory surface consumed at retro time sees the drift only after the contributor has already committed. Load-bearing-from-the-start at the closest enforcement surface to the failure mode (here: PreToolUse:Bash on `git commit`) closes the gap. Whether this generalises to a meta-rule for drift detectors is the broader question P159 surfaces; that question is queued at outstanding_questions for a separate ticket once 2-3 more drift detectors arrive and follow the same shape.
- **Plugin-developer persona's "clear patterns, not reverse-engineering" outcome (JTBD-101)** — composition driver: a future contributor authoring a new `@windyroad/*` plugin needs ONE place that says "this is how plugin READMEs are structured". This ADR is that place.
- **Tech-lead persona's pre-flight governance check (JTBD-202)** — composition driver: the advisory detector script is exactly the kind of release-time signal a tech-lead would consult before recommending a plugin to a team or client.
- **Solo-developer's enforce-governance job (JTBD-001)** — composition driver: extending the existing pressure-stack to README content composes with the documented-policy-checked-on-every-edit shape.
- **Plugin-user's report-without-pre-classifying job (JTBD-301)** — composition driver: better READMEs → better mental models → better intake.
- **Behavioural bats per ADR-005 + P081**: the detector's behaviour must be tested against synthetic fixtures (drift case, clean case, stale-ID case) — not against a structural grep on its own source. Drift detection is a behavioural property of the detector script.

## Considered Options

1. **Option D1 — "Plugin README MUST have a `## Jobs to be Done` section that lists JTBD job IDs"**: structurally force the addition. Every plugin README must contain a section with a fixed heading; the detector greps for the heading. Rigid; the section becomes a checklist tick rather than the canonical narrative anchor. Doesn't address the underlying problem that current READMEs do their value framing in `## What It Does`.
2. **Option D2 — "Plugin README MUST cite at least one current JTBD job ID; value framing SHOULD derive from JTBD" (chosen)**: the normative rule is that every `@windyroad/*` plugin README MUST contain at least one match for `JTBD-\d{3}` AND every cited JTBD ID MUST resolve to a current `docs/jtbd/<persona>/JTBD-NNN-*.md` file (any status suffix). Heading vocabulary is RECOMMENDED (see Recommended Section Structure below) but not normative. Detector is structurally simple (grep for the ID pattern + resolve to filesystem). Preserves authorial flexibility while making drift detectable. Composes with existing `## What It Does` headings while extending them.
3. **Option D3 — Status quo (do nothing)**: rely on hand-maintenance + occasional review. Drift continues to accumulate at observed rate (≥12 instances across 12 READMEs per 2026-05-03 audit). Rejected — this is the failure mode P152 surfaces.
4. **Option D4 — Generated READMEs from JTBD + SKILL.md + plugin.json**: produce the README mechanically from machine-readable inputs. Drift impossible by construction. Rejected for Phase 1 — bypasses the human narrative voice; loses the README's intended audience-framing value; would require a generator engine + per-plugin templates as net-new infrastructure. May reconsider at Phase 3+ if Phase 2 escalation surfaces persistent unfixed drift.

## Decision Outcome

Chosen option: **"Option D2 — Plugin README MUST cite at least one current JTBD job ID; value framing SHOULD derive from JTBD"**, because it (a) creates a stable, structurally-simple drift-detection anchor (JTBD ID grep + filesystem resolve) without rigidifying the README's narrative shape, (b) preserves the existing `## What It Does` value-framing section while requiring it to derive from JTBD job files, (c) leaves room for each plugin's narrative voice to evolve while keeping the JTBD anchor as the load-bearing detector signal, and (d) composes cleanly with ADR-008's per-job-file source-of-truth layout.

Sibling to ADR-049 (bin/-on-PATH script resolution) on the "plugin-published artefacts must work in adopter contexts" axis. ADR-049 addresses **executable correctness** in adopter sessions; this ADR addresses **content currency** in adopter README reads. Both are plugin-boundary leakage concerns of different kinds.

Composes with ADR-040 declarative-first pattern (the rule itself is declarative; the hook is the load-bearing enforcement of the declarative rule). Composes with ADR-013 Rule 1 (deny redirects with mechanical recovery — the hook deny names the wr-jtbd:agent recovery path + hand-edit fallback) and ADR-013 Rule 6 (fail-open paths preserve non-interactive resilience — outside git work tree, in adopter projects without ADR-051 anchors, on detector failure, on parse error). Composes with ADR-008 (JTBD directory structure) — the per-job-file layout is the load-bearing structural foundation that lets the detector resolve cited IDs deterministically.

**(Amended 2026-05-04 by P159)** The original Phase 1 design's pure advisory consumption (exit-0 always; retro-time signal) is **superseded as the primary surface** by the load-bearing-from-the-start commit-hook. The advisory script + retro Step 2b wiring (P158, `df47ad1`) survive as a backup signal — they catch drift in sessions that bypass the commit-hook (BYPASS_JTBD_CURRENCY=1 audit trail) and provide cross-cutting drift summaries in retros. The amended rationale: drift detectors that catch *mechanical, detectable, structurally-bounded* divergence between code and docs are a different class from design-question / policy detectors; for drift class, advisory-then-escalate gradualism re-creates the failure mode the detector exists to solve (the contributor commits the drift before the advisory consumer sees it). See the new Decision Driver "Load-bearing-from-the-start for drift class" below.

**Normative rules** (Phase 1, amended 2026-05-04):

1. Every `@windyroad/*` plugin's `packages/<plugin>/README.md` MUST contain at least one match for the regex `JTBD-\d{3}`.
2. Every JTBD ID cited in a plugin README MUST resolve to a current file under `docs/jtbd/<persona>/JTBD-NNN-*.md` — ANY status suffix (`.proposed.md`, `.validated.md`, `.deprecated.md`, `.superseded.md`). Status suffix is surfaced in detector signal as `jtbd_status=<status>` sub-flag so a future tightening can be added without re-architecting the detector. A README citing a `.deprecated.md` or `.superseded.md` ID is a currency signal worth flagging in `drift_hints`, not a resolution failure.
3. The detector MAY also flag inventory drift hints (skill defined in `packages/<plugin>/.claude-plugin/plugin.json` or `packages/<plugin>/skills/*/SKILL.md` but not mentioned in the README) as advisory signal — this is a soft heuristic, not a normative rule.
4. **(Added 2026-05-04 by P159 amendment)** A PreToolUse:Bash hook (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`) MUST gate `git commit` invocations against the detector running on the project's working tree. When `TOTAL drift_instances > 0`, the hook emits a PreToolUse deny that names the offending plugin slug + primary drift hint + the wr-jtbd:agent recovery path with hand-edit fallback + the BYPASS env override. The hook fails-open in adopter projects without `./packages/` or `./docs/jtbd/`, outside a git work tree, on detector-script failure, and on parse error — so the gate is a no-op for projects that haven't adopted the rule's structural anchors.

**Recommended Section Structure** (for plugin READMEs, non-normative; rewritten 2026-05-04 by P159 amendment):

The bolt-on `## Jobs to be Done` section recommended in the original Phase 1 design is **rejected as an anti-pattern**. Empirical observation across the 12 plugin READMEs refreshed in `8df1692`: the bolted-on section becomes compliance theatre that absolves the lead prose (`## What It Does`) of doing the job-framing, while the adopter's reading attention is at the top of the README — they form their value model from the un-framed prose before the JTBD context arrives. The JTBD framing should instead **inform** the existing prose where adopters are already reading.

**Prose-weaving target guidance** (where to weave JTBD-NNN citations):

- **`## What It Does` (or equivalent value-framing opening section)** — the plugin's primary value claim should name at least one JTBD job in the prose itself, not as a tail-section appendage. Example shape: *"@windyroad/architect serves [JTBD-201](../docs/jtbd/tech-lead/JTBD-201-...) by enforcing architecture decisions documented in `docs/decisions/` against every edit."* The JTBD-NNN citation is the structural anchor; the prose is the value frame.
- **Per-skill descriptions** — when a skill is introduced in the README, name the JTBD job it serves inline. Example shape: *"`/wr-architect:create-adr` (serves [JTBD-203](../docs/jtbd/tech-lead/JTBD-203-...)) authors a new MADR 4.0 architecture decision in `docs/decisions/`."*
- **Per-hook / per-agent descriptions** — when a hook or agent is introduced, name the JTBD job that drove its mechanism. Hooks and agents are policy enforcement; the JTBD job names the policy intent.

**Anti-pattern** (do NOT do this):

- A standalone `## Jobs to be Done` section as a tail appendage. Reasoning: (a) the lead prose loses the framing pressure (JTBD context arrives after value model is already formed); (b) the section becomes a compliance tick rather than the canonical narrative anchor; (c) bolted-on sections drift independently from the lead prose at higher rates than woven citations do.

**Persona-primacy preservation** (preserved across the rewrite):

- The lead prose's value framing should reflect the **primary readership persona** for that plugin. `@windyroad/itil` leads with plugin-user (adopter team adopting ITIL framework via Claude); `@windyroad/architect` leads with tech-lead (architect enforcing decision discipline); `@windyroad/retrospective` leads with solo-developer (retro author capturing learnings). Secondary personas appear later in the prose as their jobs are introduced.
- **Anti-pattern**: leading with capability enumeration (*"This plugin exposes 14 skills..."*) before the primary-persona value framing. The bolt-on section made this anti-pattern easy to fall into because the section provided a "compliance" outlet that absolved the lead prose of doing the framing. Without the bolt-on section, the lead prose carries the audience-framing weight directly.

**Heading vocabulary remains non-normative** — plugins may use `## What It Does`, `## Overview`, `## Why You Want This`, etc. The detector greps for `JTBD-\d{3}` regardless of heading vocabulary; adopters benefit from readable narrative voice over rigid schema conformance.

**Out of scope for this ADR**:

- Generalisation to adopter project surfaces (marketing HTML, public docs, changelog narrative) — follow-on ticket. The user's framing of P152 mentions adopter surfaces; ADR-051's scope is `@windyroad/*` plugin READMEs only. Adopter-surface generalisation is a distinct decision because the source-of-truth anchor differs (adopter projects have their own JTBD structure or none at all).
- **Retroactive prose-weaving refresh of the existing 12 plugin READMEs** — Phase 2 (deferred to a separate iter; surfaced as P159 Phase 2 in the change log). The 12 READMEs currently carry the bolted-on `## Jobs to be Done` shape from `8df1692`; weaving JTBD framing into existing What It Does / Skills / How It Works prose is large agent-driven content work, not Phase 1 scope.
- **Auto-fix orchestration via wr-jtbd:agent** — Phase 2 (deferred). The amended Phase 1 hook deny redirects to wr-jtbd:agent for guidance, but the agent's contract is currently read-only (Read/Glob/Grep/Bash). Phase 2 will decide whether to grant the agent Edit (architectural choice — agent gains write authority) or have the orchestrator apply edits from the agent's instruction sequence. Either choice will need its own ADR amendment / problem ticket.
- SKILL.md amendments wiring the detector into `/wr-retrospective:run-retro` Step 2b — shipped under P158 (`df47ad1`); the retro wiring survives as a backup advisory after the P159 amendment migrates the primary surface to the commit-hook.
- Extension to walk `.github/ISSUE_TEMPLATE/*.yml` per JTBD-lead's original recommendation — surfaced as a Phase 1.5 candidate; current scope is plugin READMEs only.
- **Generalisation of "load-bearing-from-the-start as default for drift class"** — surfaced for a separate problem ticket (P161) if architect review confirms the pattern after 2-3 more drift detectors arrive following the same shape. P159 captures this as the originating observation.

### Consequences

#### Good

- Adopter agents reading a `@windyroad/*` plugin README can cross-reference cited JTBD IDs to the public repo's `docs/jtbd/` tree, giving the persona-defining "low context on repo internals" reader a path to value-frame understanding without source archaeology. JTBD-302's "trust the README" outcome becomes reliably servable.
- Future plugin authors have ONE place (this ADR) that says "this is how plugin READMEs are structured" — JTBD-101's "clear patterns, not reverse-engineering" outcome is served.
- **(Amended 2026-05-04 by P159)** Drift is gated at commit time (PreToolUse:Bash hook denies drifted commits with redirect to wr-jtbd:agent recovery), with retro time + release time advisory backups (P158 retro Step 2b wiring, advisory script) catching anything that bypasses the gate. The pressure-stack asymmetry P152 surfaces is closed at the closest enforcement surface to the failure mode.
- README narrative anchors on stable identifiers (JTBD IDs) rather than skill names (which split per P071), ADR IDs (which amend per ADR-013 → ADR-044), or hook names (which churn per P124 / P141 / P144). JTBD IDs are the project's most stable + most semantically-load-bearing identifier.
- Composes with the `wr-jtbd:agent` review path — when a plugin README is edited, the JTBD agent's existing review surface naturally extends to "are the cited JTBDs still current?".

#### Neutral

- One advisory script (`packages/retrospective/scripts/check-readme-jtbd-currency.sh`) + one bin/ shim (`packages/retrospective/bin/wr-retrospective-check-readme-jtbd-currency`) + one detector bats fixture set + **(Added 2026-05-04 by P159)** one PreToolUse:Bash hook (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`) registered in `packages/retrospective/hooks/hooks.json` + one hook bats fixture set. The script body is one concern; the shim is 3 lines per ADR-049; the fixtures are synthetic markdown; the hook is ~50 lines of Bash invoking the detector and parsing its TOTAL line. Maintenance footprint is small.
- Plugin authors must include at least one JTBD citation in every README. For most plugins, the relevant JTBD already exists; for plugins that don't yet have a JTBD-anchored job (the plugin-user might say "this plugin doesn't help with any documented job"), the answer is to file the missing JTBD, not skip the citation.

#### Bad

- **(Amended 2026-05-04 by P159)** The PreToolUse:Bash hook adds ~80–150ms per `git commit` invocation in the plugin monorepo (architect's ADR-023 perf review at amendment time). Aggregate impact: ~3s per AFK loop session (~30 commits) and ~500ms per non-AFK session (~5 commits). Adopter projects without `./packages/` or `./docs/jtbd/` see ~5ms (fail-open path; one git rev-parse + two directory checks). The cost is acceptable for AFK loops but noted for monitoring; if the detector grows or the per-package count expands materially, performance budget warrants a revisit.
- The detector cannot semantically validate that a cited JTBD ID is the **right** job for the plugin — only that the cited ID exists. A README that cites JTBD-001 in every plugin would pass the detector but still be wrong. This is the residual judgement call that the wr-jtbd:agent's read of the README content (Phase 2 auto-fix scope) and retros (backup advisory) address.
- Plugin renames that change the README's JTBD framing composition (e.g. removing a deprecated persona) require coordinated edits across multiple READMEs. This is rare and grep-able.
- **(Added 2026-05-04 by P159)** The bootstrapping commit that ships the hook itself must clear any pre-existing drift OR use BYPASS_JTBD_CURRENCY=1 — otherwise the hook denies its own creator commit. The amendment commit fixes 2 pre-existing skill-inventory-drift instances tactically (architect README missing `capture-adr`; itil README missing `capture-problem`) so the bootstrap commit clears the gate naturally without BYPASS. Per ADR-053 Bootstrapping clause precedent.

## Confirmation

This decision is honoured when:

1. **Behavioural bats test passes** under `packages/retrospective/test/check-readme-jtbd-currency.bats`, asserting:
   - **Drift fixture case**: a synthetic plugin README with no `JTBD-\d{3}` match produces detector output `has_jtbd_anchor=no` and a non-zero `drift_instances` count in the `TOTAL` line. Detector exit code is 0 (advisory).
   - **Clean fixture case**: a synthetic plugin README citing one or more current JTBD job IDs produces detector output `has_jtbd_anchor=yes cited_jobs=N known_jobs=N drift_hints=` (empty drift_hints). Detector exit code is 0.
   - **Stale-ID fixture case**: a synthetic plugin README citing a JTBD ID that does NOT resolve to any current `docs/jtbd/<persona>/JTBD-NNN-*.md` file produces detector output that flags the stale ID in `drift_hints` (e.g. `drift_hints=stale-jtbd-citation`). Detector exit code is 0.
2. **Detector emits the documented signal vocabulary**: per-package `README package=<name> has_jtbd_anchor=<yes|no> cited_jobs=<count> known_jobs=<count> drift_hints=<comma-list>` lines, plus a trailing `TOTAL packages=<N> with_jtbd=<M> drift_instances=<K>` summary. Per-citation status sub-flag emitted for tightening flexibility in Phase 2. Matches the value-pair convention of sibling detectors (P099 / P134 / P145 / P148).
3. **Bin/ shim resolves on `$PATH`**: `command -v wr-retrospective-check-readme-jtbd-currency` succeeds when the plugin is installed via the marketplace cache. Per ADR-049 normative rule + naming grammar.
4. **Changeset accompanies the script + ADR**: `@windyroad/retrospective` minor bump documenting the new advisory script + bin shim. Per ADR-014 + ADR-021 + P141 changeset-discipline.
5. **(Amended 2026-05-04 by P159) Phase 1 surface is the PreToolUse:Bash commit-hook + retro Step 2b advisory backup**: the load-bearing-from-the-start hook (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`, registered in `packages/retrospective/hooks/hooks.json` under PreToolUse:Bash) is the primary consumption surface. The retro Step 2b wiring shipped under P158 (`df47ad1`) survives as a backup advisory for sessions where the commit-hook is bypassed (BYPASS_JTBD_CURRENCY=1) or where adopters consume the detector at retro time for cross-cutting drift summaries.
6. **(Amended 2026-05-04 by P159) Hook behaviour is bats-tested**: `packages/retrospective/hooks/test/retrospective-readme-jtbd-currency.bats` asserts deny on drift (no JTBD-NNN cite, skill-inventory-drift), allow on clean tree, BYPASS env, fail-open paths (outside git work tree, no `./packages/`, no `./docs/jtbd/`, parse error, malformed JSON), silent-on-pass per ADR-045 Pattern 1, and deny-band ≤300 bytes per ADR-045. Deny redirects to wr-jtbd:agent recovery with hand-edit fallback per ADR-013 Rule 1.
7. **Retroactive prose-weaving refresh deferred to Phase 2** (surfaced as a separate iter): the 12 plugin READMEs are not re-integrated in this iter. Each plugin README needs its `## Jobs to be Done` tail-section removed and JTBD-NNN citations woven into the existing What It Does / Skills / How It Works prose per the amended Recommended Section Structure clause. Two pre-existing skill-inventory-drift instances (architect README missing `capture-adr` mention from `d28bd51`; itil README missing `capture-problem` mention from `86e99e5`) are tactically fixed in the same commit as the hook to clear the bootstrap drift; the strategic re-integration follows in Phase 2.
8. **(Amended 2026-05-04 by P159 — Reassessment trigger refresh)** The original Phase 2 escalation criterion (advisory `drift_instances ≥ 2` across 3 releases triggers a load-bearing hook) is **superseded** by the load-bearing-from-the-start direction. The new reassessment trigger: if the commit-hook produces a sustained false-positive rate (legitimate commits routinely BYPASS-bypassed without remediation), revisit the hook's drift-detection logic; if the detector misses semantic drift the hook cannot catch (e.g. cited JTBD is the wrong persona for the plugin), extend the detector or add a wr-jtbd:agent review gate on README edits. See Reassessment Criteria below.

## Pros and Cons of the Options

### Option D1 — README MUST have a fixed `## Jobs to be Done` section

- Good: structurally rigid; trivial to grep for the heading.
- Good: forces the value-framing to live in a known place.
- Bad: rigid heading vocabulary discourages narrative evolution.
- Bad: doesn't address the underlying problem (`## What It Does` does the value framing today; D1 adds a section beside it without integrating).
- Bad: detector becomes brittle when an author uses synonymous heading phrasing.

### Option D2 — README MUST cite at least one current JTBD ID; value framing SHOULD derive from JTBD (chosen)

- Good: structurally simple detector (grep `JTBD-\d{3}` + resolve to filesystem).
- Good: preserves authorial flexibility — heading vocabulary is recommended, not mandated.
- Good: composes with existing `## What It Does` rather than adding a parallel section.
- Good: anchors on stable identifiers (JTBD IDs survive plugin renames, skill splits, ADR amendments).
- Neutral: requires every plugin to cite at least one JTBD; for plugins without a current JTBD-anchored job, the answer is to file the missing JTBD.
- Bad: cannot semantically validate the JTBD is the **right** one for the plugin — only that the citation exists and resolves.

### Option D3 — Status quo (do nothing)

- Good: zero new infrastructure.
- Bad: drift continues to accumulate; adopter trust continues to erode; the asymmetric pressure-stack persists.
- Bad: the failure mode P152 surfaces is the explicit reason this ADR exists.

### Option D4 — Generated READMEs from JTBD + SKILL.md + plugin.json

- Good: drift impossible by construction.
- Bad: bypasses the human narrative voice; loses audience-framing value.
- Bad: would require a generator engine + per-plugin templates as net-new infrastructure.
- Bad: composes adversely with existing per-plugin authorial voice; treating READMEs as machine output forecloses the persona-grouped narrative shape JTBD review recommends.
- May reconsider at Phase 3+ if Phase 2 escalation surfaces persistent unfixed drift after the rule + advisory + retroactive refresh have all shipped.

## Reassessment Criteria

(Amended 2026-05-04 by P159 — the original "escalate-to-load-bearing-after-3-releases" trigger is superseded because the amended Phase 1 ships the load-bearing variant directly. The triggers below now monitor the load-bearing surface for false-positives / undetected drift / generalisation pressure.)

Reassess if any of the following occur:

- The PreToolUse:Bash hook produces a sustained false-positive rate — legitimate commits (e.g. work-in-progress branches, intentional drift during a refactor) routinely BYPASS-bypass the gate without remediation. At that point, revisit the hook's drift-detection logic and consider tightening the BYPASS audit trail (e.g. require BYPASS to also stage a follow-up ticket).
- A plugin README cites a JTBD ID that resolves but is for the wrong persona (semantic drift the detector cannot catch). At that point, extend the detector to flag persona-mismatch as a `drift_hints=persona-mismatch` signal, OR add a `wr-jtbd:agent` review hook on README edits.
- Adopter-surface generalisation (marketing HTML, public docs, changelog narrative) becomes load-bearing for an adopter project. At that point, extend ADR-051 or author a sibling ADR for the adopter-surface mechanism (the source-of-truth anchor likely differs).
- A JTBD job is renamed or its status suffix changes during the per-release cadence. The detector resolves any-status-suffix matches per the established ADR-008 layout, so this is non-blocking; reassess if the resolution behaviour produces false positives or false negatives in practice.
- Generated READMEs (Option D4) become viable — e.g. an adopter's downstream tool generates READMEs from JTBD + SKILL.md and ships them. At that point, the detector should validate the generated content the same way it validates hand-authored content (the rule applies regardless of authorship).
- **(Added 2026-05-04 by P159 amendment)** Two or three more drift-class detectors arrive following the load-bearing-from-the-start shape (P159 variant). At that point, P161 (or its successor ticket) escalates the meta-question: should advisory-then-escalate be retired as the default for drift-class detectors generally? Until 2-3 more instances arrive, the meta-rule is observation, not codified guidance.

## Related

- **P152** — driver problem (No pressure or nudge for documentation currency); this ADR's normative rule + amended Phase 1 commit-hook close the asymmetric pressure-stack the ticket surfaces.
- **(Added 2026-05-04) P159** — amendment driver. P159 surfaced the user correction that retro-time advisory consumption is too late for drift class, and that the bolt-on `## Jobs to be Done` section reads as compliance theatre. This ADR's amendment ships the load-bearing-from-the-start commit-hook + rewrites the Recommended Section Structure clause to favour prose-weaving.
- **(Added 2026-05-04) P158** — sibling problem ticket; retro Step 2b wiring shipped under `df47ad1`. Retro wiring survives as a backup advisory after the P159 amendment migrates the primary surface to the commit-hook. P158 transitions Verifying → Closed in the P159 commit per architect verdict.
- **(Added 2026-05-04) P161** — sibling out-of-scope ticket (filed in the P159 commit) — broader question of whether advisory-then-escalate is the right default for drift-class detectors generally. Originating observation: P159. Codified meta-rule deferred until 2-3 more drift detectors arrive following the same shape.
- **JTBD-302** (newly filed alongside this ADR's original Phase 1) — Trust That the README Describes the Plugin I Just Installed; co-primary plugin-user job served by this ADR's rule. **(Added 2026-05-04)** JTBD-302's Desired Outcome bullet 6 is amended in the P159 commit to reflect commit-time enforcement (vs the original advisory-then-escalate phrasing).
- **JTBD-007** — Keep Plugins Current Across Projects (currency expansion: code-currency → doc-content-currency); co-primary driver. JTBD-007's file was amended in the original Phase 1 commit. **(Added 2026-05-04)** JTBD-007's currency phrasing is updated in the P159 commit to reflect commit-time enforcement (replacing the "advisory script" wording).
- **JTBD-301** — Report a Problem Without Pre-Classifying It (transitive: better READMEs → better mental models → better intake).
- **JTBD-101** — Extend the Suite with New Plugins (clear patterns, not reverse-engineering).
- **JTBD-001** — Enforce Governance Without Slowing Down (pressure-stack composition).
- **JTBD-202** — Run Pre-Flight Governance Checks Before Release or Handover (advisory-detector consumption surface).
- **ADR-002** — Monorepo with Independently Installable Per-Plugin Packages (per-package-README boundary).
- **ADR-003** — Marketplace-only distribution (READMEs ship via the marketplace cache; adopter sessions read them).
- **ADR-008** — JTBD directory structure (per-job-file layout that lets the detector resolve cited IDs deterministically).
- **ADR-013 Rule 6** — Non-interactive fail-safe / advisory-then-escalate pattern.
- **ADR-014** — Granular commits (the original ADR shipped in one commit with the script + bats + bin shim + JTBD-302 + changeset + JTBD-007 amendment; **(Added 2026-05-04)** the P159 amendment ships in one commit with the new hook + hook bats + ADR-051 amendment + JTBD-302 + JTBD-007 edits + 2 tactical README drift fixes + retrospective minor changeset + P159 transition + P161 ticket creation + P158 closure).
- **ADR-021** — Changesets for releases (the original ADR shipped under a `@windyroad/retrospective` minor bump; **(Added 2026-05-04)** the P159 amendment ships under another `@windyroad/retrospective` minor bump for the new hook).
- **ADR-040** — Session-start briefing surface (advisory-first / declarative-first precedent — Decision Drivers retain an advisory-first composition note even after the P159 amendment, because the rule itself is declarative and the hook is the load-bearing enforcement of the declarative rule).
- **(Added 2026-05-04) ADR-053 Bootstrapping clause** — precedent for "the introducing commit is exempt from the rule it introduces"; the P159 amendment commit either fixes pre-existing drift tactically or uses BYPASS_JTBD_CURRENCY=1 for legitimate one-time bootstrapping.
- **ADR-044** — Decision delegation contract (framework-resolution boundary informs whether Phase 2 escalation is silently agent-decided or surfaced via deviation-candidate).
- **ADR-049** — Plugin-bundled scripts via bin/ on `$PATH` (sibling adopter-context decision; executable correctness vs content currency).
- **P137** — Plugin-published artefacts reference internal IDs (sibling adopter-facing-content axis: semantic correctness).
- **P151** — Published skills reference repo-relative script paths (sibling adopter-facing-content axis: executable correctness; resolved 2026-05-02 via ADR-049).
- **P087** — No maturity / battle-hardening signal (sibling adopter-facing-content axis: maturity-label).
- **P099 / P134 / P145 / P148** — advisory-only-then-escalate precedents this ADR's Phase 1 detector follows.
- **P081** — behavioural-tests-over-structural-grep (the bats fixtures verify detector behaviour, not detector source structure).
