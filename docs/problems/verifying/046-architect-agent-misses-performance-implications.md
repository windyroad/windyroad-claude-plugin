# Problem 046: wr-architect:agent misses per-request performance / load implications on high-traffic endpoints

**Status**: Verification Pending
**Reported**: 2026-04-19
**Priority**: 8 (Medium) — Impact: Minor (2) x Likelihood: Likely (4)
**Effort**: L (agent prompt + potential sub-agent design + performance-budget ADR surface)
**WSJF**: 2.0 — (8 × 1.0) / 4

## Fix Released

Fix shipped in AFK iter 2 (2026-04-19, pending commit). Implemented ADR-023 (wr-architect agent performance review scope): amended `packages/architect/agents/agent.md` with a "Runtime-Path Performance Review" section that fires on cache/throttle/rate-limit/per-request-handler changes, requires quantified per-request cost delta × request-frequency estimate (with cited source), bans qualitative-only claims, and reports a verdict against any in-scope performance-budget ADR. Added 9-test regression bats file `packages/architect/agents/test/architect-performance-review.bats` satisfying ADR-023 Confirmation criterion 2. Bonus: `npm test` now covers `packages/*/agents/test/` — 54 previously-uncollected agent tests now run in CI (331/331 pass). Released via `@windyroad/architect` minor bump. Awaiting user verification — next architect review of a cache-directive or rate-limit change on a high-traffic endpoint (addressr P018 replay) should produce a quantified load-delta report rather than "load is negligible".

## Description

`wr-architect:agent` reviews proposed changes against existing decisions in `docs/decisions/` and flags ADR conflicts. Its review scope today is ADR-driven — it checks whether a change violates an accepted decision, whether a new decision is warranted, and whether file-placement / testing conventions are right. What it does NOT systematically check is the **per-request performance and load implications** of runtime-path changes on high-traffic endpoints.

The pattern was observed by a downstream consumer of this plugin (the addressr project) on 2026-04-18. Addressr's own ticket captures the incident in full: [`addressr/docs/problems/024-architect-agent-misses-performance-implications.open.md`](https://github.com/tomhoward/addressr/blob/main/docs/problems/024-architect-agent-misses-performance-implications.open.md). This ticket is the upstream counterpart — the fix, if any, lands in the `@windyroad/architect` plugin shipped from this repo.

Summary of the addressr incident:

- The architect recommended `cache-control: no-cache` for a HATEOAS root `/` endpoint as an ADR-conflict fix, reasoning "load is genuinely negligible — the response is `{}` body, CPU cost per revalidation is microseconds even at full traffic".
- The addressr maintainer rejected: every client page-load fetches the root for HATEOAS discovery, so `no-cache` would add an origin round-trip per page-load across the entire paid + free-tier consumer base.
- The qualitative "load is negligible" claim ignored the request-frequency multiplier (requests per session × sessions per consumer × consumers).
- Without the human override, the fix would have shipped and degraded live-service performance on a revenue-generating endpoint.

The same architect agent reviews changes across multiple downstream projects (per the addressr usage-data report, bbstats is another consumer). A blind spot for per-request cost trade-offs is therefore a systemic issue across the whole `wr-architect` user base, not a per-project configuration gap.

## Symptoms

- Architect approves changes with per-request cost implications on consumer-facing paths without flagging them.
- "Load is negligible" is a recurring qualitative claim in architect reviews; no quantitative check against the target project's traffic profile.
- Downstream users become the effective safety net for architect misses on performance trade-offs (e.g. addressr maintainer now holds a per-session memory guardrail, `feedback_ask_before_ops_tradeoffs.md`, to prompt re-check on "load is negligible" claims for revenue-path endpoints).
- Architect review output is biased toward "does this violate an ADR?" because that is the explicit review scope; performance implications without a matching ADR get no scrutiny.

## Workaround

- Downstream projects add per-session memory guardrails that force re-check on architect "load is negligible" claims for revenue-path endpoints (addressr has done this).
- Downstream projects author project-specific performance-budget ADRs so the architect's existing "check against ADRs" flow catches violations.
- Human review remains the backstop: the downstream maintainer overrides architect recommendations when they involve runtime-path changes on high-traffic endpoints.

None of these are systemic — each user of `@windyroad/architect` repeats the workaround independently.

## Impact Assessment

- **Who is affected**: every consumer of `@windyroad/architect` with runtime-path code (addressr today, bbstats noted as next-most-likely affected, any other downstream project whose architect reviews include cache, throttle, rate-limit, or other request-frequency-sensitive changes). Upstream: the plugin-developer persona (JTBD-101) — a known blind spot in a governance plugin weakens the "clear patterns" promise.
- **Frequency**: every architect review of a runtime-path change where performance is a non-obvious consideration. Not gated behind specific user actions; the blind spot is always present.
- **Severity**: Minor — no user-visible defect has shipped yet (the addressr maintainer caught the P018 incident before push). The severity risk is **potential** rather than **realised**. However, the pattern is confirmed and reproducible; every downstream project that hits a similar cache / throttle / rate-limit decision is exposed.
- **Analytics**: evidence from the addressr P018 session transcript; addressr's month-wide usage-data report (2026-03-17 → 2026-04-16) also flagged "shipping prematurely" as a recurring Claude pattern, which aligns with this ticket's concern.

## Root Cause Analysis

### Preliminary context

`wr-architect:agent` is configured to review against `docs/decisions/`. ADRs encode architectural decisions but rarely encode performance constraints in numeric form (request frequency budgets, origin load targets, latency SLOs). When an architect review reduces to "does this violate any ADR", performance implications that don't have an ADR get no scrutiny.

The addressr P018 architect review explicitly said "Load is genuinely negligible" for `no-cache` on root `/`, treating per-request CPU as the only cost. The review ignored:

1. **Origin round-trip latency** added to every page load.
2. **The multiplier effect** of requests per session × sessions per consumer × consumers.
3. **Business context** — this was a revenue-generating endpoint where perceived latency matters to the buyer.

The architect agent has no prompt-level instruction to ask any of (1)-(3) before approving a runtime-path change.

### Candidate fixes (from addressr P024, verbatim with upstream annotations)

1. **Expand the architect agent's review checklist** to include a performance / load / latency step: "For any change on a runtime-path endpoint, estimate per-request cost delta and request frequency on that endpoint; flag if the product of the two exceeds a threshold (e.g., > 1% origin CPU or > 10ms added p95 per page load)." Requires edits to the architect agent prompt/system message in `packages/architect/agents/`. **Upstream fix** (this repo).
2. **Add a performance budget ADR surface** that the architect agent can read. Option 2a: provide a template / reference performance-budget ADR in `packages/architect/` that downstream projects can adopt. Option 2b: ship a default "performance-budget" rule the architect applies when no project-specific ADR exists. Downstream projects extend with their own budgets. **Upstream fix** (this repo).
3. **Add a performance-specialist sub-agent** that the architect delegates to for runtime-path changes; the architect stays focused on ADRs and calls the sub-agent when a change touches a cache directive, throttle, or rate-limit. Mirrors the `wr-risk-scorer:pipeline` delegation pattern. **Upstream fix** (this repo).
4. **Memory-level guardrail** — already partly done downstream (`feedback_ask_before_ops_tradeoffs.md` in addressr's memory store). This is the least-systemic fix but the fastest to land for any one project. **Not an upstream fix** — per-project mitigation only; preserved in addressr.

Candidate ordering reflects an **upstream cost-of-fix** ranking: Candidate 1 is cheapest (prompt edit); Candidate 3 is most substantial (new sub-agent); Candidate 2 bridges the two. The architect has not yet been consulted on which option lands first — that decision is an investigation task below.

### Relationship to existing tickets

- **P037** (jtbd-reviewer returns bare verdict without reason) and **P038** (no voice-tone gate on external comms) describe the same category of failure mode for different governance agents: a review surface whose scope omits a dimension the user cares about. The fix pattern for P046 should be checked against those tickets so the three problems land a consistent remediation.
- **P014** (no lightweight aside invocation for governance skills) is an adjacent architectural pattern; if a performance sub-agent is introduced as part of Candidate 3, it will interact with whatever aside mechanism P014 settles on.
- **P022** (agents must not fabricate time estimates) is closely related in spirit: both concern agent outputs that look authoritative but have no grounded data. The "load is negligible" claim in addressr P018 is a specific instance of ungrounded quantification.

### Investigation Tasks

- [ ] Read the `wr-architect:agent` prompt in `packages/architect/agents/` to confirm the current review scope and identify the insertion point for a performance / load check.
- [ ] Architect review: decide which candidate fix to pursue. Combinations are likely (e.g., Candidate 1 prompt expansion + Candidate 2 performance-budget ADR surface).
- [ ] If pursuing Candidate 1 (agent prompt edit): draft the performance-check section. Require the architect to report per-request cost delta and request-frequency estimate alongside the ADR-conflict section. Ship as a `.proposed.md` ADR amendment or new ADR per project convention.
- [ ] If pursuing Candidate 2 (performance-budget ADR surface): propose the template or default rule; confirm downstream projects can extend it cleanly.
- [ ] Cross-check against P037 and P038 to ensure the fix pattern is consistent across governance agents with scope-gap failure modes.
- [ ] Add a reproduction case in the architect agent test suite: present a cache-directive change on a high-traffic endpoint and verify whether the performance implication is flagged. Track under P012 (skill testing harness) once that ADR lands.
- [ ] Decide changeset scope: this fix ships under `@windyroad/architect` (patch or minor depending on whether the agent prompt shape changes).

## Related

- **Upstream of**: [addressr P024 (`architect-agent-misses-performance-implications`)](https://github.com/tomhoward/addressr/blob/main/docs/problems/024-architect-agent-misses-performance-implications.open.md) — the incident that surfaced this ticket. The fix lands here; addressr retains a local workaround memory.
- [`packages/architect/`](https://github.com/windyroad/agent-plugins/tree/main/packages/architect) — the plugin this fix targets. The agent prompt lives under `packages/architect/agents/`.
- P037: `docs/problems/037-jtbd-reviewer-returns-bare-verdict-without-reason.open.md` — sibling failure mode: governance agent scope gap.
- P038: `docs/problems/038-no-voice-tone-gate-on-external-comms.open.md` — sibling failure mode: governance agent scope gap.
- P022: `docs/problems/022-agents-should-not-fabricate-time-estimates.open.md` — related: agent outputs that look authoritative but have no grounded data ("load is negligible" is a specific instance of this pattern).
- P014: `docs/problems/014-aside-invocation-for-governance-skills.open.md` — architectural adjacency if Candidate 3 (sub-agent) is pursued.
- P012: `docs/problems/012-skill-testing-harness.open.md` — reproduction-test scaffolding needed for this ticket's verification.
