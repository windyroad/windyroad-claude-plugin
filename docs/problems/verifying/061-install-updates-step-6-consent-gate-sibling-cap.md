# Problem 061: `install-updates` Step 6 consent-gate contract violates the AskUserQuestion 4-option cap when sibling count > 3

**Status**: Verification Pending
**Reported**: 2026-04-20
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S — edit `.claude/skills/install-updates/SKILL.md` Step 6 to document a grouping fall-back when siblings > 3
**WSJF**: 4.0 — (4 × 1.0) / 1

## Description

`.claude/skills/install-updates/SKILL.md` Step 6 defines the consent gate as:

> Invoke `AskUserQuestion` with **one question, multiSelect=true**:
> - `header: "Install targets"`
> - `question: "Which projects should receive the updated plugins? Detected siblings below. Current project is always included."`
> - Options: one per detected sibling name, plus a `"Dry-run — show the plan but don't install"` option.

The `AskUserQuestion` tool constrains each question to `minItems: 2, maxItems: 4`. With 5 detected siblings + the dry-run option, Step 6's "one option per sibling" contract requires 6 options — over the cap by two.

Observed 2026-04-20 end-of-session `/install-updates` invocation: this repo has 5 sibling projects with windyroad plugins (`addressr-mcp`, `addressr-react`, `addressr`, `bbstats`, `windyroad`). Step 6 could not be executed per the written contract; the operator grouped options into `All 6 projects (Recommended) / Current project only / Dry-run` to stay inside the 4-option cap, with the `Other` affordance available for a custom subset.

The contract is silent on what to do when sibling count > 3. Future operators may diverge in their grouping choices, or freeze on the contract violation. This is a bounded documentation gap with a bounded fix.

## Symptoms

- `AskUserQuestion` tool rejects a Step 6 invocation that follows the written contract when sibling count > 3.
- Operator ad-hoc grouping (as in the 2026-04-20 observation) works but is not guided by the contract — divergence across invocations is likely.
- The `"Other" — provide custom text` affordance (auto-provided by `AskUserQuestion`) covers the subset-selection use case, but the contract does not mention it, so future operators may not reach for it.

## Workaround

Group siblings into meaningful buckets manually: e.g. `All confirmed / Current only / Dry-run / Other`. `Other` lets the user name a custom subset in free text.

## Impact Assessment

- **Who is affected**: anyone invoking `/install-updates` in a workspace with > 3 sibling windyroad projects. Currently: this repo (5 siblings).
- **Frequency**: every invocation where the sibling count exceeds 3. For this repo's current layout, every invocation.
- **Severity**: Minor — the skill still works via operator grouping; the audit trail just becomes less uniform across invocations. No data loss, no security implication.
- **Analytics**: one observation (2026-04-20 end-of-session invocation).

## Root Cause Analysis

### Structural

The Step 6 contract was written without accounting for the `AskUserQuestion` cap. ADR-030's Confirmation lists the consent gate as a required first action but does not specify how to express the consent when the natural option count exceeds the tool's cap.

### Fix strategy

Amend SKILL.md Step 6 to describe a grouping fall-back when sibling count > 3. Suggested wording:

> When the combined sibling + dry-run count exceeds `AskUserQuestion`'s 4-option cap, group into:
> 1. `All <N> projects (Recommended)` — install across current + every detected sibling
> 2. `Current project only` — skip all siblings
> 3. `Dry-run — show the plan`
> 4. The auto-provided `Other` affordance covers custom subsets; encourage the user to name siblings inline.
>
> When sibling count ≤ 3, use the original contract (one option per sibling + dry-run) — the 4-option cap is not reached.

No ADR change needed; this is a Step 6 clarification within ADR-030's existing Confirmation.

### Affected files

- `.claude/skills/install-updates/SKILL.md` — Step 6 amendment.
- Optional: `.claude/skills/install-updates/test/install-updates-consent-gate-grouping.bats` — doc-lint assertion that Step 6 describes the > 3-sibling grouping path.

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20 end-of-session `/install-updates`; 5 siblings detected, operator had to group.
- [ ] Decide whether the grouping wording matches what operators should do. The suggested wording preserves the core choice (everywhere / current-only / dry-run / custom) and maps cleanly to the 4-option cap.
- [ ] Apply the Step 6 amendment.
- [ ] Optional: add bats doc-lint regression asserting the grouping language is present.

## Fix Released

Shipped 2026-04-20 (AFK iter 6 iter 6, commit pending).

- `.claude/skills/install-updates/SKILL.md` Step 6 — amended to describe two shapes. For sibling count ≤ 3 the original contract applies (one option per sibling + dry-run). For sibling count > 3 a grouping fallback kicks in: exactly 4 options (`All <N> projects (Recommended)` / `Current project only` / `Dry-run — show the plan but don't install` / auto-provided `Other — provide custom text`). Per architect advisory, the full sibling list is named in the question body text (the 4-option cap applies to options, not question description), preserving ADR-030's "list every sibling project" consent requirement.
- `.claude/skills/install-updates/test/install-updates-consent-gate-sibling-cap.bats` — NEW. 6 doc-lint structural assertions (Permitted Exception per ADR-005) verifying: fallback block presence with P061 reference, maxItems cap citation, all 4 option labels, sibling enumeration in question body, original contract preserved for ≤ 3, and the "either shape satisfies ADR-030" rationale.

Architect review PASSED (no ADR amendment needed — ADR-030's Confirmation criteria still met by either shape; ADR-013 Rule 1 maxItems cap is a tool-level constraint that the fallback correctly accommodates). JTBD review PASSED (JTBD-003 Compose Only the Guardrails I Need; solo-developer plugin-version drift pain point).

Repo-local skill per ADR-030; no npm changeset. Fix lives entirely in `.claude/skills/install-updates/` plus its `test/` sibling.

Awaiting user verification: next `/install-updates` invocation in a workspace with > 3 sibling windyroad projects (this repo qualifies — 5 siblings per the 2026-04-20 observation) should fire the grouping fallback with 4 options + the full sibling list named in the question body.

## Related

- **ADR-030** — governing decision for repo-local skills; Confirmation lists consent gate as first action. The fix sits inside the existing Confirmation criteria; no amendment required at the ADR level.
- **ADR-013 Rule 1** — `AskUserQuestion` is the sanctioned interaction surface; the 4-option cap is a Claude Code constraint, not a repo constraint. The grouping fall-back respects Rule 1 while staying inside the tool's shape.
- **`AskUserQuestion` tool schema** — enforces `minItems: 2, maxItems: 4` per question. Source of the cap.
- **P058** — the preceding install-updates correctness fix (regex digit support). Same skill, different step. No scope overlap.
- **P059** — Step 6.5 auto-migration work. Adjacent to Step 6 but different step; does not reshape the consent-gate options.
