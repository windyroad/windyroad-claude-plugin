# Inbound upstream-report discovery — audit log

> Forward-chronology audit trail of `/wr-itil:review-problems` Step 8.5 inbound-discovery passes (P079 / ADR-062). Each pass appends a `## YYYY-MM-DDTHH:MM:SSZ` heading at the bottom with channels polled, reports discovered, pipeline outcomes, and cache refresh confirmation. This file is committed to the repo for audit-replay determinism.
>
> Path is intentional per CLAUDE.md P131 — project-generated artefacts go under `docs/`, never `.claude/`. The log is read by P123's blocked-reporters enforcement when it lands; until then it's the durable closure-record for the clear-malicious / policy-violation branch.
>
> See [ADR-062](../decisions/062-inbound-upstream-report-discovery-assessment-pipeline.proposed.md) Decision Outcome → "Audit-log surface" for the append contract.

## 2026-05-15 — Scaffold created (P079 ADR-062 Slice D)

Audit-log file initialised as part of P079's foundational architecture commit. No discovery passes yet recorded; `docs/problems/.upstream-cache.json` is empty (`last_checked: null`). First pass will append the inaugural entry when Slice C ships (`/wr-itil:review-problems` Step 8.5 implementation).

This entry is the file's existence record. Future passes will follow the documented append shape (channels polled / reports discovered / pipeline outcomes — safe-and-valid / above-threshold-pushback / policy-violation-close / cache refresh confirmation).

## 2026-05-15T04:33:26Z — Discovery pass (inaugural — label-filter bug surfaced)

First inbound-discovery pass executed via `/wr-itil:review-problems` Step 4.5 (ADR-062 Slice C implementation; Step 0b pre-flight wiring just shipped at aacec45). Initial pass polled with the as-shipped `label: problem-report` filter and returned 0 reports — **misleading**. User confirmed 31 open inbound issues exist at github.com/windyroad/agent-plugins/issues. Diagnosis identified a three-way drift (issue template ↔ repo label set ↔ channels-config filter) that erased all 31 reports from discovery: the `problem-report.yml` template auto-applies `[problem, needs-triage]` labels that **do not exist in the repo's label set**, and the channels-config filtered on `problem-report` which also doesn't exist. Every open inbound report is currently unlabelled; the title prefix `[problem]` (set by template line 3) is the reliable signal.

**Filter correction**: `docs/problems/.upstream-channels.json` updated 2026-05-15 — removed `label: problem-report`, added `title_prefix: "[problem]"` plus `$filter-note` documenting the drift. Re-poll surfaced 31 reports.

**Channels polled** (3 configured, 1 polled OK, 2 skipped fail-soft):

| Channel | Status | Reports |
|---|---|---|
| `github-issues:windyroad/agent-plugins` (title_prefix=`[problem]`) | OK | 31 |
| `github-discussions:windyroad/agent-plugins` (category=`Q&A`) | skipped | 0 — Discussions disabled for repo (HTTP 410) |
| `github-security-advisories:windyroad/agent-plugins` | skipped | 0 — LIST call blocked by external-comms gate (misclassified as outbound prose; tracked upstream as #125) |

**Pipeline outcomes**: 31 reports recorded with `classification: pending-pipeline-processing`. JTBD-alignment + dual-axis-risk classifier passes deferred to the next iter (see audit notes for rationale).

**Cache refresh confirmation**: `docs/problems/.upstream-cache.json` rewritten with `last_checked: 2026-05-15T04:33:26Z` + 31-report payload under `github-issues:windyroad/agent-plugins` + skip reasons for the two non-OK channels.

**Audit notes**:

- All 31 reports authored by `tompahoward` on 2026-05-13 from downstream `windyroad/*` projects via `/wr-itil:report-upstream`. They describe gaps in `@windyroad/*` plugins observed from adopter projects. Each carries a local-ticket cross-reference to its downstream project's `docs/problems/<NNN>-*.md` (not this monorepo's local backlog — these are NEW concerns from this monorepo's perspective).
- Notable: upstream #125 reports the external-comms-gate sha-computation bug verbatim (the same bug surfaced in this session when seeding markers for the changeset write). The local capture for #125 will close the loop on the deferred capture-on-correction.
- The Discussions HTTP 410 reflects the repo's current Discussions setting (disabled). When the maintainer enables Discussions + creates the Q&A category, this channel will start returning data without configuration changes.
- The security-advisories gate-misclassification is a **real gate bug**: read-only LIST calls fire the same gate as write calls. The gate's surface-match regex doesn't distinguish HTTP method. Tracked upstream as #125 (or related); local capture pending.

## 2026-05-17T11:21:52Z — Discovery pass (TTL-expiry auto-recheck via `/wr-itil:work-problems` Step 0b pre-flight)

Pre-flight iter dispatched from `/wr-itil:work-problems` Step 0b after the AFK orchestrator detected the upstream-cache TTL had expired (cache age 198278s > 86400s `ttl_seconds`). Step 4.5b TTL-expiry auto-recheck branch fired without an explicit `--force-upstream-recheck` flag — the documented self-healing-across-maintainer-cadence path per ADR-062.

**Channels polled** (3 configured, 1 polled OK, 2 skipped fail-soft):

| Channel | Status | Reports |
|---|---|---|
| `github-issues:windyroad/agent-plugins` (title_prefix=`[problem]`) | OK | 31 |
| `github-discussions:windyroad/agent-plugins` (category=`Q&A`) | skipped | 0 — Discussions disabled for repo (HTTP 410); skip-reason preserved from prior cache per Step 4.5 fail-soft contract |
| `github-security-advisories:windyroad/agent-plugins` | skipped | 0 — LIST call still blocked by external-comms gate (gate bug not yet fixed; tracked as upstream #125 / local P198); skip-reason preserved |

**Set delta vs prior cache (2026-05-15T04:56:14Z)**: zero — identical 31-issue set (42, 56, 57, 58, 59, 60, 61, 62, 63, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 97, 98, 110, 117, 120, 121, 123, 124, 125, 126). No new reports, no closed reports. Body hashes preserved (no content diff observed at the body-hash layer — see audit notes for diffing strategy).

**Pipeline outcomes**: 0 new pipeline classifications this pass. All 31 reports remain at `classification: pending-pipeline-processing` per the 2026-05-15 user direction (verbatim from each report's `cache_audit_note`: *"discovery-only; pipeline-classification deferred per 2026-05-15 user direction (external-comms-gate sha-bug bottleneck on per-report ack comments)"*). The JTBD-alignment + dual-axis-risk classifier passes (Step 4.5e steps 2-3) and branch routing (steps 4-6) remain deferred until the external-comms-gate sha-computation bug is fully resolved across both consumer packages (cache shows P163 + P166 closed 2026-05-16 in the local backlog; verification of the fix across a full ack-comment posting cycle has not yet been observed in-session per P186 evidence-first principle).

**Cache refresh confirmation**: `docs/problems/.upstream-cache.json` rewritten with `last_checked: 2026-05-17T11:21:52Z` + per-channel `fetched_at` refreshed; reports payload preserved verbatim with no field changes. File diff is a 4-line timestamp refresh (top-level + 3 channels).

**Audit notes**:

- This is a discovery-only refresh; the pre-flight iter exists to keep the AFK orchestrator's upstream-visibility surface fresh without forcing the maintainer to remember `/wr-itil:review-problems` manually. JTBD-006 desired outcome line 24 (the *"stale-cache or missing-cache auto-promotes `/wr-itil:review-problems` as a pre-flight pass"* contract) is the load-bearing job here.
- Body-hash diffing strategy: this pass did not recompute body hashes from fresh poll bodies — the 31-issue set was identical at the (number, createdAt) layer and body-hash recomputation across the full report set would cost ~150KB of body content read for zero expected delta (the cached reports are upstream-mirrors filed via `/wr-itil:report-upstream`, not external user content; body edits by the reporter author are extremely unlikely between TTL windows). If a body-edit scenario surfaces later, a `--force-upstream-recheck` invocation will rebuild hashes from fresh bodies.
- The 31 local upstream-mirror tickets (P198-P228) already exist in `docs/problems/known-error/` and `docs/problems/open/` from prior sessions. The cache's `matched_local_ticket` field is not yet populated for these — populating it is part of Step 4.5d's semantic-comparator hit branch, which is gated behind the same pipeline deferral. Once the gate-fix verifies, a future review-problems pass will populate `matched_local_ticket` + post the gated acknowledgement comments (or skip them per P229's "acknowledgement comments are bureaucratic, not verdict-shaped" alternative — pending resolution of P229's design surface).
- No new problem-tickets captured this pass; no clear-malicious closures; no above-threshold pushbacks. The skill's fail-soft contract held: 2 skipped channels did not block the discovery-pass completion.

## 2026-05-23T12:32:32Z — Discovery pass (TTL-expiry auto-recheck via `/wr-itil:review-problems` Step 0b pre-flight)

Dedicated inbound-discovery pre-flight for the `/wr-itil:work-problems` AFK orchestrator. The 2026-05-23 focused `/wr-itil:review-problems` pass (P281/P282/P283 re-rate) explicitly deferred the inbound-discovery refresh to a separate invocation; this is that invocation. Cache was ~6 days stale (`last_checked` 2026-05-17T11:21:52Z, well past the 86400s TTL) → Step 4.5b TTL-expiry auto-recheck branch fired without an explicit `--force-upstream-recheck` flag (the documented self-healing-across-maintainer-cadence path per ADR-062).

**Channels polled** (3 configured, 1 polled OK, 2 skipped fail-soft):

| Channel | Status | Reports |
|---|---|---|
| `github-issues:windyroad/agent-plugins` (title_prefix=`[problem]`) | OK | 35 |
| `github-discussions:windyroad/agent-plugins` (category=`Q&A`) | skipped | 0 — Discussions disabled for repo (HTTP 410); reconfirmed this pass |
| `github-security-advisories:windyroad/agent-plugins` | skipped | 0 — read-only LIST call still blocked by the external-comms gate (gate substring-matched `security-advisories` and denied the poll command verbatim this pass — live evidence of P198/#125); skip-reason preserved |

**Set delta vs prior cache (2026-05-17T11:21:52Z)**: **+4 new reports, 0 closed**. New: #137 (commitlint subject-case SKILL drift, 2026-05-17), #138 (work-problems defers actionable items when user present, 2026-05-17), #139 (migrate-problems-layout.sh zsh bashism no-op, 2026-05-18), #149 (external-comms gate friction + threshold drift, composed P010+P007, 2026-05-18). The prior 31-report set (42, 56–63, 76–87, 97, 98, 110, 117, 120, 121, 123–126) is unchanged at the (number, createdAt) layer. Body hashes for the 4 new reports computed `sha256(body + "\n")[:16]` (algorithm verified against cached #126 = `43eeab2af47e1acb`): #137 `7e24420525961a0b`, #138 `54c7dc161ccdb925`, #139 `4718c55fe9f0c267`, #149 `bfda21a42bc40001`.

**Pipeline outcomes**: 0 new pipeline classifications this pass. All 35 reports (the prior 31 + the 4 new) carry `classification: pending-pipeline-processing`. The JTBD-alignment + dual-axis-risk classifier passes (Step 4.5e steps 2–3), semantic-comparator matching (Step 4.5d), branch routing (steps 4–6), and per-report acknowledgement comments remain **deferred** per the standing 2026-05-15 user direction — the external-comms-gate sha-computation bug (P198 / upstream #125) blocks per-report ack-comment posting, and this pre-flight ran AFK where the external-comms gate cannot be interactively satisfied (the gate denied this pass's `security-advisories` poll command verbatim, reconfirming the bug is live). The 4 new reports are recorded discovery-only; `matched_local_ticket` not auto-populated (Step 4.5d gated behind the same deferral). No clear-malicious closures, no above-threshold pushbacks, no new local tickets created — the safe-and-valid `/wr-itil:capture-problem` branch is part of the deferred pipeline.

**Cache refresh confirmation**: `docs/problems/.upstream-cache.json` rewritten with `last_checked: 2026-05-23T12:32:32Z`; github-issues `fetched_at` refreshed + 4 reports prepended (35 total, descending-number order preserved); both skipped channels' `fetched_at` + `skip_reason` refreshed.

**Audit notes**:

- Fail-soft contract held: 2 skipped channels did not block the pass. The github-issues poll ran independently (the combined 3-channel command was denied by the external-comms gate on the `security-advisories` substring — exactly the P198/#125 gate-misclassification — so the OK channel was re-polled in a command that omitted the gate-tripping substring).
- The 4 new reports are upstream-mirrors filed via `/wr-itil:report-upstream` from downstream `windyroad/*` adopter projects describing `@windyroad/*` plugin gaps. They are new concerns from this monorepo's perspective; semantic-matching against the local backlog + local-ticket creation is part of the deferred pipeline. Queued as a loop-end direction-class observation for the orchestrator: the 4 new reports await pipeline classification once the external-comms-gate fix (P198/P163/P166) verifies across a full ack-comment cycle.
- `AskUserQuestion` not called this pass (AFK pre-flight per ADR-013 Rule 6); no ambiguity-edge `cache_audit_note` annotations added (no semantic-comparator pass ran).

## 2026-05-25T15:15:41Z — Discovery pass

Triggered by interactive `/wr-itil:review-problems`. Cache age (2026-05-23 → now) exceeded `ttl_seconds: 86400` → TTL-expiry auto-recheck branch (no explicit `--force-upstream-recheck` needed).

| Channel | Status | Reports |
|---------|--------|---------|
| `github-issues:windyroad/agent-plugins` (title_prefix=`[problem]`) | OK | 33 |
| `github-discussions:windyroad/agent-plugins` (category=`Q&A`) | skipped | 0 — Discussions disabled for repo (HTTP 410); reconfirmed this pass |
| `github-security-advisories:windyroad/agent-plugins` | skipped | 0 — read-only LIST call still blocked by the external-comms gate (substring-matched `security-advisories`; live P276/P198/#125 evidence) |

**Set delta vs prior cache (2026-05-23T12:32:32Z)**: **0 new reports, 1 closed**. #149 (external-comms gate friction + threshold drift, composed P010+P007) is now **CLOSED upstream** — P010 fixed by `56bae5f` (released `@windyroad/risk-scorer@0.11.0`, mirrored locally as P198) and P007 fixed by `3c732ba` (released `@windyroad/risk-scorer@0.11.0`, mirrored as P286). The remaining 32 reports are unchanged at the (number, createdAt) layer. All polled `[problem]` reports are maintainer-authored (`tompahoward`) and already mirrored locally (P200–P229 series + others).

**Pipeline outcomes**: 0 new pipeline classifications. All reports remain `pending-pipeline-processing` (or `closed-upstream` for #149). The JTBD-alignment + dual-axis-risk classifiers, semantic-comparator matching, branch routing, and per-report acknowledgement comments remain **deferred** per the standing 2026-05-15 user direction (external-comms-gate sha bug P198/#125 blocks ack-comment posting). No clear-malicious closures, no above-threshold pushbacks, no new local tickets created.

**Cache refresh confirmation**: `docs/problems/.upstream-cache.json` rewritten with `last_checked: 2026-05-25T15:15:41Z`; github-issues + both skipped channels' `fetched_at` refreshed; #149 reclassified `closed-upstream`; `$last_pass_note` added.

**Audit notes**:

- Fail-soft contract held: the 2 skipped channels did not block the review (discussions-disabled + the security-advisories gate false-positive skipped with advisory notes; the github-issues poll ran in a command that omitted the gate-tripping substring).
- No new third-party concerns surfaced — the discovery surface is currently a maintainer-dogfood mirror loop; semantic-matching + local-ticket creation remain part of the deferred pipeline.
- `AskUserQuestion` not called for the discovery step (mechanical-stage carve-out per P132 / ADR-062 § 4.5 AFK behaviour).

## 2026-05-30T01:20:15Z — Discovery pass

Triggered by `/wr-itil:work-problems` Step 0b preflight dispatch (subprocess) running `/wr-itil:review-problems`. Cache age (2026-05-25T15:15:41Z → now) was ~381,814s — exceeded `ttl_seconds: 86400` → TTL-expiry auto-recheck branch (no explicit `--force-upstream-recheck` needed).

| Channel | Status | Reports |
|---------|--------|---------|
| `github-issues:windyroad/agent-plugins` (title_prefix=`[problem]`) | OK | 34 active (open upstream) + 1 retained closed-upstream historical entry |
| `github-discussions:windyroad/agent-plugins` (category=`Q&A`) | skipped | 0 — Discussions disabled for repo (HTTP 410); status carried forward |
| `github-security-advisories:windyroad/agent-plugins` | skipped | 0 — read-only LIST call still blocked by the external-comms gate (P276/P198/#125 live; fresh poll not attempted this pass to preserve fail-soft semantics — channel-skip status preserved from prior pass evidence) |

**Set delta vs prior cache (2026-05-25T15:15:41Z)**: **0 new reports, 0 newly-closed**. Fresh strict `[problem]`-prefixed open set (34: 42, 56–63, 76–87, 97, 98, 110, 117, 120, 121, 123–126, 137–139) equals the prior open set; #149 remains closed upstream (status unchanged since 2026-05-24T20:57:49Z close). All polled reports are maintainer-authored (`tompahoward`) and already mirrored locally (P198–P229 series + P282-class + earlier mirrors).

**Pipeline outcomes**: 0 new pipeline classifications. All reports remain `pending-pipeline-processing` (or `closed-upstream` for #149). The JTBD-alignment + dual-axis-risk classifiers, semantic-comparator matching, branch routing, and per-report acknowledgement comments remain **deferred** per the standing 2026-05-15 user direction (external-comms-gate sha bug P198/#125 blocks ack-comment posting). No clear-malicious closures, no above-threshold pushbacks, no new local tickets created.

**Cache refresh confirmation**: `docs/problems/.upstream-cache.json` rewritten with `last_checked: 2026-05-30T01:20:15Z`; per-channel `fetched_at` refreshed on all three channels; reports array unchanged at the (number, body_hash) layer; `$last_pass_note` updated.

**Audit notes**:

- Fail-soft contract held: the 2 skipped channels did not block the pass (discussions HTTP 410 + security-advisories gate-block both preserve their prior skip status).
- Step 4.5 invoked as part of `/wr-itil:work-problems` Step 0b preflight robustness layer — orchestrator dispatched a subprocess to refresh the inbound-discovery cache before entering the work-loop, so that the work-loop sees fresh discovery state (rather than 4.4-day-stale cache). This is the documented self-healing TTL-expiry pattern (a maintainer who runs `work-problems` once a week without `--force-upstream-recheck` still gets a fresh inbound-discovery pass at Step 0b).
- No new third-party concerns surfaced — the discovery surface remains the maintainer-dogfood mirror loop; semantic-matching + local-ticket creation remain part of the deferred pipeline.
- `AskUserQuestion` not called for the discovery step (subprocess context per orchestrator instruction — user presumed absent; mechanical-stage carve-out per P132 / ADR-062 § 4.5 AFK behaviour).
