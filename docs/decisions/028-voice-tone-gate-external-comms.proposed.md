---
status: "proposed"
date: 2026-04-20
amended-date: 2026-05-14
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, addressr maintainer, bbstats maintainer]
reassessment-date: 2026-07-20
---

# External-comms gate — voice-tone + risk/leak evaluators on shared PreToolUse surface

## Context and Problem Statement

`@windyroad/voice-tone` and `docs/VOICE-AND-TONE.md` govern voice and tone for in-repo text (READMEs, docs, commit messages). `@windyroad/risk-scorer` and `RISK-POLICY.md` govern pipeline risk (commit / push / release layers) and define the confidential-information classes that must never leak (client names, revenue figures, user counts, pricing, credentials, prod URLs, embargoed features). Neither plugin gates **external** text surfaces: GitHub issue comments, PR descriptions, npm README updates, RapidAPI listings, Shopify/marketplace pages, **changeset bodies** (which populate CHANGELOG.md, Release PRs, GitHub Release pages, and every published npm tarball).

Claude's output on these surfaces defaults to generic "AI voice" — em-dashes, hedging phrases ("it seems", "I'd suggest"), overly-polite closers ("happy to help further"), and context-blind suggestions like "let's keep this ticket open" on years-old issues. Claude's output also regularly includes scraped local-context that IS confidential under RISK-POLICY.md — client names pulled from repo text, internal prod URLs cited verbatim, revenue figures from retros. Voice-tone drift and leak drift are distinct failure modes but they share a surface: every byte of external text passes through the same tool-call invocations.

Per the session insights report (1,464 messages across 86 sessions, 2026-03-17 to 2026-04-16), voice-tone drift on external comms is one of three top friction categories. The pattern is: agent drafts an external comment, posts it, user catches the AI-tell OR a leak, issues a "FFS" correction, agent rewrites and reposts. Every correction is a late-stage cleanup of output that a pre-flight gate should have caught.

**Three upstream problem tickets** drive this ADR: P038 (voice-tone gate), P064 (risk/leak gate), P073 (changeset authoring surface — which neither P038 nor P064 enumerated in its initial fix design). The user's direction (this session's AskUserQuestion rounds): one combined ADR with two evaluators on a shared PreToolUse surface, distributed via the ADR-017 shared-code-sync pattern so each of `@windyroad/voice-tone` and `@windyroad/risk-scorer` ships an independent copy of the hook and each copy runs only its own evaluator (both copies fire when both packages are installed; either copy alone provides partial coverage when only one is installed).

## Decision Drivers

- **JTBD-001** (Enforce Governance Without Slowing Down) — solo-developer; external-comms AI-voice AND leak drift are the "manually police AI output" pain point. A pre-flight gate closes both before the comment posts, not after the "FFS" correction.
- **JTBD-002** (Ship AI-Assisted Code with Confidence) — external surfaces are the public face of the user's work. AI-tell patterns damage brand credibility; confidential-info leaks damage commercial relationships. Catching them at the gate preserves shipping confidence.
- **JTBD-003** (Compose Only the Guardrails I Need) — the combined gate is composable. Projects that install only `@windyroad/voice-tone` get voice coverage; projects that install only `@windyroad/risk-scorer` get leak coverage; projects that install both get both. Each package independently installable per ADR-002.
- **JTBD-006** (AFK) — blocking on FAIL (from EITHER evaluator) is the correct conservative default. AFK loops must not post AI-voice or confidential-info leaking comments without user review.
- **JTBD-101** (Extend the Suite with Clear Patterns) — one gate shape, two evaluator plugs. Plugin-developer adopters see a single pattern that scales to future evaluators (licence-compliance, claim-accuracy, etc.) via the same deny-plus-marker + per-evaluator verdict file mechanism.
- **JTBD-201** (Restore Service Fast with an Audit Trail) — audit trail of external comms records both voice-tone and leak verdicts. The age-check (carried over from the pre-amendment ADR-028) specifically serves JTBD-201's audit-trail integrity on stale-target follow-ups.
- **JTBD-202** — tech-lead pre-flight governance check; release-notes (changeset bodies → CHANGELOG.md → published tarballs) pass through the gate at authoring time, not at publish time. Closes P073's "gate at publish is too late" gap.
- **P038** — upstream voice-tone ticket. Closed by this ADR.
- **P064** — upstream risk/leak ticket. Closed by this ADR (sibling-ADR path collapsed into the combined scope per user direction).
- **P073** — upstream changeset authoring ticket. Closed by this ADR (surface-inventory extension to `.changeset/*.md`).

## Considered Options

1. **One combined ADR, two evaluators, shared surface, ADR-017 duplicate-script distribution** (chosen) — user direction. Single PreToolUse hook shape with composite marker; per-package copy of the script (synced from `packages/shared/hooks/external-comms-gate.sh`); each package's copy runs only the evaluators it owns. ADR-002 dependency graph stays unchanged; each package remains independently installable; both packages installed = both evaluators fire; either alone = partial coverage. Distribution model matches the `lib/install-utils.mjs` precedent that ADR-017 established.
2. **Two sibling ADRs (voice-tone + risk)** — ADR-028 stays voice-only; ADR-029 drafted for risk/leak. Rejected by user: surface inventory duplicated across two ADRs; coordination cost higher; the composite marker scheme cannot be authored in only one ADR. User picked Option 1.
3. **One base ADR + two evaluator sub-ADRs** — base ADR defines shared hook + surface; sub-ADRs define each evaluator. Rejected: over-structured for two evaluators; sub-ADR overhead kicks in when a third evaluator emerges (licence-compliance, claim-accuracy) — at which point we amend the base ADR.
4. **Combined hook in `packages/voice-tone/hooks/` with hard dep on risk-scorer** — rejected. Breaks ADR-002 "installable independently" for voice-tone-only installs.
5. **Combined hook in `packages/risk-scorer/hooks/` with voice-only fallback in voice-tone** — considered. Works, but the fallback adds a second code path (advisory-only voice-only mode when risk-scorer absent); ADR-017 duplicate-script is simpler because each package carries a complete evaluator-appropriate hook and the combining logic is "is the other package's verdict file PASS?" — testable independently per package.
6. **Pattern-based PreToolUse hook (no delegation to either agent)** — rejected per the pre-amendment ADR-028's reasoning: forbidden phrases and forbidden leak-patterns hard-coded in the hook are brittle; both classes evolve.

## Decision Outcome

**Chosen option: Option 1** — one combined ADR, two evaluators, shared surface, ADR-017 duplicate-script distribution.

Rationale:
- The deny-plus-marker pattern (ADR-009) is the repo's established gate convention; one hook firing both evaluators is a natural extension.
- ADR-017 is the pre-existing distribution model for shared code that must ship inside each plugin without cross-package runtime coupling. Hook scripts qualify as a sync target under ADR-017's shape; this ADR extends ADR-017's explicit surface list to include `hooks/`.
- `wr-voice-tone:agent` already exists for in-repo text; extending its scope to external text reuses the reviewer. `wr-risk-scorer:external-comms` is a new subagent type (not an extension of `wr-risk-scorer:pipeline`) because external-comms leak evaluation is semantically distinct from commit/push/release-layer pipeline scoring.
- Composite marker `external-comms-reviewed-<sha256(draft_body + target_surface + age_bucket + evaluator_set)>` binds both evaluator verdicts to one marker. The `evaluator_set` component ensures a marker written when only one evaluator was installed does NOT satisfy a later check when both evaluators are present.
- Advisory-only fallback (per-evaluator): if `docs/VOICE-AND-TONE.md` is absent, voice-tone review is advisory-only; if `RISK-POLICY.md` is absent, risk review is advisory-only. Each evaluator's absence degrades to advisory independently; the gate still runs whatever evaluators are present.

### Scope

**In scope (this ADR):**

- **Canonical shared hook**: `packages/shared/hooks/external-comms-gate.sh` — the authoritative source. Synced into consumer packages via `scripts/sync-install-utils.sh`-style mechanism (new script `scripts/sync-external-comms-gate.sh` OR extend the existing sync script's scope; architect call at implementation time). Matches commands via regex:
  - `gh issue comment [...]`, `gh pr comment [...]`, `gh pr create [...]`, `gh pr edit [...]`, `gh issue edit [...]` (pre-amendment list, preserved).
  - **New** (added by this amendment): `gh issue create [...]`, `gh api .../security-advisories [...]`, `gh api .../comments [...]`, `npm publish` (with README diff), `PreToolUse:Write` and `PreToolUse:Edit` on paths matching `.changeset/*.md`.

- **Per-package synced copies**:
  - `packages/voice-tone/hooks/external-comms-gate.sh` — byte-identical copy of the canonical, gated by "is the package's evaluator available" — voice-tone's copy only runs the voice-tone evaluator branch.
  - `packages/risk-scorer/hooks/external-comms-gate.sh` — byte-identical copy, runs only the risk evaluator branch.
  - CI drift check `npm run check:external-comms-gate` validates byte-identity across canonical + copies per the ADR-017 `check:install-utils` precedent.

- **Evaluators**:
  - `wr-voice-tone:agent` — extended from its current in-repo review scope to cover external-comms drafts. Writes verdict to `/tmp/voice-tone-verdict` (PASS / FAIL).
  - `wr-risk-scorer:external-comms` — **NEW subagent type**. Reviews draft text against RISK-POLICY.md's Confidential Information classes (client names, revenue, user counts, pricing, credentials, prod URLs, embargoed features). Writes verdict to `/tmp/risk-verdict` (PASS / FAIL).
  - ADR-015 Scope table gains this new type + a paired on-demand skill `/wr-risk-scorer:assess-external-comms` (wraps the subagent for explicit pre-flight review).

- **Composite marker scheme**:
  - Marker key: `sha256(draft_body + target_surface + age_bucket + evaluator_set)` where `evaluator_set` is a sorted comma-separated list of installed evaluator identities (e.g. `voice-tone,risk`). A marker written with `evaluator_set=voice-tone` does NOT satisfy a gate check that sees `evaluator_set=voice-tone,risk`.
  - Combined marker: `external-comms-reviewed-<key>`. Written ONLY when ALL installed evaluators have written PASS to their respective verdict files. If any evaluator wrote FAIL, no combined marker is written, gate still denies on retry.
  - PostToolUse:Agent hook in each package (`packages/voice-tone/hooks/external-comms-mark-reviewed.sh` + `packages/risk-scorer/hooks/external-comms-mark-reviewed.sh`) fires when its respective subagent type returns; each reads the OTHER package's verdict file too (if present) before deciding whether to write the combined marker. When both are PASS, whichever hook fires second writes the marker. When either is FAIL, neither hook writes.

- **Advisory-only modes** (per-evaluator, independent):
  - Voice-tone advisory: if `docs/VOICE-AND-TONE.md` is absent, voice-tone evaluator runs in advisory-only mode (emits systemMessage "`docs/VOICE-AND-TONE.md` not found — voice-tone evaluator advisory-only"); its verdict file reads PASS unconditionally so it does not block the combined marker.
  - Risk advisory: if `RISK-POLICY.md` is absent, risk evaluator runs in advisory-only mode (emits systemMessage "`RISK-POLICY.md` not found — risk evaluator advisory-only"); its verdict file reads PASS unconditionally.
  - With BOTH files absent, the gate permits tool calls with a systemMessage advisory noting both evaluators are advisory-only. The hook does NOT hard-fail when policy docs are missing — graceful-adoption pattern per ADR-008 / ADR-025.

- **Age-check rule** (preserved from pre-amendment ADR-028): runs independently of evaluator mode; matches stale-target-incongruous phrases; denies with extended reason when target > `VOICE_TONE_EXTERNAL_AGE_DAYS` (default 180).

- **Extension of `docs/VOICE-AND-TONE.md` scope**: unchanged from pre-amendment. File is source of truth for in-repo AND external voice; `wr-voice-tone:agent` extends its prompt to handle external-comms context.

- **`wr-voice-tone:agent` prompt amendment**: unchanged from pre-amendment. External comms review section; PASS/FAIL to `/tmp/voice-tone-verdict`.

- **`wr-risk-scorer:external-comms` agent prompt** (NEW): reviews draft text against RISK-POLICY.md's Confidential Information classes. Emits structured verdict per the ADR-026 grounding contract — specific citation of the leak-pattern matched + the matched substring. Writes PASS/FAIL to `/tmp/risk-verdict`.

- **Bats doc-lint tests** (extended from pre-amendment ADR-028):
  - `packages/shared/test/external-comms-gate-canonical.bats` — asserts canonical hook exists and contains the combined surface regex list.
  - `packages/shared/test/external-comms-gate-drift.bats` — asserts byte-identity between canonical + per-package copies.
  - `packages/voice-tone/hooks/test/external-comms-gate.bats` — asserts voice-tone's copy denies AI-voice fixtures, permits clean drafts, advisory-only when VOICE-AND-TONE.md absent.
  - `packages/voice-tone/hooks/test/external-comms-age-check.bats` — preserved from pre-amendment.
  - `packages/voice-tone/agents/test/voice-tone-external-comms-contract.bats` — preserved; asserts the agent prompt has the external-comms review section.
  - `packages/risk-scorer/hooks/test/external-comms-gate.bats` — asserts risk-scorer's copy denies leak fixtures (client names, prod URLs, revenue figures), permits clean drafts, advisory-only when RISK-POLICY.md absent.
  - `packages/risk-scorer/agents/test/risk-scorer-external-comms-contract.bats` — asserts the new subagent prompt cites RISK-POLICY.md Confidential Information classes and emits ADR-026-grounded verdicts.
  - `packages/shared/test/external-comms-composite-marker.bats` — asserts:
    - Both PASS → combined marker written → retry permits.
    - One PASS + one FAIL → no marker written → retry still denies (architect-flagged most-likely-to-regress branch).
    - Neither PASS → no marker → retry denies.
    - `evaluator_set` key component prevents marker collision across installation profiles.

- **Cross-ADR updates in the same amendment commit**:
  - **ADR-017** (Shared code sync pattern): one-line extension confirming `hooks/` qualifies as a sync target alongside `lib/` (the pre-existing `install-utils.mjs` case).
  - **ADR-015** (On-demand assessment skills): Scope table gains `wr-risk-scorer:external-comms` row + paired `/wr-risk-scorer:assess-external-comms` skill reference.
  - **ADR-024** (Cross-project problem-reporting contract): Consequences one-line note that `gh issue create` in report-upstream now fires BOTH evaluators via the combined gate.
  - **ADR-020** (Auto-release): Consequences one-line note that `.changeset/*.md` authoring is gated upstream of the auto-release flow — so aggregated Release PR bodies inherit the gate verdict at changeset-author time.

**Out of scope (follow-up tickets or future ADRs):**

- Claim accuracy on external comms ("industry-leading", "most popular" without evidence). Separate concern owned by the architect agent (ADR-023 principle) and/or a future claim-accuracy evaluator slotting into the same combined-gate shape.
- RapidAPI, Shopify, marketplace listing surfaces. Deferred — gate is designed to accept new surfaces via additional regex patterns in the canonical hook; no architectural change.
- Automatic rewrite (gate rewrites the draft rather than blocking). Rejected for now; each evaluator returns remediation guidance; human reviews the rewrite before reposting.
- Third evaluator (licence-compliance, etc.) adding to the same gate — when it emerges, amend this ADR's evaluator list and the composite marker's `evaluator_set` component; no new ADR expected.

## Consequences

### Good

- External-comms AI-voice AND leak drift caught before posting. JTBD-001's "manually police AI output" closes for both classes in one gate.
- Gate uses the existing deny-plus-marker pattern; no new hook architecture.
- Two source-of-truth files (`docs/VOICE-AND-TONE.md` for voice, `RISK-POLICY.md` for leaks) — no new policy files needed.
- Advisory-only fallback (per-evaluator, independent) preserves the graceful-adoption arc for projects without either or both policy files.
- Age-check preserved; JTBD-201's audit-trail integrity on stale-target comments protected.
- Changeset authoring now gated at author-time (closes P073). Release-PR aggregation and CHANGELOG.md inherit clean content.
- One gate shape scales: licence-compliance, claim-accuracy, or any future external-text evaluator plugs in via the same composite-marker + per-evaluator verdict-file mechanism.
- ADR-017 distribution keeps `@windyroad/voice-tone` and `@windyroad/risk-scorer` independently installable per ADR-002.

### Neutral

- Every gated tool call potentially incurs two subagent round-trips (one per evaluator). Bounded: external comms are human-timescale (seconds to minutes per post), so sub-second agent-review latency is imperceptible. The composite-marker path avoids repeated rounds within the same draft.
- Per-session, per-target age-check cache keeps the `gh api` cost bounded.
- `docs/VOICE-AND-TONE.md` and `RISK-POLICY.md` are now load-bearing for external comms. Changes to either affect external reviews. Acceptable — each file already had load-bearing consumers (in-repo voice reviews; pipeline risk scoring).
- Sync-script adds one more drift-check to CI (`check:external-comms-gate`). Latency impact < 1s.
- New `wr-risk-scorer:external-comms` subagent type adds one more row to ADR-015's Scope table.

### Bad

- **Gate requires BOTH `wr-voice-tone:agent` and `wr-risk-scorer:external-comms` to be installed and functional** when both source-of-truth files exist. If either agent is missing or errors, the gate permanently denies (fail-closed per-evaluator). Mitigation: deny message names the specific subagent that didn't produce a verdict, so the user can diagnose quickly.
- **AFK interaction**: in AFK mode, each external-comms post incurs at minimum one extra turn per evaluator (gate denies; subagent delegated; subagent reviews; marker potentially written; retry). Two evaluators = potentially two extra turns. Bounded by composite-marker caching; most AFK iterations are code changes, not comments.
- **Age-check false positives**: preserved from pre-amendment; no structural change.
- **`.changeset/*.md` authoring during a fast release cadence** triggers per-changeset evaluator review. A session authoring 3 changesets (like this one's 2026-04-20 iteration) runs the gate 3 times. Acceptable; each changeset is per-change-set human-timescale.
- **Per-skill coupling** with `wr-itil:report-upstream` (ADR-024): unchanged from pre-amendment. Report-upstream's flow accounts for the gate firing mid-workflow.
- **ADR-027 interaction** (governance skill auto-delegation): both evaluators are reviewer agents (read-only; write only their verdict files), NOT governance skills. ADR-027's Step-0 pattern does NOT apply to either. Reasoning generalises cleanly even if ADR-027 is superseded (P014).

## Confirmation

> **See Amendments §2026-05-14 for current criteria 1 + section 6 (partial supersession).** The criteria below reflect the 2026-04-21 design; the 2026-05-14 amendment refines criterion 1 (marker key shape + filename) and section 6's composite-marker regression sub-bullet (replaced with per-evaluator-marker regression).

Compliance is verified by:

1. **Source review:**
   - Canonical `packages/shared/hooks/external-comms-gate.sh` exists; per-package copies exist at `packages/voice-tone/hooks/external-comms-gate.sh` and `packages/risk-scorer/hooks/external-comms-gate.sh`; byte-identical to canonical.
   - The hook uses the deny-plus-marker convention (ADR-009); does NOT invoke subagents directly.
   - `packages/voice-tone/hooks/external-comms-mark-reviewed.sh` and `packages/risk-scorer/hooks/external-comms-mark-reviewed.sh` both exist; each reads BOTH `/tmp/voice-tone-verdict` AND `/tmp/risk-verdict` before writing the combined marker.
   - Advisory-only modes fire per-evaluator when the relevant policy file is absent; emits systemMessage and permits (via PASS verdict) without blocking the combined marker.
   - Composite marker key includes `evaluator_set` component.
   - Age threshold from `VOICE_TONE_EXTERNAL_AGE_DAYS` envvar (180 default); TTL from `EXTERNAL_COMMS_TTL` envvar (1800s default; renamed from `VOICE_TONE_EXTERNAL_TTL` since the gate is no longer voice-tone-specific).
   - `packages/risk-scorer/agents/external-comms.md` (or extension of existing `risk-scorer-pipeline.md`) exists and documents the new subagent type.

2. **Tests (bats)**: all 8 bats files listed in Scope are present and passing.

3. **ADR-009 compliance**: composite marker key `sha256(draft_body + target_surface + age_bucket + evaluator_set)` — TTL+drift pattern preserved per ADR-009.

4. **ADR-017 compliance**: canonical + synced copies + CI drift check present. `packages/shared/test/sync-external-comms-gate.bats` asserts drift detection works.

5. **Cross-reference confirmation in neighbouring docs**:
   - `packages/voice-tone/agents/agent.md` contains an "External comms review" section citing this ADR.
   - `packages/risk-scorer/agents/external-comms.md` exists.
   - `docs/VOICE-AND-TONE.md` (if present) notes scope covers both in-repo and external.
   - `RISK-POLICY.md` Confidential Information section cross-references this ADR as the external-comms enforcement surface.
   - ADR-015 Scope table has the `wr-risk-scorer:external-comms` row + `/wr-risk-scorer:assess-external-comms` skill.
   - ADR-017 notes `hooks/` as a sync target alongside `lib/`.
   - ADR-024 Consequences note both evaluators fire on `gh issue create`.
   - ADR-020 Consequences note `.changeset/*.md` is gated at author time.

6. **Behavioural replay** (end-to-end):
   - Draft `gh issue comment --body 'it seems like we should keep this open — happy to help further'` on a 2-year-old issue: gate denies with voice-tone AND age-check reasons; retry permits after rewrite.
   - Draft `gh issue comment --body 'client Acme Corp is seeing this on their production'` (with RISK-POLICY.md listing "Acme Corp" or similar client-name class): gate denies with risk-leak reason; retry permits after redacted rewrite.
   - Draft `gh issue comment --body 'we observed this'` on a fresh issue with both policy files present and both evaluators PASS: gate permits on first retry after both verdicts land.
   - Write `.changeset/p999-test.md` containing a confidential revenue figure: `PreToolUse:Write` denies with risk-leak reason.
   - With `docs/VOICE-AND-TONE.md` absent and `RISK-POLICY.md` present: voice-tone advisory, risk still blocking.
   - With both policy files absent: gate emits both advisories and permits.
   - **Composite-marker regression test**: voice-tone PASS + risk FAIL on the same draft → no combined marker → retry still denies. (Architect-flagged most-likely-to-regress branch.)

## Pros and Cons of the Options

### Option 1: Combined ADR, two evaluators, ADR-017 duplicate-script distribution (chosen)

- Good: one gate shape for two concerns; surface inventory in one place.
- Good: each package independently installable; partial coverage works when only one package is present.
- Good: composite marker handles both-PASS / partial-install / neither-PASS cases via `evaluator_set` key component.
- Good: ADR-017 distribution is a pre-existing pattern; no new distribution mechanism invented.
- Bad: sync script and drift check add CI steps.
- Bad: two verdict files to track; composite-marker regression surface is the one-PASS-one-FAIL branch — mitigated by explicit bats coverage.

### Option 2: Two sibling ADRs (rejected)

- Good: narrower per-ADR blast radius.
- Bad: surface inventory duplicated; composite marker cannot be authored in one place; user rejected.

### Option 5: Combined hook in risk-scorer + voice-only fallback in voice-tone (considered not chosen)

- Good: single hook location when both packages installed.
- Good: voice-only fallback preserves voice-tone-only install experience.
- Bad: two code paths (combined + voice-only-fallback); test matrix larger; user picked ADR-017 duplicate-script instead as simpler.

## Reassessment Criteria

Revisit this decision if:

- **False-positive rate on either evaluator exceeds ~5%** — measured via user-overridden rewrites. Signals the evaluator's prompt needs tightening.
- **Composite-marker failure mode emerges** — e.g. a PASS-PASS-but-marker-not-written bug leaks through. Trigger: bats regression-suite expansion.
- **Age-check loop-stopping in AFK**: if AFK orchestrators hit the age-check deny on a significant fraction of external posts, consider a `EXTERNAL_COMMS_AFK_AGE_BYPASS` envvar.
- **A third evaluator emerges** (licence-compliance, claim-accuracy). Amend this ADR's evaluator list and the `evaluator_set` key component. Expected amendment, not a new ADR.
- **ADR-017 changes scope**: if the sync pattern moves to a different mechanism (e.g. workspace-linking instead of script-sync), this ADR's distribution clause follows.
- **ADR-027 is superseded** (P014): the "reviewer agents, not governance skills" note stays correct; the replacement ADR should still recognise reviewer agents as distinct from user-invoked workflow skills.
- **Hook→subagent architecture changes** in Claude Code. Trigger: reconsideration of direct-invocation Option from pre-amendment.
- **Per-package drift**: if adopters install voice-tone without risk-scorer (or vice versa) at a high rate, consider whether the combined marker's `evaluator_set` component is noisy enough to warrant a per-evaluator marker scheme instead.

## Related

- **P038** — voice-tone gate. Closed by this ADR.
- **P064** — risk/leak gate. Closed by this ADR.
- **P073** — changeset authoring surface. Closed by this ADR.
- **ADR-002** (Monorepo per-plugin packages) — "installable independently" property preserved by ADR-017 distribution.
- **ADR-008** (JTBD directory structure) — graceful-fallback precedent for advisory-only modes.
- **ADR-009** (Gate marker lifecycle) — composite marker follows the TTL+drift pattern; `evaluator_set` key component extends the single-marker-per-key model without altering it.
- **ADR-013** (Structured user interaction) — Rule 6 AFK fail-safe governs both evaluators.
- **ADR-015** (On-demand assessment skills) — updated: `wr-risk-scorer:external-comms` row + `/wr-risk-scorer:assess-external-comms` on-demand skill.
- **ADR-017** (Shared code sync pattern) — distribution model; extended to cover `hooks/` alongside `lib/`.
- **ADR-020** (Governance auto-release) — updated: changeset authoring gated at author-time.
- **ADR-024** (Cross-project problem-reporting contract) — updated: `gh issue create` fires both evaluators.
- **ADR-025** (Test content quality review) — graceful-fallback precedent reused.
- **ADR-026** (Agent output grounding) — risk-scorer:external-comms evaluator's verdict must cite specific leak patterns per ADR-026 grounding rules.
- **ADR-027** (Governance skill auto-delegation) — reviewer agents not governance skills; Step-0 does not apply. Generalises under supersession.
- **JTBD-001**, **JTBD-002**, **JTBD-003**, **JTBD-006**, **JTBD-101**, **JTBD-201**, **JTBD-202** — personas whose needs drive this ADR.
- **JTBD-301** (Report a Problem Without Pre-Classifying It) — `plugin-user` persona; the upstream-reporting flow (ADR-024) is one of the surfaces this gate protects from voice/leak drift.
- `packages/voice-tone/hooks/voice-tone-enforce-edit.sh` — pre-existing in-repo gate; pattern-precedent.
- `packages/risk-scorer/hooks/git-push-gate.sh` — pre-existing pipeline-risk gate; pattern-precedent for risk-scorer hooks.
- `packages/shared/install-utils.mjs` — ADR-017 distribution precedent this ADR follows.
- `docs/VOICE-AND-TONE.md` — voice profile source; scope covers external text per this ADR.
- `RISK-POLICY.md` — risk/leak policy source; Confidential Information classes drive the risk evaluator's leak-pattern list.

## Amendments

### 2026-05-14 — Per-evaluator marker scheme (P038 land iter)

Resolves the composite-marker design ambiguity surfaced during P038 implementation review. Architect (PASS) + JTBD (PASS) confirmed 2026-05-14.

**Marker key (ratification + simplification):**

The Decision Outcome section line 75 proposed `sha256(draft_body + target_surface + age_bucket + evaluator_set)`. Production implementation under P064 shipped `sha256(DRAFT + '\n' + SURFACE)` — dropping `age_bucket` and `evaluator_set`. This amendment ratifies the simpler 2-component key:

- **`age_bucket` dropped** — age-check fires as an independent gate clause (separate deny path) rather than as a marker key component. Putting age into the key forces re-review when a stale-target follow-up is updated even though neither voice-tone nor risk content changed. Better: age-check denies independently with its own remediation message; marker key reflects only the content+surface.
- **`evaluator_set` dropped from key** — superseded by the per-evaluator marker scheme below. Within a single session (markers live under `${TMPDIR:-/tmp}/claude-risk-${SESSION_ID}/`), the installed evaluator set is stable, so the `evaluator_set` key component is redundant. The cross-session reuse risk that `evaluator_set` was designed to mitigate is already prevented by session-scoping.

Final marker key: `sha256(DRAFT + '\n' + SURFACE)` — unchanged from P064 implementation.

**Per-evaluator marker scheme (replaces combined-marker design):**

The Decision Outcome line 53 proposed a combined marker `external-comms-reviewed-<key>` written only when ALL installed evaluators emit PASS, with a composite-mark helper coordinating across packages. This amendment replaces it with per-evaluator markers:

- Each plugin's gate checks for its OWN per-evaluator marker `external-comms-<evaluator>-reviewed-<KEY>` where `<evaluator>` is the plugin's evaluator id (`risk`, `voice-tone`, …).
- Each plugin's PostToolUse:Agent mark hook writes its own per-evaluator marker on PASS.
- When both plugins installed, both gates fire on the same PreToolUse event; both deny until both per-evaluator markers exist. Gates compose at the firing level, not via shared state.

**Rationale for per-evaluator markers:**

- Eliminates the shared mark-helper race condition (which hook fires second writes the combined marker; if both fire concurrently the marker might be written twice or once with stale state).
- Eliminates the need for cross-plugin install-detection at runtime (no need to know "is voice-tone installed?" from within risk-scorer's hook — each plugin's gate fires only if its own hook is registered).
- Tests are cleaner: voice-tone gate tests live entirely in `packages/voice-tone/`, risk-scorer gate tests entirely in `packages/risk-scorer/`, composite behaviour emerges from running both gates which is naturally captured by sync-script drift tests.
- Single-evaluator install scenarios are correct by construction: only one gate is registered, only one marker is required, single PASS unblocks the retry.
- Cross-evaluator-install changes between sessions are correct by construction: each session starts with empty marker state.
- The Reassessment Criteria section already anticipated this pivot ("Per-package drift: ... consider whether the combined marker's `evaluator_set` component is noisy enough to warrant a per-evaluator marker scheme instead").

**Per-package config file (replaces evaluator_set runtime detection):**

Each consumer plugin carries `packages/<plugin>/hooks/external-comms-evaluator.conf` (NOT synced — per-package divergence by design). The canonical gate sources this file to determine:

- `EXTERNAL_COMMS_EVALUATOR_ID` — short id used in marker filename (`risk`, `voice-tone`).
- `EXTERNAL_COMMS_SUBAGENT_TYPE` — subagent type the deny message directs to (`wr-risk-scorer:external-comms`, `wr-voice-tone:external-comms`).
- `EXTERNAL_COMMS_VERDICT_PREFIX` — structured-output prefix the mark hook parses (`EXTERNAL_COMMS_RISK`, `EXTERNAL_COMMS_VOICE_TONE`).
- `EXTERNAL_COMMS_ASSESS_SKILL` — on-demand skill path (`/wr-risk-scorer:assess-external-comms`, `/wr-voice-tone:assess-external-comms`).

The canonical `packages/shared/hooks/external-comms-gate.sh` remains byte-identical across per-package copies (synced via ADR-017); the per-package `.conf` file is the only divergence and is package-specific by design (a single file lookup, no logic). The `.conf` file is explicitly EXCLUDED from `scripts/sync-external-comms-gate.sh` sweep.

**Structured-output contract (clarification):**

Each evaluator subagent emits structured output to stdout (NOT to a `/tmp/<evaluator>-verdict` file). The PostToolUse:Agent hook parses:

- `EXTERNAL_COMMS_<EVALUATOR>_VERDICT: PASS|FAIL` (e.g. `EXTERNAL_COMMS_RISK_VERDICT`, `EXTERNAL_COMMS_VOICE_TONE_VERDICT`).
- `EXTERNAL_COMMS_<EVALUATOR>_KEY: <sha256>` (matches the gate's marker key computation).
- `EXTERNAL_COMMS_<EVALUATOR>_REASON: <one-line>` (FAIL only).

Per-evaluator marker is written as `external-comms-<evaluator>-reviewed-<KEY>` on PASS; on FAIL no marker is written and the gate continues to deny on retry.

**Sync targets (extends `scripts/sync-external-comms-gate.sh`):**

The sync script's CONSUMERS list extends to include `voice-tone`. Canonical files synced byte-identically across all consumers:

- `packages/shared/hooks/external-comms-gate.sh` → `packages/<consumer>/hooks/external-comms-gate.sh`
- `packages/shared/hooks/lib/leak-detect.sh` → `packages/<consumer>/hooks/lib/leak-detect.sh`

Per-package files (NOT synced; package-specific):

- `packages/<consumer>/hooks/external-comms-evaluator.conf` — evaluator id + subagent + verdict prefix + assess-skill.
- `packages/<consumer>/hooks/external-comms-mark-reviewed.sh` — per-package PostToolUse:Agent wrapper (sources .conf; parses verdict prefix; writes per-evaluator marker on PASS).
- `packages/<consumer>/agents/external-comms.md` — package-specific subagent prompt.
- `packages/<consumer>/skills/assess-external-comms/` — package-specific on-demand skill.

**Cross-ADR updates landed in the same commit:**

- This ADR (ADR-028) — adds this Amendments section, updates `amended-date` to 2026-05-14, inserts cross-ref note at top of Confirmation section.
- ADR-015 — Scope table gains BOTH `wr-risk-scorer:external-comms` row (retroactive — P064's iter did not land it) AND `wr-voice-tone:external-comms` row + paired `/wr-voice-tone:assess-external-comms` skill.
- ADR-017 — already names hooks/ as a sync target alongside lib/ per the 2026-04-21 amendment; no further change for P038.

**Confirmation criteria delta (supersedes Confirmation criterion 1 and section 6 sub-bullet 7):**

- **Criterion 1** (was: "Composite marker key includes evaluator_set component") — superseded. Current: per-evaluator marker key is `sha256(draft + '\n' + surface)`; marker filename is `external-comms-<evaluator>-reviewed-<KEY>`; evaluator id sourced from per-package `external-comms-evaluator.conf`. No combined marker; no composite-mark helper.
- **Section 6 Behavioural replay sub-bullet 7** (was: "Composite-marker regression test: voice-tone PASS + risk FAIL on the same draft → no combined marker → retry still denies") — superseded. Current: "Per-evaluator-marker regression test: voice-tone PASS without risk PASS → risk gate still denies; risk PASS without voice-tone PASS → voice-tone gate still denies; both PASS → both gates permit (per-evaluator markers compose at gate firing level)."
- **Section 2 Tests (bats)** — partial supersede: `packages/shared/test/external-comms-composite-marker.bats` is REMOVED from the required list (no composite marker to test). Voice-tone gate bats `packages/voice-tone/hooks/test/external-comms-gate.bats` is ADDED. `packages/shared/test/sync-external-comms-gate.bats` (already present) gains voice-tone copy assertions.

**Out-of-scope decisions deferred (not addressed by this amendment):**

- Whether to publish a future `external-comms-mark.sh` shared helper if a third evaluator emerges and the per-package wrapper logic begins to duplicate. The current 2-evaluator scope is well-served by per-package wrappers each ≤30 lines.
- ADR-028 status flip from proposed → accepted. Stays proposed until both halves observed in production for one release cycle per the project's ADR-006-vintage deliberation discipline (per the architect verdict on this amendment).
