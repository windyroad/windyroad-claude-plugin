# Problem 207: report-upstream SKILL.md Step 5 example uses --label flag that fails when upstream repo has no labels

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

`packages/itil/skills/report-upstream/SKILL.md` Step 5 demonstrates the `gh issue create` invocation with a `--label "${MATCHED_TEMPLATE_LABEL_IF_ANY}"` line. When the upstream repo has not pre-created the label name in repo settings (the default for new repos), `gh issue create --label <unknown-label>` fails with `could not add label: 'X' not found`. The flag is also redundant when the matched issue template carries `labels:` in its frontmatter, because the form auto-applies those labels on submit. The skill's example is therefore wrong on two grounds: redundant when the upstream is configured correctly, and a hard fail when it is not.

## Workaround

Drop the `--label` flag from the `gh issue create` invocation. The matched template's frontmatter `labels:` field is authoritative.

## Impact Assessment

- **Who is affected**: every `/wr-itil:report-upstream` invocation against an upstream whose label names have not been pre-created.
- **Frequency**: every first attempt against such an upstream.
- **Severity**: Moderate (hard-fail on first attempt; workaround is trivial).

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Remove `--label` flag from `packages/itil/skills/report-upstream/SKILL.md` Step 5 (and any sibling SKILL.md that demonstrates the same pattern).
- [ ] Behavioural test asserting the documented example posts successfully against an upstream without pre-created labels.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/87
- **Pipeline classification**: JTBD-aligned; safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
- **Sibling**: P198/#125 — same template/label-ecosystem drift class observed at the inbound-discovery filter; this ticket's outbound-side counterpart.
