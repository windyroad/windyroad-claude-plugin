---
name: wr-itil:review-problems
description: Re-assess every open and known-error problem ticket in docs/problems/ — re-read RISK-POLICY.md, re-rate Impact × Likelihood, re-estimate Effort, recalculate WSJF, surface pending verifications, auto-transition Open → Known Error where warranted, and rewrite docs/problems/README.md with the refreshed ranking. Writes to problem files and the README cache; commits the refresh per ADR-014.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Skill
---

# Review Problems

Re-assess the problem backlog. This skill is a **batch operation** that reads every `.open.md` and `.known-error.md` ticket in `docs/problems/`, re-scores each against the current `RISK-POLICY.md`, re-estimates Effort against the current fix-strategy documentation, recalculates WSJF, auto-transitions Open tickets to Known Error when root cause + workaround are documented, fires the Verification Queue prompt for `.verifying.md` tickets, and rewrites `docs/problems/README.md` so downstream fast-paths (`list-problems` cache-hit, `work-problem` fast-path) see a fresh ranked view.

This skill is the P071 phased-landing split of `/wr-itil:manage-problem review` per ADR-010 amended Skill Granularity rule: one skill per distinct user intent. The original `/wr-itil:manage-problem review` subcommand route remains as a thin-router forwarder during the deprecation window but is scheduled for removal in `@windyroad/itil`'s next major version.

## Scope

**In scope** (RFC-002 migration window — each glob is dual-tolerant, covering BOTH the flat `docs/problems/<NNN>-<title>.<state>.md` filename-suffix layout AND the per-state subdir `docs/problems/<state>/<NNN>-<title>.md` layout):

- `docs/problems/*.open.md` + `docs/problems/open/*.md` and `docs/problems/*.known-error.md` + `docs/problems/known-error/*.md` — re-scored (Impact × Likelihood × Effort → WSJF); Priority + Effort + WSJF lines updated when they change.
- `docs/problems/*.verifying.md` + `docs/problems/verifying/*.md` — surfaced in the Verification Queue and fed to Step 4's verification prompt (Known Error → Closed path when the user confirms).
- `docs/problems/*.parked.md` + `docs/problems/parked/*.md` — listed in the Parked section; NOT re-scored (WSJF multiplier is 0).
- `docs/problems/README.md` — rewritten with the refreshed WSJF Rankings + Verification Queue + Parked tables; staged and committed with the review.

**Out of scope:**
- Work selection — the review produces the ranking, but does NOT pick the next ticket to work. That's `/wr-itil:work-problem` (slice 3 of P071, singular interactive variant; distinct from `/wr-itil:work-problems` plural AFK orchestrator).
- Ticket creation — use `/wr-itil:manage-problem`.
- Status transitions other than the Open → Known Error auto-transition and the Verification Pending → Closed prompt — use `/wr-itil:manage-problem <NNN>` (or the future `/wr-itil:transition-problem` split once it lands in a later slice).
- `docs/problems/*.closed.md` — omitted from the ranking entirely (the review addresses the active backlog).

## Steps

### 1. Read the risk framework

Read `RISK-POLICY.md` to get the current Impact levels (1-5), Likelihood levels (1-5), risk matrix, and label bands. These are the authoritative definitions — do not hardcode a scale.

### 2. Re-score every open / known-error ticket

For each open / known-error ticket (dual-tolerant enumeration spans `docs/problems/*.open.md docs/problems/*.known-error.md docs/problems/open/*.md docs/problems/known-error/*.md` per RFC-002 migration window; skip `.parked.md` / `.verifying.md` and their per-state-subdir equivalents `docs/problems/parked/*.md` / `docs/problems/verifying/*.md` entirely — their WSJF multiplier is 0 and they have dedicated sections in Step 3):

1. Read the problem file.
2. Read the codebase context — check if the root cause has been investigated since the last review, whether there are related fixes in git history, or whether the problem is stale.
3. **Re-assess Impact (1-5)** using the product-specific impact levels from `RISK-POLICY.md`. Ask: "If this problem occurs in production, what is the worst business consequence?"
4. **Re-assess Likelihood (1-5)** using the likelihood levels from `RISK-POLICY.md`. Ask: "Given the current codebase, how likely is this to affect the user?" **Inbound-report evidence (ADR-076):** if the ticket carries `**Origin**: inbound-reported`, an external user actually hit this failure — that is legitimate "previously observed failure mode" evidence and may justify Likelihood up to level 5 *on its own merits*. This is honest risk-keeping, **NOT a ranking lever**: do not inflate Likelihood to push reported tickets up the queue. The reported-first **tier** in Step 3 does the prioritisation; the risk axes stay honest because the risk-scorer release-risk gate reads the same Likelihood scale (ADR-026 grounding).
5. **Calculate Severity** = Impact × Likelihood.
6. **Look up Label** from the risk matrix label bands.
7. **Re-estimate Effort** (S / M / L / XL) by reading the Root Cause Analysis and Candidate Fix sections. Consider: how many files, how complex, does it need planning, is it cross-package or migration-heavy (XL territory)? If the bucket has changed since the last review, update the Effort line in the problem file and note the reason in a short parenthetical (e.g. "L → XL — architect review added ADR + migration script"). P047.
8. **Calculate WSJF** = (Severity × Status Multiplier) / Effort Divisor. Status Multiplier is 1.0 for Open, 2.0 for Known Error (per `/wr-itil:manage-problem`'s WSJF table — re-read if unsure).
9. **Update the Priority and WSJF lines** in the problem file if the scores changed.
10. **Auto-transition to Known Error** — if an open problem has confirmed root cause AND a workaround documented (even "feature disabled"), automatically transition it:
    - `git mv docs/problems/<NNN>-<title>.open.md docs/problems/<NNN>-<title>.known-error.md`
    - Update the Status field to "Known Error".
    - Re-stage explicitly per the P057 staging trap: `git add <new-path>` after the Edit.
    - This happens automatically — do not ask the user. The transition's fix-strategy is documented; only the shipping is outstanding.
11. **Confirm the `**Origin**` field (ADR-076)** — this is where "checking for items reported upstream to us" lands during a review. If the ticket originated from an external inbound report, set `**Origin**: inbound-reported (#NN)` (NN = the upstream issue/discussion number); cross-check `docs/problems/.upstream-cache.json` (`matched_local_ticket`) and any acknowledgement comment to confirm. Otherwise set/leave `**Origin**: internal`. Tickets predating ADR-076 carry no Origin field and default to `internal` until stamped here. This field — not the regenerable cache — drives the Step 3 reported-first tier, so stamping it during the review is what makes reported tickets rank ahead on the refreshed ranking.

### 2.5. Dependency-graph traversal — propagate transitive effort (P076)

After Step 2 assigns each ticket its **marginal** effort, run a second pass that walks the `## Dependencies` graph and propagates effort up per the transitive-dependency rule defined in `/wr-itil:manage-problem`'s WSJF Prioritisation section (the canonical location). This is a deterministic re-rate — no `AskUserQuestion` required.

1. **Build the graph**: for each `.open.md` / `.known-error.md` ticket, parse the `## Dependencies` section. Record `**Blocked by**` edges (bare IDs) into an adjacency map. Ignore `**Composes with**` (does not propagate) and `**Blocks**` (derivable from inverse).
2. **Classify upstream status**: upstreams in `.closed.md`, `.verifying.md`, or `.parked.md` contribute **0** to the closure (architect carve-out per P076). Upstreams in `.open.md` or `.known-error.md` contribute their own transitive effort.
3. **Topologically sort** and compute `Effort_transitive = max(marginal, max{ upstream transitive })`. Cycle-bundle members all receive the bundle's effort = `max{ marginal | members }`.
4. **Update Effort and WSJF lines** when the transitive effort differs from the marginal. Add a `<!-- transitive: <bucket> via <UPSTREAM> -->` HTML comment on the Effort line so the next review can distinguish a manually-set marginal from a propagated transitive.
5. **Report each re-rate** in the review summary using the concrete format `P<NNN>: Effort <OLD> → <NEW> (transitive via <UPSTREAM>)`, e.g. `P073: Effort S → XL (transitive via P038)`. Cycle bundles surface a shared line: `Bundle [P038, P064]: effort XL (cycle), WSJF 3.0 (shared)`.

Re-read the WSJF Prioritisation → "Transitive dependencies (P076)" subsection in `packages/itil/skills/manage-problem/SKILL.md` if unsure — that is the canonical rule definition.

### 3. Present the refreshed ranking

After re-scoring, present three sections matching the README.md format (same rendering used by `/wr-itil:list-problems` and by the README cache — Step 5 writes the same layout):

**WSJF Rankings** — dev-work queue (open + known-error), rendered **tier-first** — Tier 0 Critical-bypass (Severity Very High ≥17 OR security-classified OR incident-linked) → Tier 1 Inbound-reported (`**Origin**: inbound-reported`) → Tier 2 Internal — and **within each tier** by the multi-key `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so rendered top-to-bottom row order matches `/wr-itil:work-problems` SKILL.md Step 3 selection 1:1 (P138 + ADR-076). Within each tier, rows follow the canonical tie-break ladder: Known Error before Open, smaller Effort before larger, older Reported date before newer. The `Reported` column MUST appear so the third tie-break input is visible, and an `Origin` column so the Tier 1 partition is visible. <!-- REPORTED-FIRST-TIER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 (ADR-076) --> <!-- TIE-BREAK-LADDER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 --> Any change to the tie-break ladder OR the reported-first tier MUST update this rendering block, Step 5's README template, AND `/wr-itil:manage-problem` SKILL.md Step 5 P094 / Step 7 P062 / Step 9e — drift re-opens P138 / ADR-076.

```
| WSJF | ID | Title | Severity | Status | Effort | Reported | Origin | Notes |
|------|-----|-------|----------|--------|--------|----------|--------|-------|
```

**Verification Queue** — `.verifying.md` tickets, sorted by `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC) per ADR-022 + P048 user-task semantics. Older entries are the most likely-verified candidates the user wants to surface first when closing the queue; newest-first ordering pushes those actionable closure candidates below the fold and contradicts the section header. <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 --> Any change to the VQ sort direction MUST update this rendering block, Step 5's README template, AND `/wr-itil:manage-problem` SKILL.md Step 5 P094 / Step 7 P062 / Step 9c / Step 9e + `/wr-itil:transition-problem` + `/wr-itil:transition-problems` + `/wr-itil:reconcile-readme` + `/wr-itil:list-problems` — drift re-opens P150. The `Likely verified?` column carries an **evidence-first** cell (per P186 — supersedes the age-based heuristic). <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> Three canonical values:

- `yes — observed: <evidence>` — a Step 4 user confirmation, an in-session test invocation + observable outcome (per ADR-026 grounding), or a `run-retro` Step 4a close-on-evidence citation. Quote the evidence inline (≤ 120 chars; abbreviate to ticket/commit/version anchor + verb).
- `no — not observed` — fix released but no session-observable evidence yet. Default for newly-released tickets. Aging is preserved separately via the `Released` column — the Released column is the aging signal, `Likely verified?` is the evidence signal.
- `no — observed regression` — fix released and the bug recurred this session. Cite the recurrence inline (≤ 120 chars).

Any change to the canonical cell shape MUST update this rendering block, Step 5's README template, AND every co-located render site listed in the VQ-SORT-DIRECTION drift-tripwire above — drift re-opens P186. Surface `yes — observed: …` rows first in Step 4's verification prompt (user can batch-close them); `no — observed regression` rows must NOT be batch-closed (they may signal a botched fix and warrant a flip-back to `.known-error.md`).

```
| ID | Title | Released | Fix summary | Likely verified? |
|----|-------|----------|-------------|------------------|
```

**Parked** — `.parked.md` tickets (no ranking):

```
| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|
```

Highlight:
- Problems whose priority changed (↑ or ↓ since the last review).
- Problems that were auto-transitioned to known-error in Step 2.
- Problems that may be stale (reported > 2 weeks ago with no investigation progress).
- Problems that have been fixed but not closed (check git history for fix commits referencing the problem ID).
- Verification Pending tickets whose fix has been exercised repeatedly without regression (P048 detection layer — candidate for closure verification; surface these first in Step 4).

Omit an empty section rather than rendering an empty header.

### 4. Verification prompt (Verification Pending → Closed)

Target the dual-tolerant glob `docs/problems/*.verifying.md docs/problems/verifying/*.md` (RFC-002 migration window) — do NOT scan `.known-error.md` bodies for a `## Fix Released` section (per ADR-022, Verification Pending is a first-class status, not a substring marker). For each verifying ticket file, use `AskUserQuestion` to ask whether the fix has been verified in production.

The question MUST include a fix summary extracted from the `## Fix Released` section — include the first sentence (or first bullet list) of that section in the question body or as the option description, so the user can answer without reading the full problem file. Do NOT ask with only the problem ID + title + version.

- Surface the Step 3 `yes — observed: …` tickets first so the user can batch-close them (per P186 evidence-first cell shape).
- If the user confirms: close the problem (`git mv` from `.verifying.md` to `.closed.md`, update Status to "Closed", re-stage per the P057 staging trap). Update the `Likely verified?` cell on the same render path to `yes — observed: user confirmed <YYYY-MM-DD>`.
- If the user says no or is unsure: leave the ticket as Verification Pending. If the user reports recurrence, update the cell to `no — observed regression — <one-line citation>` and flag for `.verifying.md` → `.known-error.md` flip-back via `/wr-itil:transition-problem`.

**AFK / non-interactive branch (ADR-013 Rule 6):** when `AskUserQuestion` is unavailable, record the Verification Queue in the review output and skip the prompt. Do NOT auto-close verifying tickets — only the user can make that call. The user sees the queue on next interactive invocation.

<!-- ADR-062-step-naming-reconciliation: this skill's current numbering has 7 steps; ADR-062 was authored against a stale view that called the inbound-discovery sub-step "Step 8.5" and the README renderer "Step 9e". Both names appear verbatim in headers below so ADR-062 § Confirmation criterion 1 ("Step 8.5") and § Confirmation criterion final bullet ("Step 9e") remain string-anchorable. Do NOT strip the "Step 8.5" / "Step 9e" substrings on rename. -->

### 4.5. Inbound-discovery + assessment-pipeline (ADR-062 § Step 8.5 / Decision Outcome)

Per ADR-062 (peer of ADR-024). Polls configured upstream channels, runs each unmatched inbound report through the six-step assessment pipeline, and routes outcomes to one of three branches: safe-and-valid-local-ticket-create / above-threshold-pushback / clear-malicious-close-with-verdict. All external comms ride the P064 + P038 evaluator gates per ADR-028 amended. Mechanical-stage carve-out (P132 / ADR-044 category 4 silent framework action): branch decisions resolve from JTBD-alignment + dual-axis-risk verdicts; this step does NOT use `AskUserQuestion` at the branch decision. User-attention surfaces ONLY at hook gates (existing external-comms gate UX) and ambiguity edge cases recorded as `cache_audit_note` in the cache for the next interactive review.

**Fail-soft contract**: any error in Step 4.5 (missing channel config, GH API failure, malformed cache, subagent failure, gate denial on a verdict-comment post) MUST NOT block the review — emit an advisory note, skip the failing channel/report, and continue. Step 5 (README rewrite) proceeds regardless. The assessment pipeline is purely additive; no-inbound-discovery is the status-quo baseline.

#### 4.5a. Read channel config + parse invocation flags

Read `docs/problems/.upstream-channels.json`. If missing or malformed: log an advisory note (`channel config absent or malformed; inbound-discovery skipped this pass`) and skip Step 4.5 entirely. Adopters who don't ship this file inherit zero ceremony tax — the downstream-adopter non-obligation per ADR-062 § Downstream-adopter contract + JTBD-101.

Parse `$ARGUMENTS` as a whitespace-separated token list. Recognised invocation flags for inbound-discovery:

- `--force-upstream-recheck` → set `force_recheck=true`. Bypasses the TTL check in 4.5b; forces a fresh poll of every channel. Use case: maintainer pre-flight before a release (JTBD-202) — rebuild the cache from the upstream authoritative source rather than trusting in-window cached state.
- `--no-force-upstream-recheck` → set `force_recheck=false` explicitly (the default). Surfaces the flag's existence in `--help`-style discovery without changing behaviour.

Unknown leading flags addressed at inbound-discovery (those starting with `--force-upstream` or `--inbound-`) halt the inbound-discovery step with an advisory note naming the unrecognised flag; non-inbound flags are passed through unchanged (e.g. flags consumed by Step 2's re-scoring or Step 4's verification prompt are not in scope here).

Flag-parsing defaults: `force_recheck=false` when neither flag is present.

#### 4.5b. Cache TTL check + TTL-expiry auto-recheck

Read `docs/problems/.upstream-cache.json`. Compute `cache_age_seconds = (now - last_checked)` when `last_checked` is non-null.

Branch:

- `force_recheck == true` → **force-flag branch**: bypass TTL; proceed to 4.5c (fresh poll). Emit advisory note `inbound-discovery: --force-upstream-recheck flag set; bypassing TTL`.
- `last_checked == null` → **first-run branch**: cache is empty; proceed to 4.5c. Emit advisory note `inbound-discovery: cache empty (last_checked null); initial poll`.
- `cache_age_seconds > ttl_seconds` → **TTL-expiry auto-recheck branch**: cache is stale; proceed to 4.5c without requiring the explicit flag. Emit advisory note `inbound-discovery: cache age <N>s exceeds ttl_seconds <M>; auto-recheck`.
- `cache_age_seconds <= ttl_seconds` AND `force_recheck == false` → **cache-fresh branch**: skip polling; reuse the cached report list for the pipeline pass below. Emit no advisory (silent within-TTL path per ADR-013 Rule 5 below-appetite silent-pass).

The TTL-expiry auto-recheck is what makes the system self-healing across maintainer cadence: a maintainer who runs `/wr-itil:review-problems` once a week without the explicit flag still gets a fresh poll after the 24-hour TTL expires. The explicit `--force-upstream-recheck` flag is the pre-flight surface (JTBD-202) for tighter cadence — e.g. immediately before a release when the maintainer wants the freshest discovery state.

#### 4.5c. Poll each channel

For each channel in `channels[]`, run the appropriate `gh` invocation. Fail-soft per channel: missing `GH_TOKEN`, rate-limit, or HTTP error logs an advisory and skips that channel only:

- `github-issues`: `gh issue list --repo <repo> --label <label> --state open --json number,title,author,createdAt,body,labels --limit 100`
- `github-discussions`: `gh api repos/<repo>/discussions --jq '[.[] | select(.category.name == "<category>") | {number, title, author, createdAt, body}]'` (fall back to GraphQL `gh api graphql ...` if REST is insufficient for the discussions surface).
- `github-security-advisories`: `gh api repos/<repo>/security-advisories --jq '[.[] | {ghsa_id, summary, description, author, published_at}]'`.

Write the polled results to `docs/problems/.upstream-cache.json`, updating `last_checked` and the per-channel `fetched_at` + `reports` arrays. The cache file is committed to the repo for audit-replay determinism (per ADR-062).

#### 4.5d. Match reports against local tickets (P070 semantic-comparator)

For each fresh report (not present in the prior cache snapshot under the same `body_hash`), invoke P070's semantic-comparator infrastructure (the same comparator used by `/wr-itil:report-upstream` outbound dedup, per ADR-062 § Reassessment composes-with).

**Semantic-comparator hit** → record `matched_local_ticket: P<NNN>` on the cache entry AND post a gated `gh issue comment` containing the local-ticket cross-reference (e.g., *"Tracked locally as `docs/problems/<state>/<NNN>-<title>.md` — see that ticket for the verdict trail"*). The acknowledgement comment fires through the external-comms gate (P064 risk + P038 voice-tone per ADR-028 amended). This comment is the JTBD-301 acknowledgement that the report has been received and routed; silent-skip on matched-local-ticket would break the contract per ADR-062 § Decision Drivers row 1 (every submitted report receives a verdict, even if the verdict is "duplicate of P<NNN>").

**Semantic-comparator ambiguity** (multiple plausible matches) → annotate `cache_audit_note: ambiguous-match-candidates-P<X>-P<Y>-...` and DO NOT auto-route. The ambiguity surfaces at the next interactive `review-problems` invocation (the maintainer disambiguates from the cache_audit_note channel; this is the documented user-attention surface under the mechanical-stage carve-out).

**No comparator hit** → continue to 4.5e.

#### 4.5e. Six-step assessment pipeline

For each unmatched fresh report, run these steps in order; record the outcome in the cache + audit-log.

1. **Version-aware classification (P129 carve-out — stub seam)**: when P129 ships, this step compares reporter-version against closed-ticket fix-versions and routes to upgrade-pushback / recurrence / still-active. Until P129 lands: skip this step (all reports proceed to step 2). The integration seam is documented in ADR-062 § Decision Outcome step 1.

2. **JTBD-alignment classifier**: invoke `wr-jtbd:agent` subagent with the report body + persona JTBDs. Three outcomes per ADR-062:
   - `aligned-with-existing-JTBD` → continue to step 3.
   - `aligned-with-new-JTBD-for-existing-persona` → continue to step 3 + annotate `cache_audit_note: new-jtbd-flag` on the cache entry. The flag surfaces at next interactive review for maintainer-attention; auto-creation honors JTBD-301 acknowledgement.
   - `not-aligned` → route to step 4 (above-threshold-pushback) with reason `out-of-scope-for-documented-personas`; do NOT execute step 3.

3. **Dual-axis risk classifier**: invoke `wr-risk-scorer:inbound-report` subagent (shipped Slice B) with the report body + JTBD-alignment context. Outcomes:
   - `safe-low-fix-risk` → step 6 (safe-and-valid branch).
   - `safe-high-fix-risk` → step 6 (safe-and-valid branch) + annotate `cache_audit_note: high-fix-risk-flag` on the cache entry.
   - `clear-malicious-request` → step 5 (clear-malicious branch).
   - `above-threshold-risk` → step 4 (above-threshold-pushback branch).

4. **Above-threshold-pushback branch**: post a gated `gh issue comment` declining the report (the comment body names the reason — `out-of-scope-for-documented-personas` or the matched Request-risk class from step 3). Comment fires through the external-comms gate (P064 + P038 evaluators per ADR-028 amended). Upstream issue is NOT closed by the pipeline — maintainer decides closure manually after reading the pushback. Cache entry classification: `above-threshold-pushback`. Audit-log append. **Gate-denial sub-branch**: if the external-comms gate denies the comment write (either evaluator FAILs), record `cache_audit_note: gate-denied-pushback` and continue to the next report.

5. **Clear-malicious branch**: post a brief gated verdict comment (JTBD-301 acknowledgement contract — silent close is forbidden per ADR-062 Decision Drivers row 1). Comment body names the policy-violation classification verbatim from the `wr-risk-scorer:inbound-report` verdict. External-comms gates ride. Then close the upstream issue via `gh issue close <id>`. Append the reporter handle + classification to `docs/audits/inbound-discovery-log.md` for P123 block-list consumption when that ticket lands. Cache entry classification: `clear-malicious-closed`. **Gate-denial sub-branch**: if the verdict-comment gate denies, record `cache_audit_note: gate-denied-clear-malicious-pre-close` and do NOT close the upstream issue (silent close is forbidden — preserve the report for the next pass).

6. **Safe-and-valid branch**: invoke `/wr-itil:capture-problem --no-prompt <report-body-verbatim>` to create the local ticket. The `--no-prompt` flag defaults to `type=technical`; the maintainer re-classifies at next interactive `review-problems` re-rate. **Stamp the inbound origin (ADR-076)**: the skeleton writes `**Origin**: internal` by default — Edit it on the freshly-created ticket to `**Origin**: inbound-reported (#<id>)` (the upstream issue/discussion `<id>` polled this pass) so the ADR-076 reported-first tier ranks it ahead of internal tickets. The on-ticket `**Origin**` field, not the regenerable cache, is the authoritative rank input (ADR-076); the cache's `matched_local_ticket` remains the audit/replay record. Rationale: a default of `user-business` would mis-classify security-advisory-channel reports as user-business when they're often deep technical bugs; the maintainer-re-classify path is the safety net. Verbatim body preservation honors JTBD-301 persona constraint "capture context faithfully without cognitive re-shaping" and JTBD-201 audit-trail fidelity. Then post a gated `gh issue comment` acknowledgement carrying the new local-ticket reference. Cache entry classification: `safe-and-valid-local-ticket-created`; populate `matched_local_ticket: P<NNN>` with the freshly-allocated ID. **Gate-denial sub-branch**: if the acknowledgement comment gate denies, the local ticket already exists — record `cache_audit_note: gate-denied-safe-and-valid-acknowledgement` and continue. The acknowledgement comment will retry on the next discovery pass.

#### 4.5f. Audit-log append

Append a `## YYYY-MM-DDTHH:MM:SSZ — Discovery pass` heading to `docs/audits/inbound-discovery-log.md` per ADR-062 § Audit-log surface shape. The entry includes:

- Channels polled (N) and per-channel report counts (new vs unchanged).
- Pipeline outcomes by classification (counts + local-ticket IDs created + upstream issues closed + audit-flagged reporter handles for P123 future consumption).
- Cache refresh confirmation (`docs/problems/.upstream-cache.json` rewritten at `last_checked: <ISO timestamp>`).

#### 4.5g. Render-time integration

The `## Inbound Upstream Reports` README section (ADR-062 § Step 9e renderer per the naming-reconciliation note at the top of this section) is populated by Step 5's renderer reading `docs/problems/.upstream-cache.json` — that renderer ships in Slice G of RFC-004. This step (4.5g) is the integration seam; the renderer is the consumer.

#### 4.5 AFK-loop behaviour

When invoked from `/wr-itil:work-problems` Step 6.5 (AFK orchestrator), Step 4.5 runs silently per the mechanical-stage carve-out. The only user-attention surface during AFK is the existing external-comms gate UX (a known interrupt class per ADR-028 amended); per-branch `AskUserQuestion` would re-introduce the friction P132 was engineered to remove.

### 4.6. Relevance-close pass (P346 / P347 / ADR-079 Phase 1 + Phase 2)

For each `.open.md` / `.known-error.md` ticket aged ≥ 7 days, evaluate whether the ticket has become **no longer relevant** by checking observable evidence per ADR-026 grounding. Phase 1 + Phase 2 cover **five evidence shapes** grounded in the 14-fixture labeled close-on-evidence set from the 2026-05-31 foreground relevance-scan (the regression suite per ADR-052 lives at `packages/itil/scripts/test/evaluate-relevance.bats`):

| Shape | Phase | Mechanical check | Empirical closes (2026-05-31) |
|---|---|---|---|
| 1. `file-no-longer-exists` | Phase 1 | grep ticket body for `(packages\|docs\|...)/...\.(md\|sh\|...)`; verify each via `git ls-files --error-unmatch` | 0 of 14 |
| 2. `ADR-shipped-confirmed` | Phase 2 | grep ticket body for `ADR-NNN`; for each, verify `docs/decisions/<NNN>-*.md` exists AND frontmatter has `human-oversight: confirmed` | 8 of 14 — P012/P015/P018/P022/P033/P039/P194/P292 |
| 3. `named-skill-or-feature-exists` | Phase 2 | grep for SKILL.md / hook / agent paths + `/wr-<plugin>:<skill>` slash-command refs; verify each via `git ls-files` | 6 of 14 — P014/P034/P045/P079/P190/P289 |
| 4. `self-marker-in-body` | Phase 2 | line-anchored grep for `Close to (Verifying\|Closed)`, `DONE 2026-`, `## Fix Released` heading, `fix shipped session`, `awaiting K→V`. Pattern MUST anchor to line-start to avoid mid-prose false-positives (architect advisory A2) | explicit in P289; contributory in P033 |
| 5. `driver-child-ticket-closed` | Phase 2 | parse `## Related` for `P<NNN>` refs; check if any are in `docs/problems/closed/`. Suppressed when child names an unbuilt SKILL/agent path (future work, not stale; architect advisory A1) | contributory in several closes |

**Phase 1 false-positive fixes** (the iter-4 60% false-positive rate is structurally addressed; each fix routes the candidate to `KEEP-WITH-NOTE` rather than auto-close):

- **P180 — state-suffix detection**: per-state subdirs (`open|known-error|verifying|closed|parked` for problems; `investigating|mitigating|restored` for incidents) AND `.<state>.md` suffix variants.
- **P244 — sibling-file detection**: dir-glob the parent dir for files with similar slug-prefix (first 2 dash-tokens).
- **P251 — rename detection**: `git log --follow --diff-filter=AD --name-only` surfaces the renamed-to path.

Tickets with no extractable evidence (no file refs, no ADR refs, no SKILL refs, no self-markers, no closed drivers) route to `SKIP`. Other evidence shapes (ADR-supersession via `.superseded.md`, duplicate-of-X, "concern no longer concerning", test-passes-without-issue) are deferred to sibling tickets per ADR-079 scope discipline.

**User direction (verbatim, 2026-05-31)**: *"Ok, I'm happy for a skill executed as part of review problems that closes tickets that are no longer relevant, but not just because they are old"* — the relevance signal MUST be observable; age is a **gating** condition (don't bother evaluating fresh tickets), never the **closing** condition. The 7-day gate is conservative; tickets younger than that are likely still actionable.

#### 4.6a. Invoke the canonical evaluator script

For each ticket in the dual-tolerant glob `docs/problems/*.open.md docs/problems/open/*.md docs/problems/*.known-error.md docs/problems/known-error/*.md` (RFC-002 migration window), invoke the evaluator script via the ADR-049 PATH shim:

```bash
wr-itil-evaluate-relevance "$ticket"
```

The `wr-itil-evaluate-relevance` command is a `$PATH`-resolved shim shipped in `packages/itil/bin/` that dispatches the canonical `packages/itil/scripts/evaluate-relevance.sh` body. ADR-049 — never invoke the canonical script via repo-relative path; the path does not resolve in adopter trees (P317 / RFC-009).

Exit-code routing (one verdict line per ticket on stdout):

| Exit | Stdout prefix | Action |
|------|--------------|--------|
| 0 | `CLOSE-CANDIDATE <basename> — shapes: <comma-list> — <per-shape cite>; ...` | Auto-close branch (4.6b). |
| 0 | `CLOSE-CANDIDATE-WITH-CAVEAT <basename> — shapes: <comma-list> — caveat: <short-tag>: <one-line> — cites: ...` | Surface-batch-confirm branch (4.6b-with-caveat); the caveat short-tag + one-line splices verbatim into the audit section's **Caveat** field per architect condition C2. |
| 1 | `KEEP <basename> — <M>/<N> paths still present` | No action; log only. |
| 1 | `KEEP-WITH-NOTE <basename> — <note>: <evidence>` | Phase 1 false-positive class (state-suffix / sibling-file / rename) OR architect-A1 future-work disambiguation. No action; log only. |
| 2 | `SKIP <basename> — <reason>` | No action (age gate, no Reported date, no extractable evidence). |
| 3 | error | Log advisory; do not abort the pass — relevance-close is non-blocking per the Step 4.5 fail-soft precedent. |

**Algorithm (canonical body)**: runs each of the five shape detectors over the ticket body. Multi-shape matches emit cumulatively (corroborating evidence is stronger than first-match-wins per ADR-026): the `shapes:` field carries a comma-joined list, the trailing fragment carries per-shape cites semicolon-separated. The caveat fires when at least one shape matches AND the body has any unticked checkboxes (multi-phase mixed-progress umbrella class). The verdict is intentionally conservative — tickets with no shape match AND no extractable evidence route to `SKIP`, not auto-close.

**Surface-batch-confirm flow** (the methodology that produced today's 14 closes — codified for repeatable use):

1. **Surface a batch** — run the evaluator across the dual-tolerant glob in 4.6a; group all `CLOSE-CANDIDATE` and `CLOSE-CANDIDATE-WITH-CAVEAT` verdicts as a batch.
2. **Interactive surface (`AskUserQuestion`)** — present each batch of ~5 candidates with their shape annotations + caveats; user confirms close / amend / defer. Surface caveat tickets adjacent to their clean-close siblings so the maintainer sees the full batch class together. The interactive batch is the one-and-only `AskUserQuestion` per relevance-close pass (mechanical-stage carve-out per ADR-044 cat 4 + P132 — do NOT ask per-ticket; ask per-batch).
3. **AFK (`/wr-itil:work-problems` Step 6.5)** — close clean `CLOSE-CANDIDATE` verdicts silently per ADR-013 Rule 5 + ADR-044 cat 4 (file existence + frontmatter inspection + line-anchored grep are empirical). Route `CLOSE-CANDIDATE-WITH-CAVEAT` verdicts to the next interactive review's `AskUserQuestion` surface — the caveat short-tag is the maintainer's decision input.
4. **Batched closure commit per ADR-014** — all relevance-closes from one review pass batch into ONE commit (mirroring `/wr-itil:transition-problems` P139 batch grain).

Real-backlog smoke test 2026-05-31 against today's labeled fixtures: P012 → `CLOSE-CANDIDATE-WITH-CAVEAT` (shapes 2 + 5 + multi-phase-mixed-progress caveat); P136 → `KEEP-WITH-NOTE` (sibling-file class); P303/P326 → `SKIP` (age gate, recent observations).

#### 4.6b. Auto-close action per CLOSE-CANDIDATE

For each `CLOSE-CANDIDATE` or `CLOSE-CANDIDATE-WITH-CAVEAT` ticket, perform the following BEFORE the `git mv`:

1. Use the `Edit` tool to append a `## Closed as no longer relevant` section to the ticket body (cite + persist + uncertainty per ADR-026):

   ```markdown
   ## Closed as no longer relevant

   - **Evidence shape**: <comma-joined list from the verdict's `shapes:` field — e.g. `ADR-shipped-confirmed, self-marker-in-body` for multi-shape match> (ADR-079 Phase 1 + Phase 2)
   - **Closed on**: <YYYY-MM-DD>
   - **Closed by**: /wr-itil:review-problems Step 4.6 relevance-close pass
   - **Cite (per-shape evidence)**: <semicolon-separated per-shape cites from the trailing fragment of the verdict line>
   - **Caveat (if CLOSE-CANDIDATE-WITH-CAVEAT)**: `<short-tag>: <one-line>` from the verdict's `caveat:` field (splice verbatim — preserves ADR-026 uncertainty leg structurally per architect condition C2). Omit this field for plain CLOSE-CANDIDATE verdicts.
   - **Persist**: this section is committed in the ticket file itself; the script body at `packages/itil/scripts/evaluate-relevance.sh` is the re-runnable verdict source per ADR-026
   - **Uncertainty / reversibility**: verdict is deterministic given the body + git state. False-positive remediation: `git revert` the relevance-close commit OR `git mv` the ticket back to its prior state. The ≥7-day age gate + Phase 1 false-positive fixes (state-suffix / sibling-file / rename) + shape-cumulative annotation guard against premature evaluation.
   ```

2. `git mv` the ticket from its current state directory to `closed/` (lifecycle extension per ADR-079 — Open|Known Error → Closed bypasses Verifying because no fix was released; conclusion is "no fix needed"):

   ```bash
   git mv docs/problems/open/<NNN>-<title>.md docs/problems/closed/<NNN>-<title>.md
   # or known-error/<NNN>-<title>.md → closed/<NNN>-<title>.md
   ```

3. Use the `Edit` tool to update the `**Status**:` field to `Closed`.

4. **Re-stage explicitly per the P057 staging trap** — `git mv` alone stages the rename; the subsequent `Edit` content changes are not in the rename's index entry:

   ```bash
   git add docs/problems/closed/<NNN>-<title>.md
   ```

#### 4.6c. Batch commit grain (per ADR-014 / P139)

All relevance-closes from THIS review pass batch into ONE commit, mirroring `/wr-itil:transition-problems` batch grain (P139). The commit message names the count and the closure class:

```bash
git commit -m "chore(problems): relevance-close pass — close <N> tickets as no longer relevant

Auto-closed via /wr-itil:review-problems Step 4.6 (ADR-079 Phase 1
file-no-longer-exists evidence shape). Each closed ticket carries
a ## Closed as no longer relevant section citing the file paths
no longer present in git ls-files. Reversible via git revert.

Closed: P<NNN>, P<NNN>, ..."
```

Step 5's README refresh rides the same commit per ADR-014 single-commit grain — `docs/problems/README.md` gets re-rendered with the closed tickets dropped from WSJF Rankings.

#### 4.6d. AFK-policy-authorised silent proceed (ADR-013 Rule 5 / ADR-044 category 4)

The relevance-close pass runs **unconditionally** during AFK orchestration (`/wr-itil:work-problems` Step 6.5). File existence is empirical, not user-judgment — the mechanical-stage carve-out (P132) applies per ADR-044 category-4 silent framework action. Do NOT fire `AskUserQuestion` per CLOSE-CANDIDATE; the framework has already resolved the close-on-empirical-evidence question.

**Worked example (Phase 1 smoke test, 2026-05-31)**: across 143 open / known-error tickets, Phase 1 surfaced 6 CLOSE-CANDIDATEs (4.2%) — but the post-batch-1 verification showed 60% of those were false-positives (state-suffix / sibling-file / rename class). Phase 2's false-positive fixes route those to `KEEP-WITH-NOTE`. The same-day foreground relevance-scan that used the broader Phase 2 shape vocabulary produced 14 actual closes across 5 batches — empirically calibrating the Phase 2 shape set.

**Worked example (Phase 2 surface-batch-confirm, 2026-05-31)**: 14 closes across 5 batches using shapes 2-5. Each batch surfaced via `AskUserQuestion` (≤ 5 candidates per batch); maintainer confirmed clean closes and routed caveat candidates with explicit caveat acknowledgement (e.g. P039 `shared-template-not-built`; P194 `deep-dive-bloat-remains`). All closures batched into per-batch commits per ADR-014. The 14-fixture labeled set is the regression suite (`packages/itil/scripts/test/evaluate-relevance.bats` covers each shape positive + the architect A1/A2 advisory negatives).

**Cross-references**: ADR-079 (this pass's design ADR, Phase 1 + Phase 2), ADR-026 (grounding, cumulative shape cite + structured caveat field), ADR-022 + ADR-079 lifecycle extension (Open|Known Error → Closed bypassing Verifying for no-fix-needed conclusions; the Closed-row entry at `/wr-itil:manage-problem` SKILL.md line 59 names Phase 1 + Phase 2 shapes), ADR-049 (PATH shim), ADR-052 (behavioural bats at `packages/itil/scripts/test/evaluate-relevance.bats` — 33/33 GREEN), ADR-014 (batched closure commit grain per pass), ADR-044 cat 4 + P132 (mechanical-stage carve-out: ask per-batch, not per-ticket), P057 (staging trap), P346 (Phase 1 driver), P347 (Phase 2 driver).

### 5. Rewrite `docs/problems/README.md`

Write / overwrite `docs/problems/README.md` with the refreshed ranking so future `work-problem` / `list-problems` fast-paths can skip the full re-scan. Rendering rules match the SKILL.md `Present the refreshed ranking` section above — driven off globs, not file-body scans:

```markdown
# Problem Backlog

> Last reviewed: <ISO timestamp> — <one-line context about what changed>
> Run `/wr-itil:review-problems` to refresh WSJF rankings.

## WSJF Rankings

Dev-work queue only. Verification Pending (`.verifying.md`, WSJF multiplier 0) and Parked (`.parked.md`, multiplier 0) tickets are excluded per ADR-022 — surfaced in their own sections below. Rows render **tier-first** (Tier 0 Critical-bypass [Severity Very High ≥17 OR security-classified OR incident-linked] → Tier 1 Inbound-reported [`**Origin**: inbound-reported`] → Tier 2 Internal), then within each tier by `(WSJF desc, Known-Error-first, Effort-divisor asc, Reported-date asc, ID asc)` so top-to-bottom order matches `/wr-itil:work-problems` Step 3 selection 1:1 (P138 + ADR-076). The `Reported` and `Origin` columns MUST appear. <!-- REPORTED-FIRST-TIER-SOURCE: /wr-itil:work-problems SKILL.md Step 3 (ADR-076) -->

| WSJF | ID | Title | Severity | Status | Effort | Reported | Origin |
|------|-----|-------|----------|--------|--------|----------|--------|
| <score> | P<NNN> | <title> | <severity> | <status> | <effort> | <YYYY-MM-DD> | <internal / inbound-reported (#NN)> |
...

## Verification Queue

Fix released, awaiting user verification (driven off the dual-tolerant glob `docs/problems/*.verifying.md docs/problems/verifying/*.md` per ADR-022 + RFC-002 migration window). Sorted by `Released date ASC` (oldest at row 1; same-day releases tiebreak by ID ASC). <!-- VQ-SORT-DIRECTION: oldest-first per ADR-022 --> `Likely verified?` column carries an **evidence-first** cell per P186 — three canonical values: `yes — observed: <evidence>`, `no — not observed` (default for newly-released tickets), `no — observed regression`. <!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 --> Age is preserved separately via the `Released` column — aging surfaces there, not in `Likely verified?`.

| ID | Title | Released | Likely verified? |
|----|-------|----------|------------------|
| P<NNN> | <title> | <release marker> | <yes — observed: …  /  no — not observed  /  no — observed regression> |
...

## Inbound Upstream Reports

Inbound reports discovered by Step 4.5 (ADR-062 § Step 9e renderer per the naming-reconciliation note at the head of Step 4.5; rendered off `docs/problems/.upstream-cache.json`). Section is **lazy-empty**: when `.upstream-cache.json` has `last_checked: null` OR no channels have any reports, the section header is rendered but the table body is empty (the empty-table state itself signals "discovery has run; no reports awaiting triage"). Sorted by `created_at ASC` within each classification group.

| # | Source | Title | Author | Created | Classification | Matched local ticket |
|---|--------|-------|--------|---------|----------------|----------------------|
| #<id> | <channel:repo> | <title> | <author> | <YYYY-MM-DD> | <safe-and-valid \| safe-high-fix-risk \| above-threshold-pushback \| clear-malicious-closed \| matched-local-ticket \| audit-flagged> | P<NNN> \| — |
...

The `Classification` column carries the assessment-pipeline verdict; see `packages/risk-scorer/agents/inbound-report.md` § Verdict combinations for branch routing. The `Matched local ticket` column carries either the local ticket ID (when the pipeline created or matched one) or `—` (when the report is pushback or audit-flagged with no local ticket created).

When `docs/problems/.upstream-cache.json` is missing OR has `last_checked: null` AND no reports cached (initial state, first run), the section is rendered with a single advisory row: `_No inbound discovery pass has run yet. Run /wr-itil:review-problems to poll the configured channels._`

## Parked

| ID | Title | Reason | Parked since |
|----|-------|--------|-------------|
| P<NNN> | <title> | <reason> | <date> |
...
```

Update the "Last reviewed" line per the **inline P134 rotation mechanism** below. The mechanism is inlined here at the execution site (not deferred via cross-reference to `manage-problem` SKILL.md Step 5) so a single-pass agent reading this review refresh does not silently skip the archive step. **Skipping the BEFORE-rewrite archive step destroys the displaced fragment and re-opens P331** (iter-7 + iter-8 of 2026-05-30's AFK work-problems session silently skipped the rotation in 2 of 9 transition-bearing iters under exactly that failure mode). The mechanism MUST execute IN ORDER:

1. **Read** line 3 of `docs/problems/README.md`: `awk 'NR==3' docs/problems/README.md` (`head -3 | tail -1` or `sed -n '3p'` are acceptable equivalents).
2. **Append-if-non-empty (BEFORE step 3, not after)** — if line 3 is non-empty AND not a same-session same-verb near-duplicate of the new fragment, append the existing line 3 verbatim to `docs/problems/README-history.md` under a `## YYYY-MM-DD` heading (creating the heading on first append for that date). Run this BEFORE the Edit-tool rewrite in step 3 — Edit's replace pattern destroys the displaced content otherwise.
3. **Rewrite** line 3 of `docs/problems/README.md` with the new fragment naming the meaningful state change in this refresh (e.g. `auto-transitions fired: P<NNN> → KE`, priority flips, newly-stale tickets). Soft cap ≤ 1024 bytes per fragment; hard ceiling 5120 bytes per ADR-040 Tier 3 envelope; advisory-only enforcement via `packages/itil/scripts/check-problems-readme-budget.sh`.
4. **Stage both** — `git add docs/problems/README.md docs/problems/README-history.md` so the same single commit per ADR-014 captures both files.

Canonical rationale anchor: `manage-problem` SKILL.md Step 5 § Last-reviewed line discipline (P134). The cross-reference is preserved for the "why"; the "what" is inlined above for execution-time legibility per P331.

### 6. Commit the refresh

Commit all changed files per ADR-014 (governance skills commit their own work):

1. `git add` the changed problem files AND `docs/problems/README.md` AND any files renamed via `git mv` in Step 2's auto-transition branch (per the P057 staging trap — `git mv` alone stages only the rename, not the subsequent content edit; re-stage explicitly after each Edit).
2. Satisfy the commit gate — two paths are valid (either produces a bypass marker):
   - **Primary**: delegate to the `wr-risk-scorer:pipeline` subagent-type via the Agent tool.
   - **Fallback**: if the `wr-risk-scorer:pipeline` subagent-type is not available in the current tool set (e.g., this skill is itself running inside a spawned subagent), invoke the `/wr-risk-scorer:assess-release` skill via the Skill tool. Per ADR-015 it wraps the same pipeline subagent and produces an equivalent bypass marker via the `PostToolUse:Agent` hook. Do not silently skip the gate because the primary path is unavailable — the fallback exists specifically to close this gap (see P035).
3. `git commit -m "docs(problems): review — re-rank priorities"`

If `AskUserQuestion` is unavailable AND risk is above appetite, skip the commit and report the uncommitted state clearly (ADR-013 Rule 6 fail-safe). This applies only to the risk-above-appetite branch, not to the delegation-unavailable case above.

### 7. Auto-release when changesets are queued (ADR-020)

Skip this step if the skill is running inside an AFK orchestrator (e.g. `/wr-itil:work-problems`) — orchestrators handle release cadence themselves per ADR-018 (Step 6.5). Detect via orchestrator markers in the invoking prompt ("AFK", "work-problems", "batch-work", `ALL_DONE`). When in doubt, defer to the orchestrator by skipping this step.

Otherwise, after the commit in Step 6 lands, drain the release queue per the mechanism documented in `/wr-itil:manage-problem` Step 12. Review commits typically score Very Low risk (doc-only), so the drain condition (push + release within appetite) is almost always satisfied.

## Ownership boundary

`review-problems` owns:
- Re-scoring the open / known-error backlog (writes Priority + Effort + WSJF lines on problem files).
- Auto-transitioning Open → Known Error when root cause + workaround are documented.
- Firing the Verification Queue prompt (Known Error → Closed via Verification Pending).
- Rewriting `docs/problems/README.md` — this is THE ownership point for the README cache. `list-problems` explicitly defers to this skill for the refresh.

`review-problems` does NOT:
- Pick the next ticket to work (that's `/wr-itil:work-problem`, singular).
- Create new tickets (that's `/wr-itil:manage-problem`).
- Transition tickets to Parked or implement fixes (those are dedicated transitions / fix commits — use `/wr-itil:manage-problem <NNN>` until `/wr-itil:transition-problem` lands).

## Related

- **P071** (`docs/problems/071-argument-based-skill-subcommands-are-not-discoverable.open.md`) — originating ticket. This skill is phase 2 of the P071 phased-landing plan (list-problems was phase 1; work-problem singular is phase 3).
- **ADR-010 amended** (`docs/decisions/010-rename-wr-problem-to-wr-itil.proposed.md` — Skill Granularity section) — canonical skill-split naming + forwarder contract + `deprecated-arguments: true` frontmatter flag.
- **ADR-022** (`docs/decisions/022-verification-pending-status.proposed.md`) — Verification Pending status conventions; `.verifying.md` exclusion from WSJF ranking; Verification Queue rendering.
- **ADR-014** — governance skills commit their own work.
- **ADR-015** — governance skills delegate release scoring to the pipeline subagent / `assess-release` fallback.
- **ADR-037** (`docs/decisions/037-skill-testing-strategy.proposed.md`) — contract-assertion bats pattern applied to this skill.
- **P031** — git-history freshness check rationale (mtime unreliable in worktrees). Applies to the README cache this skill owns.
- **P047** — live-estimate effort buckets; the Step 2 re-estimate is the lifecycle transition this ticket closes.
- **P048** Candidate 4 — original `Likely verified?` column introduction (14-day age-heuristic). Superseded by P186 evidence-first cell shape.
- **P186** — evidence-first cell shape (`yes — observed: <evidence>` / `no — not observed` / `no — observed regression`) supersedes the age-based heuristic in Step 3 + Step 5; `<!-- LIKELY-VERIFIED-CELL-SHAPE: evidence-based per P186 -->` marker drives cross-skill drift detection (P138 / P150 fix-shape precedent).
- **P057** — staging trap. Step 2's auto-transition MUST re-stage after Edit.
- **P062** — README.md refresh on transitions. Step 5 is the review-path of the same refresh; `/wr-itil:manage-problem` Step 7 carries the transition-path.
- **JTBD-001** (`docs/jtbd/developer/JTBD-001-enforce-governance.proposed.md`) — discoverable surface via `/wr-itil:` autocomplete.
- **JTBD-101** (`docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md`) — one skill per distinct user intent.
- `packages/itil/skills/manage-problem/SKILL.md` — hosts the thin-router forwarder for the deprecated `manage-problem review` form.
- `packages/itil/skills/list-problems/SKILL.md` — sibling read-only display skill; defers the README refresh to this skill.

$ARGUMENTS
