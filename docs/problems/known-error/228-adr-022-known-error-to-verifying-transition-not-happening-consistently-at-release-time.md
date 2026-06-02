# Problem 228: ADR-022 .known-error.md → .verifying.md transition not happening consistently at release time

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The `manage-problem` review step 9b item 10 auto-transitions Open → Known Error when root cause and workaround are documented, but it does NOT auto-transition Known Error → Verification Pending when a shipped fix is detected. Separately, ADR-022 prescribes the Known Error → Verifying transition on release but the trigger surface isn't fully wired across all release paths.

## Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Identify the missing trigger surface: which release-cadence path detects shipped fixes? Probably review-problems Step 9b or work-problems Step 6.5 post-release callback.
- [ ] Extend the detection: shipped commit message contains `Closes P<NNN>` OR ticket body has `## Fix Released` populated → auto-transition Known Error → Verifying.
- [ ] Behavioural test for the auto-transition.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/42
- **Pipeline classification**: safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Composes with**: ADR-022 (Verifying status); P062 (transition README refresh).
