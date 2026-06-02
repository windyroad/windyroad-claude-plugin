# Problem 258: plugin.json top-level `hooks:` / `skills:` / `agents:` keys are RESERVED by Claude Code's manifest validator — adding arbitrary content breaks `claude plugin install`

**Status**: Verification Pending
**Reported**: 2026-05-18
**Priority**: 15 (High) — Impact: 5 (Severe — total npm distribution outage: all 11 plugins simultaneously unparseable by `claude plugin install`, every adopter blocked with a cryptic validation error; the body frames this P0) x Likelihood: 3 (Possible — re-rated 1→3 2026-05-24 to match the P0 framing: the failure class already materialised once and structural prevention via P263's manifest-shape CI gate has NOT yet landed, so any future top-level plugin.json extension can re-trigger it — "Rare" understated a live structural gap; ADR-063 Amendment 2026-05-18 mitigates the specific maturity-records case but not the class) — re-rated to match the P0 body framing per user direction 2026-05-24; WSJF refreshes at next /wr-itil:review-problems
**Effort**: M — documentation + ADR-058 amendment + plugin-distribution.md briefing entry
**WSJF**: 15.0 — (15 × 2.0) / 2 (Known Error multiplier 2.0) — re-rated 2026-05-26 from the 2026-05-24 in-ticket Severity 15

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

### Refined root cause (2026-05-26 investigation, grounded against the [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference))

The original framing ("top-level keys are RESERVED ... adding arbitrary content breaks install") was imprecise. The grounded mechanism:

- The validator recognises a **fixed set** of top-level `plugin.json` keys: `name` (the only required field), `$schema`, `displayName`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `skills`, `commands`, `agents`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`, `experimental.*` (`themes` / `monitors`), `userConfig`, `channels`, `dependencies`.
- **Recognised keys are type-checked.** `skills` / `agents` / `hooks` / `commands` are *component-path* fields expecting `string | array | object` of component paths or inline config. Supplying maturity-record objects there is a **wrong-type hard load error** — this is exactly what produced `Validation errors: hooks: Invalid input, skills: Invalid input`.
- **Unrecognised keys are warning-only** — the plugin still loads at runtime; `claude plugin validate` reports them as warnings, not errors. This is *why* the hotfix's resolution (nest under a novel top-level `maturity:` key per ADR-063 Amendment 2026-05-18) is durable: `maturity:` is unrecognised, so it can never trip the type-checker.
- **Documented pre-publish gate**: `claude plugin validate --strict` promotes warnings to errors (CI-suitable). This refines P263's open question ("does `claude plugin install --dry-run` exist?") to the documented surface.

**Broader lesson**: extend `plugin.json` only via a NEW unrecognised key — never by overloading a recognised component-path key with off-schema content.

### ADR cross-references resolved

- **ADR-058 amendment — NOT applicable.** ADR-058 (Phase 2) governs the read-only NDJSON measurement output emitted to **stdout** (its `schema_version "1.0"` / additive-only contract, Confirmation #8, is scoped to those stdout records). ADR-058 explicitly does **not** write `plugin.json` (Considered Option E4 "no cache file" rejected — "exercise the signal, not commit the signal"). The manifest validator never inspects ADR-058's output, so the validator-schema constraint is not a property of ADR-058's surface. The validator authority correctly lives on the `plugin.json` **write** surface — ADR-063 (Phase 3) — which already carries it via the Amendment 2026-05-18 (record relocation under `maturity:`, the `1.0 → 2.0` non-additive bump, and Confirmation #11 manifest-validator compatibility). Architect verdict 2026-05-26: GREEN — determination sound; no `docs/decisions/058` edit warranted.
- **ADR-063 Amendment 2026-05-18 — refined** with the recognised-and-type-checked vs unrecognised-and-warning-only distinction so Confirmation #11's authority sits with a precise root-cause statement (architect Option 1, single-file, no multi-ADR deadlock).

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems. — Transitioned to Verification Pending 2026-05-26; excluded from WSJF (multiplier 0) per ADR-022, so further re-rating is moot.
- [x] Document the validator's accepted shape — enumerated above, grounded against the Claude Code plugins reference. Empirically corroborated: all 11 post-hotfix `@windyroad/*` plugin.json files carry only `name` / `version` / `description` / `maturity` and install cleanly.
- [x] Amend `docs/decisions/058-...` if applicable — determined **NOT applicable** (rationale above); validator authority correctly resides in ADR-063 Amendment 2026-05-18. ADR-063 root-cause phrasing refined instead.
- [x] Update `docs/briefing/plugin-distribution.md` to add this lesson to the "What Will Surprise You" section. — Added 2026-05-26.
- [x] Compose with P263 (CI gate `claude plugin install --dry-run` per plugin pre-publish — closes the test-gap that allowed this to ship). — Composition verified bidirectional and accurate; P263 cross-referenced with the `claude plugin validate --strict` finding.

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

## Fix Released

The incident itself was mitigated 2026-05-18 by ADR-063 Amendment 2026-05-18 (hotfix commit 3cfa6fc — records relocated under the unrecognised `maturity:` key). P258's own remaining deliverable was **the documented learning**, completed 2026-05-26:

- Validator-accepted top-level key shape enumerated and the recognised-and-type-checked vs unrecognised-and-warning-only behaviour split documented, grounded against the [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference).
- `docs/briefing/plugin-distribution.md` "What Will Surprise You" gained the lesson + safe-extension rule + `claude plugin validate --strict` pre-publish gate.
- ADR-063 Amendment 2026-05-18 root-cause phrasing refined (recognised/unrecognised distinction); ADR-058 amendment determined not applicable (rationale in Root Cause Analysis).
- P263 cross-referenced.

Released as a docs commit on 2026-05-26 (this iteration). Awaiting user verification that the documented learning is accurate and sufficient. The structural prevention (CI gate) is tracked separately as the still-open P263 — P258 does not block on it (see Dependencies).

(captured via /wr-retrospective:run-retro Step 4b Stage 1; expanded + transitioned to Verification Pending 2026-05-26)
