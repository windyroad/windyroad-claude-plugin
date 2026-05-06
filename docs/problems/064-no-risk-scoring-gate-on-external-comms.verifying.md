# Problem 064: No risk-scoring gate on external communications

**Status**: Verification Pending
**Reported**: 2026-04-20
**Priority**: 12 (High) — Impact: Significant (4) x Likelihood: Possible (3)
**Effort**: L — new PreToolUse hook surface covering `gh issue create`, `gh issue comment`, `gh pr create`, `gh pr comment`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish` (with README diff), plus leak-pattern rules and integration with `wr-risk-scorer` subagent. Sibling-ADR path collapsed into amended ADR-028 (2026-04-21); risk evaluator implementation per architect verdict (c) on the P064 iteration — shared canonical hook + risk-scorer per-package copy + new subagent + new on-demand skill.
**WSJF**: 0 — Verification Pending excluded from dev-work ranking per ADR-022 (was 6.0 as Known Error).
**Type**: technical

## Direction decision (2026-04-20, user — AFK pre-flight via AskUserQuestion)

**Placement**: extend `wr-risk-scorer`. The gate lives as a new hook (`packages/risk-scorer/hooks/external-comms-gate.sh`) and a new subagent type `wr-risk-scorer:external-comms` (or an extension of `wr-risk-scorer:pipeline` with an external-comms scoring layer — architect call at implementation time). Keeps scoring in one plugin, avoids a new package publish and an ADR-002 graph update. Sibling ADR to ADR-028 governs the surface list, scoring path, and override.

**Override path**: `BYPASS_RISK_GATE=1` env var pattern consistent with `packages/risk-scorer/hooks/git-push-gate.sh`. Documented in the sibling ADR.

**Ship ordering**: P064 can ship in parallel with P038 (voice-tone gate on external comms) — they share the surface inventory but evaluate different content. Architect review decides whether the two hooks compose in one `PreToolUse:Bash` entry or remain separate.

## Description

The `wr-risk-scorer` plugin governs risk on **inbound** pipeline changes — commit, push, release — via `packages/risk-scorer/hooks/git-push-gate.sh` and the `wr-risk-scorer:pipeline` / `assess-release` scoring paths. There is **no equivalent gate on outbound prose** produced for external surfaces:

- `gh issue create` / `gh issue comment` — upstream or cross-repo issue bodies can carry client names, internal prod URLs, schema excerpts, pricing figures, user counts, or other confidential metadata scraped from the local repo context.
- `gh pr create` / `gh pr comment` — PR descriptions against external repos have the same exposure surface.
- `gh api repos/.../security-advisories` — advisory drafts can leak exploitation detail that belongs in a private channel only.
- `npm publish` with a README diff — publishing a package whose README mentions an unannounced feature, a client-specific integration, or a pre-GA capability exposes commercially-sensitive material.
- RapidAPI / marketplace push surfaces — product-page copy sent to third-party marketplaces is external communication with the same exposure pattern.

P038 (No voice-and-tone gate on external communications) covers the **style/tone** half of "Missing voice/risk checks on external output" (the friction category named in the 30-day insights report). This ticket covers the **risk/leak** half, which P038 names in its analytics line but does not scope in its own fix. The two gates are architecturally parallel (both are PreToolUse hooks on the same surface list) but evaluate different content:

- **Voice-and-tone gate (P038)**: rewrites prose to match `docs/VOICE-AND-TONE.md`, strips AI-tell patterns, age-checks target issues.
- **Risk-scoring gate (this ticket)**: detects leak patterns (client names, revenue figures, prod URLs, credentials-shaped tokens, internal roadmap references, any content flagged as `Contains confidential business metrics` by RISK-POLICY.md), halts and surfaces to the user before the outbound call lands.

Absent this gate, every `/wr-itil:report-upstream` invocation (ADR-024), every upstream comment, every npm README publish, every marketplace push is a potential leak event that depends on ad-hoc user review rather than a deterministic gate.

## Symptoms

- Agents draft upstream issue bodies from local-ticket content that includes client names, prod URLs, or internal-system references; the user catches these after-the-fact during a read-through (or doesn't).
- README updates ship via `npm publish` with descriptions of features that are still under embargo or tied to a specific customer rollout.
- PR comments to external repos include repro data (transcripts, log excerpts) whose surrounding context would leak internal architecture or client identity.
- `gh api .../security-advisories` bodies describe exploitation steps in a level of detail that belongs only in the vendor-private channel — agent cannot tell which detail is safe for eventual public advisory publication.
- RISK-POLICY.md's confidential-metrics exclusion applies to the risk-report artefacts (`.risk-reports/`) but not to external-comms bodies — the confidentiality bar is inconsistent across inbound and outbound surfaces.
- `/Users/tomhoward/.claude/usage-data/report.html` 30-day report: "Missing voice/risk checks on external output" is one of the three top friction categories; P038 addresses the voice half but the risk half stays open.

## Workaround

User manually reviews every external-comms draft before it lands. This is the same manual-policing pattern P038 documents as the "manually police AI output" pain point — doubled in practice, because the user has to check both tone AND leak risk on every outbound call. For `/wr-itil:report-upstream` specifically, the skill's voice-tone gate (ADR-028) catches tone issues but has no matching risk-scoring pass.

## Impact Assessment

- **Who is affected**:
  - **Solo-developer persona (JTBD-001)** — every external-comms tool call is a leak-risk moment the persona must police manually; "Enforce governance without slowing down" fails here because the governance surface doesn't cover the highest-consequence outbound channel.
  - **Tech-lead persona (JTBD-201)** — audit trail gains outbound records (good) but those records can carry content that should not have left the repo (bad); the fix-fast-with-audit-trail promise becomes a liability when audit contents leak.
  - **Plugin-developer persona (JTBD-101)** — reusable patterns for external-comms reporting (P055 Part B, `report-upstream`) ship without the risk gate their architecture assumes, so downstream adopters inherit the same exposure.
  - **Anyone receiving upstream reports from this suite** — upstream maintainers (whose repos are targeted by `/wr-itil:report-upstream`) receive reports whose content the sender hasn't risk-scored.
- **Frequency**: Every external-comms tool call. Observed rate across the 30-day insights window: dozens of outbound calls per week across `gh issue`, `gh pr`, and `npm publish` combined.
- **Severity**: Significant. The worst-case outcome is a public issue, advisory, or npm README carrying a client name, revenue number, or unannounced-product detail. Unlike voice-tone (reputational, recoverable), risk-leak incidents are durable (public artefacts are hard to unpublish) and can be contractually serious.
- **Analytics**: `/Users/tomhoward/.claude/usage-data/report.html` — friction category "Missing voice/risk checks on external output" (shared with P038); the insights report explicitly recommends a mandatory pre-flight check on every external surface.

## Root Cause Analysis

### Structural

`wr-risk-scorer` was scoped for inbound pipeline risk (commit/push/release) driven by `RISK-POLICY.md`'s commit-layer / push-layer / release-layer model. External communications were never in scope — ADR-015 (on-demand assessment skills) and ADR-022 don't cover outbound surfaces, and the existing push-gate hook (`packages/risk-scorer/hooks/git-push-gate.sh`) only intercepts `gh pr merge` (to route to `release:watch`). There is no PreToolUse hook fired for `gh issue create`, `gh issue comment`, `gh pr create`, `gh pr comment`, `gh api .../security-advisories`, `gh api .../comments`, or `npm publish` content diffs.

P038's Description (lines 17–26) names the external-comms surface list but scopes enforcement to voice-and-tone only. The risk/leak half is named in the friction category ("Missing voice/risk checks on external output") and in the analytics line but does not appear in P038's fix steps — a scope seam that left the risk-gate work unscheduled.

### Candidate fixes

The gate should be architecturally **parallel to P038's voice-tone hook**, sharing the surface-list inventory but evaluating different content:

1. Inventory the external-comms tool-call patterns that the gate must intercept:
   - `gh issue create` (upstream issue bodies).
   - `gh issue comment` (comment bodies).
   - `gh pr create`, `gh pr comment`, `gh pr review` (PR-body prose).
   - `gh api repos/.../security-advisories` (POST body).
   - `gh api repos/.../comments` (any REST surface accepting a prose body).
   - `npm publish` with a README diff against the previous published version.
   - RapidAPI CLI pushes, marketplace product-page updates (if in scope).
2. Design leak-pattern rules:
   - Confidential-business markers per RISK-POLICY.md (client names, revenue figures, user counts, pricing, internal roadmap references).
   - Credential-shaped tokens (API keys, bearer tokens, AWS keys, GitHub PATs).
   - Prod-URL patterns specific to the user's deployment footprint.
   - Internal-only module names, unannounced-product codenames, embargoed-feature references.
3. Hook implementation:
   - New `packages/risk-scorer/hooks/external-comms-gate.sh` (PreToolUse:Bash for matching command-line patterns; PreToolUse:Write for npm README diffs).
   - Delegates to a new scoring path (subagent `wr-risk-scorer:external-comms` or extension of `wr-risk-scorer:pipeline` — architect review needed).
   - Emits the same deny-plus-delegate pattern ADR-028's voice-tone gate uses, so the two gates compose cleanly on the same surface.
4. Integration with `/wr-itil:report-upstream`:
   - Skill Steps 5 and 6 already document the ADR-028 voice-tone-gate interaction. Add the risk-scoring gate to the same section so the skill documents both.
   - AFK branch: if risk-scoring fires halt-and-surface above appetite, save the drafted report to the local ticket's `## Drafted Upstream Report` section and halt the orchestrator (same pattern as the security-path halt per ADR-024 Consequences).
5. ADR scoping:
   - Likely a sibling ADR to ADR-028 (e.g. `NNN-risk-scoring-gate-external-comms.proposed.md`) rather than an extension, because the content-evaluation surface is materially different (leak patterns vs. voice profile). Architect review will decide whether to split or combine.
   - Update ADR-002 inventory if the hook lives in `packages/risk-scorer/hooks/`.
6. Regression fixtures:
   - Known-bad drafts (containing client names, revenue figures, prod URLs, credentials) — expect the gate to halt.
   - Known-good drafts (sanitised upstream reports, generic bug descriptions) — expect the gate to pass.
   - Borderline cases (repro data that mentions a package name vs. repro data that mentions an internal module) — document the pass/fail call in the fixture.

### Investigation Tasks

- [x] Inventory external-comms surfaces (reuse P038's list; add any surfaces P038 missed — notably `gh api .../security-advisories`). Done — surface list lives inline in the canonical hook + bats fixture.
- [x] Draft leak-pattern rules with RISK-POLICY.md authority (confidential-business markers are already defined there; credentials and prod-URLs need rule definitions). Done — `packages/shared/hooks/lib/leak-detect.sh` carries the regex pre-filter; `wr-risk-scorer:external-comms` subagent owns the ambiguous-prose layer.
- [x] Decide gate implementation shape: PreToolUse hook only, skill only, or both (P038 chose both — likely the same answer here for consistency). Done — both: hook (deny-plus-marker) + on-demand skill `/wr-risk-scorer:assess-external-comms` per ADR-015.
- [x] Decide scoring path: new subagent `wr-risk-scorer:external-comms`, or extend `wr-risk-scorer:pipeline` with an external-comms layer. Architect review. Done — new subagent (`packages/risk-scorer/agents/external-comms.md`) per ADR-028 amendment line 52 + architect Q2 verdict.
- [x] Draft the ADR (sibling to ADR-028). Cross-reference ADR-015 (assessment skills), ADR-028 (voice-tone gate), ADR-024 (report-upstream contract), and RISK-POLICY.md. Done — ADR-028 amended (2026-04-21) collapsed the sibling path; risk-evaluator half ships under that amendment without a new ADR per architect verdict.
- [x] Build regression fixtures from the 30-day insights window's "FFS" outputs that also carried leak content. Done — `packages/risk-scorer/hooks/test/external-comms-gate.bats` (12 assertions including credential / revenue / changeset cases). Canonical-shape contract + drift coverage in `packages/shared/test/`.
- [ ] Update `/wr-itil:report-upstream` SKILL.md's "Voice-tone gate interaction" section (currently only ADR-028) to document both gates composing on the same surface. **Deferred** — separate ticket; report-upstream cross-reference is non-blocking and the gate fires from the hook regardless of whether the skill names it.
- [ ] Coordinate with P038's implementation so both gates ship together (sharing the surface inventory and the hook scaffolding), or in consecutive iterations. **Deferred** — P038 ships independently; the two hooks compose at the `PreToolUse:Bash` matcher level when both packages are installed. Composite-marker upgrade is owned by P038's iteration.

## Fix Strategy (implemented)

The risk-evaluator half of ADR-028 amended ships in this iteration. Architecture per architect verdict (c) on the P064 iteration:

1. **Canonical hook** at `packages/shared/hooks/external-comms-gate.sh` + helper at `packages/shared/hooks/lib/leak-detect.sh`. Distributed via ADR-017 duplicate-script pattern (new `scripts/sync-external-comms-gate.sh` + `npm run check:external-comms-gate` CI step).
2. **Per-package risk-scorer copy** at `packages/risk-scorer/hooks/external-comms-gate.sh` and `packages/risk-scorer/hooks/lib/leak-detect.sh` (byte-identical to canonical).
3. **Per-evaluator marker** keyed on `sha256(draft_body + '\n' + surface)`. Composite marker (combining a future voice-tone verdict with the risk verdict) deferred until P038 lands its evaluator.
4. **Hybrid leak detection**: regex pre-filter (`leak-detect.sh`) for credentials, business-context-paired financial figures, business-context-paired user-counts; subagent (`wr-risk-scorer:external-comms`) for ambiguous prose against `RISK-POLICY.md` Confidential Information classes.
5. **New subagent type** `wr-risk-scorer:external-comms` (`packages/risk-scorer/agents/external-comms.md`). Emits `EXTERNAL_COMMS_RISK_VERDICT: PASS|FAIL` + `EXTERNAL_COMMS_RISK_KEY: <sha>` consumed by `risk-score-mark.sh` (extended in this iter).
6. **New on-demand skill** `/wr-risk-scorer:assess-external-comms` per ADR-015 — pre-satisfies the marker for a draft outside a hook trigger.
7. **Surface coverage**: `gh issue create|comment|edit`, `gh pr create|comment|edit`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish`, `PreToolUse:Write|Edit on .changeset/*.md` (P073 surface — gated at author time).
8. **Override**: `BYPASS_RISK_GATE=1` env var (consistent with `git-push-gate.sh`).
9. **Advisory-only fallback**: when `RISK-POLICY.md` is absent, the gate permits the call with a systemMessage (graceful adoption per ADR-008 / ADR-025).
10. **Bats coverage**: 12 assertions in `packages/risk-scorer/hooks/test/external-comms-gate.bats` (surface match, hard-fail leak deny, marker permit, BYPASS, advisory-only, changeset author, non-changeset path); 11 in `packages/shared/test/external-comms-gate-canonical.bats`; 7 in `packages/shared/test/sync-external-comms-gate.bats`.

## Confirming evidence — 2026-04-25 #52831 retrospective

Concrete instance of the gap: agent posted a substantive comment to anthropics/claude-code#52831 via `gh issue comment` with no PreToolUse gate firing. Retrospective `wr-risk-scorer:wip` invocation cleared at residual 3 (Low) — within appetite — but explicitly noted that RISK-POLICY.md "is policy-silent on outbound public communication to third-party repositories" and scored by analogy to the Confidential Information section (lines 19-28). Confirms: (a) the gate from this ticket is not yet in place for `gh issue comment`; (b) the rubric extension from the Investigation Tasks above ("RISK-POLICY.md ... extend with credential / prod-URL / embargoed-product rules") needs to land alongside the gate so the scorer has authoritative criteria, not analogical fallback; (c) the cleared-by-analogy outcome is the lucky case — a comment that touched no confidential markers — and shouldn't be read as evidence the gap is benign.

## Fix Released

- **Released**: 2026-04-26 — `@windyroad/risk-scorer` minor (commit `a0713f3`, "fix(risk-scorer): P064 external-comms risk-leak gate (gh issue/pr/api, npm publish, .changeset) — known error").
- **Summary**: PreToolUse risk-leak gate on outbound prose surfaces — confidential-information leaks halted before reaching external surfaces (gh issue/pr/api, npm publish, `.changeset/*.md`). Architect verdict (c) shape: canonical `packages/shared/hooks/external-comms-gate.sh` + per-package synced copy at `packages/risk-scorer/hooks/external-comms-gate.sh` (ADR-017 duplicate-script pattern, drift-checked in CI); new subagent type `wr-risk-scorer:external-comms` (`packages/risk-scorer/agents/external-comms.md`) emits structured `EXTERNAL_COMMS_RISK_VERDICT: PASS|FAIL` consumed by extended `risk-score-mark.sh`; new on-demand skill `/wr-risk-scorer:assess-external-comms` per ADR-015; hybrid leak detection (regex pre-filter for credentials / business-paired financial figures / business-paired user-counts; subagent for ambiguous prose against `RISK-POLICY.md` Confidential Information classes); `BYPASS_RISK_GATE=1` env override (consistent with `git-push-gate.sh`); RISK-POLICY.md-absent → advisory-only mode (graceful adoption per ADR-008 / ADR-025). Surface coverage: `gh issue create|comment|edit`, `gh pr create|comment|edit`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish`, `PreToolUse:Write|Edit on .changeset/*.md` (P073 author-time gate so leaks never reach CHANGELOG.md / Release PR / npm tarball).
- **Bats coverage**: 12 assertions in `packages/risk-scorer/hooks/test/external-comms-gate.bats` (12/12 green re-confirmed in this transition iter — surface match, hard-fail leak deny on GitHub-token + AWS-key, marker permit, BYPASS short-circuit, advisory-only fallback, changeset author-time gate revenue-leak deny + clean-content delegate, non-changeset path bypass, gh api security-advisories trigger, npm publish trigger); 11 in `packages/shared/test/external-comms-gate-canonical.bats`; 7 in `packages/shared/test/sync-external-comms-gate.bats` (drift coverage mirrors P095 + P026 patterns).
- **Awaiting user verification**: real-world exercise of the gate on at least one outbound `gh issue comment` / `gh pr create` / `npm publish` / `.changeset` author event with leak-shaped content blocked at the hook AND at least one clean-content draft permitted via marker-then-delegate. Two `Deferred` checked items in Investigation Tasks remain non-blocking per the ticket — `/wr-itil:report-upstream` SKILL.md cross-reference (the gate fires from the hook regardless of skill prose) and P038 voice-tone composite-marker (P038's iter owns the upgrade).

## Decision record

**ADR-028 (amended 2026-04-21)** — "External-comms gate — voice-tone + risk/leak evaluators on shared PreToolUse surface". User direction collapsed the sibling-ADR path into a combined ADR-028; this ticket's risk/leak evaluator ships as the `wr-risk-scorer:external-comms` subagent (new type, not an extension of `:pipeline`), paired with `/wr-risk-scorer:assess-external-comms` on-demand skill per ADR-015. Hook distributed via ADR-017 duplicate-script pattern (canonical in `packages/shared/hooks/`; synced copy in `packages/risk-scorer/hooks/`). Risk evaluator half shipped 2026-04-26 in commit `a0713f3`.

## Related

- **ADR-028** (amended 2026-04-21) — decision record for this ticket; closes the design question. Implementation tracks under this ticket.
- **P038** — voice-and-tone gate on external comms; sibling "external comms needs a gate" scope (voice-tone half).
- **P063** — manage-problem does not trigger `/wr-itil:report-upstream`; sibling wiring gap on the same skill.
- **P055** — parent shipping of `/wr-itil:report-upstream`; the primary external-comms skill that would benefit from this gate.
- **P034** — centralise risk reports; shares the cross-project analytics-driven pattern.
- **ADR-015** (on-demand assessment skills) — the architectural pattern for on-demand risk evaluation.
- **ADR-028** (voice-tone gate on external comms) — the sibling gate; architecture to mirror.
- **ADR-024** (cross-project problem-reporting contract) — the primary consumer; the report-upstream skill relies on outbound-surface gates.
- **RISK-POLICY.md** — authoritative definition of confidential-business markers; extend with credential / prod-URL / embargoed-product rules as part of this fix.
- `packages/risk-scorer/hooks/git-push-gate.sh` — existing risk-scorer hook; only intercepts `gh pr merge`; the new hook will extend the same plugin.
- `/Users/tomhoward/.claude/usage-data/report.html` — insights report (2026-03-17 to 2026-04-16); "Missing voice/risk checks on external output" category.
- **JTBD-001**, **JTBD-101**, **JTBD-201** — the three personas whose constraints this ticket protects.
- **P073** — No voice-tone or risk gate on changeset authoring. Surface-inventory extension: include `PreToolUse:Write` on `.changeset/*.md` alongside the existing gh-issue / gh-pr / npm-publish entries. Changeset bodies populate CHANGELOG.md, the Release PR body, the GitHub Release page, and the npm tarball — a leak in a changeset persists in every published tarball and in git history, so the gate must fire at author-time, not at `npm publish` time (which is too late — the CHANGELOG is already committed to main).
