# Problem 337: Decisions compendium omits Decision Outcome for 57% of ADRs — generator only extracts the `Chosen option:` tag, not the Decision Outcome section body

**Status**: Open
**Reported**: 2026-05-30
**Priority**: 12 (High) — Impact: 3 (Moderate — defeats ADR-077 token-cheap-load-surface goal; 43/75 ADRs render with no statement of what was decided) × Likelihood: 4 (Likely — fires for every ADR lacking a MADR `Chosen option:` tag — currently 57% of corpus)
**Origin**: internal
**Effort**: L (re-rated 2026-06-01 — architect verdict on 2026-06-01 work-problems iteration redirected the fix path from "extend the programmatic extractor" to ADR-078 Phase 1: new `architect-compendium-update-entry.sh` PostToolUse hook + `architect-readme-pairing-check.sh` pre-commit hook + retire bats test 2145 + retire `architect-compendium-refresh-discipline.sh` PreToolUse hook + cadence-driven migration of 43 non-canonical ADRs. RFC-scope per ADR-060. Was M when scoped as a regex extension; superseded.)
**WSJF**: 3.0 (re-rated 2026-06-01 — (Severity 12 × Status 1.0) / Effort L (4) = 3.0; was 6.0 under the M-effort regex-extension scope.)

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

Root cause confirmed at two layers:

1. **Surface-level**: `get_chosen` regex `/^Chosen/` matches only 34 of 77 ADRs (the plain-prefix MADR `Chosen option: …` shape). 38 ADRs use bold-prefixed `**Chosen option:**` (regex MISSES the leading `**`); 4 ADRs use prose-only `## Decision Outcome` (MADR-permitted alternative — no `Chosen option:` tag at all). Total gap: 42 ADRs.
2. **Architecture-level (architect verdict 2026-06-01)**: the original Investigation Tasks below (extend `get_chosen` regex + add Decision-Outcome-body fallback + bats coverage) is **Option 6** from ADR-078's Considered Options. ADR-078 (`human-oversight: confirmed`, oversight-date 2026-05-31) explicitly chose Option 9 (architect-on-edit LLM-authored entries via PostToolUse hook) and **rejected** Option 6 with prejudice. User direction recorded in ADR-078 amendment 2026-05-31: *"I never approved the scripted extraction. You are supposed to run decisions by me"* (P339). Implementing the regex+fallback path now would re-invest in retiring infrastructure and contradict the ratified architectural choice.

### Investigation Tasks

- [x] Re-rate Priority and Effort at next /wr-itil:review-problems — done 2026-06-01: Effort re-rated M → L given ADR-078 Phase 1 scope (multi-hook + retirement), WSJF re-rated 6.0 → 3.0.
- [x] Surface that the regex-extension fix path is the wrong mechanism — done 2026-06-01 via architect agent verdict during work-problems iteration. See `## Fix Strategy` below.
- [ ] ~~Extend `get_chosen` to fall back to `get_section "$file" "Decision Outcome"` and emit the first paragraph (or first ~240 chars) when no `Chosen option:` tag is found~~ — **SUPERSEDED by ADR-078 Option 9**. Do not implement; see Fix Strategy.
- [ ] ~~Decide whether to additionally surface the first Decision Drivers bullet~~ — **SUPERSEDED**. Architect-authored entries will surface what the architect agent judges material per-edit; no separate driver-bullet decision needed.
- [ ] ~~Update `docs/decisions/README.md` head-of-file prose at line 12 if the inclusion set widens beyond Chosen tag~~ — **SUPERSEDED**. Architect-on-edit will rewrite entries per-edit; the head-of-file prose changes only if the architectural framing changes (already amended by ADR-078).
- [ ] ~~Behavioural bats in `packages/architect/scripts/test/generate-decisions-compendium.bats`~~ — **SUPERSEDED**. ADR-078 retires bats test 2145 (`committed compendium matches generator output`) and the idempotency criterion entirely; replacement is `architect-readme-pairing-check.sh` pre-commit hook.
- [ ] ~~Patch the existing `# 9 each ADR emits ID + Title + Status + Chosen + Confirmation + Related` bats fixture~~ — **SUPERSEDED**. See above.

## Fix Strategy

Per ADR-078 Phase 1 (single phase — architect-on-edit hook), the fix is RFC-scoped infrastructure:

1. **New PostToolUse hook** `packages/architect/hooks/architect-compendium-update-entry.sh` triggers on Edit/Write events targeting `docs/decisions/*.md` (excluding `README.md`). Spawns `claude -p` subprocess invoking the architect agent with just-edited ADR body + current README entry; architect emits updated entry (Title + Status + Oversight + `**Decides:**` semantic TL;DR + `**Confirmation:**` + `**Related:**`); hook applies as `Edit` on README; stages so same-commit landing per ADR-014.
2. **New pre-commit hook** `packages/architect/hooks/architect-readme-pairing-check.sh` asserts every commit that edits a `docs/decisions/*.md` body also edits `docs/decisions/README.md`. Replaces ADR-077 confirmation criterion (g) drift gate.
3. **Retire** `packages/architect/scripts/generate-decisions-compendium.sh` as load-bearing primary path (keep as backstop for one release cycle, then remove).
4. **Retire** `packages/architect/scripts/test/generate-decisions-compendium.bats` idempotency assertion + drift-gate test 2145.
5. **Retire** `packages/architect/hooks/architect-compendium-refresh-discipline.sh` PreToolUse refresh-discipline hook (Option 9 makes drift structurally impossible).
6. **Cadence-driven migration**: existing 43 non-canonical ADRs migrate naturally the next time each is touched (the new hook fires on every edit; no mass backfill).
7. **Amend ADR-077** confirmation criteria (b), (g), (h) per ADR-078 § "Architectural relationship between body and README under Option 9".

**Scope warrants RFC capture** per ADR-060 framework — multi-hook implementation + retirement schedule + ADR-077 amendment. Stories:

- Story A: implement + test architect-compendium-update-entry.sh (PostToolUse hook + claude -p invocation + Edit application + staging).
- Story B: implement + test architect-readme-pairing-check.sh (pre-commit pairing assertion).
- Story C: retire generate-decisions-compendium.sh + bats (deferred to release cycle N+1 per ADR-078 backstop guidance).
- Story D: retire architect-compendium-refresh-discipline.sh (gated on Story A landing).
- Story E: ADR-077 confirmation-criteria amendment commit.

**Direction question queued for human ratification** (outstanding_questions in this iteration's summary): RFC capture for ADR-078 Phase 1 implementation, decomposed into the 5 stories above. The AFK orchestrator will not capture the RFC or implement the stories without explicit user direction (this work is RFC-grain per ADR-060 + carries a ratified ADR substance dependency).

## Dependencies

- **Blocks**: ADR-077's load-surface goal for routine architect-agent compliance review on 57% of ADRs.
- **Blocked by**: (none mechanical; RFC capture for ADR-078 Phase 1 is a direction-class outstanding question for the user — not encoded as a problem-ticket blocker, no ticket to reference)
- **Composes with**: ADR-077 (the compendium ADR — this is a defect against confirmation criterion (a) "Compact rendered index of every ADR's chosen option"); ADR-078 (the implementation path — Option 9 ratified 2026-05-31; fix delivers via ADR-078 Phase 1 hooks, not the original regex-extension path); P334 (just-shipped portability fix — same script being retired); P339 (substance-confirm-before-build prior occurrence on this same ADR-078).

## Related

(captured via /wr-itil:capture-problem during session 9 work-problems loop after user observation 2026-05-30; updated 2026-06-01 with architect verdict after the original Investigation Tasks fix path was identified as the user-rejected ADR-078 Option 6)

- **ADR-077** — the compendium ADR; this defect violates its stated load-surface purpose for the majority of entries. Confirmation criteria (b), (g), (h) are scheduled for retirement per ADR-078.
- **ADR-078** — the implementation path; chose Option 9 (architect-on-edit LLM-authored entries) 2026-05-31 with `human-oversight: confirmed`. THIS IS THE LOAD-BEARING ADR for P337's fix path.
- **P334** — sibling generator defect (just shipped — awk substr Unicode portability); both touch the same script being retired per ADR-078.
- **P339** — substance-confirm-before-build gap on this same ADR-078 (prior occurrence). The 2026-06-01 architect verdict on P337 caught the SECOND iteration of the same anti-pattern (agent about to implement Option 6 after Option 9 was ratified).
- `packages/architect/scripts/generate-decisions-compendium.sh` line 115 — the original locus of the gap; will be retired per ADR-078 Story C.
- `packages/architect/scripts/test/generate-decisions-compendium.bats` test 9 — passing-but-incomplete coverage; retired per ADR-078 Story C.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-014 | proposed | ADR-078 Phase 1 — architect-on-edit compendium entries |
