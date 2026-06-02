# Problem 321: Structural contract tests pin the invocation FORM (`update-*-section.sh`) — rewriting it to a shim breaks them with no heads-up, costing CI round-trips

**Status**: Open
**Reported**: 2026-05-27
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The RFC-009 fix rewrote 17 SKILL call sites from `bash "$(wr-itil-script-path || echo packages/itil/scripts)/update-X-section.sh"` to the `wr-itil-update-X-section` shim form. Two **structural** contract tests grep the SKILL.md for the OLD `.sh` invocation form and broke:

- `packages/itil/skills/manage-story-map/test/manage-story-map-contract.bats` — `grep -E 'update-problem-references-section\.sh.*Story Maps'`
- `packages/itil/scripts/test/rfc-stories-extension.bats` — `grep -E 'update-rfc-references-section\.sh.*Stories'`

Nothing flagged that changing the invocation form would break tests that assert on that exact form. They surfaced only as **red CI** ("Run hook tests") AFTER push — costing **two extra CI round-trips** (first P317 push red on manage-story-map; the rerun red on rfc-stories-extension) before both were aligned to the shim form. The local full-suite sweep that would have caught them pre-push hung (P319), compounding the cost.

This is a structural-test brittleness class: a test that greps an implementation/invocation FORM (rather than asserting behaviour) silently goes stale when the form legitimately changes, and there is no tooling that says "you changed form X; N tests grep the old form — update them."

## Symptoms

- A faithful invocation-form rewrite (ADR-049 conformance) turns green-locally / green-on-changed-files into red-CI because form-pinned structural greps in OTHER skills' contract tests still match the old string.
- The break is invisible until the full hook-test suite runs (CI or a non-hanging full local run).

## Workaround

When changing any invocation form, `grep -rn '<old-form>' packages/*/skills/*/test/ packages/*/scripts/test/` across the WHOLE test corpus before pushing and update every form-pinned assertion. (Done reactively this session after CI flagged it.)

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Decide the fix shape (≥2 options — surface for direction if genuinely contested): (a) make form-pinned contract greps form-AGNOSTIC (match the script stem `update-X-section` with or without `.sh`/shim prefix) so a form rewrite doesn't break them; (b) a pre-push lint that, given a set of changed invocation forms, greps the test corpus for the old form and warns; (c) accept as inherent structural-test brittleness (ADR-052 already deprefers structural tests) and rely on the cross-corpus grep workaround. Likely (a) — cheapest, removes the false-coupling.
- [ ] Apply the chosen fix to manage-story-map-contract.bats + rfc-stories-extension.bats (and sweep for sibling form-pinned greps).

## Dependencies

- **Composes with**: ADR-052 (behavioural-tests-default — these are structural greps; the deeper fix is behavioural, but blocked on P176 skill-invocation harness), RFC-009 (the rewrite that exposed this), P319 (the hanging full-suite that prevented catching it pre-push).

## Related

- captured via /wr-retrospective:run-retro Step 2b (Skill-contract / Release-path friction), 2026-05-27. Witnessed during RFC-009 release (2 CI red→green round-trips: manage-story-map, rfc-stories-extension).
