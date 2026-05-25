---
status: "proposed"
date: 2026-05-11
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-08-11
---

# Dogfood graduation criteria for held changesets — symmetric risk balance drives the reinstate decision

## Context and Problem Statement

ADR-042 (Auto-apply scorer remediations to reach within appetite — open vocabulary) codifies the **inflow** contract for the holding area: when cumulative pipeline residual risk exceeds appetite (≥ 5/25), the orchestrator may `git mv` a changeset from `.changeset/` to `docs/changesets-holding/` to drop release risk while preserving the underlying fix commit. The mechanism works — evidence from 2026-04-24 onward shows multiple load-bearing-from-the-start hook surfaces (P085, P064, P159, P170 / RFC-001 cohort, RFC-002 T1–T5 cohort) successfully moved to holding under ADR-042 Rule 2.

What's missing is the **outflow** contract — the symmetric criterion that decides when a held changeset is ready to be reinstated to `.changeset/` for release. ADR-042 Rule 2's vocabulary is open for `move-to-holding` actions but contains no codified `reinstate-from-holding` shape. The holding area's `README.md` "reinstate trigger" lines were prose-vague ("user signals comfort with hook behaviour OR scorer downgrades residual below appetite after dogfood observation"), producing two failure modes:

1. **Reinstate-never** (observed P085 / P064 / P159 sit-times of 8–12 days each): no agent-evaluable signal exists to recognise the dogfood window has produced enough evidence. The user has no observable mechanism to know when to reinstate; calendar-time windows ("hold 7–14 days") were explicitly rejected by the decision-maker as *"arbitrary and too long"* (2026-05-04 direction).

2. **Drain-condition empty-conjunct coupling** (observed I002, 2026-05-11): ADR-042 Rule 2/6 auto-apply moves every changeset to holding when residual exceeds appetite, leaving `.changeset/` permanently empty. ADR-018 and ADR-020 drain conditions both predicate on `.changeset/` non-empty (`docs/decisions/018-…proposed.md` line 78, `docs/decisions/020-…proposed.md` §3), so `release:watch` and `push:watch` go silent. The held cluster grew from 3 → 13 entries across 4 days during I002, with 10 of 32 unpushed commits being `chore(changeset): move ... to holding` auto-applies and zero graduations. ADR-042's outflow gap *produces* the drain-pressure failure, not just delays it.

The user's reframing (2026-05-04 verbatim direction): graduation is a **symmetric risk balance**, not a one-sided release-risk threshold. The orchestrator should ask the symmetric question to its inflow question:

- **Release risk** (current ADR-042 scoring): "what is the risk of shipping the held changeset to npm now?" Driven by load-bearing surfaces, bats coverage, blast radius, prior incidents.
- **Delay risk** (this ADR): "what is the risk of NOT shipping this fix to users right now?" Currently zero in the model — which is wrong, because the fix exists in source and addresses an observed problem with non-zero Priority.

**Key insight (2026-05-04)**: we don't need a new counterfactual delay-risk score. **It already exists, on every problem ticket, as the `Priority` field** (Impact × Likelihood per `RISK-POLICY.md`). Every held changeset is the fix for a problem ticket; every problem ticket's Priority is — by construction — the cost-of-not-having-the-fix. The asymmetry the project carried until now was *structural*: we compute Priority to rank dev-work via WSJF, then throw it away when the same fix is held in `docs/changesets-holding/`. The same number that justifies prioritising the fix justifies releasing the fix.

The graduation criterion this ADR encodes: **reinstate a held changeset when `release-risk ≤ problem-ticket Priority`** — the same balance ADR-042 applies on the release side, applied symmetrically against the score we already have. As dogfood evidence accumulates (more commits without false-positive, more auto-fix invocations succeeding), release-risk decays; problem-ticket Priority stays constant (or climbs if Likelihood re-rates upward via `/wr-itil:review-problems`); graduation triggers when the balance flips.

The I001 mitigation (2026-05-06, three orthogonal-gate holds graduated independently) and I002 mitigation H3 (2026-05-10, 13-entry atomic-cohort graduation across 5 packages) are the empirical baseline this ADR codifies. Both shipped cleanly with no false-positives, validating the symmetric framing in practice.

## Decision Drivers

- **JTBD-006 (Progress the Backlog While I'm Away)** — primary motivator. AFK persona expects forward progress without interactive halts when an evaluable signal exists. The orchestrator owns the graduation decision; per-graduation `AskUserQuestion` is the failure mode this ADR prevents. JTBD-006 Desired Outcome "stops gracefully when ... it hits a blocker" authorises the halt-and-prompt path when changeset → problem-ticket resolution is ambiguous (a judgment call the agent does not own).
- **JTBD-001 (Enforce Governance Without Slowing Down)** — held-without-graduation is governance slowing down delivery indefinitely. The 2026-05-05 amendment ("Multi-commit coordinated changes ... governed at the change-set level, not just per-edit") composes directly with the atomic-cohort graduation class.
- **JTBD-101 (Extend the Suite with New Plugins)** — plugin-developer pays move-to-holding ceremony cost expecting eventual release. The 2026-05-05 amendment ("Plugin / framework ceremony must scale down to atomic-change adopters") composes with the orthogonal-gate-vs-atomic-cohort distinction.
- **JTBD-302 (Trust That the README Describes the Plugin I Just Installed)** — held-source-merged features that never reach npm produce silently-stale README claims (features documented in source but not in published artefact). The graduation contract IS the drift-resolution path JTBD-302 line 20 names ("drift-detection signal exists at commit / release / retrospective time so adopters never receive a silently-stale README via `npm install`").
- **Symmetric risk assessment principle** — risk-scoring in the project today is asymmetric: we score the risk of *doing things* (commit / push / release) but not the risk of *not-doing things* (delay / defer / hold). This is fine when defaults are "do" and the question is "should we hold?" — but inverts when defaults are "hold" and the question is "should we ship?". The graduation contract requires the symmetric counterfactual because it asks the inverse question.
- **Score-already-exists insight (2026-05-04)** — the symmetric score is not missing; it exists on each problem ticket as the `Priority` field. The structural gap is the *connection* between the held changeset and its originating problem-ticket Priority, not the *invention* of a new score. This collapses the implementation scope from "new evidence pipeline" to "join over existing data".
- **ADR-018 / ADR-020 drain-condition coupling** — `.changeset/` non-empty conjunct in both drain conditions silently couples with ADR-042 inflow, producing the I002 release-pressure failure mode. The graduation criterion fixes the upstream cause; the drain condition needs a symmetric amendment so it wakes when graduatable held entries exist.
- **ADR-022 (Verification Pending lifecycle)** — held changesets are typically tied to `.verifying.md` tickets (P085, P064, P159 all in VP at hold-time). Auto-reinstating a held changeset whose originating ticket is in VP would short-circuit the user-owned verify-or-reject decision the lifecycle is built to protect. Symmetric to ADR-042 Rule 2b (no auto-revert of VP commits).
- **ADR-026 (Agent output grounding — cite + persist + uncertainty)** — the per-class evidence floor must ground in observable, re-readable artefacts. Bare "≥ N firings" counts fail the *cite* and *persist* legs unless the firings land in a re-readable surface (log marker, telemetry path, git-trail pattern).
- **ADR-060 finding 12 (atomic-cohort graduation)** — RFC-shaped held changesets graduate atomically — the entire commit chain ships or doesn't. ADR-061 operationalises this finding without amending ADR-060: the symmetric-risk math is identical across classes; only the *evaluation unit* differs.
- **I001 + I002 empirical baseline (2026-05-06 / 2026-05-10)** — the manual graduations executed as I001 and I002 mitigations are the observable evidence this ADR grounds in. P085 / P064 / P159 graduated as independent orthogonal-gate holds (12 / 10 / 2 day windows); the 13-entry RFC-001 + RFC-002 cohort graduated atomically. Both groups shipped clean across npm publish + post-graduation `push:watch` + `release:watch` drain.

## Considered Options

**Option 1 — Sibling ADR codifying symmetric-balance graduation (chosen).** New ADR-061 declaring the `release-risk ≤ problem-ticket Priority` criterion, two evaluation units (orthogonal-gate + atomic-cohort), per-class evidence floors, VP carve-out, and the drain-condition coupling fix. ADR-042 stays focused on inflow; ADR-061 owns outflow. Parallel "inflow ADR / outflow ADR" framing.

**Option 2 — Amend ADR-042 with a Rule 8/9 covering outflow.** Reject. Three concrete factors against:
- ADR-042's reassessment trigger is specifically about vocabulary stabilisation (Innovation Window close signal); wrapping outflow into ADR-042 muddies that trigger.
- ADR-042 already supersedes ADR-041; loading outflow rules complicates the supersession history and the eventual Innovation-Window-close supersession.
- ADR-060 finding 12 already cites P162 as the graduation contract authority (`Phase 1 ships under a held window per ADR-042 / P162 graduation criteria`). Folding outflow into ADR-042 retroactively makes ADR-060's reference inaccurate.

**Option 3 — Calendar-time graduation window (e.g. "hold 7–14 days, then ship").** Reject per decision-maker direction (2026-05-04): *"1-2 weeks is arbitrary and too long. What are the concrete signals that will tell us when it's ready to be included in the published packages?"* Calendar time does not measure dogfood quality; it measures wall-clock elapsed.

**Option 4 — Pure user-comfort signal (no agent-evaluable criterion).** Reject. This is the status-quo ante observable failure: P085 sat for 12 days because no agent-evaluable signal existed to tell the user *"now is the time"*. Operationalises to "the user remembers"; the I001 / I002 observable evidence is that the user did not remember (held queue grew 3 → 13 across 4 days during I002).

**Option 5 — New evidence-collection pipeline (e.g. `.afk-run-state/dogfood-evidence.jsonl` accumulator).** Reject per 2026-05-04 user refinement: the score already exists as problem-ticket Priority; building a parallel evidence-pipeline is duplicative work that grows the Effort bound (M → L) without adding signal.

### Phase 1b — drain-condition empty-conjunct coupling: considered options

The I002 mitigation surfaced an orthogonal-but-coupled failure: ADR-018/020 drain conditions predicate on `.changeset/` non-empty, so when ADR-042 Rule 2/6 moves every changeset to holding, drain silently stops firing even though held entries may be graduatable. Three remediation options:

**Phase 1b Option A — Amend ADR-018/020 drain condition to include `docs/changesets-holding/` graduatable-entries clause (chosen).** Drain triggers when (`.changeset/` non-empty) OR (`docs/changesets-holding/` contains entries that satisfy the Rule 1 graduation criterion AND are not VP-blocked per Rule 2b below). The drain condition becomes symmetric with the inflow contract: drain wakes on either form of release-eligible material. Smallest change; threads through this ADR's own graduation criterion; preserves ADR-018/020's existing at-appetite drain semantics.

**Phase 1b Option B — Amend ADR-042 Rule 2/6 with a WIP-size guard on holding-area accumulation.** Reject as primary fix. Band-aid: caps inflow without addressing outflow. Does not solve drain-stopped-firing; only delays the failure. Could compose with Option A as belt-and-braces but is not required given Option A's symmetric resolution.

**Phase 1b Option C — Amend ADR-060 finding 12 with a periodic graduation-pressure check.** Reject. The periodic-check shape duplicates Step 6.5's existing post-iter scoring; the work is to make Step 6.5 *evaluate the graduation criterion* (Rule 1 here), not to introduce a parallel periodic process.

## Decision Outcome

Chosen option: **Sibling ADR codifying symmetric-balance graduation (Option 1) with Phase 1b Option A drain-condition amendment.**

Reasoning: the never-release-above-appetite invariant established in ADR-042 Rule 1 is preserved exactly; this ADR adds the symmetric never-hold-below-graduation-threshold invariant. The two together produce a closed risk-control system — material flows to holding when release-risk would exceed appetite, and flows back when release-risk falls at or below problem-ticket Priority. ADR-018/020 drain condition amendment ensures the loop wakes on either form of release-eligible material so the I002 silent-stop failure cannot recur.

### Rules

#### Rule 1 — Symmetric graduation criterion

A held changeset is **eligible to graduate** from `docs/changesets-holding/` back to `.changeset/` when:

```
release-risk(pipeline with held changeset hypothetically reinstated) ≤ problem-ticket Priority
```

Where:

- **release-risk** is computed by `wr-risk-scorer:pipeline` (subagent, preferred) or `/wr-risk-scorer:assess-release` (skill, fallback) against the current pipeline state with the held changeset hypothetically `git mv`'d back to `.changeset/`. Same scoring path as ADR-042 Rule 2's re-score, applied to the symmetric hypothesis.
- **problem-ticket Priority** is the `Priority: <N> (<band>) — Impact: <I> × Likelihood: <L>` field on the held changeset's originating problem ticket, looked up via the join in Rule 1a.

Graduation eligibility is necessary but not sufficient — the per-class evidence floor in Rule 4 must also be met before evaluating the comparison.

#### Rule 1a — Changeset → problem-ticket join

Resolve a held changeset's originating problem ticket via:

1. **Filename convention** (primary): `<package>-p<NNN>-<slug>.md` → ticket ID `P<NNN>` → `docs/problems/**/<NNN>-*.<status>.md`. Worked example: `wr-itil-p085-assistant-output-gate.md` → P085 → `docs/problems/closed/085-…closed.md`.
2. **Body grep fallback** (secondary): if filename does not match the convention (e.g. RFC-shaped changesets, multi-package surfaces), grep the changeset body for `P\d+` references and use the first match as the originating ticket.
3. **Multi-ticket changeset**: when the join surfaces multiple ticket references, use `max(Priority)` across the referenced set — the most-painful-to-defer wins.
4. **Halt-and-prompt** (terminal): when neither path resolves a ticket OR the resolved ticket file is missing/unreadable, the orchestrator MUST NOT auto-graduate. Halt the loop (AFK) or skill (non-AFK) with the changeset name and the resolution failure logged. Per JTBD-006 Desired Outcome line 25 (*"stops gracefully when ... it hits a blocker"*) and persona constraint line 30 (*"Does not trust the agent to make judgment calls ... ambiguous investigations"*), join ambiguity is a user-decision surface, not an agent-decision surface.

#### Rule 2 — Verification Pending carve-out (symmetric to ADR-042 Rule 2b)

A held changeset whose originating problem ticket is in **Verification Pending** status (`.verifying.md` suffix per ADR-022) is **never** eligible for auto-graduation. The orchestrator MUST NOT auto-reinstate the changeset until the ticket transitions to `.closed.md` (or the user manually reinstates via direct `git mv`).

Rationale: ADR-022 establishes the user-owned verify-or-reject decision surface; auto-reinstating a held changeset whose fix is mid-verification short-circuits that surface and could publish a fix the user is actively assessing as broken. Symmetric to ADR-042 Rule 2b (no auto-revert of commits attached to a `.verifying.md` ticket).

A `.verifying.md` → `.closed.md` transition auto-clears the carve-out; the next Step 6.5 graduation pass evaluates the held changeset normally.

#### Rule 3 — Two graduation evaluation units

The symmetric-balance math in Rule 1 is identical across classes; the **evaluation unit** differs:

**Class 3a — Orthogonal-gate graduation**: each held changeset is evaluated independently. The release-risk computation is the marginal risk of reinstating that single changeset; the Priority lookup is the single changeset's originating ticket. Worked baseline (I001 mitigation, 2026-05-06): P085, P064, P159 graduated independently across 12 / 10 / 2 day windows.

**Class 3b — Atomic-cohort graduation** (per ADR-060 finding 12): RFC-shaped held changesets graduate as a single atomic unit — the entire cohort ships or none does. The release-risk computation is the marginal risk of reinstating the **full cohort**; the Priority lookup uses `max(Priority)` across all referenced tickets in the cohort. Worked baseline (I002 mitigation H3, 2026-05-10): RFC-001 + RFC-002 13-entry cohort graduated atomically across 5 packages; release-risk computed against full cohort; cohort shipped clean.

The orchestrator MUST classify the held changeset's evaluation unit before applying Rule 1. Default class is 3a unless the changeset is part of a cohort declared in an RFC ticket (per ADR-060 finding 12 — the RFC ticket explicitly enumerates the cohort).

#### Rule 4 — Per-class evidence floor (grounded per ADR-026)

Before applying Rule 1's symmetric comparison, the orchestrator MUST verify that the **class-specific evidence floor** has been met. The floor exists to prevent reinstating before the dogfood window has produced enough observation; it is a *prerequisite for evaluation*, not a *score input*.

Per ADR-026 (cite + persist + uncertainty), each class names a persistable evidence artefact:

- **PreToolUse:Bash gates** (baseline example: P064 external-comms-gate). **Evidence shape**: ≥ 1 gate-fire log entry per intended trigger surface, with subsequent commit-trail post-fire showing no false-block. **Persistable artefact**: gate stderr → user-visible session output (re-readable via session log), plus commit history showing the user's intended action eventually landed. **Uncertainty**: false-positive-rate point estimate from observed firings, with the count of firings as the confidence proxy.
- **UserPromptSubmit detectors** (baseline example: P085 prose-ask detector). **Evidence shape**: ≥ 1 detector firing logged to hook stderr or `.afk-run-state/` per pattern in the detector vocabulary. **Persistable artefact**: hook stderr (re-readable from CLI scrollback or session log) AND/OR `.afk-run-state/<detector>.log` if the detector persists. **Uncertainty**: false-positive-rate per pattern from observed firings.
- **commit-hook-with-auto-fix** (baseline example: P159 JTBD-currency hook). **Evidence shape**: ≥ 1 auto-fix commit log entry per intended trigger surface, with post-fix verification of correctness (the auto-fix produced the right output). **Persistable artefact**: git log of auto-fix commits (re-readable via `git log --grep=<hook-marker>`) with the diff showing the correct fix shape. **Uncertainty**: false-fix-rate from observed firings.
- **SessionStart additionalContext hooks** (baseline example: any briefing-injection hook). **Evidence shape**: ≥ 1 session-trail entry showing the injection fired without regression in the immediate-next turn. **Persistable artefact**: session log + observable agent behaviour citing the injected content. **Uncertainty**: injection-failure-rate from observed sessions.

For each held changeset, the orchestrator MUST cite the class-specific evidence artefact in the auto-apply audit line per Rule 6 below. A bare "≥ N firings" count without a re-readable citation does NOT satisfy this rule — that pattern is exactly the ungrounded estimate ADR-026 rejects.

#### Rule 5 — When to evaluate (Step 6.5 trigger)

The orchestrator MUST evaluate Rule 1 for each held changeset only when **both** of the following hold:

- The held changeset's class-specific evidence floor (Rule 4) has been met since the changeset entered holding.
- The orchestrator is in **within-appetite drain mode** per ADR-018 Step 6.5 / ADR-020 §6 — i.e. cumulative pipeline residual is ≤ 4/25 AND drain would be running anyway under the amended drain condition (Rule 8 below).

This prevents running the graduation join every iter when nothing else is shipping. When both conditions hold, the orchestrator emits a `RISK_REMEDIATIONS:` entry with the **`reinstate-from-holding`** action class (open-vocabulary per ADR-042 Rule 2a). The agent reads the entry and decides whether to apply, per ADR-042 Rule 2.

When Rule 1's comparison evaluates true (release-risk ≤ Priority), the orchestrator MAY auto-apply the reinstate (subject to Rule 7 gate traversal). When the comparison evaluates false, the held entry remains in holding and the next Step 6.5 cycle re-evaluates after further evidence accumulates.

#### Rule 6 — Audit trail (extends ADR-042 Rule 6)

Every `reinstate-from-holding` auto-apply MUST be logged in two places:

1. **Iteration / skill report** — append one line per graduation under the Auto-apply trail subheading with:
   - Pre-apply `release` score
   - Post-apply re-score
   - The reinstate action (`git mv docs/changesets-holding/<name>.md .changeset/<name>.md`)
   - The class-specific evidence artefact citation (Rule 4)
   - The resolved problem-ticket ID and Priority value
   - The class (3a orthogonal-gate or 3b atomic-cohort)

2. **Holding-area README** (`docs/changesets-holding/README.md`) — move the entry from "Currently held" to "Recently reinstated" with the reinstate date + the reason: `graduation criterion met (release-risk ≤ P<NNN> Priority <N>); class <3a/3b>; evidence cited`.

#### Rule 7 — Governance gates apply (extends ADR-042 Rule 3)

Every graduation reinstate goes through the standard ADR-014 commit flow: architect review, JTBD review, risk-scorer gate. The graduation criterion does NOT bypass the gates — Rule 1 authorises the *intent*; the gates authorise the *action*. A gate rejection on any graduation falls through to ADR-042 Rule 5 halt with the rejection reason logged.

In AFK mode, graduation auto-apply commits fold into the iteration's main commit via `git commit --amend` per ADR-042 Rule 3 amend-based folding, preserving ADR-032's one-commit-per-iteration invariant.

#### Rule 8 — Drain condition amendment (Phase 1b)

ADR-018 Step 6.5 and ADR-020 §3 drain conditions are amended to add a disjunct covering graduatable held entries. The amended condition reads:

```
Drain when: pipeline residual ≤ 4/25 AND
            (.changeset/ non-empty OR
             docs/changesets-holding/ contains entries that satisfy Rule 1
             AND are not VP-blocked per Rule 2)
```

This wakes the drain when graduation-eligible material exists, closing the I002 empty-conjunct silent-stop failure mode. ADR-018/020's at-appetite + non-empty-`.changeset/` semantics are preserved as the primary disjunct; the graduation-eligible holding disjunct is the symmetric addition.

The ADR-018 / ADR-020 prose updates ride a separate commit (this ADR's landing commit covers the ADR-061 file + the P162 ticket Phase 1 checkbox; the ADR-018/020 amendments and the SKILL.md plumbing land in subsequent Phase 2 / Phase 4 iters per the P162 phasing).

### Scope

**In scope (this ADR's landing commit):**

- `docs/decisions/061-dogfood-graduation-criteria.proposed.md` — this document.
- `docs/problems/open/162-codify-dogfood-graduation-criteria-with-counterfactual-risk-assessment-for-held-changesets.md` — Phase 1 Investigation Tasks checkbox marked done; Change Log entry recording the ADR landing.

**Out of scope (this ADR's landing — owned by later P162 phases):**

- **Phase 2** — Risk-scorer extension implementing the `release-risk` re-computation with hypothetical reinstate, the Rule 1a join, the Rule 4 evidence-floor lookup, and emission of `reinstate-from-holding` `RISK_REMEDIATIONS:` entries. Behavioural bats per ADR-052 covering: (a) release-risk > Priority → no remediation; (b) release-risk ≤ Priority + floor met → remediation emitted; (c) ambiguous/missing problem reference → halt-with-prompt; (d) multi-ticket changeset uses max(Priority); (e) Priority climbs via re-rate → graduation triggers without release-risk decay; (f) VP-blocked changeset → no remediation; (g) atomic-cohort class evaluates full cohort.
- **Phase 3** — Retroactive evaluation against any then-held changesets to establish a graduation-criterion baseline. The I001 + I002 manual graduations (2026-05-06 / 2026-05-10) are the *empirical baseline* this ADR grounds in — Phase 3 exercises the *automated* join on whatever holds exist when the risk-scorer extension lands.
- **Phase 4** — `docs/changesets-holding/README.md` Process amendment adding the graduation flow as an explicit step; ADR-018 + ADR-020 prose amendments encoding Rule 8.

## Consequences

### Good

- **Symmetric risk control loop closes.** ADR-042 Rule 1 (never release above appetite) + ADR-061 Rule 1 (never hold below graduation threshold) together produce a closed system. Material flows in when release-risk would exceed appetite; material flows out when release-risk falls at or below problem-ticket Priority.
- **Score-already-exists insight collapses Effort.** Phase 2's risk-scorer extension is a join (changeset filename → ticket ID → Priority field), not a new evidence pipeline. Effort bound stays firmly M; the L-growth path via a `.afk-run-state/dogfood-evidence.jsonl` accumulator is closed.
- **I001 + I002 empirical baseline grounds the design.** This is not a speculative ADR — the symmetric-balance criterion was applied manually as I001 (3 orthogonal-gate holds, 12 / 10 / 2 day windows) and I002 mitigation H3 (13-entry atomic-cohort across 5 packages). Both shipped clean. Per ADR-026, the design grounds in observable evidence rather than projection.
- **Drain-condition coupling is fixed at the source.** Phase 1b Option A amends ADR-018/020 drain condition so it wakes on either form of release-eligible material (`.changeset/` non-empty OR graduatable held entries). I002's silent-stop failure mode cannot recur once Phase 4 lands the prose.
- **JTBD-006 / 101 / 302 / 001 contracts all close their loops.** Backlog drains without per-graduation `AskUserQuestion`. Plugin-developer ceremony cost has a defined payoff path. Plugin-user adopters receive published features, not silently-merged-but-unreleased ones. Change-set-level governance applies symmetrically to inflow and outflow.
- **VP carve-out (Rule 2) prevents the auto-reinstate-publish-during-verification soft-lock.** Symmetric to ADR-042 Rule 2b.
- **Per-class evidence floors are grounded per ADR-026.** Each class names a persistable artefact (gate stderr, hook log, git log, session trail) — the floor cites + persists + carries uncertainty rather than relying on a bare count.

### Neutral

- **Phase 2 implementation introduces new join surface in the risk-scorer.** The join is mechanical (filename → ticket file → Priority field) but adds a code path the risk-scorer didn't previously have. Mitigated by ADR-052 behavioural-bats coverage in the Phase 2 landing.
- **Rule 4 per-class evidence floors require careful classification of held changesets.** The four classes enumerated (PreToolUse:Bash / UserPromptSubmit / commit-hook-with-auto-fix / SessionStart additionalContext) cover all observed surfaces to date but a fifth class is plausible (e.g. PostToolUse hooks, MCP-server hooks). Reassessment trigger covers this.
- **Atomic-cohort class (Rule 3b) requires RFC-ticket cohort enumeration.** The RFC ticket must explicitly enumerate the cohort for the orchestrator to classify reliably. ADR-060 finding 12 already requires this; ADR-061 inherits the requirement.

### Bad

- **Rule 4 evidence-floor satisfaction is class-specific and may not generalise cleanly to novel hook patterns.** When a new hook class emerges, the orchestrator may halt-and-prompt under Rule 1a (no class match) rather than picking a default. Mitigation: halt-and-prompt is the JTBD-006 graceful-stop path, not a failure — surfacing the class gap to the user is the correct behaviour, and the Reassessment Triggers list captures the trigger for amending the rule set.
- **Multi-ticket changesets with `max(Priority)` may over-prioritise graduation when the highest-Priority ticket is incidentally referenced.** The body-grep fallback is permissive. Mitigated by Rule 7 gate traversal: every graduation goes through architect + JTBD + risk-scorer review at commit time; an over-eager graduation fails the gates and routes to ADR-042 Rule 5 halt.
- **Phase 1b drain-condition amendment introduces a new disjunct that increases evaluation cost per drain check.** ADR-018/020 drain checks now need to enumerate graduatable held entries to test the second disjunct. Cost is bounded by holding-area size; observable I001/I002 sizes (3, 13 entries) suggest the cost is low. If holding-area grows beyond observed size, the cost may become non-trivial — covered in Reassessment Triggers.
- **Graduation criterion is downstream of a problem-ticket Priority that may itself be miscalibrated.** If the ticket's Impact × Likelihood is wrong, the graduation balance is wrong. Mitigated by `/wr-itil:review-problems` re-rate pass, which is the authoritative source of Priority for graduation purposes (the same source WSJF dev-ranking uses).

## Confirmation

Compliance is verified by:

1. **Source review of ADR-061** — this document contains: the symmetric-balance criterion (Rule 1), the join contract (Rule 1a) with halt-and-prompt fallback, the VP carve-out (Rule 2), the two evaluation units with ADR-060 finding 12 citation (Rule 3), the four per-class evidence shapes with persistable artefacts per ADR-026 (Rule 4), the Step 6.5 trigger conditions (Rule 5), the audit trail per ADR-042 Rule 6 extension (Rule 6), the gate-per-graduation per ADR-014 + ADR-042 Rule 3 extension (Rule 7), and the drain-condition amendment (Rule 8).

2. **Bats contract assertions (Phase 2 deliverable per ADR-052 behavioural-bats default)** — Phase 2 lands behavioural tests against the risk-scorer's new join surface. Required coverage:
   - Filename-convention join resolves `wr-itil-p085-…md` → P085 → Priority value.
   - Body-grep fallback resolves when filename does not match convention.
   - Multi-ticket changeset uses `max(Priority)` across the referenced set.
   - Halt-and-prompt fires when no resolution path succeeds.
   - VP-blocked ticket is excluded from graduation.
   - Atomic-cohort class evaluates the full cohort (release-risk computed against all cohort members, Priority = max across cohort tickets).
   - Per-class evidence floor lookup cites the class-specific artefact path.

3. **Behavioural (manual until Phase 2 lands)** — the I001 manual graduation (2026-05-06, P085 + P064 + P159) and I002 mitigation H3 (2026-05-10, 13-entry RFC-001 + RFC-002 atomic cohort) are the empirical confirmation that the symmetric-balance criterion produces clean shippable outcomes. Both groups shipped to npm with no false-positives in post-graduation `push:watch` + `release:watch` drain. The ADR-061 codification is consistent with the observed manual practice.

4. **Drain-condition amendment landed (Phase 4 deliverable)** — ADR-018 Step 6.5 and ADR-020 §3 prose include the graduatable-holding disjunct; bats coverage in the relevant SKILL.md test files asserts the load-bearing strings (`docs/changesets-holding/`, `Rule 1`, `non-empty disjunct`).

## Reassessment Triggers

Revisit this decision if:

- **Graduation criterion fires but reintroduces a regression within N commits** (suggesting the criterion is too aggressive). Concrete signal: a graduated changeset is reverted within 3 commits post-graduation, OR a graduated changeset's originating problem ticket is re-opened with a status reflecting the just-shipped behaviour as the regression source. Treat as a Rule 4 evidence-floor calibration signal or a Rule 1 threshold signal.
- **Held changesets accumulate past N entries with no graduations firing** (suggesting the criterion is too conservative). Concrete signal: holding-area size exceeds the I002 baseline (13 entries) for ≥ 7 days with zero `reinstate-from-holding` auto-applies despite ≥ 1 within-appetite drain cycle per iter.
- **A fifth class of held surface emerges beyond the four enumerated in Rule 4** (e.g. PostToolUse hooks, MCP-server hooks, additionalContext outside SessionStart). Treat as a Rule 4 extension trigger; draft an amendment that adds the new class with its evidence shape + persistable artefact.
- **The risk-scorer's `release-risk` scoring shape changes** in a way that affects the Rule 1 symmetric-balance math (e.g. score becomes asymmetric across move-to-holding vs reinstate-from-holding). The amendment ADR or supersession would re-pin Rule 1's comparison.
- **ADR-022 (Verification Pending) is superseded** — Rule 2's VP carve-out cites ADR-022 directly. A supersession may rename or restructure the lifecycle status; Rule 2 needs to track.
- **ADR-042 (parent inflow contract) is superseded** by the Innovation-Window-close ADR — ADR-061 cites ADR-042 Rules 2 / 2a / 2b / 3 / 6 directly. The superseding ADR may restructure Rule 2a's open vocabulary; Rule 5 and Rule 6's references need to track.
- **ADR-060 finding 12 (atomic-cohort graduation) is amended** — Rule 3b cites finding 12 directly. An amendment may change the cohort-enumeration shape; Rule 3b needs to track.
- **Holding-area enumeration cost becomes non-trivial** per Phase 1b Consequence — i.e. holding-area size grows beyond what the per-drain enumeration can absorb without slowing Step 6.5 below the JTBD-001 per-edit budget. Treat as a Rule 8 amendment trigger (e.g. cache graduation eligibility per held entry; invalidate on entry / re-score event).
- **Manual graduations diverge from criterion verdicts** — the user manually reinstates a changeset that Rule 1 would have rejected, or refuses to reinstate one Rule 1 would have approved. Treat as criterion-calibration evidence; surface in the next `/wr-retrospective:run-retro` for codification.

## Related

- **ADR-042** (`docs/decisions/042-auto-apply-scorer-remediations-open-vocabulary.proposed.md`) — parent inflow contract; this ADR is the symmetric outflow contract. Rule 1 mirrors ADR-042 Rule 1's never-release-above-appetite invariant. Rule 2 mirrors ADR-042 Rule 2b's VP carve-out. Rule 6 extends ADR-042 Rule 6's audit trail. Rule 7 extends ADR-042 Rule 3's gate-per-commit.
- **ADR-018** (`docs/decisions/018-inter-iteration-release-cadence-for-afk-loops.proposed.md`) — Step 6.5 drain trigger. Rule 8 amends to add the graduatable-holding disjunct. Phase 4 prose update lands the amendment.
- **ADR-020** (`docs/decisions/020-governance-auto-release-for-non-afk-flows.proposed.md`) — §3 drain trigger. Rule 8 amends to add the graduatable-holding disjunct. Phase 4 prose update lands the amendment.
- **ADR-022** (`docs/decisions/022-problem-lifecycle-verification-pending-status.proposed.md`) — Verification Pending lifecycle authority for Rule 2 VP carve-out.
- **ADR-026** (`docs/decisions/026-agent-output-grounding.proposed.md`) — cite + persist + uncertainty grounding requirement; Rule 4 per-class evidence shapes ground in observable persistable artefacts per this ADR.
- **ADR-052** (`docs/decisions/052-behavioural-tests-default-for-skill-testing.proposed.md`) — behavioural-bats default for Phase 2 join-surface coverage per Confirmation criterion 2.
- **ADR-060** (`docs/decisions/060-problem-rfc-story-framework-with-mandatory-problem-trace-and-unified-problem-ontology.accepted.md`) — finding 12 atomic-cohort invariant; Rule 3b operationalises without amending ADR-060.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — commit-discipline authority; Rule 7 inherits gate-per-commit requirement.
- **ADR-013** (`docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`) — Rule 5 policy-authorised silent-action authority; graduation-driven reinstate is policy-authorised once Rules 1 / 1a / 2 / 4 / 5 all evaluate true; no per-reinstate `AskUserQuestion` is required.
- **ADR-015** (`docs/decisions/015-on-demand-assessment-skills.proposed.md`) — pure-scorer contract; Phase 2 extends with the `release-risk` re-computation against hypothetical reinstate.
- **ADR-044** (`docs/decisions/044-decision-delegation-contract.proposed.md`) — framework-resolution boundary; per-graduation `AskUserQuestion` is exactly the silent-framework class the contract carves out. Halt-and-prompt under Rule 1a is the genuine direction-class surface.
- **P162** (`docs/problems/open/162-codify-dogfood-graduation-criteria-with-counterfactual-risk-assessment-for-held-changesets.md`) — driver ticket. This ADR lands Phase 1. Phases 2–4 remain Open under P162.
- **P085** (`docs/problems/closed/085-…closed.md`) — first orthogonal-gate hold; 12-day dogfood window; I001 mitigation baseline.
- **P064** (`docs/problems/closed/064-…closed.md`) — second orthogonal-gate hold; 10-day dogfood window; I001 mitigation baseline.
- **P159** (`docs/problems/closed/159-…closed.md`) — third orthogonal-gate hold; 2-day dogfood window; I001 mitigation baseline.
- **I001** (`docs/incidents/I001-unreleased-changeset-queue-violates-lean-wip-and-raises-cumulative-release-risk.restored.md`) — first empirical orthogonal-gate-graduation baseline (2026-05-06).
- **I002** (`docs/incidents/I002-release-pressure-and-wip-limit-controls-not-firing.restored.md`) — first empirical atomic-cohort-graduation baseline (2026-05-10); also the surfacing surface for the Phase 1b drain-condition empty-conjunct coupling.
- **`docs/changesets-holding/README.md`** — Currently held / Recently reinstated audit surface per Rule 6.
- **JTBD-006** (`docs/jtbd/solo-developer/JTBD-006-work-backlog-afk.proposed.md`) — primary motivator; auto-graduation + halt-and-prompt both authorised by JTBD-006 Desired Outcomes.
- **JTBD-001** (`docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md`) — change-set-level governance authority (2026-05-05 amendment).
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — plugin-developer move-to-holding payoff contract.
- **JTBD-302** (`docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`) — adopter README-currency contract.
