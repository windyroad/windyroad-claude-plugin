---
"@windyroad/itil": minor
"@windyroad/architect": patch
---

P287: retire technical/user-business type classification from problems

Per twice-confirmed user direction (2026-05-25 + 2026-06-02 "GET RID OF IT"), the `type: technical | user-business` axis is retired from `/wr-itil:capture-problem`. The axis was already redundant with RFC/Story persona-anchoring per ADR-060 Phase 4.

**@windyroad/itil (minor)**:
- `/wr-itil:capture-problem` SKILL: removed Step 1.5 Type classification (lexical-signal classifier + AskUserQuestion + stderr advisory); removed Rule 6 type-classification row; removed flag table rows for `--type=technical`, `--type=user-business`, `--no-prompt`; removed `**Type**:` line from Step 4 skeleton template; removed type-tag row from Composition table.
- `/wr-itil:capture-problem` SKILL Step 1.5b (JTBD-trace + persona dispatch): decoupled from `type_value = user-business`; fires unconditionally; I12 hard-block retired (type-keyed JTBD-required halt no longer applies).
- `packages/itil/lib/derive-first-dispatch.sh`: removed `lexical_classify_two_sided` function (no remaining consumer); synced from `packages/shared/derive-first-dispatch.sh` per ADR-017.
- Behavioural fixtures: removed P185 classifier tests + stderr-advisory tests + flag-precedence tests + meta-recursive corpus test from `capture-problem.bats`; removed 4 `lexical_classify_two_sided` tests from `derive-first-dispatch.bats`; renamed `i2-no-type-branching.bats` → `no-type-regression-guard.bats` with positive-state assertions (no `**Type**:` field in tickets/template/SKILL; no `lexical_classify_two_sided` function; per-package lib sync intact); amended `capture-problem-step-1-5b-jtbd-trace.bats` I12 hard-block tests to assert the predicate never blocks (regression guard).
- Mass-strip `**Type**:` body field from 347 docs/problems/**/*.md tickets (one-shot inverse of the original `migrate-problems-add-type.sh` migration; the original migration script is preserved in git history per architect verdict).

**@windyroad/architect (patch)**:
- `packages/architect/lib/derive-first-dispatch.sh`: byte-identical sync of the `lexical_classify_two_sided` removal from `packages/shared/derive-first-dispatch.sh` per ADR-017. No surface change in `/wr-architect:create-adr` (it never used the two-sided classifier).

**Out of scope this iter (queued for user re-confirmation per ADR-074)**:
- ADR-060 amendment substance: in-place strike of type-tag clauses (Decision Outcome item 1, I2 invariant body, I12 invariant body, Phase-4 type-keyed dispatch); decision on I12 replacement shape; Phase-4 persona/jtbd rework keyed off some other discriminator (or unconditionally). The ADR-060 body and the SKILL implementation are intentionally inconsistent until the amendment lands — this is the P287 trade-off the user accepted twice.
- Clearing ADR-060 `human-oversight: confirmed` marker.
- JTBD-008 line 31 amended in this changeset to strike `type: user-business` clause; JTBD-201/JTBD-301 verified unaffected per JTBD agent review.

P287 transitions Open → Known Error per ADR-022; Verification Pending transition follows next release.
