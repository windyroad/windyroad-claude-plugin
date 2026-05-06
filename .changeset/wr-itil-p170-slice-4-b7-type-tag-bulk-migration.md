---
"@windyroad/itil": minor
---

P170 / ADR-060 Phase 1 Slice 4 B7 — type-tag schema bulk migration + I2 load-bearing behavioural test (items 8b + 8d)

The `@windyroad/itil` plugin gains the `**Type**: technical | user-business` field on problem-ticket frontmatter per ADR-060's uniform problem ontology invariant (I2). Existing maintainer tickets bulk-migrate to the default `technical` value via a one-shot script; the I2 invariant is enforced behaviourally by a load-bearing bats fixture per ADR-051 + architect finding 2.

**New scripts**:

- **`packages/itil/scripts/migrate-problems-add-type.sh`** — bulk migration apparatus. Diagnose-mode default (read-only; exit 1 on drift); `--apply` writes `**Type**: technical` after the last present body field marker (Status / Reported / Priority / Effort / WSJF). Idempotent — re-running with Type already present is a no-op. One-shot maintainer tool for adopters who want to migrate their own `docs/problems/` to the type-tag schema (parity with this repo's Phase 1 Slice 4 B7 migration).

- **`packages/itil/scripts/test/migrate-problems-add-type.bats`** — script-level bats per ADR-005 (280 lines). Covers diagnose default, `--apply` mode, idempotency, exit-code contract, malformed-ticket SKIP behaviour.

- **`packages/itil/scripts/test/i2-no-type-branching.bats`** — load-bearing I2 behavioural test (320 lines) per ADR-060 architect finding 2 ("I2 needs load-bearing behavioural test, not prose prohibition"). Asserts no pure-bash supporting script branches on the `type` field by running scripts (`reconcile-readme.sh`, `update-problem-rfcs-section.sh`, `classify-readme-drift.sh`, `reconcile-rfcs.sh`, `migrate-problems-add-type.sh`) against twin synthetic ticket-set fixtures (one `type: technical`, one `type: user-business`) and asserting observable outputs (stdout / exit code / file mutations) are isomorphic.

**SKILL.md surface coverage gap (named, not silent)**:

The i2-no-type-branching bats covers pure-bash supporting scripts only. Behavioural enforcement of I2 on the agent-driven SKILL.md surface (`/wr-itil:capture-problem`, `/wr-itil:manage-problem`, `/wr-itil:work-problems`, `/wr-itil:review-problems`, `/wr-itil:transition-problem(s)`) requires a skill-invocation harness that doesn't exist yet. The gap is captured as `P176` (descendant of P012 master harness ticket) with audit-trail citation per ADR-052 § Surface 2 escape-hatch contract. P081 (no structural grep on SKILL.md) prevents the tempting "quick structural grep" workaround.

**ADR-060 spec correction**:

The originally-accepted ADR-060 line 91 stated the type-tag location as "YAML frontmatter, after existing fields". This was inaccurate to the actual `docs/problems/*.md` schema (which uses body-field bullets like `**Status**:`, `**Reported**:`, etc., not YAML frontmatter — RFC tickets use YAML frontmatter; problem tickets use body-bullets). The wording has been corrected in-iter to reflect the true schema. The grandfathered inconsistency between RFC frontmatter and problem-ticket body-bullets is acknowledged but not addressed by this Slice (out of scope per ADR-060).

**ADR-060 § Confirmation criterion 8 status**:

- **Pure-bash supporting-script subset**: PASSED (i2-no-type-branching.bats is the test fixture).
- **SKILL.md agent-driven surface**: deferred to P176 (named ticket; not silent-deferral).

**JTBD impact**:

- **JTBD-001** (governance enforcement) — load-bearing class-level invariant guard satisfies the change-set-level governance shape per the 2026-05-05 amendment.
- **JTBD-006** (AFK orchestrator backlog selection) — verified WSJF parsing unaffected by the new body-field; orchestrator selection unchanged.
- **JTBD-008** (decompose-fix-into-coordinated-changes) — composes; this slice is JTBD-001 + JTBD-006 territory (lifecycle governance + AFK selection); P176 captured as first-class WSJF-ranked entity per JTBD-008 outcome.
- **JTBD-101** (plugin-developer atomic-fix-adopter) — friction-add bounded; one-shot bulk migration; default `technical` (no per-ticket judgement); no SKILL.md surface forces type decision in this slice (item 8c deferred).
- **JTBD-301** (plugin-user no-pre-classification) — protected; migration scope is `docs/problems/[0-9][0-9][0-9]-*.md` only; never touches `.github/ISSUE_TEMPLATE/problem-report.yml`.

**Out of scope (deferred to subsequent slices)**:

- Item 8c — `/wr-itil:capture-problem` AskUserQuestion type prompt (maintainer-side only). Deferred to next iter on P170 Slice 4.
- Slice 5 forward dogfood (RFC-002 captured before commit-1 + run to closure).
- Slice 6 graduate-to-adopters (counterfactual risk assessment + held-window reinstate + 30-day denial-rate tracking).

Held-changeset window remains paused per ADR-060 § Confirmation criterion 6 until RFC-001 reaches `closed` post-Slice-5 forward-dogfood.
