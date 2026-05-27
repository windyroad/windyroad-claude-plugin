# Problem 324: Agent-prose verdicts have no behavioural test harness — forcing the ADR-052 structural-test escape hatch + above-appetite release workarounds, perpetuating the structural tests the user has rejected

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 9 (Med-High) — Impact: 3 x Likelihood: 3 (deferred — re-rate at next /wr-itil:review-problems; flagged HIGH-LEVERAGE — see Impact)
**Effort**: L (deferred — re-rate at next /wr-itil:review-problems)
**Type**: technical

## Description

There is no behavioural test harness for **agent-prose verdicts** — the LLM-generated output of the architect / jtbd / voice-tone / risk-scorer review agents (e.g. `[Unratified Dependency]`, `ISSUES FOUND`, `Needs Direction`). `bats` (this repo's test model) is deterministic shell and cannot exercise a prompt-driven agent. That gap (the root of `P012` master-harness + `P176`) has a compounding, recurring cost:

1. Every new agent verdict ships via the **ADR-052 structural-test escape hatch** (Surface 2, the line the user selected: "Escape") — a doc-lint bats that greps the agent.md prose, NOT a behavioural test of the verdict. **The user has repeatedly directed that structural tests are not acceptable and circumvent the desired outcome** (`P081`: "wasteful, not real tests"; `P290`: "structural tests not permitted at all" — user direction during the P283 drain). The escape hatch exists *only because* the harness doesn't.
2. The agent-verdict release class is **structurally above appetite**: R009 scores it 8/25 (Impact 4 — ships to every adopter's review workflow — × Likelihood 2, where the Likelihood-2 floor is precisely "the LLM verdict has no behavioural harness"). Evidence can't reduce it (unlike a deterministic hook à la P283, one observed firing doesn't prove an LLM verdict always fires correctly). So every agent-verdict release needs a hold-changeset + user-override workaround.

**Concrete, twice this session (2026-05-27):** RFC-010 (architect surface-3) and RFC-011 (jtbd surface-3) each shipped a structural-permitted bats and rode an above-appetite 8/25 release that required user-override.

**Behaviour-reflex (the captured-on-correction half, sibling of P197 contract-bypass-reflex):** the agent treated the harness gap as an *immovable standing constraint to route around* (reach for the structural escape + hold/override) rather than naming it as the *highest-leverage fix*. Building the harness would (a) make behavioural-only testing possible so the ADR-052 escape hatch can finally be removed (`P290`), (b) drop the entire agent-verdict release class within appetite, (c) retire the recurring release-gate blocker for every future agent verdict. The user surfaced this directly: *"why aren't you implementing P176/P012?"* + *"structural tests are not ok and circumvent the desired outcome."*

## Symptoms

- Each new review-agent verdict ships with a `tdd-review: structural-permitted (justification: P176)` bats (grep of agent.md prose), never a behavioural test of the verdict itself.
- Each agent-verdict changeset scores R009 8/25 and is held + released via user-override (RFC-010, RFC-011).
- `P290` (remove the structural escape hatch) stays blocked — it cannot land until the harness gives a behavioural alternative.

## Impact Assessment

- **Who is affected**: maintainers (every agent-verdict change pays the escape-hatch + override tax) + the framework's own credibility (it ships the structural tests it tells adopters not to write).
- **Frequency**: every new or changed review-agent verdict, indefinitely, until the harness exists. Already 2× this session.
- **Severity / leverage**: **HIGH-LEVERAGE.** This is the single root that gates the agent-verdict release class, blocks P290, and forces the structural-test pattern the user rejected. `P012`'s WSJF 0.75 (XL effort) under-rates its true leverage now that it is the *recurring* release-gate blocker, not just an abstract "harness scope undefined."

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems; re-rate P012's WSJF up given its recurring-blocker leverage.
- [ ] **Evaluate the solution space** (record an ADR amending ADR-052):
  - **(A) `@windyroad/skill-creator` eval/benchmark capability** — it already does LLM-in-the-loop skill evals (triggering accuracy, variance analysis). Determine whether its harness pattern extends from skill-triggering to agent-verdict-correctness (feed the agent a fixture change → assert the verdict). Closest existing in-repo tooling; investigate first.
  - **(B) LLM-as-judge** — run the real agent against a fixture diff, have a second model grade verdict correctness against a rubric. Industry-standard (promptfoo, deepeval, OpenAI/Anthropic evals, Braintrust). Non-deterministic → needs pass-rate thresholds + variance bounds, not binary asserts.
  - **(C) Golden-transcript / snapshot** — record canonical agent outputs on fixtures, assert structural invariants of the verdict (verdict line present, correct artifact named, marker file written). Cheaper, deterministic, but weaker than (B) on semantic correctness.
  - **(D) Live-agent-in-CI** — invoke the agent in CI on fixtures. Most faithful, but network + cost + flake; needs a gating policy (sampled, not every PR).
  - Likely shape: a thin first slice — (C)-style deterministic invariants for cheap CI coverage + a (B)-style sampled eval for semantic correctness — leveraging (A) if its harness fits.
- [ ] Decide CI integration (which surfaces run live vs. recorded; cost/flake budget).
- [ ] Once a behavioural alternative exists, unblock `P290` (remove the ADR-052 structural escape hatch) and back-fill behavioural tests for the architect (RFC-010) + jtbd (RFC-011) verdicts.

## Dependencies

- **Blocks**: `P290` (remove ADR-052 structural escape hatch — needs a behavioural alternative first); within-appetite release of every agent-verdict change (RFC-010, RFC-011, and future).
- **Composes with / sharpens**: `P012` (master harness — this is the agent-prose-verdict facet + its now-quantified leverage), `P176` (agent-side I2 coverage gap — same root), `P081` (structural tests are wasteful), `P197` (contract-bypass-reflex — the behaviour sibling).

## Related

- captured via /wr-itil:capture-problem + P078 capture-on-correction (user: *"structural tests are not ok and circumvent the desired outcome"* + *"why aren't you implementing P176/P012"*), 2026-05-27.
- **ADR-052** — behavioural-tests-default; its Surface-2 structural escape hatch (the selected line) is what this harness would let P290 remove.
- **R009** (`docs/risks/`) — the 8/25 agent-prose residual class this harness reduces.
- RFC-010 / RFC-011 — the two in-session instances that paid the escape-hatch + override tax.
