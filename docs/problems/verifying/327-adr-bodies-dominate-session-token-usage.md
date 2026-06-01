# Problem 327: ADR bodies dominate session token usage — design a summary surface for routine compliance loading

**Status**: Verification Pending
**Reported**: 2026-05-30
**Fix released**: 2026-06-01 — @windyroad/architect@0.12.2 (commit 252702a, Slice 3 closer; Slices 1+2 shipped in 0.11.0/0.12.0)
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems; user signaled "highest priority because of token burn" at capture)
**Origin**: inbound-reported (relayed from other projects)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; design + summary-surface ADR + 76-ADR migration likely XL once scoped)
**Type**: technical

## Description

In adopting projects using @windyroad/architect, `docs/decisions/` ADR content dominates session token usage — often over 50% of total context. The full ADR bodies (especially **Considered Options**, **Pros and Cons of the Options**, **Consequences**, and **Reassessment Criteria**) are valuable for understanding the thinking at the time and evolving decisions later, but in a typical compliance/review session we don't need all that information — only enough to follow each decision (the chosen option + the binding constraints).

**Design question.** How might we maintain decision **summaries** (e.g. a per-ADR distilled `summary:` frontmatter field, a `docs/decisions/README.md` compendium, or a separate short-form surface) that the architect / JTBD / risk-scorer agents load by default for routine compliance review, while preserving the full ADR body for explicit deep-dive review, human ratification, and decision evolution?

**Reporter framing.** Reported by external adopters during multi-project sessions — this is an inbound report per ADR-076 (Tier 1: customer-service / feedback-signal preservation). User signal during capture: *"that's probably the highest priority issue because of the amount of token burn."*

**Goal.** Drop the architect per-edit token cost without losing the deep-context-on-demand value that the full ADR body provides.

**Scope correction (architect vet 2026-05-30).** The initial framing said "architect / JTBD / risk-scorer" — only partly correct. Only `wr-architect:agent` body-reads ADRs in the load path (`packages/architect/agents/agent.md:20`: "Read all existing decisions in `docs/decisions/`"). `wr-jtbd:agent` reads `docs/jtbd/`, not `docs/decisions/`. `wr-risk-scorer:wip` enumerates `docs/decisions/*.md` as a path-list only (governance-artefact diff-detection — not body-read). The architect agent is the **single dominant ADR-body consumer**; designing for it captures essentially all the win.

**Direction (user pick 2026-05-30): `docs/decisions/README.md` compendium.** One generated file listing every ADR's chosen option + key constraints in a compact format; architect agent loads the compendium instead of N individual ADRs for routine compliance. Direct precedent in ADR-031 (problem-ticket README-as-rendered-index). Full ADR bodies remain authoritative; the compendium is a derived/cached view kept in sync by a generator + drift detector (mirrors P138 tie-break-ladder drift pattern).

## Symptoms

- Token usage profile in adopting-project sessions shows >50% spend on `docs/decisions/` reads.
- Effect compounds in agents (architect, JTBD, risk-scorer) that fire on every project-file edit — each invocation re-loads the ADR set.
- Reported across multiple adopter sessions; not project-specific.

## Workaround

(deferred to investigation — informal candidate: agents could opportunistically read only the Decision Outcome section, but no enforced contract exists yet)

## Impact Assessment

- **Who is affected**: every adopter using `@windyroad/architect` (and indirectly `@windyroad/jtbd`, `@windyroad/risk-scorer`); developer persona JTBD-006 (AFK backlog work) and tech-lead persona JTBD-201 (restore service fast — context budget directly affects investigation depth).
- **Frequency**: every session that touches a project file — i.e. essentially every working session.
- **Severity**: High — direct degradation of usable context budget; reporter framed as "highest priority issue."
- **Analytics**: (deferred — would benefit from a token-spend profile across a representative session set)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems (user signaled "highest priority" at capture — likely re-rates to Impact 4 × Likelihood 5 = Severity 20 / Very High → ADR-076 Tier 0)
- [x] Design the summary surface — three candidate shapes: (a) per-ADR `summary:` frontmatter field; (b) `docs/decisions/README.md` compendium loaded in lieu of full bodies for routine reads; (c) separate short-form file per ADR (e.g. `<NNN>-<slug>.summary.md`). **Resolved by ADR-077: option (b) generated `docs/decisions/README.md` compendium.**
- [x] Decide which agents load the summary vs the full body — default-to-summary, fall back to full on explicit deep-dive surfaces (review-decisions drain, create-adr, capture-adr). **Resolved by ADR-077 scope correction: only `wr-architect:agent` body-reads ADRs; designed for it specifically.**
- [x] Migration path for existing 76 ADRs — auto-generate first-cut summaries from existing `## Decision Outcome` sections; human-confirm + refine opportunistically. **Resolved by Slice 1 `generate-decisions-compendium.sh` — first-cut auto-generated for all 75 ADRs (commit 846b5f2); hand-confirm folds into the existing `/wr-architect:review-decisions` drain.**
- [x] Update create-adr / capture-adr to author the summary at decision time so new ADRs are born compact. **Resolved by Slice 2 — `/wr-architect:create-adr` Step 5 + `/wr-architect:capture-adr` Step 4.5 regenerate the compendium and stage with the new ADR file (commit 9832593). Slice 3 extends to `/wr-architect:review-decisions` Step 4.5.**
- [ ] Confirm with adopters whether the proposed summary shape preserves the deep-context-on-demand value they actually use. **Deferred — post-release adopter feedback loop; tracked here for ADR-076 Tier 1 reporter follow-up.**

## Fix Strategy

ADR-077 (Generated `docs/decisions/README.md` compendium as token-cheap load surface) — shipped across three slices:

- **Slice 1** (commit 846b5f2, `@windyroad/architect@0.11.0`): agent prompt amendment loading compendium by default; `generate-decisions-compendium.sh` + `wr-architect-generate-decisions-compendium` PATH shim per ADR-049; initial generated compendium (75 ADRs, 41 KB — ~40× reduction vs full bodies). Closed Confirmation items (a) (b) (c).
- **Slice 2** (commit 9832593, `@windyroad/architect@0.12.x`): two-section format (in-force vs historical); `/wr-architect:create-adr` Step 5 + `/wr-architect:capture-adr` Step 4.5 regen-and-stage; `architect-compendium-refresh-discipline.sh` PreToolUse hook (P165 mirror) as safety net; `--check` flag on the generator. Closed Confirmation items (d) (e) (h).
- **Slice 3** (this commit): `/wr-architect:review-decisions` Step 4.5 + Step 5 stage list regen-and-stage; CI drift-detection bats (13 behavioural tests) at `packages/architect/scripts/test/generate-decisions-compendium.bats`. Closes Confirmation items (f) (g). ADR-077 prose explicitly names the per-ADR body as authoritative and the compendium as derived (item (i) holds throughout); sibling test sweep clean (item (j) holds).

All ADR-077 Confirmation items (a)–(j) green at source.

## Fix Released

Released across three slices on `@windyroad/architect` (Slice 1 → 0.11.0 commit `846b5f2`; Slice 2 → 0.12.0 commit `9832593`; Slice 3 → **0.12.2** commit `252702a`, the load-bearing closer). Current published version is `@windyroad/architect@0.13.0` (includes all three slices + P181/P339/P340). Token-load reduction (~40× on routine architect-agent compliance path) defended at three layers: skill-time regen (primary), PreToolUse commit hook (safety net), CI drift bats (audit trail). Awaiting user verification: next adopter session should observe the token-load drop on the routine architect-agent compliance path (reporter-confirmable per ADR-076 Tier 1 inbound).

## Dependencies

- **Blocks**: (none)
- **Blocked by**: (none)
- **Composes with**: P194 (ADRs accumulate forward-chronology evidence inline — decisions bucket dominates context; same family — both target the ADR-content-load-cost class)

## Related

- **P194** — sibling, decisions bucket dominates context (forward-chronology evidence accumulation angle).
- **P097** — SKILL.md files mix runtime-necessary steps with maintainer-facing rationale, bloating every skill invocation (same family at the SKILL-prose surface; this ticket is the ADR-prose surface).
- **ADR-076** — reported-first ranking tier; this ticket exercises the Tier 1 inbound path.
- **ADR-038** — progressive-disclosure pattern (SKILL.md + REFERENCE.md split); the ADR-prose analogue would be ADR-summary + ADR-body split.
- Dup-check matches (non-blocking; SKILL Step 2 contract): P030, P103, P194, P216, P248, P310, P315, P316, P148.

(captured via /wr-itil:capture-problem; expand at next investigation)
