---
'@windyroad/risk-scorer': minor
---

Extend held-changeset graduation evaluator with atomic-cohort (Class 3b) support per ADR-061 Rule 3b (P162 Phase 2b).

`packages/risk-scorer/scripts/evaluate-graduation.sh` now parses the `docs/changesets-holding/README.md` "Currently held" section, groups entries by shared reinstate-trigger prose (parenthetical elaborations stripped, em-dash continuations trimmed before comparison), and emits `class=3b | cohort=<id>` columns for multi-member cohorts. Cohort priority is `max(Priority)` across all member tickets; any halt-no-resolution or VP-blocked member propagates atomically to the entire cohort ("entire cohort ships or none does"). Single-member groups continue to emit `class=3a` — no Phase 2a regression.

`packages/risk-scorer/agents/pipeline.md` retires the "Scope — Phase 2a only" subsection and gains a "Class 3b atomic-cohort evaluation" subsection codifying the 7-step cohort evaluation flow (group → cohort release-risk → compare against cohort priority → per-member evidence floors → cohort-level VP carve-out → cohort-level halt-and-prompt → emit atomic-batch reinstate-from-holding lines).

Behavioural bats coverage extended with 10 new cases satisfying ADR-061 Confirmation criterion 2 item (g); 29 tests total green.
