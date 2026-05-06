# Problem 079: No inbound sync of upstream-reported problems — reports filed via the intake templates never surface in the local backlog

**Status**: Open
**Reported**: 2026-04-21
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: L — re-rated 2026-04-26 from M after user direction resolved 4 of 7 design questions and added substantive new scope (inbound-report assessment pipeline + blocked-user-list + downstream-contract symmetry). Original M scope (gh issue list + JSON cache + README section) remains the foundation; new scope adds: (1) JTBD alignment classifier that assesses each inbound report against documented persona JTBDs OR detects a new valid JTBD for an existing persona; (2) two-axis risk assessment of each report (risk of the request itself — malicious info-extraction / backdoor / malicious code injection — AND risk of fixing the reported problem); (3) above-threshold pushback path — comment back explaining why we're declining (the comment goes through external-comms risk gate + voice-and-tone gate per P064 and P038); (4) malicious-request path — close the upstream ticket AND maintain a blocked-user list refusing future tickets from the user; (5) safe-and-valid path — create the local problem ticket AND respond on the upstream issue with details (the response also goes through risk + voice-tone gates); (6) downstream-contract symmetry — our shipped intake templates must mirror the lookup pattern that `/wr-itil:report-upstream` uses to discover upstream contracts (so downstream projects' report-upstream can find our intake correctly). Pushes effort from M (4 hours) to L (full day) and creates transitive dependencies on P064 (risk gate on external comms — required for the pushback + response paths) and P038 (voice-tone gate on external comms — required same paths). Marginal effort post-dependency-closure: still L for the assessment-pipeline + blocked-user-list infrastructure.

**WSJF**: 1.5 (transitive) — re-rated 2026-04-26 — `(12 × 1.0) / max(L=4, P064=L=4, P038=XL=8) = 12 / 8 = 1.5`. Marginal-only would be `(12 × 1.0) / 4 = 3.0` but P038 is unbuilt (XL) and the user direction binds the assessment-pipeline + pushback comment surface to P038/P064 infrastructure. Per the transitive-dependency rule (P076), P079's effective WSJF cannot exceed P038's. Original 6.0 rating was for the marginal scope before the assessment pipeline was added.
**Type**: technical

<!-- transitive: L (marginal) → XL (transitive) via P038 -->

**Effort marginal**: L (assessment-pipeline + blocked-user-list + symmetry) — the work this ticket adds on top of P064 + P038 closing.

## User direction (2026-04-26 interactive AskUserQuestion resolution)

Four of the original investigation questions were resolved interactively at the 2026-04-26 stop-condition #2 surface (P122 trigger):

- **(a) ADR shape**: **New sibling ADR** defining the inbound-discovery contract as a peer of ADR-024's outbound contract. Author the ADR FIRST per architect framing (avoid retrofitting documentation to whatever the implementation lands).
- **(b) Cache file shape**: **JSON** (`docs/problems/.upstream-cache.json` per existing per-project cache patterns; trivially parseable in bash + agent surfaces).
- **(c) Channel scope**: **All three GitHub channels** — issues (`gh issue list` against problem-report.yml-labelled), discussions (`gh api repos/.../discussions`), security advisories (`gh api repos/.../security-advisories`). Plus a meta-direction: **examine how `/wr-itil:report-upstream` discovers upstream contracts** (it reads the upstream's `.github/ISSUE_TEMPLATE/`, `SECURITY.md`, etc. per ADR-024 + ADR-033). The inbound surface MUST be **symmetric** — our shipped intake templates and SECURITY.md are what downstream projects' `report-upstream` skills discover, so we need to publish in the shape they expect to find. This is a contract-symmetry concern that composes with **P065** (skill scaffolds intake files in downstream projects).
- **(d) Auto-create vs surface-only — REPLACED with assessment pipeline**: instead of a binary choice, the user directed a **multi-step assessment pipeline**:
  1. **JTBD alignment check** — does the report align with a documented JTBD? Or does it identify a new valid JTBD for an existing persona? (If neither, flag for review.)
  2. **Risk assessment of the request itself** — is this a malicious info-extraction attempt? A backdoor request? A request to add malicious code? Use the existing risk-scoring framework against the inbound text.
  3. **Risk assessment of fixing the reported problem** — what's the risk of doing the work the report asks for? (Some legitimate-looking requests might create high-risk changes.)
  4. **Above-threshold-risk path** — push back with a comment on the upstream ticket explaining why we're declining. The pushback comment goes through the external-comms risk gate (P064) and voice-tone gate (P038).
  5. **Clear-malicious path** — close the upstream ticket AND add the user to a **blocked-user list** (we won't accept any future tickets from them). Blocked-user enforcement gates inbound discovery itself — reports from blocked users are filtered out at discovery time.
  6. **Safe-and-valid path** — create the local problem ticket AND respond on the upstream issue with the local ticket reference + acknowledgement. The response comment goes through external-comms risk gate (P064) and voice-tone gate (P038).
  7. **All external comms** (pushback OR acknowledgement) require the dual gate (risk + voice-tone). No bare comment posting.

This is substantively richer than the original "auto-create OR surface-only" binary. It introduces three new infrastructure pieces:
- A **JTBD-alignment classifier** (could compose with `wr-jtbd:agent` evaluation).
- A **dual-axis risk evaluator** (request-text risk + fix-work risk) that extends `wr-risk-scorer:external-comms` (P064) with the inbound-report axis.
- A **blocked-user list** mechanism — new lifecycle artefact (e.g., `docs/blocked-reporters.json` or similar; needs ADR call on persistence and per-machine vs per-repo scope).

## Out-of-scope-but-newly-surfaced (carve-outs from user direction)

The user direction surfaced concerns that should compose with P079's fix but warrant separate ticket capture:

- **P123 candidate**: **blocked-user list mechanism** — persistent block list, ADR call on per-machine vs per-repo scope, enforcement at inbound discovery time + outbound report-upstream time (do not file new reports against a project that has us blocked). Captured separately so P079 isn't a new-ADR-bundle.
- **P065-extension**: **downstream-contract symmetry** — our intake templates + SECURITY.md must be discoverable by downstream `/wr-itil:report-upstream` invocations using the same lookup pattern we use for upstream discovery. P065 already tracks skill-scaffolds-intake-files; this extension says scaffolded files must also be **schema-compatible** with our own report-upstream's discovery logic.

These carve-outs are referenced from P079's Dependencies section as `**Composes with**` — they don't strictly block P079 (the assessment pipeline can ship without the blocked-user list initially, treating "block" as an audit-log-only action), but the design surfaces overlap.

## Description

Plugin users have two shipped reporting channels:
- **This repo's intake templates** (`.github/ISSUE_TEMPLATE/problem-report.yml` — shipped 2026-04-20 under `P055 Part A` + `P066`). Plugin users file GitHub issues on `windyroad/agent-plugins` when they hit a problem.
- **Downstream-scaffolded intake templates** (per `ADR-036` — `/wr-itil:scaffold-intake` drops the same `problem-report.yml` into downstream OSS projects). Those issues land on the downstream repo's tracker, not ours; inbound sync for those is out of scope for this ticket (see P080's sibling note on bidirectional updates — the downstream-tracker case composes with the bidirectional-update surface, not with this inbound-discovery gap).

For the first channel (this repo), there is no mechanism that makes us aware of newly-filed reports. The maintainer must manually check `gh issue list` or the GitHub UI. Nothing in `/wr-itil:manage-problem review` (Step 9a–9e — the canonical "re-rank the backlog" operation) queries the upstream channel; the README.md cache renders only locally-sourced tickets. Result: a plugin user files a well-structured `problem-report.yml` issue and it sits invisible in `gh issue list` until the maintainer remembers to look.

This breaks the end-to-end promise set up by `P055 Part A` (intake templates shipped), `ADR-024` (report-upstream contract), `ADR-036` (downstream scaffold), and the `plugin-user` persona + `JTBD-301` landed under `P072`. The reporter followed the documented path; we never close the loop.

The user's direction (2026-04-21 interactive): `manage-problem review` should check the configured upstream channels for new reports. Cache the results to avoid thrashing the GitHub API, with a `force-recheck` escape and a default TTL-based auto-recheck on every review.

## Symptoms

- Plugin user files `problem-report.yml` issue on `windyroad/agent-plugins`. Issue sits in GitHub's tracker with no maintainer awareness.
- Maintainer runs `/wr-itil:manage-problem review` — WSJF table re-renders but doesn't reference the new report. README.md refreshes; the inbound queue is invisible.
- Maintainer runs `/wr-itil:work-problems` AFK — the orchestrator iterates the local backlog and never sees the upstream report; WSJF scoring ignores it entirely.
- The triage delay between "reporter files" and "maintainer notices" can stretch days or weeks, even when the reporter's issue is higher-priority than the top of the local backlog.
- `manage-problem review` prose claims "comprehensive WSJF re-rank" but the scope is local-only; the claim is technically true but misleading for the `JTBD-201` (tech-lead audit-trail) persona that expects end-to-end visibility.

## Workaround

Maintainer manually runs `gh issue list --repo windyroad/agent-plugins --label problem` before each `manage-problem review`, cross-checks against the local backlog, and creates local tickets for any unmatched upstream reports. Error-prone, slow, and doesn't scale beyond a single maintainer. Defeats the point of having an automated re-rank step.

## Impact Assessment

- **Who is affected**:
  - **plugin-user persona** (`JTBD-301` — report-upstream job) — their report enters a black hole after submission. The `problem-report.yml` structured intake produces high-quality reports, and that quality is wasted if nobody discovers them promptly.
  - **solo-developer persona** (`JTBD-001` — governance without slowing down) — maintainer must manually poll GitHub to discover new reports, which is exactly the "manually police" pain pattern `JTBD-001` is designed against.
  - **tech-lead persona** (`JTBD-201` — audit trail) — backlog audit assumes local-backlog-completeness; inbound reports violate that assumption silently.
  - **plugin-developer persona** (`JTBD-101` — extend the suite) — downstream plugin authors adopting the intake templates via `ADR-036` inherit the same gap for their own projects unless we document the inbound-discovery pattern explicitly.
- **Frequency**: every upstream report. Rate-of-fire scales with plugin adoption; low now, will grow.
- **Severity**: High. Systemic failure mode on a shipped end-to-end contract. The outbound scaffolding is in place; the inbound close-the-loop is missing.
- **Analytics**: N/A today. Post-fix candidate metrics: (1) time-to-triage histogram (reporter-submit to maintainer-acknowledge), (2) inbound-reports count over time, (3) percentage of local tickets that originated upstream (traceability).

## Root Cause Analysis

### Structural

`packages/itil/skills/manage-problem/SKILL.md` Step 9 ("For review: Re-assess all open problems") operates entirely on local state:

- Step 9a: Read `RISK-POLICY.md` — local file.
- Step 9b: For each open/known-error problem in `docs/problems/*.md` — local glob.
- Step 9c: Present summary + select problem to work — derived from local files.
- Step 9d: Check for pending verifications via `docs/problems/*.verifying.md` — local glob.
- Step 9e: Update files and refresh `README.md` cache — local write.

No step queries external channels. The `## Reported Upstream` section (per `ADR-024` Confirmation criterion 3a) records the outbound link when a ticket WAS reported upstream — but that marker is written at `/wr-itil:report-upstream` invocation time, not refreshed from the upstream side. There is no inbound pull.

`/wr-itil:report-upstream` (per ADR-024) is outbound-only. P070's direction decision (2026-04-20) added dedup-before-filing via an LLM-based semantic comparator, but that comparator runs at outbound time, not inbound — it asks "does my local ticket match an existing upstream issue?" not "are there upstream issues without a matching local ticket?".

`/wr-itil:work-problems` Step 1 scans `docs/problems/README.md` (or the raw local files). No inbound awareness.

### Why it wasn't caught earlier

`ADR-024` scoped the report-upstream contract to outbound only. Inbound was noted as out-of-scope under the reasoning that maintainers could use `gh issue list` manually. That reasoning doesn't hold up once the shipped workflow (`manage-problem review` + `work-problems` AFK) promises a comprehensive backlog view — users reasonably expect the automation to surface inbound reports alongside local tickets.

`ADR-036` scoped downstream scaffolding; it assumes the reports land on the downstream repo's tracker and the downstream maintainer handles inbound triage. For this repo's reports (`windyroad/agent-plugins`), there's no analogous downstream to offload — we ARE the inbound.

`P055 Part A` shipped the templates; `P066` corrected the template shape to problem-first. Neither ticket modelled the inbound-sync step because the scope was "make reporting possible" not "make reports visible".

### Candidate fix

**Option A: Extend `manage-problem review` with an inbound-discovery sub-step (Step 9a-minus-1, or a new Step 8.5).**

The sub-step queries each configured upstream channel, caches results, and renders a new "Inbound Upstream Reports" section in `docs/problems/README.md`. Shape:

1. **Channel configuration** — a small config file (e.g. `docs/problems/.upstream-channels.json`) listing `{ type: "github-issues", repo: "windyroad/agent-plugins", label: "problem", template: "problem-report.yml" }` entries. Default config checked into this repo; adopters edit to suit.
2. **Cache file** — `docs/problems/.upstream-cache.json` storing `{ last_checked: <ISO timestamp>, reports: [...] }` per channel. TTL default 24 h.
3. **Fetch mechanism** — `gh issue list` via Bash (or `gh api` for GH Discussions). Must handle auth failures (no GH_TOKEN), rate-limits, and empty results without crashing the review.
4. **Force-recheck** — CLI flag pattern: `/wr-itil:manage-problem review --force-upstream-recheck` OR sibling skill `/wr-itil:review-problems --force-upstream-recheck` (P071 split). Also: expiry-based auto-recheck when cache is older than TTL.
5. **Render** — new "## Inbound Upstream Reports" section in `README.md`, listing `{ #issue, title, author, date, matched-local-ticket? }`. Matching against local tickets uses the P070 semantic-comparator infrastructure (architect review at implementation time to decide whether this ticket hard-depends on P070 or duplicates the comparator logic).
6. **Actionable surfacing** — for unmatched reports, either (a) auto-create local tickets using the `problem-report.yml` content as the description, OR (b) list them for the maintainer to triage via `AskUserQuestion` during the next interactive review, OR (c) both. Architect review to decide; lean direction is (b) first — auto-creation is a big policy step.

Pros: single cohesive surface; leverages existing review step's cache-refresh cadence; no new skill needed.
Cons: adds an external-dependency (GH API) to every review invocation — must fail-soft.

**Option B: New sibling skill `/wr-itil:sync-upstream-reports` invoked from `manage-problem review` Step 9e.**

Dedicated skill handles the inbound query; review delegates to it. More modular; matches the sibling-skill pattern from `P071` split. May be over-engineered for the current scope.

**Option C: A new ADR that defines the inbound-discovery contract as a first-class primitive.**

The inbound contract becomes a peer of ADR-024's outbound contract. This is the most complete solution and probably the right call given the scope touches multiple existing ADRs (ADR-024, ADR-036) and introduces a new cache + trigger surface.

### Lean direction

**Option C — new ADR defining the inbound contract as a peer of ADR-024's outbound contract.** Paired with Option A's concrete mechanism (review-step inbound-discovery sub-step). This matches the repo's pattern of "ADR-first for cross-cutting discipline, implementation ticket for execution". Single fix ticket (P079) for the implementation execution; the ADR drafting is called out as the first investigation task.

Architect call required at implementation time to finalise ADR shape + extension-vs-new-ADR decision.

### Related sub-concerns

**Sub-concern 1**: the downstream channel (ADR-036-scaffolded) is OUT of scope for P079. Those reports land on the downstream repo's tracker; downstream maintainer handles inbound triage on their side. Our `manage-problem review` checks THIS repo's tracker, not every tracker we've scaffolded into.

**Sub-concern 2**: bidirectional updates (the inverse flow — local ticket transitions trigger upstream comment) are the sibling concern tracked on **P080** — see the Related section. P079 closes the inbound leg; P080 closes the outbound-lifecycle leg; together they make the reporter experience end-to-end.

**Sub-concern 3**: rate-limiting. `gh issue list` on a repo with many issues could be slow or rate-limited. The cache mitigates; the TTL tunes the cost. Worst case (first-run, no cache): one API call per review. Acceptable.

**Sub-concern 4**: multi-channel composition. If Discord (plugin-discord) becomes a reporting channel, the channel-config shape must extend cleanly. The `{ type, ... }` discriminator in the config entry is designed for that.

**Sub-concern 5** (added 2026-04-25 from #52831): duplicate-detection-bot comment class. Some upstream trackers (notably `anthropics/claude-code`) run a duplicate-detection bot that posts a possible-duplicates comment shortly after issue filing. The bot comment carries a fixed auto-close countdown and a "👎 to prevent auto-closure" mechanic. The inbound-discovery sub-step must classify comments by author-class — `maintainer` / `bot` / `reporter` — because the user-response surface differs (👎 the bot or comment to prevent auto-close vs. reply to a maintainer with new info). Without classification, a bot countdown reads identically to maintainer engagement and the user gets no signal which path to take.

**Sub-concern 6** (added 2026-04-25 from #52831): time-pressured upstream events. Auto-close timers, "stale" labellers, scheduled-close bots, and "needs-info" timeouts each impose a deadline on the local maintainer that is invisible until checked. The inbound-discovery sub-step needs deadline awareness: parse comment bodies and label-event metadata for time-pressure markers (auto-close-in-N-days, stale-in-N-days, scheduled-close-on-DATE) and surface a `Days until <event>` column in the rendered Inbound Upstream Reports section. Decide whether to fire a proactive notification surface (e.g., `ScheduleWakeup` from a session that observed the deadline, or a `/loop`-driven recheck cadence that converges on the deadline) when the deadline drops below a threshold.

**Sub-concern 7** (added 2026-04-25 from #52831): upstream-resolution-driven local lifecycle transitions. When an upstream issue closes with a resolution marker (linked PR with `Closes #N`, milestone marked released, label `fixed`, or a maintainer comment matching a release-announcement shape), the local ticket's `## Reported Upstream` link becomes a closure signal. The inbound-discovery sub-step should detect the resolution and either (a) auto-advance the local ticket from `.open.md` / `.known-error.md` to `.verifying.md` with the upstream resolution serving as the `## Fix Released` evidence, or (b) surface the inferred transition to the user via `AskUserQuestion` during review (lean: option b first, auto-advance is policy-heavy). This is the inbound counterpart to P080's outbound-transition-comments — closing the resolver-feedback loop in both directions. Composes with P063's external-root-cause lineage: a P063-marked ticket whose upstream resolves should auto-Verifying without re-investigation.

### Investigation Tasks

- [ ] Architect review: pick Option A / B / C. ADR shape (new ADR vs ADR-024 extension). Decide auto-create-vs-list policy for unmatched reports.
- [ ] Draft the new ADR (or ADR-024 amendment) documenting the inbound contract.
- [ ] Design the `.upstream-channels.json` and `.upstream-cache.json` shapes.
- [ ] Implement the inbound-discovery sub-step in `manage-problem review` (or the dedicated skill per Option B).
- [ ] Add the "Inbound Upstream Reports" section renderer to `README.md` refresh logic (Step 9e).
- [ ] Add `--force-upstream-recheck` flag + TTL-expiry auto-recheck.
- [ ] Compose with P070's semantic-comparator for matched-local-ticket? detection — architect review decides dependency direction.
- [ ] Bats doc-lint assertions for the new review sub-step (per ADR-037): cache contract, channel-config shape, force-recheck flag, renderer section presence, TTL honour.
- [ ] End-to-end test: file a synthetic issue via `gh issue create`; run `manage-problem review`; confirm the inbound report surfaces in README.md.
- [ ] Wire P072's `plugin-user` persona into the Related section of the new ADR — the inbound contract is where the reporter's submission becomes visible to the maintainer.
- [ ] Sub-concern 5: classify inbound comments by author-class (maintainer / bot / reporter). Surface bot comments — especially duplicate-detection-bot output — as a distinct comment class with its own action surface (e.g., a "👎 bot to prevent auto-close" affordance in the rendered table or an interactive prompt during review).
- [ ] Sub-concern 6: parse comment bodies and label-event metadata for time-pressure markers (auto-close-in-N-days, stale-in-N-days, scheduled-close-on-DATE). Render a `Days until <event>` column in the Inbound Upstream Reports section. Architect call: notification surface (ScheduleWakeup vs. /loop recheck cadence vs. surface-only-during-review).
- [ ] Sub-concern 7: detect upstream-resolution markers (linked-PR `Closes #N`, milestone:released, label:fixed, release-announcement comment shapes). Propose local lifecycle transitions for `## Reported Upstream`-linked tickets. Compose with P063 lineage so external-root-cause tickets auto-Verifying without re-investigation. Architect call: auto-advance vs. AskUserQuestion-confirm.

## Dependencies

- **Blocks**: P080 (bidirectional update of upstream-reported problems — depends on P079's inbound discovery + matched-local-ticket detection to know which upstream tickets to update on lifecycle transition)
- **Blocked by**: P064 (risk-scoring gate on external comms — required for the assessment-pipeline pushback + acknowledgement comment paths), P038 (voice-and-tone gate on external comms — same paths). Without P064/P038, the assessment pipeline cannot ship the comment-back paths; only the local-ticket-creation path could ship in isolation, which would be a partial implementation.
- **Composes with**: P065 (skill scaffolds intake files in downstream projects — extends to schema-compatibility with our own report-upstream's discovery), P063 (external-root-cause lineage — sub-concern 7's upstream-resolution-driven local lifecycle transitions ride P063's lineage marker), P070 (semantic-comparator from report-upstream's dedup branch — could be reused for matched-local-ticket detection on inbound), P122 (orchestrator stop-condition #2 routing — fix to that ticket's interactive-default branch is what surfaced these answers in the first place), P123-candidate (blocked-user list — composes with the assessment pipeline's clear-malicious branch)

## Confirming evidence — 2026-04-25 anthropics/claude-code#52831 retrospective

Concrete instance of the inbound-discovery gap and the three new sub-concerns above. Agent posted upstream issue anthropics/claude-code#52831 (P113's Reported Upstream URL) on 2026-04-24. On 2026-04-25, the upstream duplicate-detection bot replied flagging three possible duplicates with a 3-day auto-close countdown. The reply was discovered only because the user manually checked the upstream issue — no inbound-discovery surface in this skill suite would have surfaced (a) the bot reply (sub-concern 5), (b) the 3-day deadline (sub-concern 6), or — had it auto-closed — (c) the resulting upstream resolution-as-duplicate that should propagate back to the local ticket lifecycle (sub-concern 7). All three sub-concerns were live on the same comment thread within 24 h of filing. Workaround was `gh issue view 52831 --comments` per upstream-reported ticket; doesn't scale to N tickets, doesn't fire on time-sensitive triggers, doesn't classify bot vs. maintainer comments. Concrete cost: without the user's manual check, the upstream issue would have silently auto-closed despite our report having two unique asks not covered by the suggested duplicate, and we'd have learned only by re-discovering the closed issue weeks later. This is the inbound-side counterpart to the outbound gap class tracked under P038 / P064 (no latch on outbound public comms) — wr-itil ships the outbound half of an interaction without the inbound half.

## Related

- **P080** (`docs/problems/080-no-bidirectional-update-of-upstream-reported-problems.open.md`) — sibling concern. Outbound-lifecycle-update leg; together P079 + P080 close the reporter-loop end-to-end.
- **P055** (`docs/problems/055-no-standard-problem-reporting-channel.closed.md`) — shipped Part A (intake templates) + Part B (`/wr-itil:report-upstream`). This ticket (P079) closes the inbound-side gap P055 did not model.
- **P063** (`docs/problems/063-manage-problem-does-not-trigger-report-upstream-for-external-root-cause.verifying.md`) — trigger surface for `/wr-itil:report-upstream` (outbound). Inverse direction.
- **P066** (`docs/problems/066-intake-templates-split-bug-feature-instead-of-problem.verifying.md`) — problem-first template shape this ticket's discovery logic matches against.
- **P067** (`docs/problems/067-report-upstream-classifier-is-not-problem-first.open.md`) — same template-shape direction; compatibility dependency.
- **P070** (`docs/problems/070-report-upstream-does-not-check-for-existing-upstream-issues.open.md`) — outbound dedup-before-filing; shares the semantic-comparator infrastructure this ticket wants to reuse for matched-local-ticket detection.
- **P072** (`docs/problems/072-no-persona-models-external-repo-reporter.verifying.md`) — `plugin-user` persona + `JTBD-301` that this ticket serves.
- **ADR-024** (`docs/decisions/024-cross-project-problem-reporting-contract.proposed.md`) — outbound contract this ticket's new ADR / amendment pairs with.
- **ADR-036** (`docs/decisions/036-scaffold-downstream-oss-intake.proposed.md`) — downstream scaffolding; defines the channel shape this ticket's inbound discovery follows.
- **ADR-014** (`docs/decisions/014-governance-skills-commit-their-own-work.proposed.md`) — the inbound-discovery sub-step must commit its cache + README refresh per this ADR.
- **JTBD-001**, **JTBD-101**, **JTBD-201**, **JTBD-301** — personas whose end-to-end promise this ticket restores.
