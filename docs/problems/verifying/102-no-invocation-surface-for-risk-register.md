# Problem 102: No invocation surface creates risk register entries — `docs/risks/` stays empty after P033 scaffolding

**Status**: Verifying (fix landed 2026-04-22)
**Reported**: 2026-04-22
**Priority**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Effort**: M
**WSJF**: (15 × 1.0) / 2 = **7.5**

> Surfaced 2026-04-22 by the user during routine review of P033's Verification Pending queue: *"033 has been in verifiying for a few days, but I'm not seeing any risks created"*. Confirmed: `docs/risks/` contains only `README.md` + `TEMPLATE.md` (the P033 scaffolding) — zero `R<NNN>-*.md` files 5 days after release. P033's Fix Strategy was explicit about the design — "scaffolding only; no automation for v1; populate incrementally as risks are identified" — but the "incrementally" path has no trigger. Nothing in the current plugin suite or CLAUDE.md flow prompts the user or the assistant to write a risk file.

## Description

P033 shipped `docs/risks/README.md` (register index) and `docs/risks/TEMPLATE.md` (per-risk template) on 2026-04-17. The Fix Strategy intentionally deferred automation: *"Leave the register empty — populate incrementally as risks are identified (same philosophy as ADRs and problems)"*. Two Investigation Tasks explicitly deferred skill creation and auto-population:

- *"Decide whether risk register management belongs in the risk-scorer plugin or a new plugin — Deferred to future work. Current scaffolding is pure docs; no skill is needed for v1."*
- *"Decide whether the risk-scorer `update-policy` skill should seed the register from RISK-POLICY.md impact examples — No for v1."*

The "ADRs and problems" comparison papered over a key asymmetry: ADRs and problems have invocation surfaces (`/wr-architect:create-adr`, `/wr-itil:manage-problem`) that the assistant and the user invoke routinely during related workflows. Risks have no equivalent. The only way to create a risk file today is `Write` to `docs/risks/R<NNN>-*.active.md` by hand — a workflow that fires neither proactively (no hook, no retro step, no pipeline integration) nor on user prompt (no slash command). Result: the register is empty despite the project carrying real standing risks surfaced in recent sessions (confidential-info leakage via public-repo push, session-wide context budget, subprocess Edit permission denial, governance-hook stack overhead, mutation-test flakiness, and others).

## Symptoms

- `docs/risks/` contains 2 files (`README.md`, `TEMPLATE.md`), 0 `R`-prefixed risk files (confirmed 2026-04-22, 5 days after P033 release)
- `RISK-POLICY.md` describes "Severe" examples (malicious/broken bin scripts, leaked npm auth tokens) that match the register's risk definition but are not captured in the register
- Pipeline risk reports (e.g., this session's Layer 2 confidential-info scan at Risk 1) identify standing risk shapes but have no back-channel to the register
- The user expected risks to accumulate organically and observed the absence

## Workaround

None automatic. Manual workflow: `Write` a file to `docs/risks/R<NNN>-<kebab-title>.active.md` by hand for each identified risk, using `TEMPLATE.md` as the source. No invocation surface exists today to make this routine.

## Impact Assessment

- **Who is affected**:
  - Tech-lead persona — auditability gap. ISO 27001 audit expects a populated, reviewed register; an empty register signals "risk management not exercised" even when per-change scoring is active.
  - Solo-developer persona (JTBD-001 Enforce Governance Without Slowing Down) — can't see standing risks at a glance; risks live as tribal knowledge across problem tickets, `BRIEFING.md`, and ephemeral `.risk-reports/`.
- **Frequency**: Every session. No mechanism fires risk-file creation, so the gap compounds.
- **Severity**: Moderate. The risk-scorer pipeline still works for per-change scoring; the gap is in persistent-risk inventory. Moderate on auditability; low on immediate operational impact.
- **Analytics**: 5-day empty-register window observed 2026-04-22. Baseline: 0 risk files created since P033 scaffolding landed.

## Root Cause Analysis

### Confirmed Root Cause

P033's fix was lean scaffolding with deferred automation. The "populate incrementally" plan assumed organic adoption (analogous to ADRs and problems), but those surfaces have invocation routes that trigger use — slash commands (`/wr-architect:create-adr`, `/wr-itil:manage-problem`) invoked both proactively by the assistant during related workflows and directly by the user. Risks have no such surface. Without an invocation route, there's no reason for risks to be written.

### Investigation Tasks

- [ ] Decide fix shape. Candidates:
  - (a) **New slash command** `/wr-risk-scorer:manage-risk` — CRUD skill analogous to `/wr-itil:manage-problem` for risk files (create/update/transition active → accepted → retired, WSJF-equivalent ranking where relevant).
  - (b) **Risk-scorer integration** — when `wr-risk-scorer:pipeline` identifies a novel risk shape during per-change scoring (e.g. "confidential-info leakage via public-repo push"), prompt to create or update a matching register entry. Back-channel from ephemeral `.risk-reports/` to persistent `docs/risks/`.
  - (c) **Retro step** — add to `/wr-retrospective:run-retro` a "risks-observed-this-session" capture step, analogous to Step 4b's codification-candidates table.
  - (d) **CLAUDE.md workflow rule** — mandate that the assistant proposes a risk-register entry whenever a pipeline risk scoring identifies an above-appetite residual.
  - (e) **Combination** of the above.
- [ ] Architect review to decide whether this warrants an ADR (new skill, new integration pattern, or amendment of existing ADR-026 risk-scorer-grounding).
- [ ] Draft initial risks based on already-identified shapes: confidential-info leakage, session context budget (P091), subprocess permission denial (surfaced iteration 1 2026-04-22), governance-hook stack overhead (P091 cluster), mutation-test flakiness. Use existing evidence (`RISK-POLICY.md` examples + recent `.risk-reports/`) as source material.

### Fix Strategy

**Landed 2026-04-22 (iteration 3 of `/wr-itil:work-problems` AFK session).**

Implemented candidate (a) from the Investigation Tasks, scoped to CREATE-only as the minimum-viable invocation surface:

1. **New skill `/wr-risk-scorer:create-risk`** — `packages/risk-scorer/skills/create-risk/SKILL.md`. Modeled verbatim on `/wr-architect:create-adr` (guided creation; `AskUserQuestion` for user input; origin-max ID collision check per ADR-019; writes `docs/risks/R<NNN>-<kebab-title>.active.md`; auto-derives ID, date, and category where unambiguous; pulls impact/likelihood scales from `RISK-POLICY.md`; updates register table in `docs/risks/README.md`; commits per ADR-014 with `docs(risks): open R<NNN>` message).
2. **Seeded R001** — `docs/risks/R001-confidential-info-leak-via-public-repo-push.active.md`. First populated risk; proves the pattern + the register is non-empty on close. Inherent 12 (High), Residual 9 (Medium), Treatment Mitigate, owner plugin-maintainer.
3. **Register index updated** — `docs/risks/README.md` Register table gains an R001 row.

### Verification

- [ ] Invoke `/wr-risk-scorer:create-risk` in a real session and observe it creates a well-formed `R<NNN>-*.active.md` file.
- [ ] Confirm the README register table stays in sync after a second risk is added.
- [ ] Observe whether the register actually gets populated in subsequent sessions (non-empty register in 30 days is the acceptance signal).

### Explicitly out of scope for this fix (follow-ups)

- **Passive trigger** (candidates b/c/d from Investigation Tasks) — tracked in **P110** (opened 2026-04-22). JTBD review flagged that slash-command-only invocation partially satisfies JTBD-001 (solo-developer: Enforce Governance Without Slowing Down) because it still depends on the assistant remembering to invoke. Needs hook-driven integration in one of: risk-scorer pipeline back-channel, retro step, or CLAUDE.md workflow rule.
- **Lifecycle transitions** (`active → accepted → retired`) — no skill yet; manual `git mv` per `docs/risks/README.md` "How to Review" suffices until the register has ~5+ entries. Follow-up ticket can be opened at that point.
- **Additional seeded risks** (session context budget, subprocess permission denial, governance-hook stack overhead, mutation-test flakiness) — can be added via the new skill as the user encounters them; a single-seed was enough to validate the pattern and unblock P033's verification path.

## Dependencies

- **Blocks**: (none directly; closing this ticket unblocks meaningful verification of P033's scaffolding — verification today is "does empty scaffolding match intent?" rather than "does the populated register serve the audit?")
- **Blocked by**: (none)
- **Composes with**: P033, P034

## Related

- **P033 (No persistent risk register for ISO 31000 / ISO 27001 compliance)** — parent. Verification Pending; its Fix Strategy explicitly deferred the population mechanism to "future work" on two Investigation Tasks. This ticket captures the deferred work as a concrete follow-up.
- **P034 (Centralise risk reports for cross-project skill improvement)** — sibling. About centralising ephemeral `.risk-reports/`; complementary to this ticket's standing-register work. If the risk-scorer pipeline gains a back-channel (Investigation Task (b)), it may feed both persistent risks (this ticket) and centralised reports (P034).
- **`RISK-POLICY.md`** — defines impact/likelihood scales and appetite; current source of implicit risks that aren't yet registered.
- **`docs/risks/README.md`** and **`docs/risks/TEMPLATE.md`** — the P033 scaffolding; this ticket's fix populates or feeds them.
- **ADR-026 (Risk-scorer grounding)** — may need amendment if Investigation Task (b) lands (back-channel from pipeline reports to register).
