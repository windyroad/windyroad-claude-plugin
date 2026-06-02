# Problem 221: work-problems Step 6.5 lacks baseline CI health check before drain

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

> **safe-high-fix-risk flag** (per dual-axis-risk classifier): the proposed CI-health gate sits on the AFK-critical drain path. A wrong implementation could (a) over-block legitimate drains on transient CI flake, OR (b) under-block and let drain proceed against broken main. Not a "removal of load-bearing safety check" — it ADDS one — but it sits on a critical path so the maintainer should weigh failure modes + coordinate with sibling P208/#86 before accepting.

## Description

`/wr-itil:work-problems` Step 6.5 ("Release-cadence check") decides whether to drain the changeset queue based on local risk scores only. It never checks the health of the latest `main` pipeline run before invoking `npm run push:watch`. When `main` is already red for reasons outside the local risk scope, the drain may proceed and compound the breakage.

## Workaround

User-in-the-loop: check `gh run list --branch main --limit 1` before authorising an AFK loop or after Step 6.5 has fired.

## Impact Assessment

- **Severity**: High — drains can compound red-CI breakage; AFK promise broken.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] **Architect call (safe-high-fix-risk)**: design the CI-health gate to fail-CLOSED on API/auth/pending; coordinate with P208/#86 push-gate hardening.
- [ ] Extend Step 6.5 with a baseline CI-health check that halts drain on `conclusion: failure` / `conclusion: cancelled`.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/62
- **Pipeline classification**: **safe-high-fix-risk** (cache_audit_note: high-fix-risk-flag); route=safe-and-valid + flag.
- **Affected plugin**: @windyroad/itil + @windyroad/risk-scorer.
- **Sibling**: P208/#86 (push-gate CI-status gap — closely related; resolve together).
