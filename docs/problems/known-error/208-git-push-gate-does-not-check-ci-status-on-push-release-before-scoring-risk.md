# Problem 208: git-push-gate.sh does not check CI status on push/release before scoring risk

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

> **safe-high-fix-risk flag** (per dual-axis-risk classifier): `git-push-gate.sh` is a load-bearing release-risk gate. Modifications to it (even hardening ones) need maintainer attention to ensure the new `gh run list` integration doesn't degrade-to-allow on API timeout / auth failure / pending-run states, which would silently weaken the very gate the fix intends to strengthen. The fix-risk class flagged is "Removal of load-bearing safety check" applied inversely — a buggy harden can degrade to a bypass.

## Description

`git-push-gate.sh` (in `packages/risk-scorer/hooks/`) gates `npm run push:watch` and `npm run release:watch` on the wr-risk-scorer pipeline output, but never directly checks whether the latest CI run on the target branch is red. A push that scores low predicted risk can still proceed onto a CI-broken master because the gate consumes only the leading risk signal, not the lagging CI-status signal.

The same gap applies to `npm run release:watch`: a low-risk release can ship onto a master where the most recent CI run was a failure.

## Workaround

User-in-the-loop review: manually inspect `gh run list --branch master --limit 1` before approving every push and release. Works for low-volume cadence; does not scale.

## Impact Assessment

- **Who is affected**: every adopter project running push:watch / release:watch with CI integration.
- **Frequency**: pattern-applies to every push and release attempt.
- **Severity**: High — a red-CI-on-master push lands shipped code on a broken baseline; release ships broken code to npm.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] **Architect call (safe-high-fix-risk)**: design the CI-status integration to fail-CLOSED on API timeout / auth failure / pending-run states. The hardening must NOT degrade to allow under any failure mode.
- [ ] Extend `git-push-gate.sh` to consult `gh run list --branch <target> --limit 1` for the target branch's most recent CI conclusion. Treat `conclusion: failure` / `conclusion: cancelled` as deny-with-reason; treat `status: in_progress` / `pending` as halt-with-prompt; treat API errors as deny.
- [ ] Behavioural test asserting red-CI deny + pending halt + API-error deny.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/86
- **Pipeline classification**: JTBD-aligned (JTBD-006 + JTBD-202); **safe-high-fix-risk** (cache_audit_note: high-fix-risk-flag); route=safe-and-valid + flag.
- **Affected plugin**: @windyroad/risk-scorer.
