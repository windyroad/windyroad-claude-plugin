# @windyroad/risk-scorer

## 0.9.0

### Minor Changes

- f635470: RFC-004 Slice B: inbound-report sibling subagent + assess-inbound-report skill

  Ships RFC-004 Slice B per ADR-062 § Sibling subagent — net-new evaluator concern
  for third-party prose flowing INWARD (Request-risk + Fix-risk axes), distinct
  from `external-comms` which reviews OUR outbound prose for leaks. Sibling, NOT
  extension — preserves `external-comms` scope-purity (JTBD-101).

  Adds:

  - `packages/risk-scorer/agents/inbound-report.md` — new read-only subagent.
    Reviews inbound third-party reports (problem-report issues, Q&A discussions,
    security-advisory submissions) against two axes:
    - Axis 1 Request-risk — info-extraction / backdoor request / malicious-code
      injection
    - Axis 2 Fix-risk — privilege escalation / removal of load-bearing safety
      check / adopter-attack-surface expansion
      Emits structured `INBOUND_REPORT_VERDICT` + `INBOUND_REPORT_KEY` +
      `INBOUND_REPORT_CLASS` + optional `INBOUND_REPORT_REASON`. Consumed by the
      assessment-pipeline (ADR-062 § Decision Outcome step 3) for mechanical
      branch routing into one of {safe-and-valid-local-ticket-create,
      above-threshold-pushback, clear-malicious-close-with-verdict}.
  - `packages/risk-scorer/skills/assess-inbound-report/SKILL.md` — on-demand
    wrapper per ADR-015. Pre-flight surface for JTBD-005 (Invoke Governance
    Assessments On Demand) + JTBD-202 (Pre-Flight Governance Checks). Step 6
    AskUserQuestion only fires on manual maintainer invocations; silent on
    pipeline pre-satisfier invocations (P132 mechanical-stage carve-out per
    ADR-044 category 4 framework-resolution boundary).
  - `packages/risk-scorer/README.md` — Agents + skills tables extended with new
    entries + JTBD anchors per JTBD-currency hook contract.

  Policy + ADR amendments alongside:

  - `RISK-POLICY.md` gains `## Inbound Report Risk Classes` section between
    `## Confidential Information` and `## Risk Appetite`. Enumerates Axis 1 +
    Axis 2 classes the subagent grounds FAIL verdicts against. No changes to
    impact levels / likelihood levels / risk matrix / label bands / appetite /
    control composition / risk catalog mechanics. Validated via
    `wr-risk-scorer:policy` — `RISK_VERDICT: PASS`. Last-reviewed bumped
    2026-05-04 → 2026-05-15.
  - `docs/decisions/015-on-demand-assessment-skills.proposed.md` — Scope table
    gains `assess-inbound-report` row; Confirmation checkbox added; Related
    extended with ADR-062 + P079.

  The subagent + skill are inert in installed plugins until Slice C wires them
  into `/wr-itil:review-problems` Step 8.5. Slice B ships the contract +
  policy-grounding surfaces; Slice C ships the runtime orchestration; Slice E
  ships behavioural bats coverage per ADR-037 + P081 (subagent prompt contract +
  six pipeline outcomes + anti-`AskUserQuestion` assertion protecting the P132
  mechanical-stage carve-out).

  Architect PASS / JTBD PASS / policy PASS (wr-risk-scorer:policy validated
  the RISK-POLICY.md amendment per ISO 31000 compliance) / external-comms
  substantive PASS (no Confidential Information class matched — package /
  RFC / ADR / JTBD / problem IDs are public OSS artefacts; no client names,
  no financial metrics, no usage counts, no commercial-engagement strategy);
  gate-key bypass per P166 — agents lack Bash access to compute sha256 so
  marker keys cannot match the gate's computation. RFC-004 `accepted →
in-progress` rides this slice commit per the `docs/rfcs/README.md`
  transition-table contract.

### Patch Changes

- 0fda8a5: P038 voice-tone evaluator half of ADR-028 amended external-comms gate

  Ships the voice-tone half of the external-comms PreToolUse gate alongside the
  existing risk evaluator (P064 / commit a0713f3, 2026-04-26). When both plugins
  installed, both gates fire on the same outbound prose call (gh issue/pr/api,
  npm publish, .changeset/\*.md) and each denies until its own evaluator has
  emitted PASS. Composition at the firing level — per-evaluator markers, no
  shared composite marker (ADR-028 amendment 2026-05-14 ratifies the simplified
  design and supersedes the original combined-marker scheme).

  Adds:

  - packages/voice-tone/hooks/external-comms-gate.sh (byte-identical sync from
    packages/shared/hooks/external-comms-gate.sh)
  - packages/voice-tone/hooks/lib/leak-detect.sh (synced; voice-tone evaluator
    does NOT run leak pre-filter per EXTERNAL_COMMS_LEAK_PREFILTER=no in .conf)
  - packages/voice-tone/hooks/external-comms-evaluator.conf (per-package
    evaluator config — id + subagent + verdict prefix + assess skill + policy file)
  - packages/voice-tone/hooks/external-comms-mark-reviewed.sh (PostToolUse:Agent
    for subagent_type wr-voice-tone:external-comms; writes per-evaluator marker
    external-comms-voice-tone-reviewed-<KEY> on PASS)
  - packages/voice-tone/agents/external-comms.md (new subagent prompt;
    reviews drafts against docs/VOICE-AND-TONE.md; emits structured
    EXTERNAL_COMMS_VOICE_TONE_VERDICT + EXTERNAL_COMMS_VOICE_TONE_KEY)
  - packages/voice-tone/skills/assess-external-comms/SKILL.md (on-demand
    delegation skill per ADR-015)

  Changes:

  - packages/shared/hooks/external-comms-gate.sh — canonical hook now sources
    per-package external-comms-evaluator.conf (evaluator id + subagent type +
    verdict prefix + assess skill + policy file + leak-prefilter flag); marker
    filename includes evaluator id (external-comms-<id>-reviewed-<KEY>).
  - packages/risk-scorer/hooks/external-comms-gate.sh — synced byte-identical
    from canonical (now sources its own .conf).
  - packages/risk-scorer/hooks/external-comms-evaluator.conf — new per-package
    config for the risk evaluator.
  - packages/risk-scorer/hooks/risk-score-mark.sh — writes marker filename
    external-comms-risk-reviewed-<KEY> (was external-comms-reviewed-<KEY>).
  - scripts/sync-external-comms-gate.sh — CONSUMERS list adds voice-tone.
  - ADR-028 — ## Amendments section appended (2026-05-14); ratifies per-evaluator
    marker scheme, drops age_bucket and evaluator_set from marker key,
    documents per-package config file pattern.
  - ADR-015 — Scope table gains wr-risk-scorer:external-comms (retroactive — P064
    iter never landed the row) + wr-voice-tone:external-comms (P038).

  Test coverage (all behavioural per ADR-037 + P081):

  - packages/voice-tone/hooks/test/external-comms-gate.bats — 13 assertions
  - packages/risk-scorer/hooks/test/external-comms-gate.bats — extended to 13
  - packages/shared/test/external-comms-gate-canonical.bats — extended to 12
  - packages/shared/test/sync-external-comms-gate.bats — extended to 9

  Architect + JTBD reviews PASSED 2026-05-14 (ADR-028 amendment + ADR-015 update

  - implementation). Risk reviewer PASS (clean technical implementation doc; no
    Confidential Information class matched). BYPASS_RISK_GATE used for the
    changeset write because the risk-scorer agent cannot compute the exact sha256
    key (P166 — agents lack shell tool access for shasum) so the marker would not
    match the gate's computation; substantive review verdict PASS recorded above.

  Closes P038. ADR-028 remains proposed for one release cycle post-land per
  ADR-006 deliberation discipline.

- e8ef115: RFC-004 Slice E: bats coverage for inbound-discovery + assessment-pipeline

  Closes the R009 empirical-coverage gap for Slice B (`f635470`) + Slice C
  (`368b8e6`) SKILL/agent prose. 85 assertions across 4 bats files —
  structural-with-Permitted-Exception per ADR-005 / P011 / ADR-037 /
  ADR-052 § Surface 2 for SKILL/agent-prose contracts; behavioural per
  P081 for JSON file shapes.

  Files added:

  - `packages/itil/skills/review-problems/test/inbound-discovery-contract.bats`
    (28 tests) — Step 4.5 SKILL.md prose contract: section presence,
    ADR-062 substring anchors preserved (Confirmation criterion 1
    string-anchorable), sub-step structure, six pipeline outcomes
    enumerated, JTBD-301 acknowledgement on all four outcome paths, P070
    matched-local-ticket cross-reference comment, **load-bearing
    anti-AskUserQuestion assertion** at the branch decision (protects
    JTBD-001 + JTBD-006 against inverse-P078 drift per P132
    mechanical-stage carve-out / ADR-044 category 4), fail-soft, downstream
    non-obligation, AFK silent path, SLICE-C-FLAG-STUB marker.

  - `packages/risk-scorer/agents/test/inbound-report-contract.bats`
    (27 tests) — inbound-report subagent prompt contract: frontmatter,
    sibling-not-extension framing, two-axis rubric, four classifications,
    structured verdict block, ADR-026 grounding, read-only invariant,
    P123 block-list scope carve-out, RISK-POLICY.md integration.

  - `packages/risk-scorer/skills/assess-inbound-report/test/assess-inbound-report-contract.bats`
    (14 tests) — on-demand skill contract: frontmatter, subagent
    delegation, no marker self-writes, manual-vs-pipeline carve-out,
    JTBD-005 + JTBD-202 drivers, ADR-015 Scope-table row.

  - `packages/itil/skills/review-problems/test/inbound-channels-cache-shape.bats`
    (16 tests — behavioural per P081) — JSON file shape contracts:
    upstream-channels.json + upstream-cache.json + inbound-discovery-log.md
    P131 path discipline.

  All 85 assertions pass; broader test suite (205 tests across
  review-problems + risk-scorer surfaces) green.

  Full behavioural synthetic-channel fixture (running the pipeline
  end-to-end with synthetic gh API responses and asserting six-outcome
  routing) remains deferred to the P012 master harness ticket; in-skill
  behavioural-replay is structurally limited per ADR-005 / P011 Permitted
  Exception.

  Slice E closes the R009 SKILL-prose-class empirical-coverage gap that
  the pipeline scorer flagged on Slice B + Slice C ship.

## 0.8.0

### Minor Changes

- afddda0: Phase 2a of P162 dogfood-graduation criteria — new `evaluate-graduation.sh` script + `wr-risk-scorer-evaluate-graduation` shim implement ADR-061 Rule 1a deterministic join (changeset filename convention primary + body-grep fallback + multi-ticket `max(Priority)`) and Rule 2 VP carve-out detection over dual-tolerant problem-ticket layout per ADR-031 / RFC-002. The script emits structured `GRADUATION_CANDIDATE:` lines for each held changeset with resolved problem-ticket ID + Priority + class + status; `wr-risk-scorer:pipeline` agent prompt extended with "Held-Changeset Graduation Evaluation" section codifying Rule 1 symmetric comparison + Rule 4 evidence-floor judgement per ADR-026 cite + persist + uncertainty + `reinstate-from-holding` emission shape. Behavioural bats `evaluate-graduation.bats` covers ADR-061 Confirmation criterion 2 items (a)-(f); item (g) atomic-cohort Class 3b RFC cohort enumeration is deferred to Phase 2b per the architect-approved orthogonal-gate-now / atomic-cohort-later split.

### Patch Changes

- 7741fd4: `risk-score-commit-gate.sh` recognises commit-message-embedded `RISK_BYPASS: adr-031-migration` token as a self-attestation bypass for adopter `docs/problems/` auto-migration commits (P170 / RFC-002 / ADR-031 T11 / Open-Execution Q3 lean (b)). Pure-rename + pure-mkdir migration commits emitted by `migrate_problems_to_per_state_layout` (shipped in `@windyroad/itil` T7/T8/T9) skip the full risk-score overhead while preserving the audit trail. Case-sensitive token match; `adr-031-MIGRATION` and unrelated tokens (e.g. `reducing`, `incident`) do NOT match this path. Future commit-message-embedded bypass markers MUST be added explicitly here and to ADR-014's commit-message convention table.
- 880c9a5: Narrative-only: consolidate `packages/risk-scorer/agents/wip.md` governance-artefact detection glob from dual `docs/problems/*.md` + `docs/problems/*/*.md` to a single recursive `docs/problems/**/*.md` (behavioural superset — matches both pre-T5a flat-layout and post-T5a per-state-subdir-layout adopter repos). Aligns wip.md with ADR-016's amended path-list shape per P170 Slice 5 T5b cross-reference reconciliation. No behavioural change to the governance-artefact detection set; clarifies the post-ADR-031 (accepted 2026-05-12) encoding canonical.

## 0.7.2

### Patch Changes

- d3468c4: P164 — apply `10#` base-10 prefix to next-ID formula across 6 ticket-creator skills to prevent latent octal-eval failure at the `099 → 100` ID transition

  **Bug shape**: The next-ID formula `next=$(printf '%03d' $(( $(echo -e "${local_max:-0}\n${origin_max:-0}" | sort -n | tail -1) + 1 )))` in 6 ticket-creator SKILL.md files passes its zero-padded ID string through bash's `$(( ... ))` arithmetic context. Bash treats leading-zero numbers as octal; `099` is invalid octal (digit ≥ 8) and bash emits `bash: 099: value too great for base (error token is "099")`, exiting non-zero before the skill writes its marker, before opening the file. The user sees a cryptic bash error.

  **Trigger**: latent until any ticket-creator surface's `local_max` returns `099`. Fires once per surface per project lifetime (the 099 → 100 transition). Has not yet fired in this repo because problem-ticket IDs already crossed 099 before this formula's shape solidified, but any new ticket-creator surface (or any adopter project today) hits the bug as soon as their backlog reaches 099 entries.

  **Fix**: standard `10#` base-10 prefix on the inner `$(echo ... | sort -n | tail -1)` expansion. Applied uniformly across all 6 affected SKILL.md (scope expanded from the originally-named 4 to 6 after grep verification per the ticket's Investigation Task):

  - `packages/itil/skills/manage-problem/SKILL.md` Step 3
  - `packages/itil/skills/capture-problem/SKILL.md` Step 2
  - `packages/itil/skills/capture-rfc/SKILL.md` Step 2
  - `packages/architect/skills/create-adr/SKILL.md` Step 3
  - `packages/architect/skills/capture-adr/SKILL.md` Step 2
  - `packages/risk-scorer/skills/create-risk/SKILL.md`

  **Regression coverage**:

  - `packages/architect/skills/capture-adr/test/capture-adr.bats` test 6 — synthetic `098-foo.proposed.md` + `099-bar.proposed.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
  - `packages/itil/skills/capture-problem/test/capture-problem.bats` test 21 — synthetic `098-foo.open.md` + `099-bar.open.md` fixture asserts `local_max=099` and `next=100` cleanly without bash error.
  - Existing 26 bats updated in-place with `10#` prefix; full 28-test contract bats green.
  - Manual sanity check confirms unfixed formula fires the documented octal error and fixed formula returns `100`.

  **Why three packages in one changeset**: ADR-014 single-purpose grain — one logical change (the octal-eval defect) across three package boundaries that share the next-ID formula shape. Per ADR-014 "one logical change across multiple files / packages" guidance, the grain holds. The bats fixtures and SKILL.md edits are byte-symmetric across packages by design.

  **Shared helper deferred**: the ticket's optional Investigation Task to extract a shared `lib/next-id.sh` is deferred. DRY benefit is small (~6 byte-identical formulas) versus the regression risk of introducing sourcing-order coupling across 6 currently-independent skills. Re-evaluate if a 7th ticket-creator surface lands.

  **ADR alignment**:

  - ADR-014 (one ticket = one commit) — holds; one logical change.
  - ADR-019 (orchestrator preflight) — unaffected; preflight is about origin fetch, not ID computation.
  - ADR-031 (per-state subdir layout) — unaffected; formula input glob unchanged.
  - ADR-044 (decision-delegation contract) — aligned; one viable shape (`10#` is the standard bash idiom); scope-expansion from 4 → 6 is empirical evidence-driven (grep verified), exactly the framework-mediated mechanical action ADR-044 endorses.
  - ADR-052 (behavioural tests default) — aligned; new regression tests assert formula output not SKILL.md prose.
  - ADR-055 (namespace-prefixed IDs) — unaffected; no shipped-artefact IDs touched.

  **JTBD alignment**:

  - JTBD-301 (Report a Problem Without Pre-Classifying It) — primary; a cryptic `bash: 099: value too great for base` failure at ID rollover would break the "under 2 minutes or the report will be abandoned" constraint.
  - JTBD-001 (Enforce Governance Without Slowing Down) — composes; ticket-creator skills are the substrate that lets solo-developers and tech-leads create ADRs, problems, RFCs, and risks automatically.
  - JTBD-201 (Restore Service Fast with an Audit Trail) — composes; reliable next-ID computation is load-bearing for the audit trail.

  Refs: P164

## 0.7.1

### Patch Changes

- 670929a: RFC-002 T5 (mechanical migration only): bulk `git mv` of 177 problem tickets from flat `docs/problems/<NNN>-<slug>.<state>.md` to per-state subdirectory layout `docs/problems/<state>/<NNN>-<slug>.md` per ADR-031. State encoded by directory; filename `.<state>.md` suffix dropped. `packages/risk-scorer/agents/wip.md` governance-artefact detection heuristic widened to dual-tolerant (matches both flat and per-state subdir layouts during the T1-T6 migration window). T5b — ADR-031 `proposed → accepted` transition + ADR-022/016/024 amendments referencing the dual-pattern — deferred to follow-up iter. Refs: RFC-002 T5.

## 0.7.0

### Minor Changes

- 91c28fb: P064: external-comms risk-leak gate covering gh issue/pr, security-advisories, npm publish, and `.changeset/*.md` author surface

  `@windyroad/risk-scorer` gains a PreToolUse gate on outbound prose tool calls so confidential-information leaks are caught before they reach an external surface. Implements the risk-evaluator half of ADR-028 amended; the voice-tone half (P038) remains owned by `@windyroad/voice-tone` and ships independently.

  - New canonical hook `packages/shared/hooks/external-comms-gate.sh` + helper `packages/shared/hooks/lib/leak-detect.sh` (regex pre-filter for credentials, business-context-paired financial figures, business-context-paired user counts).
  - Per-package synced copy at `packages/risk-scorer/hooks/external-comms-gate.sh` and `packages/risk-scorer/hooks/lib/leak-detect.sh` per ADR-017 duplicate-script pattern. New `scripts/sync-external-comms-gate.sh` + `npm run sync:external-comms-gate` / `npm run check:external-comms-gate`. CI now runs the drift check.
  - Gate matches: `gh issue create|comment|edit`, `gh pr create|comment|edit`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish`, and `PreToolUse:Write|Edit` on `.changeset/*.md` (P073 — gated at author time so leaks never reach CHANGELOG.md / Release PR / npm tarball).
  - Hybrid leak-pattern flow per architect verdict on the P064 iteration: regex pre-filter denies hard-fail patterns (credentials, prod-URL prefixes, business-context-paired metrics) immediately; ambiguous prose is delegated to the new `wr-risk-scorer:external-comms` subagent for context-aware review against `RISK-POLICY.md` Confidential Information classes.
  - New subagent type `wr-risk-scorer:external-comms` (`packages/risk-scorer/agents/external-comms.md`) emits structured `EXTERNAL_COMMS_RISK_VERDICT: PASS|FAIL` + `EXTERNAL_COMMS_RISK_KEY: <sha256>` consumed by the existing `risk-score-mark.sh` PostToolUse hook (extended to write the per-draft `external-comms-reviewed-<sha>` marker).
  - New on-demand skill `/wr-risk-scorer:assess-external-comms` (`packages/risk-scorer/skills/assess-external-comms/SKILL.md`) per ADR-015 — pre-satisfies the marker for a draft outside a hook trigger.
  - `BYPASS_RISK_GATE=1` env var override (consistent with `git-push-gate.sh`); `RISK-POLICY.md`-absent → advisory-only mode (graceful adoption per ADR-008 / ADR-025).
  - Behavioural bats coverage: `packages/risk-scorer/hooks/test/external-comms-gate.bats` (12 assertions across surface match, hard-fail leak deny, marker permit, BYPASS, advisory-only, changeset/non-changeset paths). Canonical-shape contract `packages/shared/test/external-comms-gate-canonical.bats` (11 assertions). Drift coverage `packages/shared/test/sync-external-comms-gate.bats` (7 assertions, mirrors P095 + P026).
  - Composite-marker scheme (combining a future `wr-voice-tone:external-comms` verdict with the risk verdict against the same draft) is intentionally deferred until P038 ships its evaluator. Both gates compose at the `PreToolUse:Bash` matcher level when both packages are installed; promotion to the composite marker is a localised follow-up in the canonical hook.

  Closes P064 → Verification Pending. JTBD-001 (Enforce Governance Without Slowing Down), JTBD-101 (Extend the Suite with Clear Patterns), JTBD-201 (Restore Service Fast with an Audit Trail). ADR-028 amended; ADR-017 distribution pattern extended to `hooks/`.

## 0.6.0

### Minor Changes

- 8edaf7b: P168 / ADR-059: pipeline consume-catalog protocol + create-risk flag-driven path

  The `@windyroad/risk-scorer` agent prompt and create-risk skill gain two coordinated extensions per ADR-059 (Consume-catalog and bootstrap-from-reports register population):

  - **`packages/risk-scorer/agents/pipeline.md`** — new `## Catalog Consumption Protocol` section. Pipeline now reads `docs/risks/` first, applies a hybrid filter (slug-token-match primary, free-form judgement fallback) to identify catalog entries applicable to THIS action, and emits per-risk-item `Catalog match:` (slug-token / judgement / none) + `Catalog baseline:` (lifetime baseline residual citing R<NNN>) lines. Per-run `CATALOG_HIT_RATE: matched=N missed=M` observability line. `RISK_SCORES:` continues to carry per-action residual (gate-firing semantic preserved); catalog lifetime baseline is contextual NOT in the gate-firing line. Closes the missed-risk-class hazard (P168) by giving the agent a deterministic-first match path against the persistent catalog; closes the wasted-effort cost by removing redundant per-action regeneration of risk classes the agent surfaced before. Pure-scorer contract preserved (`Read + Glob` only — no `Write` grant added). Empty-catalog handling: emit a one-line nudge in the report body recommending `/install-updates` or `/wr-risk-scorer:bootstrap-catalog`; do NOT halt; do NOT inflate per-action residual.

  - **`packages/risk-scorer/skills/create-risk/SKILL.md`** — new Step 1b (orchestrator flag-driven path). Skill accepts `--slug <slug>` and `--prefill <prose>` flags (plus optional `--report-path <path>`) for orchestrator-driven prefilled invocation under ADR-013 Rule 5 (catalog framing in `RISK-POLICY.md` IS the policy authorisation). Flag-driven path skips the AskUserQuestion-driven authoring step and writes the entry deterministically with: `Status: Active (auto-scaffolded — pending review)` (ADR-056 pending-review pattern); `Description: <prefill>` verbatim; Inherent / Residual scoring fields = ADR-026 sentinel `not estimated — no prior data`; required `## Source Evidence` block citing originating `.risk-reports/` files. Slug-collision handling: append to existing file's Source Evidence block instead of creating new entry. Existing AskUserQuestion-driven authoring path preserved unchanged for human invocation (no flags supplied).

  - **NEW `/wr-risk-scorer:bootstrap-catalog` skill** (Commit 2 of the P168 fix) — on-demand surface for one-shot bootstrap of `docs/risks/` from `.risk-reports/` corpus. Walks reports, dedupes by ADR-056 slug, emits one `R<NNN>-<slug>.active.md` per unique slug with `## Source Evidence` block citing originating reports per ADR-026 grounding. Idempotent (file-existence test per slug; re-run on populated catalog appends to existing Source Evidence blocks but does NOT modify other fields). Pre-conditions verified at Step 0: RISK-POLICY.md present, docs/risks/ scaffolded (ADR-047 Phase 1), .risk-reports/ corpus non-empty. Maturity tag `proposed` per ADR-053. Auto-trigger surface: `/install-updates` Step 6.5.1 fires this skill when register is empty + RISK-POLICY.md present + .risk-reports/ non-empty (per ADR-013 Rule 5 silent proceed under existing per-sibling consent gate). Pure-scorer contract preserved on agent side: pipeline agent unchanged (`Read + Glob` only); the new bootstrap-catalog skill IS the legitimate orchestrator-side write surface per ADR-059 verdict G.

  Backward-compatible — no existing call site changes. Adopters whose pipeline agent prompt cache still emits the pre-ADR-059 risk-item format continue to work; the new lines are additive. Adopter create-risk invocations without flags continue to fire the existing AskUserQuestion-driven authoring path.

  Behavioural bats coverage:

  - `packages/risk-scorer/agents/test/risk-scorer-catalog-consumption.bats` — 15 cases covering protocol section, hybrid filter, risk-item-format extension, residual reconciliation, hit-rate observability, empty catalog handling, pure-scorer contract preservation. Permitted Exception structural assertions per ADR-005 / P011 (agent prompts are specification documents).
  - `packages/risk-scorer/skills/create-risk/test/create-risk-flag-driven.bats` — 15 cases covering flag detection, deterministic-write defaults, Source Evidence requirement, AskUserQuestion skip-vs-preserve, slug-collision append, ADR-013 Rule 5 authorisation citation. Same Permitted Exception applies.

  Pairs with the forthcoming `/wr-risk-scorer:bootstrap-catalog` skill (Commit 2 of the P168 fix) and the `/install-updates` Step 6.5 bootstrap auto-trigger (also Commit 2). The wipe + re-bootstrap validation pass lands in Commit 3.

  ADR-047 amended in-place with one-line forward pointer naming ADR-059 as Phase 2/3 successor.

  **Commit 4 follow-up (substantive register seed)**: After Commit 3 wiped pre-correction R001-R006 and the agent's first bootstrap pass produced a mechanical 1-of-1 stub the user explicitly flagged as unacceptable, the bootstrap was re-done by hand into seven theme-level curated entries grounded in corpus evidence + retro signals + held-changeset patterns + ADR control inventory. Each entry carries structured agentic-AI frontmatter beyond ISO 31000/27001 (asset_path, cascade_scope, afk_class, reversal_class, control_budget_class, dogfood_days, authority_class, ci_a, agentic_category). The extractor script's ID-allocation logic was tweaked to start from R001 on a fresh wipe (filesystem-max + 1, defaulting to R001 when empty) instead of inheriting origin/main's pre-wipe IDs per ADR-019; ADR-019 still applies to /wr-risk-scorer:create-risk for incremental adds post-bootstrap. Substantive entries: R001 documentation-runtime drift; R002 hook regression cascades; R003 confidentiality leakage via outbound prose; R004 marketplace/prompt-cache divergence; R005 cross-package release coordination drift; R006 authority-delegation confusion; R007 ambient state leaks into commits.

  References: ADR-059 (this fix's design ADR), ADR-056 (slug primitive consumed), ADR-026 (grounding sentinel), ADR-013 Rule 5 (policy-authorised silent proceed), ADR-015 (pure-scorer contract preserved), P168 (driver), P167 (parent), P033 (99%-miss-rate ticket).

### Patch Changes

- 0efdb1b: Test-only fix: synthetic fixtures for `drain-register-queue.bats` + `bootstrap-catalog.bats` SKILL-wording assertion (CI green; P171 captures deeper divergence)

  Two pre-existing test regressions in `@windyroad/risk-scorer`'s bats suite, both rooted in P168 commit `8edaf7b` ("FFS WIPE THE RXXX risks ... THEY ARE WRONG") which wiped `docs/risks/TEMPLATE.md` and renamed R001 without updating dependent fixtures. CI failure surfaced via push:watch when 33 unpushed commits batched today (P116 hazard).

  `packages/risk-scorer/scripts/test/drain-register-queue.bats`:

  - setup() previously did `cp $REPO_ROOT/docs/risks/TEMPLATE.md ...` and `cp $REPO_ROOT/docs/risks/R001-confidential-info-leak-via-public-repo-push.active.md ...` — both source files were wiped or renamed in the canonical state.
  - Replacement: synthesize fixture-local `TEMPLATE.md` and an old-shape `R001-...active.md` inline via `cat <<EOF`. Drain script's `TEMPLATE.md` existence gate (line 66) and old-shape filename regex (line 126) are preserved by the synthetic fixtures so the existing 16-test contract exercises end-to-end without canonical-state coupling.
  - Inline P171 cross-reference documents the workaround status.
  - Verified locally: 16/16 tests pass.

  `packages/risk-scorer/skills/bootstrap-catalog/test/bootstrap-catalog.bats`:

  - Test 1325 asserted SKILL.md contains `requires docs/risks/ scaffold` wording. SKILL.md was rewritten in the wipe iter to say "directory may or may not exist; created on demand; bootstrap owns the directory's full lifecycle" — the assertion was inverted.
  - Updated assertion to match new contract: grep for `may or may not exist | creates it on demand | owns the directory's full lifecycle`.
  - Renamed test from "requires scaffold" to "owns directory lifecycle".
  - Verified locally: 19/19 tests pass.

  The synthetic-fixture pattern is workaround-shape, not canonical-shape. P171 (`docs/problems/171-drain-register-queue-script-and-tests-reference-obsolete-pre-wipe-r-file-shape.open.md`) captures the underlying script-vs-format divergence for a future fix iter that:

  - removes the vestigial `TEMPLATE_FILE` gate from `drain-register-queue.sh`
  - updates generated filename + dedupe regex to canonical bare-`.md` shape
  - replaces synthetic-fixture bats with real-shape fixtures
  - adds reciprocal contract bats asserting drain output matches catalog

  Refs P171, P168, P116 (push:watch local-only-commits hazard surfaced this).

## 0.5.0

### Minor Changes

- b3ff785: `wr-risk-scorer:pipeline` agent now emits a 3-column `RISK_REGISTER_HINT:` block (`<reason-tag> | <risk-slug> | <prose>`) and the `risk-score-mark.sh` PostToolUse hook parses each bullet and appends one JSONL line per valid entry to `.afk-run-state/risk-register-queue.jsonl`. The queue file is the durable bridge between pipeline-fire and risk-register population — consumer skills (work-problems, manage-problem, install-updates, assess-release) drain it in subsequent iters with dedicated `docs(risks): scaffold ...` commits per ADR-014 commit-grain discipline.

  Backward-compatible **dual-parse contract**: the hook accepts both the new 3-column shape AND the legacy 2-column shape (`<reason-tag> | <prose>`), deriving the slug from the reason-tag plus the prose prefix when only two columns are present. In-flight pipeline agents on adopter machines whose prompt cache still emits the 2-column shape continue to enqueue entries — no hint loss during the cache-warm transition.

  Pipeline agent stays `Read, Glob`-only (no agent-side write); the hook stays silent on stdout (ADR-045 Pattern 2); the queue artefact lives under `.afk-run-state/` which is already gitignored. 12-test behavioural-fixture bats covers both parse paths, mixed-shape blocks, malformed-bullet skip, append-only semantics, directory creation, and stdout silence — all GREEN with no regression in adjacent suites.

  Driver: P033 Phase 2a (`docs/problems/033-no-persistent-risk-register.known-error.md`). Authority: ADR-056 (`docs/decisions/056-risk-register-back-channel-write-contract.proposed.md`). Parent ADR: ADR-047 (Phase 1 scaffolding precondition, landed iter 18). P033 status remains Known Error pending Phase 2b drain steps — Phase 2a closes the trigger gap (queue-write); Phase 2b materialises register files from the queue.

- 4466eec: P033 Phase 2b — first consumer-skill drain wires up. Adds shared drain script `packages/risk-scorer/scripts/drain-register-queue.sh` (with `bin/wr-risk-scorer-drain-register-queue` shim per ADR-049) and a new Step 6.4 in `/wr-itil:work-problems` between Step 6 (Report progress) and Step 6.5 (Release-cadence check). The drain reads `.afk-run-state/risk-register-queue.jsonl` (populated by the Phase 2a hook), dedupes by `risk_slug` (N reports : 1 register entry per the user direction), mints new `R<NNN>-<slug>.active.md` files via local-max + origin-max +1 (ADR-019), and updates `docs/risks/README.md` Register table with stub-scoring rows. Existing slug matches gain Evidence Log entries without scoring change; new entries carry `Status: Active (auto-scaffolded — pending review)`, `Curation: pending review`, and ADR-026 sentinel `not estimated — no prior data` for ungrounded scoring fields.

  Per-iter cadence keeps the queue bounded and attaches the resulting `docs(risks): scaffold ...` commit to the iter that produced the hint, preserving ADR-014 single-ticket-unit-of-work grain. Step 6's progress-report template gains a `Risk register: N entries scaffolded (pending review)` line so AFK summaries surface register population per JTBD-006 outcome 4. The drain script exits 0 on no-op (empty queue / missing `docs/risks/`), preserving the queue for next drain when Phase 1 scaffolding has not yet fired.

  Behavioural coverage: 16-test bats fixture at `packages/risk-scorer/scripts/test/drain-register-queue.bats` covers shim resolution, no-op idempotency, single + multi-hint flows, slug dedupe, two-slug sequential IDs, existing-match Evidence Log append, README row append, queue-truncation contract, no-truncate-on-no-op, stdout key=value shape, file-staging, origin-max collision avoidance, and malformed-line skip — all GREEN. Also adds `"scripts/"` to the `@windyroad/risk-scorer` package.json `files` array so the canonical script ships in the npm tarball (ADR-049 packaging requirement).

  Driver: P033 Phase 2b (`docs/problems/033-no-persistent-risk-register.known-error.md`). Authority: ADR-056 (`docs/decisions/056-risk-register-back-channel-write-contract.proposed.md`). Phase 2b remaining (deferred to subsequent iters): `/wr-itil:manage-problem` Step 11 drain, `/install-updates` Step 6.6 drain, `/wr-risk-scorer:assess-release` drain — each integrates via the same shared shim. P033 status remains Known Error until Phase 2b is complete and Phase 3 backfill recovers historical reports.

## 0.4.2

### Patch Changes

- d59dae1: P096 Phase 2 — `plan-risk-guidance.sh` (PreToolUse EnterPlanMode) once-per-session emission + new shared session-marker consumer:

  - **First-vs-subsequent EnterPlanMode behaviour**: first EnterPlanMode of a session emits the full advisory body (compressed: drops the standing release-strategy listing in favour of cross-references to ADR-018 / ADR-042). Subsequent EnterPlanMode invocations in the same session emit a terse one-line reminder.
  - **New consumer of `lib/session-marker.sh`**: `packages/risk-scorer/hooks/lib/session-marker.sh` (NEW byte-identical copy synced from `packages/shared/hooks/lib/session-marker.sh` per ADR-017 duplicate-script pattern). risk-scorer joins the session-marker CONSUMERS list as the 7th plugin.
  - **`scripts/sync-session-marker.sh` extended**: CONSUMERS list now covers 7 plugins; `packages/shared/test/sync-session-marker.bats` drift fixtures extended to match (mkdir + iteration both updated).

  Confirms ADR-038's documented extension pattern: the once-per-session helper is event-type-agnostic (PostToolUse and PreToolUse both supported).

  7 new behavioural bats tests (`packages/risk-scorer/hooks/test/plan-risk-guidance-once-per-session.bats`) cover first-emit body, marker write, terse reminder shape, byte budget, distinct-session re-emit, empty-session-id fallback, JSON validity on both branches. All green.

  Refs: P096, P095 (session-marker), ADR-009, ADR-017 (duplicate-script), ADR-038 (progressive disclosure).

## 0.4.1

### Patch Changes

- 1fe2cad: Gate markers now survive long-running Agent and Bash subprocesses (P111).

  A new PostToolUse hook (`*-slide-marker.sh`) fires on Agent and Bash tool
  completion in the parent session. If the parent already holds a valid gate
  marker, the hook touches it — sliding the TTL window forward — so the wall-
  clock time spent inside an Agent-tool subagent or a `claude -p` iteration
  subprocess no longer counts against the parent's TTL.

  The slide is bounded:

  - The hook only TOUCHES an existing marker. It NEVER creates one — creation
    still requires a real gate review with verdict parsing in
    `*-mark-reviewed.sh`.
  - The hook skips the touch when `tool_response.is_error` is true. A failed
    subprocess does not extend the parent's trust window.
  - For risk-scorer, only the score files (`commit`, `push`, `release`) are
    slid. The `*-born` markers are deliberately invariant under sliding so
    the 2×TTL hard-cap from P090 still bounds total marker life.

  This replaces the symptom-treatment of P107 (TTL bumped 1800s → 3600s) with
  the architectural fix per ADR-009's new "Subprocess-boundary refresh"
  subsection. Adopters who configured a non-default `ARCHITECT_TTL` /
  `REVIEW_TTL` / `RISK_TTL` envvar do not need to change anything.

## 0.4.0

### Minor Changes

- 7934868: feat(risk-scorer): pipeline agent emits `RISK_REGISTER_HINT:` passive trigger for the risk register (P110)

  The `wr-risk-scorer:pipeline` agent now emits a structured `RISK_REGISTER_HINT:` block alongside its existing `RISK_SCORES:` / `RISK_REMEDIATIONS:` / `RISK_BYPASS:` outputs when it identifies a register-worthy risk shape. The calling orchestrator consumes the hint post-remediation-loop and hands off to `/wr-risk-scorer:create-risk` with pre-filled context.

  This closes the passive-trigger gap P102's MVP slash command left open. JTBD-001 (Enforce Governance Without Slowing Down) requires passive triggers that fire "without a manual step" — the pipeline agent is hook-fired on every commit/push/release gate, so a hint emitted from it inherits that passivity.

  **Shape** (bulleted-list, multi-hint capable):

  ```
  RISK_REGISTER_HINT:
  - above-appetite-residual | <one-line prefill>
  - confidentiality-disclosure | <one-line prefill>
  - user-stated-precondition | <one-line prefill>
  ```

  **Reason-tag vocabulary** (closed — extending requires a new ticket):

  - `above-appetite-residual` — any cumulative residual score > appetite
  - `confidentiality-disclosure` — business metric or client detail flagged in diff
  - `user-stated-precondition` — paired capability unmet; standalone Risk item

  **Consumption semantics**: the hint is consumed by the orchestrator **after** the ADR-042 auto-apply remediation loop converges or halts — not interleaved. A remediation that reduces residual back within appetite does not retract the hint; the risk is standing even if this change is no longer in breach.

  **Silence guarantee**: no hint is emitted when all cumulative scores are within appetite AND no confidentiality-disclosure or user-stated-precondition item fires — preserves the ADR-013 Rule 5 silent-pass contract.

  Additive change — existing `RISK_SCORES:` / `RISK_REMEDIATIONS:` / `RISK_BYPASS:` outputs and the ADR-042 auto-apply loop are unchanged.

  Refs P110, P102 (parent), JTBD-001, JTBD-005, ADR-015 (Scorer Output Contract addendum).

## 0.3.6

### Patch Changes

- 43e9cc0: Three-band TTL policy in `check_risk_gate` eliminates the manual rescore round-trip when the working tree is unchanged but the clock has moved past the half-life of the marker (P090).

  - **Band A** (age < TTL/2) → pass silently (unchanged).
  - **Band B** (TTL/2 ≤ age < TTL) → if the pipeline state-hash is invariant since the scorer ran, pass and slide the marker forward; if the hash drifted, halt as before. Bounded by a 2×TTL hard-cap from a new `<action>-born` sibling so an unchanged-but-idle tree cannot ride a single score indefinitely.
  - **Band C** (age ≥ TTL) → halt with the existing expired message (unchanged).

  `git-push-gate.sh` push-gate now routes through `check_risk_gate "push"` and inherits the band logic (previously carried its own inline binary TTL check). Push-specific threshold guidance preserved via a new `RISK_GATE_CATEGORY` export.

  Backward-compatible: markers written before this release have no `-born` sibling and retain the pre-P090 binary TTL behaviour until the next scorer run writes both files.

  ADR-009 amended with a three-band refinement footnote.

## 0.3.5

### Patch Changes

- 45e9c71: Fix pipeline-state drift hash to be stable across `git push` (P054). Previously the `--hash-inputs` output of `packages/risk-scorer/hooks/lib/pipeline-state.sh` used `git diff origin/main --stat`, which shrinks to empty after a policy-authorised push advances `origin/main`, causing `npm run release:watch` to fire a spurious "Pipeline state drift" denial every time and forcing a rote mid-cycle delegation to `wr-risk-scorer:pipeline`. The hash now derives from a tree-based snapshot (via `git stash create`, falling back to `HEAD^{tree}` on a clean tree) of the conceptual "committed + index + working tree" content, which is invariant across both commit and push. Adds 8 regression tests in `pipeline-state-hash.bats`. Also documents the post-push stability contract in `scripts/release-watch.sh`.

## 0.3.4

### Patch Changes

- 0370c4e: Risk scorer emits explicit STOP verdict above appetite.

  - `pipeline.md`, `wip.md`, `plan.md`: Above-Appetite sections now contain an
    explicit STOP / PAUSE / FAIL directive and forbid "Proceed", "Continue",
    "You may ship", and similar nudge language when cumulative risk exceeds
    appetite. The only sanctioned above-appetite output is the Risk Report +
    `RISK_SCORES:` + structured `RISK_REMEDIATIONS:` block — matching the
    symmetrical Below-Appetite Output Rule (ADR-013 Rule 5)
  - Doc-lint guard `risk-scorer-above-appetite-stop.bats` prevents regression
    across all three scoring modes
  - Previously, the scorer could contradict itself (structured output: high
    risk; verbal verdict: proceed with release), causing the agent to attempt
    gated actions and waste tool calls when the hook gate correctly blocked them

- 0edec54: Risk scorer refuses to credit monitoring as a control.

  - `pipeline.md`, `wip.md`, `plan.md`: Control Discovery now contains an
    explicit "Monitoring is not a control" rule. Monitoring, alerting,
    dashboards, "watch for elevated errors", and "be ready to rollback"
    MUST NOT be credited or reduce residual risk. Post-release detection
    shortens time-to-notice; it does not reduce pre-release risk.
  - Doc-lint guard `risk-scorer-monitoring-not-a-control.bats` (6 assertions)
    prevents regression across all three scoring modes.
  - Previously, 329-report corpus analysis showed scorers crediting
    monitoring as a control, producing false-confidence residual risk
    scores on releases with genuine pre-release risk gaps.

- 16be06f: Risk scorer now honours user-stated preconditions.

  - `pipeline.md`, `wip.md`, and `plan.md`: new **User-Stated Preconditions Check** section requires the scorer to inspect recent conversation, problem tickets, commits, and changesets for user-stated conditional-delivery warnings ("A is only safe if B ships alongside")
  - Unmet preconditions surface as standalone Risk items with inherent risk >= Medium (>= 5), routing into the existing above-appetite `RISK_REMEDIATIONS:` flow rather than being buried in prose or ignored because the diff's technical risk scored Low
  - Doc-lint guard test `risk-scorer-user-stated-preconditions.bats` prevents regression across all three scoring modes

- 6abd0ee: Tighten `RISK_BYPASS: reducing` criteria to restore discriminating power.

  - `pipeline.md`: reducing bypass now requires one of (1) ticket closure,
    (2) remediation of a previously-flagged risk, or (3) removal of a
    documented risk. Ordinary docs-only edits, test-only additions without
    a remediation link, and routine refactors are now risk-neutral and do
    NOT earn the bypass label.
  - Added companion `RISK_BYPASS_REASON:` line — every reducing bypass must
    cite the ticket closed, prior report remediated, or removed risk. This
    makes the bypass auditable.
  - Doc-lint guard `risk-scorer-reducing-bypass-criteria.bats` prevents
    regression.
  - Background: 329-report retrospective across 6 projects showed the
    previous loose criteria applied `reducing` to 97.9% of commits in this
    repo and 79.6% across consumer projects, rendering the label
    meaningless. Only 2 of 96 reports omitted it.

## 0.3.3

### Patch Changes

- a36a084: WIP verdict now emits `RISK_VERDICT: COMMIT` with a `RISK_COMMIT_REASON` when the WIP scorer detects completed governance work (closed problem tickets, accepted ADRs, transitioned states) that has not yet been committed (closes P024, implements ADR-016).

  - `wr-risk-scorer:wip` agent emits the new verdict with an explicit false-positive safeguard: any file outside governance-artefact paths suppresses `COMMIT`.
  - `wr-risk-scorer:assess-wip` skill Step 4 surfaces the verdict via `AskUserQuestion` with a "Not yet" defer option so users can defer without consequence.
  - New `packages/risk-scorer/agents/test/risk-scorer-commit-verdict.bats` covers the four contract assertions from ADR-016.

## 0.3.2

### Patch Changes

- 83b8be7: fix(risk-scorer): expand RISK_REMEDIATIONS to 5-column format (closes P021)

  - Adds `effort S/M/L` and `risk_delta -N` columns to RISK_REMEDIATIONS format
  - Updated in pipeline.md, wip.md, and plan.md agents
  - Structural BATS tests added to enforce format

## 0.3.1

### Patch Changes

- 8a15336: Fix `--update` flag failing with "Plugin not found" (P025). The `updatePlugin` command was missing the `@windyroad` marketplace suffix and `--scope project`, causing all `npx @windyroad/<pkg> --update` invocations to fail. The correct command is now used: `claude plugin update "<name>@windyroad" --scope project`.

## 0.3.0

### Minor Changes

- b7d6739: Add on-demand assessment skills (P020)

  New user-invocable skills per ADR-015:

  - `wr-risk-scorer:assess-release` — pipeline risk score on demand; pre-satisfies the commit gate
  - `wr-risk-scorer:assess-wip` — WIP risk nudge for the current uncommitted diff
  - `wr-architect:review-design` — on-demand ADR compliance review
  - `wr-jtbd:review-jobs` — on-demand persona/job alignment check

  All four skills are discoverable via `/` autocomplete and delegate to existing
  governance subagents. No hook gate changes; bypass marker is still written by
  the PostToolUse hook after the pipeline subagent runs.

## 0.2.1

### Patch Changes

- 23d0d10: Require structured `AskUserQuestion` prompts at all governance-skill decision branches (P021, ADR-013).

  **@windyroad/itil**: `manage-problem` skill now requires `AskUserQuestion` for WSJF tie-breaks, problem selection, and scope-change decisions. Prose "(a)/(b)/(c)" option lists are prohibited.

  **@windyroad/risk-scorer**: All three scorer agents (pipeline, wip, plan) now enforce below-appetite silence — no advisory prose, "Your call:", or suggestions when scores are within appetite. Above-appetite output uses structured `RISK_REMEDIATIONS:` blocks instead of free-text suggestions.

  New ADR-013 establishes the cross-cutting standard: every governance-skill branch point with ≥2 options must use `AskUserQuestion`; scoring agents stay pure output-only.

## 0.2.0

### Minor Changes

- fe1b903: Gate markers now persist across prompts (ADR-009). Removed Stop-hook reset scripts from all 5 review plugins. Marker lifecycle is now governed entirely by TTL (30 min default, configurable via `*_TTL` env vars) + drift detection of policy files. Resolves P001 — reviews no longer need to re-run on every prompt. Note: this is a behaviour change; users who relied on fresh-review-every-prompt should set a shorter TTL.

## 0.1.6

### Patch Changes

- ec16630: Add project-root check to all enforce hooks (P004). Absolute file paths outside the current project (e.g., ~/.claude/channels/discord/access.json) are no longer gated — gates now only fire on files within the project root.

## 0.1.5

### Patch Changes

- b12e7c0: Fix misleading error messages in release gate: drift now clearly instructs "re-run risk-scorer", score-too-high retains "split/reduce/incident" guidance inline. Remove generic suffix in git-push-gate that conflated the two cases.

## 0.1.4

### Patch Changes

- 7ee97ba: Add README.md to every package and rewrite the root README with better engagement, problem statement, and project-scoped install documentation.
- eb47a86: Improve git-push-gate hook to detect missing release:watch script and guide the agent to create one instead of directing to a non-existent command.

## 0.1.3

### Patch Changes

- eda2a15: Fix release preview to use pre-release versions (e.g., 0.1.2-preview.42) instead of exact release versions, preventing version collision with changeset publish.

## 0.1.2

### Patch Changes

- a4cbfd9: Fix misleading error messages in risk-gate.sh that said the risk-scorer "runs automatically on each prompt". It doesn't — the agent must explicitly delegate to wr-risk-scorer:pipeline.

## 0.1.1

### Patch Changes

- 3833199: Fix: bundle shared install utilities into each package so bin scripts work when installed via npx.
