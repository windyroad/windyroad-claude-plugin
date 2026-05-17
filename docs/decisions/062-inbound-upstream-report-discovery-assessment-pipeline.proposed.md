---
status: "proposed"
date: 2026-05-14
decision-makers: [tomhoward]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users, plugin maintainers, downstream adopters]
reassessment-date: 2026-08-14
---

# Inbound upstream-report discovery + assessment pipeline (peer of ADR-024)

## Context and Problem Statement

ADR-024 defined the **outbound** problem-reporting contract — `/wr-itil:report-upstream` files a structured report from a local problem ticket against an upstream repo's intake (issue / discussion / security advisory). ADR-036 scaffolded the **intake** templates downstream adopters install.

But there is **no inbound discovery contract**. Reports filed against this repo's intake (`windyroad/agent-plugins`) sit in `gh issue list` until a maintainer manually polls. The end-to-end promise — plugin user files a report → maintainer sees it → ticket gets triaged — has an invisible gap at the discovery step. P079 ticket: *"plugin user files a well-structured `problem-report.yml` issue and it sits invisible in `gh issue list` until the maintainer remembers to look."*

The user's direction (2026-04-21 + 2026-04-26 interactive resolution recorded in P079) extends inbound discovery from "list new reports" to a **multi-step assessment pipeline** that processes each inbound report through JTBD-alignment + dual-axis risk + branches to {auto-acknowledge with local ticket | pushback comment | policy-violation close with verdict comment}. All external comms ride the P064 + P038 gates (ADR-028 amended).

Three carve-outs from P079 ship as separate tickets:
- **P123** — blocked-user-list persistence + enforcement (ADR-046 already accepted; this ADR consumes its scaffold).
- **P128** — outbound report Versions schema (ADR-033 amended 2026-05-03).
- **P129** — version-aware inbound classifier (already-fixed-in-newer / recurred / still-active branches).

This ADR documents the **inbound discovery contract** and the **assessment-pipeline framework** that those carve-outs extend.

## Decision Drivers

- **JTBD-301** (Report a Problem Without Pre-Classifying It — plugin-user persona) — every submitted report must receive a predictable acknowledgement: labelled, routed, and eventually responded to with a verdict (fix released / parked / duplicate / won't-fix / policy-violation). Silent disappearance breaks the contract. **Non-negotiable**: even policy-violation closes require a brief gated verdict comment before close.
- **JTBD-001** (Enforce Governance Without Slowing Down — solo-developer) — the assessment-pipeline classifier is **mechanical** at the {pushback | policy-violation | safe-and-valid} branch decision (driven by JTBD-trace + dual-axis risk verdicts, not user choice). Per-branch confirmation would re-introduce the friction P132 was engineered to remove.
- **JTBD-101** (Extend the Suite with New Plugins — plugin-developer) — downstream adopters scaffold intake templates per ADR-036. The inbound-discovery contract runs **on this repo's tracker only**; downstream adopters do NOT inherit an obligation to implement inbound discovery on their own trackers. Explicit non-obligation closes a JTBD-101 ceremony-tax risk.
- **JTBD-201** (Restore Service Fast with an Audit Trail — tech-lead) — discovery-pass results and classify-malicious decisions must be inspectable for replay. Cache file + audit-log surface satisfies this.
- **JTBD-202** (Run Pre-Flight Governance Checks Before Release or Handover — tech-lead) — the assessment pipeline runs at `manage-problem review` cadence, the same point where the maintainer audits backlog state. No new invocation surface to remember.
- **JTBD-006** (Progress the Backlog While I'm Away — AFK) — `/wr-itil:work-problems` should surface inbound reports during AFK loops. The assessment-pipeline's mechanical branches keep the loop running; user-attention surfaces only at the verdict-comment delegation step (which rides the P064 + P038 external-comms gates).
- **P079** — inbound discovery gap. This ADR closes it.
- **ADR-024** — outbound peer contract. This ADR explicitly extends ADR-024's outbound semantics with the matching inbound half.
- **ADR-028 amended** — both pushback + acknowledgement + policy-violation-verdict comments fire through the external-comms gate (P064 risk evaluator + P038 voice-tone evaluator). No bare comment posting.
- **ADR-029** (Diagnose before implement) — the assessment-pipeline classifier IS a diagnose-style operation (hypothesis: this report aligns with persona X's JTBD-N; evidence: structured signals from the report body + risk evaluators' verdicts; structured verdict: aligned / not-aligned / above-threshold / clear-malicious). The pipeline's structured-output contract follows ADR-029's evidence-then-verdict shape.
- **ADR-031** (problem-ticket directory layout) — the cache file (`docs/problems/.upstream-cache.json`) and channel-config file (`docs/problems/.upstream-channels.json`) live under `docs/problems/` per ADR-031's scope.
- **ADR-046** (Blocked-reporters persistence) — already accepted. The clear-malicious branch writes to the audit-log + (optionally, per P123) the block-list maintained by `block-list.sh`.

## Considered Options

### Option 1 (chosen): Extend `/wr-itil:review-problems` with a new Step 8.5 inbound-discovery sub-step

Add a sub-step between Step 8 (re-rank dev-work queue) and Step 9 (refresh README.md cache) that:
1. Reads `docs/problems/.upstream-channels.json` (channel config).
2. Queries each channel via `gh issue list` / `gh api discussions` / `gh api security-advisories`; caches results to `docs/problems/.upstream-cache.json` (TTL configurable; default 24h, `--force-upstream-recheck` flag bypasses TTL).
3. For each **unmatched** report (new since last cache snapshot — matching against existing local tickets via P070's semantic-comparator infrastructure), runs the assessment pipeline (see Decision Outcome).
4. Renders the `## Inbound Upstream Reports` section in `docs/problems/README.md`.
5. Appends discovery-pass entries to `docs/audits/inbound-discovery-log.md`.

**Pros:** single cohesive surface; leverages existing review-step cache cadence; commit-grain stays one-per-review per ADR-014; matches ADR-010's skill-granularity rule (inbound-discovery is part of "re-assess backlog" intent).

**Cons:** adds external-dependency (GH API) to every review invocation — must fail-soft.

### Option 2 (rejected): New sibling skill `/wr-itil:sync-upstream-reports`

Maintainer must remember a second command. Cadence drifts from main review.

### Option 3 (rejected): Inline auto-poll on every commit

Far too noisy; rate-limits GH API; runs at wrong cadence (review-time is the natural surface for backlog audits).

## Decision Outcome

**Chosen: Option 1.**

### Channel config

`docs/problems/.upstream-channels.json` enumerates channels to poll:

```json
{
  "$schema": "https://windyroad.github.io/agent-plugins/schemas/upstream-channels.json",
  "channels": [
    {
      "type": "github-issues",
      "repo": "windyroad/agent-plugins",
      "label": "problem-report",
      "template": "problem-report.yml"
    },
    {
      "type": "github-discussions",
      "repo": "windyroad/agent-plugins",
      "category": "Q&A"
    },
    {
      "type": "github-security-advisories",
      "repo": "windyroad/agent-plugins"
    }
  ],
  "ttl_seconds": 86400
}
```

Default config checked into this repo; adopters edit to suit.

### Cache file

`docs/problems/.upstream-cache.json` stores the most-recent discovery snapshot:

```json
{
  "last_checked": "2026-05-14T22:30:00Z",
  "channels": {
    "github-issues:windyroad/agent-plugins:problem-report": {
      "fetched_at": "2026-05-14T22:30:00Z",
      "reports": [
        {
          "id": 42,
          "title": "...",
          "author": "...",
          "created_at": "...",
          "body_hash": "<sha256>",
          "matched_local_ticket": null,
          "classification": null
        }
      ]
    }
  }
}
```

Committed to the repo (audit-trail value > storage cost; rebuild via `--force-upstream-recheck`).

### Assessment pipeline

For each unmatched inbound report, the pipeline runs these steps **in order**. Each step's output is recorded in the cache (and, for clear-malicious, also in the audit log).

1. **Version-aware classification (P129 carve-out — future extension)** — compare reporter's version vs closed-ticket fix-versions. Three outcomes: `already-fixed-in-newer` (upgrade-pushback path), `recurred-in-newer-version` (regression-handling path), `still-active` (continue to step 2). When P129 is unlanded, this step is skipped and all reports go to step 2.

2. **JTBD alignment classifier** — invoke `wr-jtbd:agent` against the report body + persona JTBDs. Three outcomes:
   - `aligned-with-existing-JTBD` — report fits a documented JTBD; continue to step 3.
   - `aligned-with-new-JTBD-for-existing-persona` — report identifies a new valid JTBD; flag for maintainer attention (auto-create local ticket + JTBD-extension note); continue to step 3.
   - `not-aligned` — report doesn't fit any persona's JTBD; route to **above-threshold pushback** branch (step 4) with reason "out-of-scope-for-documented-personas".

3. **Dual-axis risk classifier** — invoke the **new sibling subagent `wr-risk-scorer:inbound-report`** (peer of `wr-risk-scorer:external-comms`, NOT an extension — see "Sibling subagent" below). Reviews two axes:
   - **Axis 1 — Request risk**: is the report itself an attack vector? Info-extraction (asks the maintainer to reveal internals), backdoor request (asks to add a backdoor / weaken security), malicious-code injection (asks to incorporate user-supplied code that's likely malicious). RISK-POLICY.md amendment lands alongside this ADR to enumerate these classes.
   - **Axis 2 — Fix risk**: what's the risk profile of doing the work the report asks for? Some legitimate-looking reports request changes that are themselves high-risk to ship (e.g., privilege escalation, removal of a load-bearing safety check).
   - Outcomes: `safe-low-fix-risk` (continue), `safe-high-fix-risk` (continue with maintainer attention flag), `clear-malicious-request` (route to step 5 clear-malicious branch), `above-threshold-risk` (route to step 4 above-threshold pushback).

4. **Above-threshold pushback branch** — pipeline posts a gated `gh issue comment` explaining why the report is declined. The comment fires through the external-comms gate (both P038 voice-tone + P064 risk-scorer evaluators per ADR-028 amended 2026-05-14). Upstream issue is NOT closed by the pipeline (maintainer decides closure manually after the pushback). Cache entry classification: `above-threshold-pushback`.

5. **Clear-malicious branch** — pipeline posts a **brief gated verdict comment** (JTBD-301 requires acknowledgement; silent close is forbidden) explaining the policy-violation classification, THEN closes the upstream issue, THEN appends the reporter handle to the audit log (`docs/audits/inbound-discovery-log.md`). P123 carve-out extends this branch with block-list enforcement at the next discovery pass; until P123 lands, the audit-log entry alone is the record. Cache entry classification: `clear-malicious-closed`.

6. **Safe-and-valid branch** — pipeline auto-creates a local problem ticket via `/wr-itil:capture-problem` (passing the report body verbatim as the description) AND posts a gated `gh issue comment` acknowledgement carrying the local ticket reference. Cache entry classification: `safe-and-valid-local-ticket-created`, with `matched_local_ticket: P<NNN>`.

### Sibling subagent `wr-risk-scorer:inbound-report`

**NEW** subagent type, NOT an extension of `wr-risk-scorer:external-comms`. Reasoning:

- `wr-risk-scorer:external-comms` reviews **outbound prose** for confidential-information leaks per RISK-POLICY.md (this repo's data leaking outward).
- `wr-risk-scorer:inbound-report` reviews **third-party prose for malicious intent + fix-risk** (third-party intent flowing inward). Distinct evaluator concern.

ADR-015 Scope table gains the new row when this ADR lands its implementation. The on-demand skill `/wr-risk-scorer:assess-inbound-report` is the manual-delegation wrapper per the ADR-015 pattern.

### Mechanical-stage carve-out (P132)

Per JTBD-001 + P132 (agents over-ask when SKILL contract carves out mechanical stages), the **three branch decisions** in the assessment pipeline (above-threshold-pushback / clear-malicious / safe-and-valid) are explicitly mechanical. `wr-itil:review-problems` Step 8.5 does NOT use `AskUserQuestion` to ask the maintainer "which branch?" — the dual-axis risk verdict + JTBD-alignment classifier resolve the branch deterministically. User-attention surfaces ONLY at:

- Hook gates (the external-comms gate fires on the comment write — user is asked to delegate to the evaluator subagents per the existing gate UX).
- The new-JTBD-for-existing-persona case (step 2 outcome 2.b) — auto-creates the local ticket BUT flags it for maintainer review at next interactive `review-problems` invocation.
- Cache-divergence edge cases (e.g., the same upstream issue title matches two local tickets under P070's semantic-comparator) — the cache writer surfaces ambiguity via a `cache_audit_note` field; maintainer resolves at review time.

Per-branch `AskUserQuestion` would re-introduce friction in AFK loops (`/wr-itil:work-problems` Step 6.5 calling `review-problems`) — those loops are designed to drain backlog mechanically. This carve-out is the framework-resolution boundary (ADR-044 category 4: silent framework action).

### Audit-log surface

`docs/audits/inbound-discovery-log.md` (new) is the durable audit trail for inbound discovery passes. **Path is intentional**: per CLAUDE.md P131, project-generated artefacts go under `docs/` (NOT `.claude/`). The log is committed to the repo (audit-trail value > storage cost; rebuild via `--force-upstream-recheck`).

Each pass appends:

```markdown
## 2026-05-14T22:30:00Z — Discovery pass

- Channels polled: 3 (github-issues:windyroad/agent-plugins, github-discussions:windyroad/agent-plugins, github-security-advisories:windyroad/agent-plugins)
- Reports discovered: 7 new, 12 unchanged
- Pipeline outcomes:
  - Safe-and-valid: 5 (local tickets P201..P205 created)
  - Above-threshold pushback: 1 (issue #42 — out-of-scope-for-documented-personas)
  - Clear-malicious: 1 (issue #43 — info-extraction pattern; reporter @bad-actor logged for P123 block-list when that ticket lands)
- Cache: docs/problems/.upstream-cache.json refreshed.
```

The audit-log is read by P123's enforcement when it lands; until then it's the closure-record for the clear-malicious branch.

### Downstream-adopter contract (JTBD-101 non-obligation)

Downstream adopters who run `/wr-itil:scaffold-intake` per ADR-036 receive the **outbound** half of the contract (intake templates installed in their repo). They do NOT inherit an obligation to implement inbound-discovery on their own trackers — their tracker is their own concern.

This ADR's inbound-discovery contract is **specific to this repo** (`windyroad/agent-plugins`). When downstream adopters want symmetric inbound-discovery on their own repos, they can opt-in by adding `docs/problems/.upstream-channels.json` to their repo (the schema is portable; `review-problems` Step 8.5 reads it without further configuration). But adoption is opt-in, not required.

### Scope

**In scope (this ADR):**

- Channel config + cache file schemas (above).
- `/wr-itil:review-problems` Step 8.5 inbound-discovery sub-step.
- Assessment-pipeline framework (steps 2–6; step 1 is the P129 carve-out's future extension point).
- Sibling subagent `wr-risk-scorer:inbound-report` + on-demand skill `/wr-risk-scorer:assess-inbound-report`.
- RISK-POLICY.md amendment enumerating Request-risk + Fix-risk classes.
- ADR-015 Scope table gains `wr-risk-scorer:inbound-report` row (when implementation lands).
- ADR-024 amendment: Confirmation note that inbound counterpart exists (this ADR).
- Audit-log file `docs/audits/inbound-discovery-log.md`.
- Bats coverage per ADR-037 + P081 (behavioural — synthetic inbound reports through synthetic-channel fixture; assert each of the six pipeline outcomes routes correctly).
- `## Inbound Upstream Reports` section renderer in `docs/problems/README.md` (per `review-problems` Step 9e).

**Out of scope (future ADRs or carve-outs):**

- **P129** version-aware classification (step 1 above) — separate carve-out ticket; this ADR's step 1 is the integration seam.
- **P128** outbound Versions schema — ADR-033 amendment 2026-05-03 already shipped; this ADR's classifier consumes it.
- **P123** blocked-user-list enforcement — separate ticket per ADR-046's enforcement extension; this ADR's clear-malicious branch just appends to the audit-log.
- **P080** bidirectional outbound-lifecycle update — local ticket transitions propagate back to upstream issue comments. Outbound-direction sibling; separate ADR if needed.
- Auto-resolution detection (sub-concern 7 from P079 — upstream issue closes with a resolution marker, propagate to local lifecycle). Carve-out candidate; deferred.
- Duplicate-detection-bot comment-class detection (sub-concern 5 from P079) — bot-comment vs maintainer-comment classification. Carve-out candidate; deferred.
- Time-pressure deadline tracking (sub-concern 6 from P079 — auto-close timers, stale labellers). Carve-out candidate; deferred.

## Consequences

### Good

- Inbound reports surface at the same cadence maintainers audit the backlog. JTBD-301 acknowledgement contract honored end-to-end.
- Assessment-pipeline classifier reduces manual triage burden. JTBD-001 "without slowing down" preserved.
- Audit-log surface satisfies JTBD-201 replay-ability for inbound-discovery decisions.
- Sibling subagent keeps `external-comms` scope-pure; future evaluators (licence-compliance, claim-accuracy) plug in via the same ADR-015 row pattern.
- Downstream-adopter non-obligation prevents JTBD-101 ceremony-tax accumulation.
- Cache file committed makes audit replay deterministic.

### Neutral

- External GH API dependency added to every `review-problems` invocation. Fail-soft: cache TTL absorbs API outages; advisory-only systemMessage on API failure permits the review to complete.
- Cache file changes contribute to commit churn at every review. Mitigated by ADR-014's commit-grain rule (one review = one commit including cache + README.md refresh).
- Assessment-pipeline runtime cost = N × (JTBD-classifier round-trip + inbound-report-classifier round-trip) where N = unmatched reports. Bounded by cache TTL; typical batch size is low (1-3 reports per day at current adoption).

### Bad

- Sibling subagent adds one more row to ADR-015's Scope table.
- New audit-log file under `docs/audits/` is a new persistence layer. Pattern-precedent: P099 advisory accumulator extension under `docs/briefing/`; this ADR follows the same shape.
- Auto-action surface on safe-and-valid branch (auto-creates local ticket) is bounded but a new policy step. Mitigation: classification + branch decisions are recorded in cache + audit-log for replay; maintainer can override at interactive review.
- Policy-violation-close branch posts a brief verdict comment before close (JTBD-301 acknowledgement non-negotiable). This is more conservative than silent-close but adds one gated external-comms call per malicious report.

## Confirmation

Compliance is verified by:

1. **Source review:**
   - `packages/itil/skills/review-problems/SKILL.md` Step 8.5 exists and documents the six pipeline steps.
   - `docs/problems/.upstream-channels.json` + `.upstream-cache.json` schemas match the shapes above.
   - `packages/risk-scorer/agents/inbound-report.md` exists; subagent type `wr-risk-scorer:inbound-report` documented in ADR-015 Scope table.
   - `packages/risk-scorer/skills/assess-inbound-report/SKILL.md` exists (peer of `assess-external-comms`).
   - RISK-POLICY.md `## Inbound Report Risk Classes` section enumerates Request-risk + Fix-risk classes.
   - `docs/audits/inbound-discovery-log.md` exists with the documented append shape.

2. **Tests (bats)** — behavioural per ADR-037 + P081:
   - `packages/itil/skills/review-problems/test/inbound-discovery.bats` — synthetic inbound report fixture; assert each of the six pipeline outcomes routes correctly.
   - `packages/itil/skills/review-problems/test/inbound-cache-contract.bats` — channel-config parse + TTL contract + `--force-upstream-recheck` flag.
   - `packages/risk-scorer/agents/test/inbound-report-contract.bats` — subagent prompt carries both Request-risk + Fix-risk axis rubric; emits structured `INBOUND_REPORT_VERDICT` + `INBOUND_REPORT_KEY`.
   - `packages/itil/skills/review-problems/test/inbound-discovery-readme-render.bats` — `## Inbound Upstream Reports` section appears in README.md after pipeline runs.

3. **Behavioural replay** (end-to-end):
   - File a synthetic clean report via `gh issue create`; run `manage-problem review`; confirm local ticket created + acknowledgement comment posted (both rides external-comms gates).
   - File a synthetic out-of-scope report; confirm pipeline routes to above-threshold-pushback; comment fires through gate.
   - File a synthetic info-extraction report; confirm pipeline routes to clear-malicious; verdict comment fires through gate; issue closed; audit-log appended.
   - File a synthetic report whose body matches an existing local ticket (semantic-comparator hit via P070); confirm pipeline skips creation + comments with cross-reference.

4. **Cross-reference confirmation:**
   - ADR-024 Consequences note inbound counterpart exists (this ADR).
   - ADR-015 Scope table has the `wr-risk-scorer:inbound-report` row.
   - ADR-046 audit-log shape extended to enumerate this ADR's append entries.

5. **Work-problems pre-flight wiring (JTBD-006 driver):**
   - `packages/itil/skills/work-problems/SKILL.md` Step 0b sources `packages/itil/lib/check-upstream-cache-staleness.sh` and pre-flights `/wr-itil:review-problems` when the upstream inbound-discovery cache is stale, missing, or has `last_checked: null`. Pre-flight dispatch shape mirrors Step 5's `claude -p` subprocess wrapper per P084 + ADR-032 subprocess isolation. Behavioural test: `packages/itil/skills/work-problems/test/work-problems-step-0b-cache-staleness-behavioural.bats`. JTBD-006's "Desired Outcomes" lists this pre-flight as a documented expectation. The staleness comparison stays symmetric with review-problems Step 4.5b's branches; the contract-source marker `<!-- INBOUND-CACHE-STALENESS-CONTRACT-SOURCE -->` is anchored in both spots so future TTL-semantics changes update them in the same commit.

## Reassessment Criteria

Revisit this decision if:

- **Pipeline classifier false-positive rate exceeds ~10%** on either JTBD-alignment or inbound-report axis (measured against maintainer-overridden pipeline outcomes). Signals classifier prompts need tightening.
- **Cache TTL is too aggressive or too conservative** for the inbound rate. Triggers: maintainer complaints about stale view, or rate-limit failures. Adjust `ttl_seconds` in channel config.
- **A second consumer of the inbound-discovery primitive emerges** (e.g., a different skill needs to query upstream channels). Promote Step 8.5 to a sibling skill `/wr-itil:sync-upstream-reports` per the original Option 2; this ADR's Option-1 choice is non-permanent.
- **Auto-resolution detection (sub-concern 7) emerges as priority** — carve out as a new ticket; this ADR's `safe-and-valid` branch becomes the natural integration point.
- **Block-list enforcement (P123) ships** — this ADR's clear-malicious branch consumes the block-list at discovery time (filter reports from blocked reporters before pipeline runs). ADR-046's enforcement contract extends accordingly.
- **Downstream-adopter opt-in pattern emerges** — if multiple downstream projects start using the same channel-config schema for their own inbound-discovery, promote the schema to a shared library and document the contract as portable.

## Related

- **P079** — inbound discovery gap. Closed by this ADR's implementation.
- **P123** — blocked-user-list enforcement. Composes with this ADR's clear-malicious branch.
- **P128** — outbound Versions schema. Consumed by this ADR's step 1 (P129 future extension).
- **P129** — version-aware inbound classifier. Step 1 of this ADR's pipeline; future extension.
- **P080** — bidirectional outbound-lifecycle update. Outbound-direction sibling.
- **P249** — no process for issue reporters to check for responses. Phase 1 ships `/wr-itil:check-upstream-responses` skill as the **outbound-response-check sibling** of this ADR's inbound discovery pipeline. Together, both axes form the bidirectional cross-repo coordination surface JTBD-004 names: this ADR polls reports filed AGAINST our repos by external reporters; the P249 Phase 1 skill polls reports we filed AGAINST upstream repos. Outbound cache + audit-log mirror this ADR's `.upstream-cache.json` + `docs/audits/inbound-discovery-log.md` shapes (under `docs/problems/.outbound-responses-cache.json` + `docs/audits/outbound-responses-log.md`). P249 Phase 2 (external-reporter-as-our-reporter — plugin users polling responses to reports filed against THIS repo) is deferred to a separate iter as scheduled-future-surface per P179.
- **P070** — semantic-comparator infrastructure. Used for matched-local-ticket detection at this ADR's cache layer.
- **P132** — agents over-ask in mechanical-stage carve-outs. This ADR's mechanical-stage carve-out for the three pipeline branches is explicit per P132's framework-resolution boundary.
- **ADR-024** — outbound problem-reporting contract. Explicit peer of this ADR.
- **ADR-028** — external-comms gate. All pushback + acknowledgement + verdict comments ride both evaluator halves (P064 risk + P038 voice-tone).
- **ADR-029** — Diagnose before implement. Classifier follows hypothesis/evidence/structured-verdict discipline.
- **ADR-031** — problem-ticket directory layout. Cache + channel-config files live under `docs/problems/`.
- **ADR-033** — outbound report-body classifier. Mirror-direction; this ADR consumes the Versions schema ADR-033 amended produces.
- **ADR-036** — downstream scaffolding. Downstream adopters get the outbound half; inbound is non-obligation per this ADR.
- **ADR-037** — bats doc-lint. Behavioural coverage required.
- **ADR-044** — decision-delegation contract. The mechanical-stage carve-out is the framework-resolution-boundary application (category 4: silent framework action).
- **ADR-046** — blocked-reporters persistence. Already accepted. This ADR's audit-log file is the read surface; ADR-046's `block-list.sh` is the write surface.
- **CLAUDE.md P131** — `.claude/` is user-controlled; project-generated artefacts go under `docs/`. This ADR's audit-log file at `docs/audits/inbound-discovery-log.md` honors P131.
- **JTBD-001**, **JTBD-101**, **JTBD-201**, **JTBD-202**, **JTBD-006**, **JTBD-301** — personas whose constraints drive this ADR.
- `packages/itil/skills/review-problems/SKILL.md` — host of the Step 8.5 implementation.
- `packages/itil/skills/report-upstream/SKILL.md` — outbound peer; ADR-024 host.
- `packages/risk-scorer/agents/external-comms.md` — sibling-not-extension precedent for the new `inbound-report.md` agent.
