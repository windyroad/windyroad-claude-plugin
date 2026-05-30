# Problem 337: Decisions compendium omits Decision Outcome for 57% of ADRs — generator only extracts the `Chosen option:` tag, not the Decision Outcome section body

**Status**: Open
**Reported**: 2026-05-30
**Priority**: 3 (Medium) — Impact: 3 x Likelihood: 1 (deferred — re-rate at next /wr-itil:review-problems; HIGH in practice — defeats the stated ADR-077 goal of "token-cheap load surface for routine architect-agent compliance review" because 43/75 ADRs render with no statement of what was decided at all)
**Origin**: internal
**Effort**: M (deferred — re-rate at next /wr-itil:review-problems; small generator edit to extract the `## Decision Outcome` section body, similar in shape to the existing `get_section`/`get_bullets` helpers)
**Type**: technical

## Description

Surfaced by user direct observation 2026-05-30 (work-problems session 9, after the P334 compendium-portability fix shipped + the freshly-regenerated `docs/decisions/README.md` was reviewed). User asked: *"is there enough information in here to follow the decisions without having to consult the full ADR file. It doesn't look like there is."*

Empirical audit:

```
LC_ALL=C awk '/^### ADR-/ {adrs++} /^\*\*Chosen:\*\*/ {chosen++} /^\*\*Confirmation:\*\*/ {confirm++} END {print adrs, chosen, confirm}' docs/decisions/README.md
75 32 39
```

Of 75 ADRs:
- 32 (43%) carry a rendered `**Chosen:**` line
- 39 (52%) carry a rendered `**Confirmation:**` line
- **43 ADRs (57%) carry NO Decision Outcome statement in the compendium at all** — only their title, status badge, oversight badge, supersession links, and (if present) related-ADR refs.

Example: ADR-002 ("Monorepo with Independently Installable Per-Plugin Packages") renders with **Status**, **Oversight**, and a **Confirmation** line of test-shaped bullets. Nowhere does the compendium say what was actually decided — the reader is left to infer the choice from the confirmation tests.

Root cause locus: `packages/architect/scripts/generate-decisions-compendium.sh` line 115:

```bash
| awk '/^Chosen/ { print; exit }' \
```

The generator's `get_chosen` extractor matches ONLY lines that begin with "Chosen" — typically MADR's `Chosen option: "Option X — Title", because ...` tag. ADRs that use the MADR-permitted alternative shape (`## Decision Outcome` heading followed by prose, no explicit `Chosen option:` line) render with no decision content. This is half the corpus.

## Symptoms

- Reading the compendium tells you which tests proved an ADR landed, but not what the ADR decided.
- Architect agent doing routine compliance review must fall through to the per-ADR file body for any ADR without a `Chosen option:` tag — defeats ADR-077's "routine load" goal for 57% of the corpus.
- The compact rendered index is structurally incomplete for half the ADRs.

## Workaround

Open the per-ADR file (`docs/decisions/<NNN>-<slug>.<status>.md`) for any ADR whose compendium entry lacks a Chosen line. The full Decision Outcome section is always in the body.

## Impact Assessment

- **Who is affected**: architect agent (every routine-load), maintainer (every compendium read), any reader who relies on the compendium as the single navigation entry-point.
- **Frequency**: every routine architect-agent compliance review touches the compendium; this is a hot read path.
- **Severity**: HIGH — defeats the stated load-surface purpose for the majority of entries; the ADR-077 confirmation criterion (g) "committed compendium matches generator output" is satisfied but the content per-entry is insufficient.
- **Analytics**: 43/75 = 57% gap; not measurable until fix lands.

## Root Cause Analysis

### Investigation Tasks

- [ ] Re-rate Priority and Effort at next /wr-itil:review-problems — likely HIGH given the load-surface impact
- [ ] Extend `get_chosen` to fall back to `get_section "$file" "Decision Outcome"` and emit the first paragraph (or first ~240 chars) when no `Chosen option:` tag is found
- [ ] Decide whether to additionally surface the first Decision Drivers bullet on entries that have no Decision Outcome prose either — separate decision per ADR-077 § Intentionally NOT in this routine view
- [ ] Update `docs/decisions/README.md` head-of-file prose at line 12 if the inclusion set widens beyond Chosen tag
- [ ] Behavioural bats in `packages/architect/scripts/test/generate-decisions-compendium.bats`: assert that every ADR in `docs/decisions/` (excluding README.md) renders a Decision Outcome line in the compendium output — coverage floor; currently the `each ADR emits ID + Title + Status + Chosen + Confirmation + Related` test passes despite 57% having no Chosen line because the test fixture's ADRs all carry the tag
- [ ] Patch the existing `# 9 each ADR emits ID + Title + Status + Chosen + Confirmation + Related` bats fixture to include an ADR WITHOUT a `Chosen option:` tag and assert it still renders Decision Outcome content — closes the gap that lets the production corpus drift past the fixture

## Dependencies

- **Blocks**: ADR-077's load-surface goal for routine architect-agent compliance review on 57% of ADRs.
- **Blocked by**: (none)
- **Composes with**: ADR-077 (the compendium ADR — this is a defect against confirmation criterion (a) "Compact rendered index of every ADR's chosen option"); P334 (just-shipped portability fix — same script).

## Related

(captured via /wr-itil:capture-problem during session 9 work-problems loop after user observation 2026-05-30)

- **ADR-077** — the compendium ADR; this defect violates its stated load-surface purpose for the majority of entries.
- **P334** — sibling generator defect (just shipped — awk substr Unicode portability); both touch the same script.
- `packages/architect/scripts/generate-decisions-compendium.sh` line 115 — the locus of the gap.
- `packages/architect/scripts/test/generate-decisions-compendium.bats` test 9 — passing-but-incomplete coverage that allowed the gap to ship.
