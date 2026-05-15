---
"@windyroad/itil": minor
---

work-problems Step 0b: auto-pre-flight inbound-discovery on stale upstream cache

`/wr-itil:work-problems` now pre-flights `/wr-itil:review-problems` at Step 0b
(after Step 0a auto-migrate, before Step 1 backlog scan) when the upstream
inbound-discovery cache is missing, has `last_checked: null`, or has aged past
its TTL. Closes the ADR-062 § JTBD-006 driver gap: review-problems' Step 4.5b
TTL self-healing only fires if review-problems is entered; AFK loops would
otherwise never poll upstream channels unless the maintainer ran review-problems
manually first.

- New helper: `packages/itil/lib/check-upstream-cache-staleness.sh` exposing
  `should_promote_inbound_discovery_preflight` (idempotent, fail-soft on missing
  channels-config — downstream-adopter non-obligation per ADR-062 §
  Downstream-adopter contract).
- New behavioural test: `packages/itil/skills/work-problems/test/work-problems-step-0b-cache-staleness-behavioural.bats`.
- Doc-hardening: `Edge Cases` and Step 1's exclusion list now reference
  `/wr-itil:review-problems` directly (replacing the deprecated
  `/wr-itil:manage-problem review` alias text).
- AFK-safe by design: P132 mechanical-stage carve-out keeps the promotion point
  silent; review-problems' Step 4.5 pipeline's external-comms gates silent-pass
  on low-risk verdicts per ADR-028 + the `wr-risk-scorer:external-comms` *"policy-authorised drafts proceed silently"* contract.
- ADR-062 Confirmation criterion 5 records the wiring and the staleness-contract
  drift-prevention anchor.
- JTBD-006 Desired Outcomes lists the pre-flight as a documented expectation.
