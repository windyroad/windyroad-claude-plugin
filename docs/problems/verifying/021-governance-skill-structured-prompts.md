# Problem 021: Governance-skill decision prompts must be structured (AskUserQuestion + plan mode), not prose — silent below appetite

**Status**: Verification Pending
**Reported**: 2026-04-16 (generalised 2026-04-16 from risk-scorer-only to cross-skill pattern)
**Priority**: 12 (High) — Impact: Moderate (3) x Likelihood: Likely (4)
**Effort**: M
**WSJF**: 12.0 — (12 × 2.0) / 2

## Description

Governance skills and agents in this suite present decision prompts as free-text prose ("Your call: accept X, or take N hour for remediations", "Options: (a) X, (b) Y, (c) Z — which?") instead of using the `AskUserQuestion` tool (and, where appropriate, plan mode) to produce structured, auditable exchanges. The failure mode is repeated across multiple skills.

**Instances observed:**

1. **Risk-scorer (pipeline mode) — below appetite.** Asks "do you want to accept the risk?" even when residual is at or below the appetite threshold. RISK-POLICY.md is explicit (lines 30-36): "Pipeline gates block when cumulative residual risk exceeds 4. Very Low (1-2) and Low (3-4) risk changes proceed without intervention." Accepting risk is only semantically meaningful when residual **exceeds** appetite. Below appetite, the release is pre-authorised by policy, so an accept-risk prompt is redundant (nothing to authorise), misleading (implies a choice the user doesn't have — they can't meaningfully "reject"), and friction (empty ceremonial step). Session evidence: residual 3 (Low, within appetite 4), agent still prompted "accept the risk?".

2. **Risk-scorer (pipeline mode) — above appetite.** Output is free-text "Your call: accept X/25 explicitly and merge, or take the N hour for the remediations" — unstructured, hard to automate against, forces the user to parse prose and decide between accept-or-remediate in their head.

3. **manage-problem skill (`work` mode).** When re-ranking surfaced a WSJF tie and an architect-expanded scope on P019, the skill presented "Options: (a) continue P019 as expanded, (b) update P019 and re-run work, (c) pick a different tier-6 problem — which way?" as prose. Should have been an `AskUserQuestion` with the three options as structured choices. (This session, 2026-04-16, on the second tie-break turn.)

**The correct shape, universally:**
- Below appetite / policy-authorised: proceed silently. No prompt at all.
- Above appetite / requires user decision: automatically enter plan mode to draft concrete remediations or options, and use `AskUserQuestion` to collect the decision. Structured, auditable, machine-readable.
- Every governance-skill branch point with ≥2 mutually exclusive options must be an `AskUserQuestion` call, never a prose "(a)/(b)/(c)" paragraph.

## Symptoms

- Risk-scorer (pipeline mode) emits an accept-risk prompt on every assessment, regardless of residual vs appetite.
- Users habituate to dismissing the prompt → when a real above-appetite case arrives, the dismissal reflex may misfire.
- Assessments that should take < 60s (per JTBD-001 outcome) are padded with an empty decision step.
- The screenshot from this session shows residuals at 3, 3, 3 with verdict "accept appetite threshold of 4" — immediately followed by "Your call: accept 3/25 explicitly and merge, or take the 1 hour for the two remediations to bring it into appetite" — but it's already IN appetite.
- Above-appetite outputs use free-text "Your call:" prose instead of structured tooling. No planning mode entry, no `AskUserQuestion` for clarifications, no machine-readable remediation list. Auditing above-appetite decisions requires parsing English.
- **manage-problem (`work` mode)** presents WSJF tie-breaks and scope-change decisions as prose "(a)/(b)/(c)" option lists in plain markdown — user cannot click-select, cannot be captured as a structured answer, and the skill cannot branch cleanly on the reply.
- Any prose decision prompt across the suite is untyped (no header, no option chips), unauditable (no structured record of what was offered vs chosen), and not composable with non-interactive runs (CI, scheduled triggers, scripted invocations).

## Workaround

User manually dismisses the prompt. Friction, not harm.

## Impact Assessment

- **Who is affected**:
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — prompt friction directly violates "speed without sacrificing quality" and the under-60-second outcome target.
  - Tech-lead persona — repeated empty prompts erode trust in the governance surface.
  - Any user of `wr-risk-scorer` on a low-risk release path — most releases should be Very Low / Low and should therefore pass silently.
- **Frequency**: Every pipeline assessment where residual is within appetite — which per policy framing should be the common case. Expected to fire most of the time.
- **Severity**: Medium. Friction, not correctness. The gate still works. But compounding friction erodes adoption.
- **Analytics**: Observed this session — addressr v0.23.4 release risk assessment, residual 3/25 (Low), verdict "Below appetite threshold of 4", still asked "Your call: accept 3/25 explicitly and merge…" See Image #3.

## Root Cause Analysis

**Shared root cause (cross-skill): no suite-wide rule that governance-skill decision prompts must be structured.** Each skill/agent author falls back to prose prompts because there is no documented standard requiring `AskUserQuestion` + plan mode, and no review gate (architect, hooks, or lint) catches prose decision prompts before release. The pattern re-emerges in every new governance skill.

**Risk-scorer-specific contributors (confirmed via source 2026-04-16):**
1. **Scorer agents are already output-only.** `pipeline.md`, `wip.md`, `plan.md` all have `tools: [Read, Glob]` and emit structured blocks (`RISK_SCORES`, `RISK_VERDICT: below-appetite|CONTINUE|PASS|FAIL`, `RISK_BYPASS`). The agents themselves do NOT emit "Your call:" prose — they are correctly pure scorers.
2. **The prose comes from the PRIMARY AGENT interpreting scorer output.** When the PostToolUse hook reads the scorer's verdict and the primary agent presents the result to the user, there is no skill or instruction telling the primary to use `AskUserQuestion` for above-appetite cases or to stay silent for below-appetite. The primary falls back to conversational prose.
3. **No skill exists between scorer output and user decision.** The calling context (hooks → primary agent) has no structured instruction for presenting risk decisions. This is where the ADR-013 pattern belongs — the skill or hook that wraps the scorer should own the `AskUserQuestion` call.
4. **Acceptance is conflated with acknowledgement.** Below appetite, the user needs no acceptance (policy-authorised). The primary agent treats both cases identically because nothing tells it not to.
5. **No self-check against RISK-POLICY.md framing.** The policy says "proceed without intervention" below 4, but no instruction enforces that in the primary agent's output shape.

**manage-problem-specific contributors (confirmed via source 2026-04-16):**
5. **Skill already grants `AskUserQuestion`** (frontmatter `allowed-tools`) and uses it at 3 decision points: duplicate detection (step 2), data gathering (step 4), and pending verification (step 9d). But it does NOT mandate `AskUserQuestion` for: WSJF-tie "which problem to work next" (step 9c → work), scope-change "continue / re-run / pick different", or recommendation hand-offs. The primary falls back to prose for these un-specified branches.
6. **manage-incident (ADR-011) is the positive example.** It uses `AskUserQuestion` at every decision branch including hypothesis evidence validation and problem-creation optionality. The gap is specific to manage-problem's `work` and `review` flows.
7. **No explicit step for "present the review result and ask which problem to work"** — the skill describes the ranking and the work loop but leaves the hand-off to the user's choice unspecified.

### Investigation Tasks

**Cross-cutting (decide the pattern once):**

- [x] **Drafted ADR-013**: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md`. Covers 6 rules: AskUserQuestion mandatory at branch points, agents stay pure, skills own interaction, plan mode for multi-step remediations, policy-authorised silence, non-interactive fail-safe. Architect-reviewed and PASS.
- [x] Architect-preferred split (Option B) confirmed by source: scoring agents are already pure (`tools: [Read, Glob]`, structured output only). The calling skill (or primary agent) must own `AskUserQuestion` + plan mode. No tool-grant expansion needed on scorer agents.
- [x] Define the machine-readable remediation/options marker format. Expanded to 5 columns: `id | description | effort (S/M/L) | risk_delta (-N) | files_touched` in `pipeline.md`, `wip.md`, and `plan.md`. Guarded by `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats` (11 tests).
- [x] Establish a review gate that catches prose decision prompts before release — `manage-problem-no-prose-options.bats` (P021 guard) added and `package.json` test script extended to `packages/*/skills/*/test/` so skill tests run in CI alongside hook tests.

**Risk-scorer-specific:**

- [x] Inspected risk-scorer agent prompts (`pipeline.md`, `wip.md`, `plan.md`). All are `tools: [Read, Glob]` and emit structured `RISK_SCORES`/`RISK_VERDICT`/`RISK_BYPASS` blocks. No "Your call:" or accept-or-remediate prose in the agent templates. The prose originates in the primary agent's unguided interpretation of scorer output.
- [x] Added "Below-Appetite Output Rule" to `pipeline.md`: when all scores ≤ appetite, emit ONLY the report structure + RISK_SCORES + RISK_BYPASS. No advisory prose, no suggestions, no "Your call:". References ADR-013 Rule 5.
- [x] Added "Above-Appetite Remediations" to `pipeline.md`: replaced "Suggested Actions" + "Downstream Back-Pressure" with structured `RISK_REMEDIATIONS:` block. Machine-readable format for future P020 wrapping skill.
- [x] Applied same pattern to `wip.md`: below-appetite = assessment table + CONTINUE only; above-appetite = structured `RISK_REMEDIATIONS:` block + PAUSE.
- [x] Applied same pattern to `plan.md`: PASS = no advisory prose; FAIL = structured `RISK_REMEDIATIONS:` block. Added ADR-013 Rule 5 reference.
- [x] Checked wip.md and plan.md — same pattern. All three scorer modes are output-only (`RISK_VERDICT: CONTINUE|PAUSE|PASS|FAIL`). No decision prompts in any scorer agent.
- [ ] Update `RISK_SCORES:` / `RISK_VERDICT:` / `RISK_BYPASS:` marker contract (if needed) so the commit-gate hook distinguishes silent-pass from bypass-reducing from above-appetite-needs-remediation. (Deferred to P020 — hook parser for `RISK_REMEDIATIONS:` not needed until a wrapping skill exists.)
- [x] Decided: plan-mode entry and `AskUserQuestion` live in the calling skill per ADR-013 Rule 3. P020 (`/wr-risk-scorer:assess-release`) will own the orchestration. Hooks stay as-is (gate logic only).

**manage-problem-specific:**

- [x] Amended `packages/itil/skills/manage-problem/SKILL.md`: step 9c now requires `AskUserQuestion` for WSJF-tie and single-top-problem selection; "Working a Problem" section now requires `AskUserQuestion` for scope-change decisions. Includes explicit prohibition on prose "(a)/(b)/(c)" prompts.
- [x] Audited the skill for prose-option moments. Remaining `AskUserQuestion` usages (duplicate check step 2, data gathering step 4, pending verification step 9d) were already structured. No additional gaps found.
- [x] Add a BATS or doc-lint test that fails if the skill contains prose option patterns like `Options: (a)` or `which would you like` without a preceding `AskUserQuestion` reference. — `packages/itil/skills/manage-problem/test/manage-problem-no-prose-options.bats` (6 tests, all GREEN — 2 new regression guards for WSJF tie-break and scope-change AskUserQuestion mandates added 2026-04-16)

**Reproduction evidence (manual — automated tests deferred to P012 skill testing harness):**

- [x] Risk-scorer below-appetite prose: Image #3 this session — residual 3, "Your call: accept 3/25 explicitly and merge..."
- [x] manage-problem prose option prompt: Image #4 this session — "(a)/(b)/(c)" WSJF tie-break as plain markdown
- [x] Automated (structural proxy): Risk-scorer residual 3 → `pipeline.md` defines "Below-Appetite Output Rule" prohibiting advisory prose. Guarded by `risk-scorer-structured-remediations.bats` test 4.
- [x] Automated (structural proxy): Risk-scorer residual 6 → `pipeline.md` defines structured `RISK_REMEDIATIONS:` with 5-column format. Guarded by `risk-scorer-structured-remediations.bats` tests 1-3.
- [x] Automated: manage-problem WSJF tie → `SKILL.md` mandates `AskUserQuestion` for work-next selection. Guarded by `manage-problem-no-prose-options.bats` test 5.

## Fix Released

All active investigation tasks complete as of 2026-04-16. Deployed in current `@windyroad/itil` and `@windyroad/risk-scorer` packages:
- `pipeline.md`, `wip.md`, `plan.md`: structured 5-column `RISK_REMEDIATIONS:` format defined; Below-Appetite Output Rule enforced
- `manage-problem` SKILL.md: `AskUserQuestion` mandated for all decision branches
- `packages/risk-scorer/agents/test/risk-scorer-structured-remediations.bats`: 11 structural tests (GREEN)
- `packages/itil/skills/manage-problem/test/manage-problem-no-prose-options.bats`: 6 tests (GREEN)
- Deferred: `RISK_SCORES` marker contract update — remains deferred to P020 (hook parser not needed until assess-release skill wraps it)

Awaiting user verification that governance skills no longer emit unstructured "Your call:" prose.

## Related

- `RISK-POLICY.md` lines 28-36 — authoritative appetite framing ("proceed without intervention")
- `packages/risk-scorer/agents/pipeline.md`, `plan.md`, `wip.md`, `agent.md`, `policy.md` — agent prompt templates (primary fix location); currently tool-restricted to `Read + Glob`
- `packages/risk-scorer/skills/update-policy/SKILL.md` — only existing risk-scorer surface with `AskUserQuestion` grant; pattern reference if Option A is chosen
- `packages/risk-scorer/hooks/plan-risk-guidance.sh` — reacts to EnterPlanMode but does not trigger it
- Related: `docs/problems/020-on-demand-assessment-skills.open.md` — any on-demand assessment skill wrapping risk-scorer must inherit the corrected prompt shape AND may be the natural home for above-appetite orchestration (Option B)
- Related: ADR-011 `docs/decisions/011-manage-incident-skill.proposed.md` — nearest neighbour for the structured-interaction ADR; should adopt the same convention
- Candidate new ADR: `docs/decisions/013-structured-user-interaction-for-governance-decisions.proposed.md` (architect flagged — cross-cutting pattern, generalised to all governance skills)
- `docs/BRIEFING.md` — notes that risk-scorer agents have no Bash tool and output structured markers
- Session evidence: Image #3 showing residual 3 with accept-risk prompt
- Session evidence: Image #4 showing manage-problem `work` mode presenting "(a)/(b)/(c)" prose instead of `AskUserQuestion`
- JTBD-001: `docs/jtbd/solo-developer/JTBD-001-enforce-governance.proposed.md` — "governance without slowing down"; under-60-second outcome target
- JTBD-002: `docs/jtbd/solo-developer/JTBD-002-ship-with-confidence.proposed.md` — "the agent cannot bypass governance"; structured remediation strengthens this
- `packages/wr-itil/skills/manage-problem/SKILL.md` — manage-problem skill with unstructured decision branches
