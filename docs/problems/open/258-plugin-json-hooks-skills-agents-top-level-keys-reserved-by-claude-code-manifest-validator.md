# Problem 258: plugin.json top-level `hooks:` / `skills:` / `agents:` keys are RESERVED by Claude Code's manifest validator — adding arbitrary content breaks `claude plugin install`

**Status**: Open
**Reported**: 2026-05-18
**Priority**: 15 (High) — Impact: 5 (Severe — total npm distribution outage: all 11 plugins simultaneously unparseable by `claude plugin install`, every adopter blocked with a cryptic validation error; the body frames this P0) x Likelihood: 3 (Possible — re-rated 1→3 2026-05-24 to match the P0 framing: the failure class already materialised once and structural prevention via P263's manifest-shape CI gate has NOT yet landed, so any future top-level plugin.json extension can re-trigger it — "Rare" understated a live structural gap; ADR-063 Amendment 2026-05-18 mitigates the specific maturity-records case but not the class) — re-rated to match the P0 body framing per user direction 2026-05-24; WSJF refreshes at next /wr-itil:review-problems
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; documentation + ADR-058 amendment + plugin-distribution.md briefing entry)
**Type**: technical

## Description

Surfaced 2026-05-18 by the Phase 3 retroactive rollout (commit d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins). The Phase 3 populate script wrote per-surface maturity records at top-level plugin.json keys (`hooks: { <name>: {maturity: ...} }`, `skills:`, `agents:`). Claude Code's plugin manifest validator rejected the shape with `Validation errors: hooks: Invalid input, skills: Invalid input`.

All 11 affected plugins on npm were unparseable by `claude plugin install` for ~20 minutes until the hotfix (commit 3cfa6fc, ADR-063 Amendment 2026-05-18) shipped.

**Root cause**: Claude Code's plugin manifest validator expects the top-level `hooks:` / `skills:` / `agents:` keys to follow a specific event-keyed schema (registered hook events, skill entries with required fields). Maturity-only records (`{schema_version, band, computed_at, evidence}`) at those locations are NOT in the validator's accepted shape and cause hard-rejection.

The lesson is broader than the specific maturity-records case: **any future maintainer extension to plugin.json that adds top-level keys must verify Claude Code's validator accepts the shape**, OR nest the extension under a key the validator already allows (like top-level `maturity:` — the hotfix's resolution).

## Symptoms

- `claude plugin install <plugin>@<marketplace> --scope project` fails with `Validation errors: hooks: Invalid input, skills: Invalid input`.
- Pre-existing installs continue to work (loader is more permissive at runtime than the install validator).
- Bats fixtures that assert JSON shape pass — they don't run `claude plugin install --dry-run` against the published shape.

## Workaround

Move new per-component records OUT of top-level `hooks:` / `skills:` / `agents:` to a sibling location (e.g. `maturity.<kind>.<name>` under top-level `maturity:`). Strip the broken keys entirely.

## Impact Assessment

- **Who is affected**: Every adopter of any `@windyroad/*` plugin when the next release ships with the broken shape. P0 class — install fails completely.
- **Frequency**: Rare — only fires when maintainer extends plugin.json with a new top-level key shape. Currently mitigated by ADR-063 Amendment 2026-05-18 + P263 (CI gate).
- **Severity**: Significant (3) — breaks adopter `claude plugin install`; recovery requires hotfix release + cache refresh.
- **Analytics**: 1 incident this session (2026-05-18, 11 plugins for ~20 minutes); 0 prior incidents.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems.
- [ ] Document the validator's accepted shape — what top-level keys are allowed in plugin.json? Read Claude Code's source / docs to enumerate.
- [ ] Amend `docs/decisions/058-plugin-maturity-measurement-mechanism.proposed.md` if applicable — the additive-only schema-version contract should reference the validator schema as the load-bearing surface.
- [ ] Update `docs/briefing/plugin-distribution.md` to add this lesson to the "What Will Surprise You" section.
- [ ] Compose with P263 (CI gate `claude plugin install --dry-run` per plugin pre-publish — closes the test-gap that allowed this to ship).

## Dependencies

- **Blocks**: (none — P263 closes the structural prevention; this ticket is the documented learning)
- **Blocked by**: (none)
- **Composes with**: P263 (CI gate implementation), ADR-063 Amendment 2026-05-18, ADR-058 (schema-version contract)

## Related

- ADR-063 Amendment 2026-05-18 — codifies the Phase 3 maturity record path move + schema_version 2.0 bump + 3 new Confirmation criteria.
- ADR-058 — plugin maturity measurement schema-version contract.
- P263 — CI gate implementation (the structural prevention).
- Commit 3cfa6fc — hotfix that ships the corrected shape.
- Commit d33bb7d — the broken Phase 3 retroactive rollout commit.

(captured via /wr-retrospective:run-retro Step 4b Stage 1; expand at next investigation)
