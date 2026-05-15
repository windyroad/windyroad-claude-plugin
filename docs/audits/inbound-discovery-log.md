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
