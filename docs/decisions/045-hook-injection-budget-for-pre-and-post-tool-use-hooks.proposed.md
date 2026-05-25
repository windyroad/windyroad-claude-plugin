---
status: "proposed"
date: 2026-04-28
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, windyroad-claude-plugin adopters]
reassessment-date: 2026-07-28
---

# Hook injection budget policy for PreToolUse and PostToolUse hooks

## Context and Problem Statement

Windy Road plugins register 36 hooks across 9 plugins on `PreToolUse`, `PostToolUse`, and `Stop` matchers (see audit table at `docs/problems/096-pretooluse-posttooluse-hook-injection-volume-unaudited.known-error.md` lines 109–146). Unlike the `UserPromptSubmit` cluster covered by [ADR-038](038-progressive-disclosure-for-governance-tooling-context.proposed.md), most per-tool-call hooks already exit silently on the happy path; the audit (P096 Phase 1, 2026-04-26) confirmed 33/36 hooks emit 0 bytes on pass and only emit prose via `permissionDecisionReason` on deny.

Three outliers — `tdd/tdd-post-write.sh` (PostToolUse:Edit|Write), `risk-scorer/plan-risk-guidance.sh` (PreToolUse:EnterPlanMode), and `retrospective/retrospective-reminder.sh` (Stop) — were always-on advisories. P096 Phase 2 (2026-04-26) trimmed them in code: `tdd-post-write.sh` is now silent on GREEN-unchanged transitions and hash-dedupes repeated RED test output; `plan-risk-guidance.sh` reuses the shared `lib/session-marker.sh` helper from ADR-038 to gate its advisory body once-per-session; `retrospective-reminder.sh` was already minimal. Aggregate savings: −1 to −15 KB per typical 30-turn session, dominated by `tdd-post-write.sh` cumulative reduction.

What Phase 2 does *not* yet do: codify the patterns. ADR-038's "Out of scope" clause (lines 81–86) explicitly defers this surface — *"PreToolUse / PostToolUse hook prose volume (P096) — audit pending; the shared `session-marker.sh` helper is reused when Phase 2 of P096 lands, but additional patterns (once-per-file, gate-pass-silent) are expected and will be codified in a sibling ADR or a Section extension here."* Until the patterns sit in policy, future hook authors do not know which patterns are repository-canon vs which are P096-specific accidents, and a future plugin adding a fourth always-on advisory could re-introduce the bloat ADR-038 + Phase 2 spent reclaiming.

**P091** (Session-wide context budget — meta) is the parent. **P096** is the driver ticket and transitions to `.verifying.md` on this ADR landing per ADR-022. This ADR is the per-tool-call sibling that ADR-038 names; together they constitute the hook-surface coverage of the progressive-disclosure pattern (`UserPromptSubmit` + `PreToolUse`/`PostToolUse` + `Stop`).

## Decision Drivers

- **JTBD-001 — Enforce Governance Without Slowing Down**: codifying silent-on-pass as the default for the 33/36 audited hooks, plus the four reduction patterns Phase 2 implemented, holds enforcement (PreToolUse deny path) constant while reclaiming context budget. The deny path remains verbose so governance violations stay loud — the asymmetry is exactly what JTBD-001's "every edit reviewed before it lands" outcome requires.
- **JTBD-002 — Ship AI-Assisted Code with Confidence**: hooks block on deny while emitting nothing on pass preserves JTBD-002's "agent cannot bypass governance — hooks block edits until reviews pass" while reclaiming the budget that supports the audit-trail outcomes.
- **JTBD-003 — Compose Only the Guardrails I Need**: silent-on-pass is the right default precisely because per-plugin baseline cost matters when composing subsets. Users installing 2 of 9 plugins emit ~0 bytes per tool call from the others.
- **JTBD-006 — Progress the Backlog While I'm Away**: `tdd-post-write.sh` fires on every Edit/Write of an impl/test file. In a 30-iteration AFK orchestrator run with 5–10 impl edits per iteration, the GREEN-unchanged + RED hash-dedupe paths are the dominant cumulative reclamation and lengthen safe-loop duration.
- **JTBD-101 — Extend the Suite with New Plugins**: this ADR codifies five reusable patterns (silent-on-pass, side-effect-only-silent, silent-on-unchanged-state, hash-dedupe of repeated body content, once-per-session gating reuse) that future plugin developers MUST follow when adding `PreToolUse`/`PostToolUse` hooks. Pattern-codification heavy ADR is exactly the JTBD-101 desired outcome — *"Plugins follow the same structure... clear patterns, not reverse-engineering."*
- **ADR-038** is the parent pattern; this ADR is its sibling, not its extension. ADR-040 and ADR-043 set the sibling-not-extension precedent (ADR-043 lines 22–23 articulate the rule). Per-tool-call patterns include semantic classes ADR-038 does not own — silent-on-unchanged-state and hash-dedupe of repeated body content — which justifies the sibling shape.
- **ADR-009 gate-marker lifecycle**: this ADR extends the announcement-marker semantic class (no-TTL, no-drift, session-scoped) introduced by ADR-038 unchanged. No third semantic class is added.
- **ADR-017 shared-code sync pattern**: the `lib/session-marker.sh` helper distribution invariant remains; risk-scorer joining the `sync-session-marker.sh` `CONSUMERS` array (Phase 2) is an instance of this pattern, not a deviation.
- **ADR-023 performance review scope**: per-call cost × call-frequency is a discoverable budget surface. The four budget bands below are quantified in concrete bytes (not qualitative phrases), per ADR-023's ban on `load is negligible`/`microseconds only`/`minimal`.
- **ADR-026 agent-output grounding**: every quantitative claim cites the P096 audit table or the Phase 2 implementation; no `not estimated — no prior data` sentinels are needed because both layers have measured grounding.
- **P091** (parent meta) — this ADR closes one of P091's "split action tickets by cluster" outputs.
- **P096** is the Known Error this ADR's landing transitions to Verification Pending per ADR-022.

## Considered Options

1. **Sibling ADR codifying five patterns (chosen)** — separate ADR mirroring ADR-038's shape but covering the per-tool-call surface. Codifies the patterns Phase 2 already implements as repository-canon for future hooks.
2. **Extension Section in ADR-038** — fold the per-tool-call patterns into ADR-038's Decision Outcome. Rejected: ADR-038's Confirmation list, Reassessment Criteria, and "Out of scope" boundaries would have to absorb a second semantic class (silent-on-unchanged-state and hash-dedupe of repeated body content). ADR-040 and ADR-043 set the precedent for sibling-not-extension; ADR-043 lines 22–23 articulate the same rule explicitly.
3. **No ADR — leave Phase 2 patterns as code-only** — rely on the implementation as the source of truth. Rejected: future hook authors reading the codebase have no way to distinguish repository-canon patterns from P096-specific accidents, and there is no surface for the "always-on advisory must justify each byte" rule that the audit's findings imply.
4. **Single combined ADR replacing ADR-038 + this ADR** — one mega-ADR covering all hook surfaces. Rejected: ADR-038 is already accepted in the codebase and cited from many places; rewriting it for symmetry is large surface change for no benefit. Sibling-pair shape is the project's documented precedent.

## Decision Outcome

**Chosen option: Option 1** — sibling ADR codifying five patterns for `PreToolUse` / `PostToolUse` / `Stop` hooks.

### Scope

This ADR governs every hook registered on a `PreToolUse`, `PostToolUse`, or `Stop` matcher in any windyroad plugin's `hooks.json`. ADR-038 continues to govern `UserPromptSubmit` hooks. `SessionStart` is governed by ADR-040 and is out of scope here.

### Pattern catalogue

Five mandatory patterns. Future hook authors MUST adopt the applicable subset.

#### 1. Silent-on-pass default

A hook whose gate passes (the proposed action is permitted) MUST emit zero bytes to stdout. The hook MAY exit `0` immediately, or MAY write a side-effect (marker file, log line) that does not surface in the conversation. 33/36 hooks audited 2026-04-26 already follow this default — it is now policy.

Applies to: every `PreToolUse` enforcement gate (architect, jtbd, tdd, style-guide, voice-tone, risk-scorer, itil cluster). Deny-path prose lives in pattern 4.

#### 2. Side-effect-only silent

A hook whose sole purpose is to update gate state (write a marker file, refresh a hash, advance a session counter) MUST emit zero bytes. The audit identified 13 hooks in this class — `*-mark-reviewed.sh` × 5, `*-slide-marker.sh` × 5, `architect-refresh-hash.sh`, `risk-hash-refresh.sh`, `wip-risk-mark.sh`, `risk-score-mark.sh`, `tdd-setup-marker.sh`, `tdd-reset.sh` (Stop). All currently emit 0 bytes. Future side-effect-only hooks MUST follow.

#### 3. Silent-on-unchanged-state

A `PostToolUse` hook that emits state-update prose (current state, before/after diff, tracked-list snapshot) MUST exit with zero stdout when the post-tool state is byte-identical to the pre-tool state on the dimension the hook reports. The reference implementation is `tdd/tdd-post-write.sh`: when `OLD_STATE == NEW_STATE == GREEN`, the hook exits before the `TDD STATE UPDATE` block is built. Verified by `packages/tdd/hooks/test/tdd-post-write-phase2.bats` tests 1–2.

Applies to: any future `PostToolUse` hook reporting per-edit state. Authors MAY treat this as advisory if the dimension is not state-shaped (e.g. a hook that emits a count is not subject to silent-on-unchanged unless the count is the report).

#### 4. Hash-dedupe of repeated body content

A hook that emits large dynamic blocks (test output, log tail, structured trace) MUST hash the block and suppress re-emission on hash-match. The reference implementation is `tdd/tdd-post-write.sh`: failure output is keyed by `/tmp/tdd-stdout-hash-${SESSION_ID}-${ENCODED_TEST}` and replaced with `Test output unchanged from previous emission (hash match).` (~57 bytes) on match. Verified by `tdd-post-write-phase2.bats` tests 3–4.

The hash-key MUST include `SESSION_ID` so dedupe state never crosses sessions. The hash-match acknowledgement MUST stay ≤80 bytes (pattern 5 budget). The hash-store MUST live under `/tmp` so it clears on reboot per ADR-009's `/tmp` convention.

#### 5. Once-per-session gating for always-on advisories

A hook whose detection cannot reasonably be gated by tool-call boundaries (e.g. a `PreToolUse:EnterPlanMode` advisory the user always benefits from on first plan-mode entry) MUST gate its full advisory body via the shared `lib/session-marker.sh` helper from ADR-038. First emission emits the full body (≤700 bytes); subsequent emissions within the same session emit a terse reminder (≤150 bytes) carrying the four ADR-038 elements (imperative signal word, gate name, trigger artifact, delegation affordance / cross-reference).

The reference implementation is `risk-scorer/plan-risk-guidance.sh` (system name `risk-scorer-plan-guidance`). Verified by `packages/risk-scorer/hooks/test/plan-risk-guidance-once-per-session.bats` (7 tests, green). The plugin MUST join `scripts/sync-session-marker.sh` `CONSUMERS` array. The marker convention (`/tmp/${SYSTEM}-announced-${SESSION_ID}`) and reminder shape are unchanged from ADR-038.

The `tdd-inject.sh` dynamic-state carve-out (ADR-038 Decision Outcome) generalises here: dynamic per-call content (the current state line, the changed file path, the deny reason) emits per-call irrespective of announcement state; only static policy prose is gated.

### Per-band byte budget (codifying Phase 2 measurements)

| Band | Budget | Reference implementation |
|------|-------:|--------------------------|
| Pass-path | 0 bytes | every PreToolUse enforce gate |
| Side-effect-only | 0 bytes | `*-mark-reviewed.sh`, `*-slide-marker.sh`, `tdd-reset.sh` |
| Silent-on-unchanged-state | 0 bytes | `tdd-post-write.sh` GREEN-unchanged |
| Hash-match acknowledgement | ≤ 80 bytes | `tdd-post-write.sh` RED hash-match (~57 bytes implementation) |
| Always-on advisory — terse reminder | ≤ 150 bytes | `plan-risk-guidance.sh` subsequent-emit |
| Always-on advisory — first-emit body | ≤ 700 bytes | `plan-risk-guidance.sh` first-emit (~600 bytes implementation) |
| Deny-path `permissionDecisionReason` | Honour-system, typically 200–700 bytes; no fixed cap | `architect-enforce-edit.sh`, `risk-score-commit-gate.sh`, etc. |

The deny-path band is honour-system because deny prose carries the actionable evidence the user needs to remediate (which file, which gate, which trigger artefact). ADR-026's ban on qualitative-only prose applies — every deny reason MUST cite specific evidence (file path, gate name, the rule clause violated) rather than restating policy in the abstract. Bats tests assert `[ "${#output}" -lt 1000 ]` as testability slack over the typical 200–700 byte ceiling — drift past 1000 bytes warrants a review of whether the hook is restating policy or carrying evidence.

The terse-reminder ≤150 byte budget mirrors ADR-038's UserPromptSubmit envelope. Bats tests assert ≤250 bytes as testability slack over the 150-byte policy budget (matching ADR-038 line 110's slack convention).

### Marker lifecycle and distribution (inherited from ADR-038, no new semantic class)

- **Marker convention**: `/tmp/${SYSTEM}-announced-${SESSION_ID}` for once-per-session gating; `/tmp/<plugin>-stdout-hash-${SESSION_ID}-${KEY}` for hash-dedupe.
- **No TTL, no drift check** for once-per-session markers (per ADR-038 — bookkeeping for prose verbosity, not enforcement). Hash-dedupe markers are per-session ephemeral; they expire when `SESSION_ID` rolls.
- **Distribution**: canonical helper at `packages/shared/hooks/lib/session-marker.sh` (ADR-038); per-plugin synced copies at `packages/<plugin>/hooks/lib/session-marker.sh`; sync via `scripts/sync-session-marker.sh` (ADR-017 canonical+sync). Plugins consuming pattern 5 MUST appear in the `CONSUMERS` array.
- **ADR-002 invariant**: each plugin remains installable independently. Pattern 5 distributes via the existing helper duplication; no cross-plugin coupling is introduced. Patterns 1–4 are per-plugin local.

### Out of scope (follow-up tickets or future ADRs)

- **Cross-plugin consolidation of `*-slide-marker.sh` × 5 and `*-mark-reviewed.sh` × 5** — mechanical duplication noted in P096's audit. These hooks already comply with patterns 1–2; consolidation reduces source surface area but not injection bytes. Deferred per the P096 ticket's "Phase 2 / cross-plugin consolidation" follow-up note.
- **`SKILL.md` runtime size (P097)** — sibling cluster; progressive disclosure applied to skill bodies (runtime-steps vs reference-material split) needs its own design decision.
- **CI-time budget enforcement** that fails the build on overflow. Both layers are advisory only; budgets are honour-system + bats drift checks per ADR-038's precedent.
- **Framework-injected surfaces** (`available-skills` / `subagent-types` / `deferred-tools` listings) — emitted by Claude Code itself, not project-editable. ADR-043 measures them as `not measured — framework-injected`.

## Consequences

### Good

- The five patterns become repository-canon. Future hook authors get a checklist (silent-on-pass; side-effect silent; silent-on-unchanged-state; hash-dedupe; once-per-session for always-on advisories) instead of having to reverse-engineer Phase 2's intent from `tdd-post-write.sh` and `plan-risk-guidance.sh`. JTBD-101 served.
- The deny-path band makes ADR-026's grounding rule explicit at the hook surface — every deny reason cites evidence, not policy abstractions. Future plugin authors lean on the band as the contract shape.
- Aggregate session savings (Phase 2 measured: −1 to −15 KB per session) are codified rather than dependent on tribal memory. Future regressions get caught by the bats coverage already cited.
- ADR-009 marker semantics extended without a new class — the announcement marker (no-TTL, no-drift) introduced by ADR-038 covers pattern 5; the hash-dedupe marker (per-session ephemeral) is documented as a sibling under the same `/tmp` lifetime convention.
- ADR-017 distribution invariant unchanged. ADR-002 self-contained-published-package invariant unchanged.
- P091 cluster gains its second per-cluster ADR; the meta ticket's "split action tickets by cluster" structure pays off as designed.

### Neutral

- The deny-path band is honour-system. No CI fail on over-budget deny prose; bats tests assert ≤1000 bytes as a soft ceiling. Drift is caught by review, not by enforcement — same shape ADR-038 chose for the terse-reminder budget.
- Per-band budgets are inherited from Phase 2 measurements; no fresh measurement was done for this ADR. The audit table at P096 lines 109–146 is the persistent grounding source.
- The pattern catalogue is additive only. Existing hooks already in compliance need no edits. Five reference implementations exist (one per pattern); future hooks cite them.

### Bad

- **Always-on advisory bands are tunable but the 700-byte first-emit ceiling is a single-data-point estimate** (only `plan-risk-guidance.sh` exists in this class). If a second always-on advisory needs more first-emit body — e.g. a multi-section policy reminder — the band will need to relax. Mitigated by the Reassessment Criteria below.
- **Hash-dedupe correctness depends on hash-key choice**. A hash-key that misses a relevant input dimension (e.g. forgetting `SESSION_ID`) leaks state across sessions. The `tdd-post-write.sh` reference includes `SESSION_ID + ENCODED_TEST`; future authors copying the pattern need the same key discipline. Mitigated by the bats coverage at `tdd-post-write-phase2.bats`.
- **The deny-path band has no enforced ceiling**. A future hook author writing a 1500-byte deny reason re-introduces the bloat the audit reclaimed. Mitigated by the bats `< 1000` testability slack and the ADR-026 ban on qualitative restatement of policy.
- **The pattern catalogue does not yet cover `PreToolUse:Bash` hooks that gate on argv** (e.g. `git-push-gate.sh`, `risk-score-commit-gate.sh`, `external-comms-gate.sh`). These all already comply with pattern 1 (silent on pass) but have larger deny-path payloads (300–900 bytes). Pattern 4 — deny-path band — covers them; if regressions appear, revisit.

## Confirmation

Compliance is verified by:

1. **Source review:**
   - `packages/tdd/hooks/tdd-post-write.sh` — Pattern 3 (silent-on-unchanged-state) and Pattern 4 (hash-dedupe) reference.
   - `packages/risk-scorer/hooks/plan-risk-guidance.sh` — Pattern 5 (once-per-session) reference; sources `lib/session-marker.sh`.
   - `scripts/sync-session-marker.sh` `CONSUMERS` array includes `risk-scorer` (post-Phase 2).
   - 33 audited hooks emit 0 bytes on pass per Patterns 1–2; future hook PRs MUST preserve this.
   - Every deny-path prose (Pattern 4 band) cites file path + gate + rule (no qualitative-only phrases per ADR-026).

2. **Tests (bats — already in place from Phase 2):**
   - `packages/tdd/hooks/test/tdd-post-write-phase2.bats` — 7 tests covering silent-on-GREEN-unchanged + RED hash-dedupe (Patterns 3 + 4).
   - `packages/risk-scorer/hooks/test/plan-risk-guidance-once-per-session.bats` — 7 tests covering first-emit body, terse-reminder shape, byte budget, distinct-session re-emit, empty-session-id fallback, JSON validity (Pattern 5).
   - `packages/shared/test/session-marker.bats` — 9 unit tests for the helper.
   - `packages/shared/test/sync-session-marker.bats` — 6 drift tests for the canonical+sync distribution.

3. **Performance budget (ADR-023):** the band table above is discoverable to ADR-023's `performance-budget-*` glob via this ADR's title.

4. **ADR-022 transition:** P096 transitions from `.known-error.md` to `.verifying.md` in the same commit that lands this ADR. `## Fix Released` section records the release marker per ADR-022.

5. **Behavioural replay (end-to-end):**
   - Fresh AFK orchestrator session running 5 impl edits with no state changes: `tdd-post-write.sh` emits 0 bytes (Pattern 3).
   - Same session re-running the same failing test: second emission is the hash-match acknowledgement (~57 bytes) not the full test output (Pattern 4).
   - Same session entering plan mode twice: first emission is ~600 bytes; second emission is ≤150 bytes (Pattern 5).
   - Aggregate hook preamble from PreToolUse/PostToolUse/Stop cluster: −1 to −15 KB per typical session vs pre-Phase-2 baseline.

## Pros and Cons of the Options

### Option 1 — Sibling ADR codifying five patterns (chosen)

- Good: codifies Phase 2 patterns as repository-canon; future hooks have a checklist; JTBD-101 directly served.
- Good: preserves ADR-038's scope clean; adds no new semantic class to ADR-009.
- Good: matches ADR-040 / ADR-043 sibling-not-extension precedent.
- Bad: one more ADR file in `docs/decisions/`. Marginal cost.

### Option 2 — Extension Section in ADR-038

- Good: single-ADR cohesion for the progressive-disclosure surface.
- Bad: ADR-038's Confirmation list, Reassessment Criteria, and "Out of scope" boundaries would absorb a second semantic class. Precedent in ADR-043 (lines 22–23) explicitly chose sibling over extension for the same reason.

### Option 3 — No ADR

- Good: minimum surface change.
- Bad: future hook authors have no canon to follow; Phase 2 patterns become tribal memory; regressions reintroduce the bloat reclaimed.

### Option 4 — Single combined ADR replacing ADR-038 + this

- Good: maximum cohesion.
- Bad: rewrites accepted ADR-038 for symmetry alone; large surface change for no measurable benefit.

## Reassessment Criteria

Revisit this decision if:

- **A second always-on advisory needs > 700 bytes first-emit**: the Pattern 5 first-emit ceiling is single-data-point. If a multi-section policy reminder warrants more, relax the band and document the comparable prior in the new hook's PR.
- **Deny-path payloads drift past the 1000-byte testability slack** in any hook: review whether the hook is restating policy abstractly (ADR-026 violation) or carrying load-bearing evidence. If load-bearing, consider an ADR amendment to introduce a deny-path band ceiling.
- **A hook emits state-shaped prose without adopting Pattern 3** (silent-on-unchanged-state): tighten the pattern's wording so future authors recognise applicability.
- **A hook emits dynamic-block prose without adopting Pattern 4** (hash-dedupe): same; tighten or extend.
- **Cross-plugin consolidation of `*-slide-marker.sh` or `*-mark-reviewed.sh` lands** (deferred follow-up): update Pattern 2's reference list and confirm the consolidated hook still complies.
- **A `Stop` hook joins the always-on advisory class** beyond `retrospective-reminder.sh`: extend Pattern 5's reference list and confirm the marker convention applies.
- **ADR-038 changes** in a way that affects the shared helper or marker convention: this ADR's Pattern 5 follows ADR-038; track changes.
- **P097 (SKILL.md runtime size) lands a sibling ADR** that introduces patterns this ADR could borrow (e.g. runtime-steps vs reference-material split): cross-reference.
- **Framework hook contract changes** in Claude Code (e.g. new matcher kinds, new payload fields): revisit which matchers this ADR governs.

## Related

- **P091** (Session-wide context budget — meta) — parent meta ticket. This ADR is the per-tool-call cluster's codification.
- **P096** (PreToolUse/PostToolUse hook injection — Known Error → Verification Pending on this ADR landing) — the driver ticket.
- **P095** (UserPromptSubmit hook injection — sibling cluster) — companion cluster covered by ADR-038.
- **P097** (SKILL.md runtime size cluster — Open) — sibling cluster; pattern shape may borrow.
- **P098** (project/user-owned context contributors — Open) — sibling cluster; out of scope here.
- **JTBD-001** — enforce governance without overhead.
- **JTBD-002** — ship AI-assisted code with confidence; hooks block on deny.
- **JTBD-003** — compose only the guardrails I need; per-plugin baseline cost.
- **JTBD-006** — progress the backlog while AFK; cumulative reclamation extends safe-loop duration.
- **JTBD-101** — extend the suite with new plugins; this ADR is the documented pattern catalogue future hook authors follow.
- **ADR-002** — monorepo per-plugin packages; installable-independently invariant.
- **ADR-009** — gate marker lifecycle (TTL+drift); announcement-marker class extended unchanged.
- **ADR-013** Rule 6 — AFK fallback; deny path JSON consumed via stdin, no `AskUserQuestion` involved.
- **ADR-014** — governance skills commit their own work; this ADR + P096 transition + README refresh land in one commit.
- **ADR-017** — shared code sync pattern; `lib/session-marker.sh` distribution invariant.
- **ADR-022** — problem lifecycle Verification Pending; P096 transition path.
- **ADR-023** — performance review scope; per-band byte budget table is discoverable here.
- **ADR-026** — agent output grounding; deny-path evidence-citation rule.
- **ADR-037** — skill testing strategy (bats-contract); test shape adopted from Phase 2 coverage.
- **ADR-038** — Progressive disclosure for `UserPromptSubmit` governance prose; parent ADR; this ADR is its sibling.
- **ADR-040** — Session-start briefing surface; sibling-not-extension precedent.
- **ADR-043** — Progressive context-usage measurement; sibling-not-extension precedent (lines 22–23).
- `packages/tdd/hooks/tdd-post-write.sh` — Patterns 3 + 4 reference.
- `packages/risk-scorer/hooks/plan-risk-guidance.sh` — Pattern 5 reference.
- `packages/shared/hooks/lib/session-marker.sh` — canonical helper.
- `scripts/sync-session-marker.sh` — distribution mechanism.
