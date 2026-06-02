# Problem 210: work-problems SKILL.md AFK-fallback marker wording uses em-dash, forces consumer-side whitespace surgery

**Status**: Known Error
**Reported**: 2026-05-15
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems)
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems)

## Description

The fallback-marker pattern in `packages/itil/skills/work-problems/SKILL.md` prose uses an em-dash (U+2014) in its canonical wording. Consumers parsing the marker (grep / awk / sed) need to handle the unicode character specifically — ASCII-only consumer scripts treat the em-dash differently from ASCII hyphen-minus, breaking the match.

## Workaround

Consumer-side scripts handle both em-dash and hyphen-minus variants (extra branch), or normalize unicode to ASCII before matching.

## Impact Assessment

- **Who is affected**: any consumer script that parses the AFK-fallback marker pattern from work-problems' iter output.
- **Frequency**: every parse.
- **Severity**: Low — consumer-side workaround is straightforward but the friction is repeated across every consumer.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems
- [ ] Switch the em-dash to ASCII hyphen-minus in `packages/itil/skills/work-problems/SKILL.md` AFK-fallback marker wording.
- [ ] Audit other SKILL.md prose for em-dash usage in machine-parseable identifiers / markers; switch to ASCII where consumer-parsing is implied.
- [ ] Document the convention: ASCII-only in machine-parseable identifiers; em-dash permitted in pure narrative prose.

## Related

- **Reported Upstream**: https://github.com/windyroad/agent-plugins/issues/84
- **Pipeline classification**: JTBD-aligned; safe-low-fix-risk; route=safe-and-valid.
- **Affected plugin**: @windyroad/itil.
