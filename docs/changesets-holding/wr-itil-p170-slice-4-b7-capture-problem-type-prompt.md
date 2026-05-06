---
"@windyroad/itil": minor
---

P170 / ADR-060 Phase 1 Slice 4 B7.T3 — `/wr-itil:capture-problem` type-tag classification prompt (item 8c)

The `/wr-itil:capture-problem` skill gains a new Step 1.5 that classifies new problem captures as `type: technical | user-business` per ADR-060's uniform problem ontology invariant (I2). The classification is one AskUserQuestion (taste authority per ADR-044 category 5) — NOT a control-flow branch. Steps 0-7 of the skill execute identically regardless of the chosen type value; only the substituted value in the Step 4 skeleton template's `**Type**:` body field differs.

**SKILL.md changes** (`packages/itil/skills/capture-problem/SKILL.md`):

- **Rule 6 audit table** updated: from "zero AskUserQuestion branches" to "one classification-only AskUserQuestion (type-tag, taste authority per ADR-044 category 5) and zero control-flow branches keyed on the answer". New audit-table row documents the type-classification carve-out + JTBD-301 protection + I2 invariant guard.
- **Step 1** extended to recognise leading caller-side flags: `--type=technical`, `--type=user-business`, `--no-prompt`. Recognised flags pre-resolve `type_value` and skip Step 1.5's AskUserQuestion (silent-proceed per ADR-013 Rule 5). Unknown leading flags halt-with-stderr-directive.
- **New Step 1.5** (Type classification, taste authority per ADR-044 category 5): three-arm dispatch (`--type=` value | `--no-prompt` defaults to `technical` | interactive AskUserQuestion). Per-option descriptions provide plain-language guidance. Inline I2 invariant guard names the no-control-flow-branch contract.
- **Step 4 skeleton template** carries `**Type**: <type_value>` after `**Effort**:`, matching the body-bullet schema per ADR-060 line 91.
- **Composition table** extended with two new rows: type-tag prompt (Step 1.5 vs manage-problem's Step 4-equivalent) + AskUserQuestion authority (one classification-only fire vs multiple branches).
- **Related section** extended with P170, P176, ADR-060, JTBD-301, and the i2-no-type-branching bats fixture pointer.

**AFK orchestrator protection (JTBD-006)**:

The `--no-prompt` flag (defaults to `technical`) and `--type=<value>` flag pre-resolve the type classification without requiring AskUserQuestion. AFK orchestrators MUST pass one of these flags per JTBD-006 § Persona Constraints — the skill's caller-side contract. Defence-in-depth: even though AFK orchestrators currently forbid invoking `capture-*` skills mid-loop per ADR-032 carve-out + the iteration prompt's "DO NOT invoke capture-* background skills" constraint, the flags exist so any future programmatic caller (CI, automated triage) has a non-interactive path.

**JTBD-301 protection (plugin-user no-pre-classification)**:

The Step 1.5 prompt fires on the maintainer-side `/wr-itil:capture-problem` skill ONLY. The plugin-user-side intake (`.github/ISSUE_TEMPLATE/problem-report.yml`) carries no equivalent type selector and is NOT touched by this slice. Triage assigns `type` during `/wr-itil:manage-problem` ingestion of user-reported issues, not at user-report time. Per ADR-060 line 132 + line 160 (Confirmation criterion 4): "the type-tag prompt fires on maintainer-side `/wr-itil:capture-problem` only; plugin-user-side intake (GitHub issue templates) MUST NOT add a type-tag selector".

**I2 invariant preservation (ADR-060 line 98)**:

- **Pure-bash supporting-script subset**: PASSED — `i2-no-type-branching.bats` (9 tests) green after this change. The SKILL.md edit does not modify any pure-bash script's behaviour, so the bats outcome is structurally unaffected (verified locally).
- **SKILL.md agent-driven surface**: deferred to P176 per ADR-052 § Surface 2 escape-hatch contract. The I2 invariant guard at the new Step 1.5 is audit-trailed prose, not a behavioural test fixture; behavioural enforcement awaits the P012 master harness. P176 captures the gap as first-class WSJF-ranked entity (not silent-deferral).

**ADR-060 § Confirmation criterion status post-Slice-4-B7.T3**:

- Criterion 4 (type prompt maintainer-side only with JTBD-301 protection): PASSED — Step 1.5 placement + JTBD-301 scope guard prose in-skill.
- Criterion 8 (I2 load-bearing enforcement): pure-bash subset PASSED via 8d bats; SKILL.md surface deferred to P176 (named, audit-trailed).

**JTBD impact**:

- **JTBD-001** (governance enforcement, extended scope) — change-set-level governance composes correctly: classification facet, single prompt per capture, no workflow split.
- **JTBD-006** (AFK orchestrator) — protected via `--no-prompt` / `--type=<value>` flags; AFK callers control the silent-proceed path.
- **JTBD-101** (atomic-fix-adopter) — friction bounded: ≤ 1 keypress in interactive context (default `technical` accepts via Enter); zero keypresses in non-interactive context (`--no-prompt`). Reassessment criterion at ADR-060 line 183 (JTBD-101 amendment drift) is the tripwire if proportionality fails.
- **JTBD-301** (plugin-user no-pre-classification) — protected: maintainer-side scope guard at Step 1.5; user-side intake unchanged.

**Out of scope (deferred to subsequent slices)**:

- Slice 5 forward dogfood (RFC-002 captured before commit-1 + run to closure) — closes architect finding 14 bootstrap-circularity.
- Slice 6 graduate-to-adopters (counterfactual risk assessment + held-window reinstate + 30-day denial-rate tracking).

Held-changeset window remains paused per ADR-060 § Confirmation criterion 6 until RFC-001 reaches `closed` post-Slice-5 forward-dogfood. This held entry sits adjacent to its B7.T2 + B7.T4 sibling (`wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md`) per architect finding 8 ("one commit advances at most one bounded sub-task") + ADR-014 single-purpose grain. Held-window atomicity contract (ADR-060 architect finding 12): the entire RFC-001 chain — including this entry — graduates together or not at all.
