# Problem 015: TDD enforcement does not flag vague Gherkin outcome steps

**Status**: Open
**Reported**: 2026-04-16
**Priority**: 9 (Medium) — Impact: Moderate (3) x Likelihood: Possible (3)
**Effort**: L — ADR + heuristic design + reproduction fixtures (scope contained within the `@windyroad/tdd` plugin per direction decision below)
**WSJF**: 2.25 — (9 × 1.0) / 4
**Type**: technical

## Direction decisions (2026-04-20, user — AFK loop stop-condition #2)

**Enforcement level**: **Both — gate + advisory agent**. Deterministic TDD gate catches obvious vague-Then and missing-concrete-example patterns (blocking). A specialist agent reviews subtler shape issues as advisory output. P015 is the Cucumber-specific reference case; P018 owns the framework-agnostic rule.

**Plugin home**: **Extend `@windyroad/tdd`**. No new plugin, no ADR-002 graph change — the content-quality review couples to the existing TDD lifecycle.

Implication: the candidate ADR (`docs/decisions/NNN-test-content-quality-review.proposed.md`, ID to be minted at creation time — see P022 renumber rule) can be drafted with both decisions fixed. Scope: gate + advisory agent, both inside `@windyroad/tdd`.

## Description

The TDD gate enforces test *presence* and the RED→GREEN transition, but not test *content* quality. Cucumber's natural-language surface makes it easy to write `Then` steps that look like assertions but don't assert anything concrete. Example from addressr:

```gherkin
Scenario: Address detail has related links to locality, postcode, and state
  Given an address database is loaded from gnaf
  When the root api is requested
  And the "https://addressr.io/rels/address-search" link template is followed with:
    | q | UNIT 1, 19 MURRAY RD, CHRISTMAS ISLAND |
  And the 1st "item" link is followed
  And the "canonical" link is followed
  Then the address detail will have related links
```

The final `Then` asserts *that* there are related links, not *which* ones. A step definition that returns `true` whenever any link exists would pass. The scenario title promises locality, postcode, and state — the `Then` step does not verify any of them.

This class of defect passes the TDD gate silently and produces false confidence.

**Canonical framing: Example Mapping.** Cucumber's Example Mapping practice (https://cucumber.io/blog/bdd/example-mapping-introduction/) is explicit that every rule a scenario encodes must be backed by *concrete examples* — specific inputs and specific expected outputs. A vague `Then` step like "will have related links" is a rule without an example: it names the category of outcome but does not name the outcome. The correct shape for the scenario above is one `Then` step per concrete example (e.g. `Then the response has a "locality" link to "/localities/CHRISTMAS-ISLAND"`, `Then the response has a "postcode" link to "/postcodes/6798"`, etc.) or a data table listing the expected link rel + href pairs. This reframes the detection problem from "does the step contain quoted literals" (a weak proxy) to "does the step map to a concrete example that could fail if the behaviour regressed" (the actual invariant).

## Symptoms

- Gherkin scenarios with outcome steps like `Then X will have related links`, `Then the response is returned`, `Then the data is correct` pass the gate despite asserting nothing concrete.
- Scenario titles name specific outcomes (locality/postcode/state) but `Then` steps use generic language.
- Step definitions backing vague outcomes can be under-specified without any signal to the author or reviewer.
- No mechanism currently reviews test content — only test presence.

## Workaround

Manual review. Reviewers must read every `Then` step and check whether it contains concrete assertions (quoted literals, specific counts, explicit field predicates). Not scalable; easy to miss when `.feature` files are long.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-002 Ship With Confidence) — "the agent cannot bypass governance" is weakened when a vague test passes the gate
  - Tech-lead persona — BDD adoption in consulting contexts amplifies exposure
- **Frequency**: Every Gherkin scenario authored by the agent or a distracted human. Increases with adoption of Cucumber.
- **Severity**: Medium. Vague tests don't break prod directly but mask regressions and erode the discipline the gate is meant to enforce.
- **Analytics**: N/A. Observed in screenshot from addressr this session.

## Root Cause Analysis

No component of the TDD plugin inspects test *content*. The gate's scope is state machine transitions on file writes. Introducing assertion-quality review is a **new enforcement surface**, not an extension of an existing one — the architect has flagged this as ADR-worthy before implementation.

### Investigation Tasks

- [ ] Design a vague-outcome heuristic grounded in Example Mapping. Primary signal: does each `Then` step correspond to a concrete example (specific input → specific expected output), or is it a rule stated in the abstract? Candidates: (a) structural — `Then` steps must contain at least one quoted literal, number, data-table row, or doc-string reference that names the expected value; (b) semantic — step definition body must reference a named captured value from the step text (no "hidden" assertions against implicit context); (c) LLM review — a specialist agent classifies each `Then` step as rule-with-example vs rule-without-example using the Example Mapping frame
- [ ] Decide enforcement level: blocking gate vs advisory agent output. The gate is synchronous and deterministic; an LLM review is neither
- [ ] Decide placement: part of `@windyroad/tdd` or a new `@windyroad/test-quality` plugin
- [ ] Draft ADR — candidate `docs/decisions/012-test-content-quality-review.proposed.md` — covering: which heuristic, blocking vs advisory, where it lives, what the escape hatch looks like
- [ ] Create reproduction fixtures: a `.feature` file with the addressr-style vague `Then` step, and a good/bad pair for each heuristic candidate

## Related

- Split from original P013 (combined ticket) — see P016 for the meta concern
- Sibling: `docs/problems/013-tdd-feature-file-classifier.open.md` — classifier gap
- Trigger example: addressr Gherkin scenario (screenshot this session)
- Canonical reference: Cucumber Example Mapping — https://cucumber.io/blog/bdd/example-mapping-introduction/
- Architect note: new enforcement surface → ADR required before implementation
- ADR 002 (proposed): `docs/decisions/002-monorepo-per-plugin-packages.proposed.md` — may influence new-plugin vs extend-existing decision
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md`
- JTBD-101: `docs/jtbd/plugin-developer/JTBD-101-extend-suite.proposed.md` — if this becomes a new plugin
