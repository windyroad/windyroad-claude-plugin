# Problem 254: report-upstream skill has automation blocks that clamp the agent feedback signal — external-comms risk assessment is the actual protection layer

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

When you build the report-upstream capability, you put automation blocks in there, which creates undesirable friction. I want agents to freely report issues. I don't want to clamp that feedback signal. The external-comms risk assessment protects us.

Concrete surfaces where this fires (verbatim observation from `/wr-itil:work-problems` Step 4 upstream-blocked branch and `/wr-itil:report-upstream` SKILL.md Step 6):

- **`/wr-itil:work-problems` Step 4** — upstream-blocked branch MUST NOT auto-invoke `/wr-itil:report-upstream` (the SKILL contract says "Step 6 security-path branch is interactive per ADR-024 Consequences"). The AFK fallback writes a `**Upstream report pending** —` marker to the ticket's `## Related` section instead of actually invoking the report. The user sees the marker on their next interactive session and runs `/wr-itil:report-upstream` manually. This is a clamp on the feedback signal: the agent identified the external dependency, the report could have been drafted and submitted within the existing external-comms risk-scorer gate, but the contract chose deferral instead of forward motion.
- **`/wr-itil:report-upstream` SKILL.md Step 6 security-path branch** — when the classifier surfaces a security-class issue, the skill halts and requires the user to confirm before submitting. The intent is "don't leak a vulnerability publicly," but the actual protection is the external-comms risk assessment (per `wr-risk-scorer:external-comms` agent and the `external-comms-gate` marker) which already classifies security-class issues and routes them appropriately.
- **Authority hierarchy mis-stated**: ADR-024 names the report-upstream Step 6 branch as interactive on a defence-in-depth argument — "human-in-the-loop on outbound security-class reports." But ADR-028's external-comms risk-scorer is the load-bearing gate per the SKILL's own contract; the Step 6 halt is a redundant clamp.

**Audit note on type classification (added at capture time)**: Step 1.5 lexical-signal classifier matched "friction" as a user-business journey-word signal and would have classified this as `user-business` (0 technical signals + 1 user-business signal = unambiguous user-business). The agent overrode the classifier verdict to `technical` because the description's authorial intent is clearly about an agent-SKILL contract surface (`/wr-itil:report-upstream` automation gates and the `/wr-itil:work-problems` Step 4 AFK fallback), not a plugin-user / adopter persona job. "Friction" here is agent-skill-invocation friction (an internal-developer surface), not persona UX. Per the user's feedback memory `feedback_derive_classification_dont_ask.md` ("derive when description signals are clear"), the override avoids an I12 hard-block round-trip for what is clearly a maintainer-internal SKILL contract gap. Surfaces a downstream finding: the Step 1.5 lexical classifier over-weights single weak signals like "friction" outside their persona-job context; the classifier may want a minimum-confidence threshold (≥2 signals on one side) or a context-aware weighting for "friction" / "interrupt" / "attention" when the surrounding text indicates internal-developer actors rather than personas.

## Symptoms

- `/wr-itil:work-problems` Step 4 upstream-blocked branch writes a `**Upstream report pending** —` marker instead of auto-invoking `/wr-itil:report-upstream`. The marker accumulates one per iter; the user reviews them on return and runs the reports manually. Latency on outbound feedback is bounded by user session frequency, not by when the agent identified the dependency.
- `/wr-itil:report-upstream` Step 6 security-path branch halts on classifier verdict and requires interactive confirmation. The external-comms risk-scorer already has the verdict at this point; the halt re-asks a decision the framework resolved.
- Aggregate observable effect: outbound upstream-issue reports are NEVER submitted by an AFK loop. The feedback channel from windyroad-claude-plugin's dogfood findings → upstream maintainers (Claude Code, plugin marketplaces) is gated behind interactive user invocation.

(symptoms section deferred to investigation — above are verbatim observations from the capture session)

## Workaround

User manually runs `/wr-itil:report-upstream` for each pending marker on session start. Friction is real but bounded.

## Impact Assessment

- **Who is affected**: Plugin-developer persona (JTBD-101) — feedback signal to upstreams gets clamped; bug reports linger as local markers instead of becoming actionable upstream issues. Maintainer persona (JTBD-001) — relies on the upstream channel staying responsive; clamped reports mean upstream maintainers lose visibility into windyroad-driven findings.
- **Frequency**: Every AFK iter that detects an external root cause appends a pending marker. Observed rate during current session: ~4 markers across recent iters (cited surfaces P006/P010/P011/P012).
- **Severity**: (deferred to investigation)
- **Analytics**: (deferred to investigation)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next `/wr-itil:review-problems`.
- [ ] Audit ADR-024 (`/wr-itil:report-upstream` security-path interactivity) against ADR-028 (external-comms risk-scorer gate) — does the Step 6 halt add value over the risk-scorer verdict, or is it pure defence-in-depth that's clamping the feedback channel?
- [ ] Audit `/wr-itil:work-problems` Step 4 upstream-blocked branch fallback contract — should the AFK orchestrator be authorised to auto-invoke `/wr-itil:report-upstream` when the external-comms risk-scorer pre-resolves the verdict? Per ADR-013 Rule 5 (policy-authorised silent-proceed): if the risk-scorer says PASS, the orchestrator proceeds; if the scorer says BLOCK, the orchestrator falls back to the pending-marker path.
- [ ] Specify the auto-invoke contract: when does the AFK orchestrator invoke `/wr-itil:report-upstream` directly vs append the pending marker? Suggested gate: (a) external root cause identified, (b) classifier confidence above threshold, (c) external-comms risk-scorer returns PASS, (d) no security-class verdict.
- [ ] Cite the user's verbatim direction in the new ADR / SKILL amendment: *"when you build the report upstream capability, you put automation blocks in there, which creates undesirable friction. I want agents to freely report issues. I don't want to clamp that feedback signal. The external comms risk assessment protects us."*
- [ ] Composes with the sibling capture (intake-scaffold AFK auto-scaffold fail-safe — ADR-036 Rule 6) — same class of "agent-side clamp that the external-comms / risk-scorer gate already protects against."

## Dependencies

- **Blocks**: (none — pending-marker workaround keeps the channel functional, just slow.)
- **Blocked by**: (none — ADR-024 + ADR-028 + ADR-013 are all landed; this is a reconciliation of their interactions, not a new framework decision.)
- **Composes with**: sibling capture (intake-scaffold AFK auto-scaffold fail-safe — same class-of-behaviour at ADR-036 Rule 6 surface)

## Related

- `/wr-itil:report-upstream` SKILL.md Step 6 — security-path interactive branch.
- `/wr-itil:work-problems` SKILL.md Step 4 — upstream-blocked branch + AFK pending-marker fallback.
- ADR-024 — `/wr-itil:report-upstream` interactive-only Step 6 security-path branch (cited by both SKILLs as the authority for the clamp).
- ADR-028 — external-comms risk-scorer gate (the user's named protection layer).
- ADR-013 Rule 5 — policy-authorised silent-proceed (the framework principle that would authorise auto-invoke when the risk-scorer says PASS).
- ADR-044 — decision-delegation contract; this ticket frames the clamp as defensive over-asking the framework already resolved.
- P063 — `/wr-itil:manage-problem` external-root-cause detection AFK fallback (writes the pending marker); composes with this ticket's `/wr-itil:work-problems` Step 4 surface.
- P185 — `/wr-itil:capture-problem` derive-first refactor for Step 1.5 lexical classifier; the override note above surfaces a sibling finding about classifier over-weighting of single weak signals like "friction".

(captured via `/wr-itil:capture-problem`; expand at next investigation)
