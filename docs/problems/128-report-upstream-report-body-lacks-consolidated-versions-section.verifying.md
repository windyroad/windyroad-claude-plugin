# Problem 128: /wr-itil:report-upstream report body lacks consolidated Versions section

**Status**: Verifying
**Reported**: 2026-04-26
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M — template change (yaml + structured-default fallback) + auto-detection helper functions in the skill + bats coverage for the new Versions block contract + ADR-033 amendment.
**WSJF**: 3.0 — `(12 × 1.0) / 2 = 6.0` marginal; `(12 × 1.0) / max(M=2, P064=L=4) = 12 / 4 = 3.0` transitive via P064 (P038 also composes-with but does not strictly block; only the risk-gate path is a hard prerequisite for landing the auto-population helper through the external-comms surface). Records the transitive value per ADR-022 / P076. <!-- transitive: M (marginal) → L (transitive) via P064 -->
**Type**: technical

## Description

`/wr-itil:report-upstream` (P055 Part B, ADR-024 outbound contract, ADR-033 problem-first classifier) emits an upstream-report body whose version information is **scattered**, not **consolidated**:

- The matched-template path (when the upstream's intake template carries a `version` field) populates that single slot — ambiguous which version it represents (local plugin? upstream package? Claude CLI?).
- The structured-default fallback (when no matched template exists) emits two adjacent line items in the body: `- Version: <detected via npm ls or local ticket's notes>` and `- Claude Code version: <claude --version>`. These are line items, not a labelled section, and they don't cover OS, Node version, upstream package's installed version, or fields that couldn't be detected.
- ADR-033 Step 5 names a single `## Environment` section with prose contents synthesised from session context — no auto-population of structured fields, no enforcement that all relevant version slots are at least attempted.
- The local intake template (`.github/ISSUE_TEMPLATE/problem-report.yml`) treats environment as a single freeform `textarea` whose placeholder text asks reporters to type plugin version, Claude Code version, and OS by hand.

Result: an upstream maintainer reading a report can't tell which version the bug applies to without replying-to-ask. Triage stalls on a question the report should already answer.

User direction (2026-04-26): outbound reports must include version information; downstream-side intake (which our `report-upstream` discovers in adopters' repos via ADR-036 scaffolding) must mirror the same shape so symmetry holds — what we ship out, we should accept in.

## Symptoms

- **Maintainer-side (upstream)**: receives a report; can't determine version applicability; replies asking "which version of `<pkg>` are you on?" before triage proceeds. Triage delay extends by one round-trip per report.
- **Reporter-side (us, when we're filing)**: `/wr-itil:report-upstream` emits a body whose version slots are partially populated and labelled inconsistently across template-vs-structured-default paths. The same report drafted twice (matched-template path vs. structured-default path) carries different version information.
- **Inbound-side (us, when we're receiving)**: downstream adopters using our `problem-report.yml` (ADR-036 scaffold) submit reports with freeform environment text; the inbound assessment pipeline (P079) cannot reliably parse version fields for the version-aware classification companion concern (P129).
- **Audit trail**: historical `## Reported Upstream` links in closed/verifying tickets carry no consistent version provenance — regression analysis ("did this recur in vN?") requires re-fetching the upstream issue body to look for ad-hoc version mentions.

## Workaround

Maintainer side: reply asking for version info; reporter manually adds `claude --version`, plugin version, OS to the body before posting. Plugin authors using `/wr-itil:report-upstream` from this skill suite manually copy-paste version output into the report body before invocation. None of this is enforced or automated; it's reporter discipline.

## Impact Assessment

- **Who is affected**:
  - **plugin-developer (`JTBD-101` — file high-quality reports against upstream packages)**: outbound report quality degrades without enforced version data; triage round-trips eat into the "extend the suite" workflow.
  - **plugin-user (`JTBD-301` — get heard upstream)**: report-to-acknowledgement latency extends by one maintainer round-trip per report; the structured intake's quality benefit is partially wasted.
  - **tech-lead (`JTBD-201` — audit trail)**: historical reports lack version provenance; cross-version regression analysis requires re-parsing each upstream issue body individually.
  - **solo-developer (`JTBD-001` — governance without slowing down)**: indirect — every report invocation requires manual version-prep effort that an auto-population helper would eliminate.
- **Frequency**: every upstream report. The plugin suite ships `/wr-itil:report-upstream` as the canonical outbound path per ADR-024; every external-root-cause ticket routes through it.
- **Severity**: Moderate (3) — non-catastrophic but systemic friction on every upstream-reported ticket. Not a security or correctness issue; a quality and triage-velocity issue.
- **Likelihood**: Likely (4) — no enforcement today; every report is at risk.
- **Analytics**: N/A today. Post-fix candidate metrics: (1) percentage of reports with all-Versions-fields populated, (2) maintainer round-trip count per report (proxy: count of comments before first triage label), (3) regression-analysis lookup time (qualitative).

## Root Cause Analysis

### Structural

`packages/itil/skills/report-upstream/SKILL.md` defines two body-shape paths:

- **Matched-template path** (when the upstream's `.github/ISSUE_TEMPLATE/<file>.yml` exists): the skill fills the matched template's required fields. The `version` field — when present — is a single-slot input. The skill's field-mapping table captures this:

  ```
  | `version` | Local ticket's environment notes; or `npm view <pkg> version` for the latest if ambiguous |
  | `claude-code-version` | `claude --version` if the report originates from a Claude Code session |
  ```

  Each row addresses a single slot. There is no contract that all five+ relevant version dimensions (local plugin, upstream package, Claude CLI, Node, OS) are populated. The skill picks one for the template's `version` field and stops.

- **Structured-default fallback path** (when no matched template exists): emits a body whose environment block reads:

  ```
  - Version: <detected via npm ls or local ticket's notes>
  - Claude Code version: <claude --version>
  ```

  Two line items, not a `## Versions` section. No OS, no Node, no upstream-package-installed-version. Adjacent line items, not a consolidated block.

ADR-024 Decision Outcome documents the structured default as `- Version: <detected via npm ls or local ticket>` — same single-line shape. ADR-033's Step 5 (problem-first classifier reshape) names a single `## Environment` section with prose contents — `<Claude Code version, OS, plugin versions — synthesised from session context or prompted>` — leaving the field shape implicit and unenforced.

The local intake template (`.github/ISSUE_TEMPLATE/problem-report.yml`):

```yaml
- type: textarea
  id: environment
  attributes:
    label: Environment
    description: Plugin version (`claude plugin list`), Claude Code version (`claude --version`), and operating system.
```

A single freeform `textarea` with a placeholder. Reporters can paste anything; nothing enforces shape; nothing auto-populates.

### Why it wasn't caught earlier

`ADR-024` scoped the report-upstream contract to outbound delivery. Body-shape granularity below "structured default with environment notes" was deferred. `ADR-033`'s reshape focused on the **classifier** (problem-first vs. bug-vs-feature dichotomy); the environment section's shape was carried over from ADR-024 without re-examination. `P055 Part A` shipped intake templates; `P066` corrected the classifier shape; neither modelled the version-info granularity the user is now asking for.

The user remembered this concern on 2026-04-26 (verbatim direction): *"hey, I just remembered for the reporting upstream, it needs to include version information if it doesn't already and then when we are receiving problems from downstream, we need to consider if the issue has already been fixed in a newer version or if it's recouured in a newer version, etc"*. This ticket captures the **outbound half** of that direction; the **inbound half** (version-aware assessment of received reports) is captured separately as P129 (companion ticket).

### Candidate fix shape

**Option A — ADR-033 amendment + skill-layer auto-population helper.**

1. **Amend ADR-033** Step 5 to replace the freeform `## Environment` section with a dedicated `## Versions` section carrying a fixed schema:

   ```markdown
   ## Versions

   - Local plugin: `@windyroad/<pkg>@<version>` (or "not detected" if reporting against a non-windyroad package)
   - Upstream package: `<pkg>@<version>` (or "not detected" if not applicable)
   - Claude Code CLI: `<claude --version output>` (or "not detected")
   - Node: `<node --version output>` (or "not detected")
   - OS: `<uname -a output or platform detection>` (or "not detected")
   ```

   Optional fields render as `not detected` rather than being omitted, so triage knows we tried each slot. The schema is fixed; the auto-population sources are documented; the parsing surface is stable for downstream consumers (P129's inbound classifier).

2. **Implement an auto-population helper** in the report-upstream skill before body drafting. Sources:
   - Local plugin version: read `package.json` for `@windyroad/*` packages, or `claude plugin list --json` (where applicable).
   - Upstream package version: `gh api repos/<owner>/<repo>/releases/latest` (for GitHub-hosted) or `npm view <pkg> version` (for npm-published).
   - Claude CLI: `claude --version` (best-effort; absence isn't an error).
   - Node: `node --version`.
   - OS: `uname -a` (POSIX) or platform-specific equivalent.

3. **Mirror the schema in the local intake template** (`.github/ISSUE_TEMPLATE/problem-report.yml`): replace the freeform `environment` textarea with a structured set of `input` fields matching the same schema (or keep the textarea but add five `input` fields above it for the structured slots). Per ADR-036, this propagates to downstream-scaffolded intakes via `/wr-itil:scaffold-intake`'s template-seed path.

4. **Bats coverage** for the new contract: assert a generated default body contains the `## Versions` section header; assert each schema field appears (populated or "not detected"); assert the matched-template path also emits the section when the upstream template doesn't carry equivalent fields.

**Option B — full new ADR for cross-cutting version-info contract.**

If the body-shape change is judged broad enough to warrant its own ADR (touches outbound report shape, inbound intake shape, scaffold-template seed, and the inbound-assessment pipeline P129 in one schema), a new sibling ADR — e.g. `ADR-NNN: version-info schema for problem reports (inbound + outbound)` — pairs ADR-024 (outbound delivery) and ADR-033 (problem-first classifier) and exposes the schema as a primitive both ends consume.

**Lean direction**: **Option A** — ADR-033 amendment is sufficient; the schema sits inside the body-shape ADR-033 already governs. Option B's primitive-extraction is a nice-to-have but inflates scope; defer to architect call at implementation time if the schema turns out to compose with more than the immediate two surfaces.

### Investigation Tasks

- [ ] Architect review: ADR-033 amendment vs. new sibling ADR. Confirm schema field set (5 fields proposed: local plugin, upstream package, Claude CLI, Node, OS) and "not detected" rendering rule.
- [ ] Draft the ADR-033 amendment documenting the consolidated `## Versions` schema and the inbound-symmetry contract with `problem-report.yml`.
- [ ] Implement the auto-population helper in `packages/itil/skills/report-upstream/`. Each source (package.json, gh api, npm view, claude --version, node --version, uname) needs a fail-soft path returning "not detected" rather than crashing the skill.
- [ ] Update the matched-template path's field-mapping table: when the matched template carries a `version` slot, populate it with the local plugin version; emit the full `## Versions` section in the body's prose alongside whatever single-slot the template requires (so the upstream maintainer has both the template's structured slot AND the consolidated schema).
- [ ] Update the structured-default fallback's body shape to carry the `## Versions` section as a labelled block, replacing the two adjacent line items.
- [ ] Update `.github/ISSUE_TEMPLATE/problem-report.yml` to mirror the schema — either structured `input` fields per slot OR a textarea with a placeholder enumerating the five fields. Architect call: structured fields are stricter but limit the reporter's ability to add custom version info; textarea-with-schema-placeholder is looser but easier to retrofit. Lean: structured fields, per the user direction's emphasis on enforcement.
- [ ] Wire into `/wr-itil:scaffold-intake` (ADR-036) so downstream-scaffolded intakes inherit the same schema. Bats coverage: scaffold a fresh project; assert the seeded `problem-report.yml` carries the same five fields.
- [ ] Compose with P129 (companion ticket — inbound assessment pipeline): verify the schema's parse-ability matches what P129's classifier needs to extract. If P129 requires additional fields, surface the requirement back to this ticket's schema before P129 implementation begins.
- [ ] Bats doc-lint assertions: any body-shape change to ADR-033 or the skill's body-template requires bats coverage per ADR-037.
- [ ] End-to-end test: invoke `/wr-itil:report-upstream` against a synthetic upstream repo (matched-template + structured-default paths); assert each generated body carries the `## Versions` section with all five fields populated or "not detected".
- [ ] Document the version-detection cost in the skill's preamble (gh api + npm view are network calls; cache where reasonable).

## Dependencies

- **Blocks**: P129 (companion — inbound version-aware assessment classification depends on this schema being stable enough for the classifier to parse)
- **Blocked by**: P064 (no risk-scoring gate on external comms — auto-populated Versions block is part of the comm body the gate scores). The Versions section adds new fields to the comm body the risk-gate evaluates; without P064 closed, the auto-population contract can't safely ship through the external-comms surface.
- **Composes with**: P070 (`.verifying.md` — adjacent body-shape gap on the same skill surface; both want stronger contracts on what `/wr-itil:report-upstream` emits), P038 (no voice-tone gate on external comms — same external-comms surface; Versions block contents pass through the gate), ADR-024 (outbound contract — partially-superseded predecessor; needs forward-pointer from ADR-024's `## Amendments` to ADR-033's amendment), ADR-033 (problem-first classifier — primary governing ADR; this ticket's fix amends Step 5), ADR-036 (downstream scaffolding — schema must propagate to seeded intakes), ADR-037 (bats doc-lint — new contracts require coverage)

## Related

- **P129** (`docs/problems/129-p079-inbound-assessment-pipeline-lacks-version-aware-classification.open.md`, companion ticket — INBOUND version-aware assessment classification for P079's pipeline; same user direction, opposite side of the contract; this ticket strictly blocks P129 because P129's classifier needs the Versions schema to parse reporter-version)
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.verifying.md`) — sibling concern on the same skill surface; existing-issue dedup gap. Both tickets want stronger contracts on what `/wr-itil:report-upstream` emits — this ticket on body shape, P070 on dedup-before-filing.
- **P063** (`docs/problems/063-manage-problem-does-not-trigger-report-upstream-for-external-root-cause.closed.md`) — trigger surface for `/wr-itil:report-upstream`. Inverse direction — P063 governs invocation; P128 governs body shape after invocation.
- **P064** (`docs/problems/064-no-risk-scoring-gate-on-external-comms.known-error.md`) — risk-gate that scores the comm body the Versions block extends.
- **P038** (`docs/problems/038-no-voice-tone-gate-on-external-comms.open.md`) — voice-tone gate on the same external-comms surface; Versions block contents pass through.
- **P055** (`docs/problems/055-no-standard-problem-reporting-channel.closed.md`) — shipped Part A (intake templates) + Part B (`/wr-itil:report-upstream`); this ticket strengthens the body-shape contract Part B emits.
- **P066** (`docs/problems/066-intake-templates-split-bug-feature-instead-of-problem.verifying.md`) — problem-first classifier shape; this ticket's intake-template change rides the same template the classifier landed.
- **P067** (`docs/problems/067-report-upstream-classifier-is-not-problem-first.closed.md`) — same classifier reshape; ADR-033 amendments share its predecessor's `## Amendments` lineage.
- **P079** (`docs/problems/079-no-inbound-sync-of-upstream-reported-problems.open.md`) — inbound discovery; P129 (companion to this ticket) carves out the version-aware classification step within P079's assessment pipeline.
- **ADR-024** (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — outbound contract; partially-superseded predecessor for the body shape this ticket changes. Forward-pointer to ADR-033 amendment lands in ADR-024's `## Amendments`.
- **ADR-033** (`docs/decisions/033-report-upstream-classifier-problem-first.proposed.md`) — primary governing ADR; this ticket's fix lands as an ADR-033 amendment to Step 5.
- **ADR-036** (`docs/decisions/036-scaffold-downstream-oss-intake.proposed.md`) — downstream scaffolding; the Versions schema must propagate to seeded intakes.
- **ADR-014** — governance skills commit their own work; the implementation work this ticket captures lands per ADR-014.
- **ADR-022** — lifecycle suffix-based status; this ticket follows the standard Open → Known Error → Verifying → Closed lifecycle.
- **ADR-037** — bats doc-lint; new body-shape contracts require coverage.
- **JTBD-101** (plugin-developer — extend the suite by filing high-quality upstream reports)
- **JTBD-201** (tech-lead — audit-trail clarity across version transitions)
- **JTBD-301** (plugin-user — get heard upstream by way of structured intake)
- **JTBD-001** (solo-developer — governance without slowing down; auto-population helper eliminates manual version-prep effort)

## Fold-fix (2026-05-03 — AFK iter 16)

**Status transition**: Open → Verifying.

**What landed**:

1. **ADR-033 amendment** added at `docs/decisions/033-report-upstream-classifier-problem-first.proposed.md` `## Amendments` section, dated 2026-05-03 (P128). Frontmatter gains `amended-date: 2026-05-03`. The amendment reshapes Step 5's structured default body: replace freeform `## Environment` with labelled `## Versions` carrying a five-field schema (Local plugin / Upstream package / Claude Code CLI / Node / OS); missing fields render as `not detected` (normative MUST). Applies to problem-shaped default AND bug-shaped fallback default; feature-shaped + question-shaped fallbacks unchanged (those use cases are not version-bound). Architect approved (no new ADR; amendment is the right vehicle — Step 5's body shape sits inside what ADR-033 already governs).

2. **ADR-024 forward-pointer** added in `## Amendments` (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) pointing at the ADR-033 2026-05-03 amendment.

3. **SKILL.md changes** (`packages/itil/skills/report-upstream/SKILL.md`):
   - Added `#### Versions schema (ADR-033 amendment 2026-05-03, P128)` block under Step 5's field-mapping table — documents the five-field schema, the normative `not detected` rendering rule, the auto-population sources (package.json / `claude plugin list`, `gh api` releases or `npm view`, `claude --version`, `node --version`, `uname -srm`), and the network-cost note for `gh api` / `npm view`.
   - Updated field-mapping table's `version` row to call out the consolidated-schema relationship.
   - Replaced the freeform `## Environment` block in the problem-shaped structured-default body with the labelled `## Versions` block.
   - Replaced the freeform `## Environment` block in the bug-shaped fallback default body with the same `## Versions` block.

4. **Intake template (this repo)** at `.github/ISSUE_TEMPLATE/problem-report.yml`: replaced freeform `environment` textarea with five structured `input` fields matching the schema.

5. **Scaffold-intake template** at `packages/itil/skills/scaffold-intake/templates/problem-report.yml.tmpl`: same five-input replacement, with substitution tokens preserved for downstream propagation per ADR-036.

6. **Bats coverage**:
   - `packages/itil/skills/report-upstream/test/report-upstream-contract.bats` — added six new assertions for the Versions schema (section-header presence, all five labels, `not detected` rule, ADR-033 amendment authority citation, auto-population sources enumeration, freeform-`## Environment`-section absent). Updated existing problem-shaped section-order test to use `## Versions` in place of `## Environment`.
   - `packages/shared/test/intake-templates.bats` — added `intake: problem-report.yml carries the consolidated Versions schema` test asserting the five `input` field labels; updated existing problem-ticket-sections test to drop `Environment` from its iteration list.
   - Both bats files carry a `tdd-review: structural-permitted (justification: P012 ...)` comment per ADR-052 line 198 (Migration clause: touched bats files retrofitted-with-justification when no behavioural alternative is yet expressible — P012 is the canonical harness-gap ticket).

7. **Changeset** at `.changeset/p128-consolidated-versions-schema.md` — `@windyroad/itil` minor bump.

**Out of scope for this iter** (deferred composables):

- **Auto-population helper bash code** — the SKILL.md instructions are sufficient for the LLM-driven skill; no extracted helper script needed today. If a runtime-helper extraction emerges later (driven by a behavioural-test harness gap closing), that becomes a separate ticket.
- **P129 inbound version-aware classifier** — companion ticket; depends on this schema being stable. Now unblocked.
- **P064 / P038 external-comms gate composability** — architect confirmed version strings are low-leak (factual identifiers, not prose) so the schema is safe to land before P064/P038 verify.

**Verification path**:

1. **Bats green** — `node_modules/.bin/bats packages/itil/skills/report-upstream/test/report-upstream-contract.bats` reports 30/30 ok; `packages/shared/test/intake-templates.bats` reports 12/12 ok; `packages/itil/skills/scaffold-intake/test/` reports 29/29 ok.
2. **First real `/wr-itil:report-upstream` invocation post-ship** — body should carry the `## Versions` section with all five fields populated (or `not detected` per the rule).
3. **Downstream scaffold-intake invocation** — adopters running `/wr-itil:scaffold-intake` should get the structured five-input intake template per ADR-036 propagation.

**Effort**: actual L (broader than M-frontmatter estimate — the bats retrofit + ADR-052 migration justification + intake-template symmetry across two source files added scope). Within iter wall-clock; no scope-expansion outcome.
