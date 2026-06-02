---
status: proposed
rfc-id: adr-078-phase-1-architect-on-edit-compendium-entries
reported: 2026-06-02
decision-makers: [Tom Howard]
problems: [P337]
adrs: [ADR-078, ADR-077]
jtbd: []
stories: []
human-oversight: confirmed
oversight-date: 2026-06-02
---

# RFC-014: ADR-078 Phase 1 — architect-on-edit compendium entries

**Status**: proposed
**Reported**: 2026-06-02
**Problems**: P337
**ADRs**: ADR-078, ADR-077
**JTBD**: (none)

## Summary

ADR-078 Phase 1 — implement architect-on-edit LLM-authored compendium entries via PostToolUse hook + readme-pairing pre-commit hook + retire the current programmatic generator (and its drift gate + refresh-discipline hook) + cadence-driven migration of the 43 non-canonical ADRs + ADR-077 confirmation-criteria amendment.

This RFC scopes the implementation arc for the ADR-078 decision (Option 9 — architect-on-edit, ratified 2026-05-31 with `human-oversight: confirmed`). The decision itself is settled; this RFC sequences and tracks the multi-commit work that delivers it. Substance of each story is intentionally deferred — populate Scope / Tasks at `/wr-itil:manage-rfc <NNN> accepted` transition.

## Driving problem trace

- **P337** (Open) — Decisions compendium omits Decision Outcome for 57% of ADRs. The generator's `get_chosen` regex (`packages/architect/scripts/generate-decisions-compendium.sh:115`) matches only plain-prefix `Chosen option:` tags; 43/75 ADRs render with no decision content. Defeats ADR-077's load-surface goal for the majority of entries. ADR-078 Phase 1 replaces the programmatic extractor with architect-on-edit authored entries — this RFC is that replacement's delivery vehicle.

## Scope

**Substantive sub-decisions ratified 2026-06-02 via AskUserQuestion surface** (per ADR-074 substance-confirm-before-build; `human-oversight: confirmed`):

- **(SQ-014-1) Test strategy for Story A's `claude -p` subprocess**: **PATH-priority fake-claude shim.** Bats fixtures stub the subprocess with a fixed-response `claude` shim placed first on `PATH` (per ADR-049 / JTBD-301 adopter-portable fixture pattern). Real-subprocess integration tests are out of scope for Phase 1; if they become necessary, a separate tagged CI lane gated on `CLAUDE_P_AVAILABLE` is the follow-on path.
- **(SQ-014-2) Story C backstop window for `generate-decisions-compendium.sh`**: **one minor-version release cycle of `@windyroad/architect`.** The script gains a stderr deprecation notice on every invocation citing ADR-078 (per ADR-078 Confirmation criterion j); after one full minor-version cycle in which Stories A + B + D are in production, the script + bats test 2145 + CHANGELOG entry are removed entirely.
- **(SQ-014-3) ADR-077 confirmation-criteria amendment shape in Story E**: **verify (b), (g), (h) reflect as-shipped Story A/B/D enforcement state + tighten residual aspirational language.** ADR-077's criteria were already partially amended 2026-05-31 by the ADR-078 ratification; Story E is a verify-and-tighten pass that lands as a same-commit edit per Story B's pre-commit pairing gate (Story A's PostToolUse hook regenerates the README ADR-077 entry automatically on commit).
- **(SQ-014-4) Migration ordering for the 43 non-canonical compendium entries**: **OPPORTUNISTIC BATCH** (user override of the iter recommendation of strict cadence, 2026-06-02). Every ADR body edit triggers Story A's per-edit governance + Story B's pre-commit pairing — the touched-entry currency is enforced edit-by-edit. The 43 untouched entries are migrated opportunistically as ADRs are touched for unrelated edits (not on a forced cadence). No mass-backfill commit is in scope; no time-based ceremony is added. Strict cadence was rejected because non-edit-driven ceremony misaligns with the developer-persona constraint "Wants speed without sacrificing quality" (JTBD-001 line 22 amendment 2026-05-05 explicitly covers change-set-level governance, not uniform-freshness ceremony).

Implementation work proceeds from this point per Stories A–E with the substance now ratified.

### In scope

- Implement the **PostToolUse:Edit/Write** hook + **pre-commit pairing** hook that together replace the programmatic compendium generator. The hook pair is the single mechanism that makes drift between `docs/decisions/*.md` bodies and `docs/decisions/README.md` structurally impossible (ADR-078 § "Architectural relationship between body and README under Option 9").
- Retire the programmatic generator + its drift-gate bats test + its PreToolUse refresh-discipline hook on the ADR-078 backstop schedule (see § Retirement sequencing).
- Amend ADR-077's Confirmation criteria (b), (g), (h) to reflect the move from "compendium = programmatic derivation" to "compendium = architect-authored living view".
- Cadence-driven migration: the new hook fires on every ADR body edit, so the 43 currently-non-canonical compendium entries migrate the next time each ADR is touched. **No mass backfill of the 43 entries is in scope.**
- Adopter opt-out: an `ARCHITECT_AUTO_UPDATE_COMPENDIUM=0` env var (per ADR-078 Confirmation criterion k) disables the PostToolUse hook for API-cost-sensitive adopter setups.

### Out of scope

- Mass backfill of the 43 non-canonical entries (explicitly cadence-driven per ADR-078).
- Programmatic regex-extension fix paths (ADR-078 Option 6 — user-rejected 2026-05-31; P339 lineage).
- Frontmatter `tldr:` cache (ADR-078 Option 7 — rejected).
- ADR body normalisation (ADR-078 Option 8b — rejected).
- New ADR-049 shim for the hook (the hook fires by Claude Code runtime, not via `$PATH`-resolved invocation — no shim needed).
- Story decomposition for Phase 2 (this RFC is single-phase per ADR-078).

## Anticipated story decomposition

Five stories deliver Phase 1. Story IDs are minted at `/wr-itil:manage-rfc 014 accepted` via `/wr-itil:capture-story` invocations; this RFC's `stories:` frontmatter array is refreshed at that time with the ordered execution sequence.

### Story A — Implement architect-compendium-update-entry.sh (PostToolUse hook)

- **Locus**: `packages/architect/hooks/architect-compendium-update-entry.sh` (new file).
- **Trigger**: PostToolUse matching Edit/Write events targeting `docs/decisions/*.md` (excluding `README.md`).
- **Mechanism**: hook spawns `claude -p` subprocess invoking the `wr-architect:agent` with: (1) the just-edited ADR body, (2) the current README entry for that ADR-ID (or empty string if new). The subprocess prompt instructs the architect to emit the updated compendium entry shape: `### ADR-NNN — <title>` h3 header + Status badge + Oversight badge + Supersedes link (if applicable) + `**Decides:**` line (one-or-two-sentence semantic TL;DR derived from `## Decision Outcome`) + `**Confirmation:**` line (truncated bullet join from `## Confirmation`) + `**Related:**` line (deduped ADR-ID list).
- **Application**: hook captures the architect's emit from the subprocess's JSON `.result` field; applies as `Edit` on `docs/decisions/README.md` (replacing existing entry block for that ADR-ID, or inserting in numeric-sort order under the appropriate section: in-force for `proposed` / `accepted`; historical for `superseded` / `rejected` / `deprecated`).
- **Staging**: hook stages the README change automatically so it lands in the same commit as the ADR body change.
- **Failure mode**: subprocess error (network, quota, model error) → hook logs failure + leaves README unchanged (degraded-mode-warn per ADR-078 Confirmation criterion l); subsequent commit attempt is denied by Story B's pairing check, surfacing the failure to the user for manual recovery.
- **Opt-out**: `ARCHITECT_AUTO_UPDATE_COMPENDIUM=0` (or equivalent `settings.json` key) suppresses the hook with stderr message directing the user to run `wr-architect-generate-decisions-compendium` manually.

**Acceptance criteria for Story A** (each verifiable by a bats fixture in `packages/architect/hooks/test/architect-compendium-update-entry.bats`):
1. Hook fires on Edit/Write to any `docs/decisions/*.md` body (not `README.md`).
2. Hook produces a stderr signal or log entry on every invocation (observable).
3. Hook emits the expected entry shape (h3 + Status badge + Oversight badge + Supersedes + Decides + Confirmation + Related).
4. Hook replaces existing entry in-place on ADR amendment (no duplicate entries).
5. Hook inserts entry in numeric-sort order on new ADR (correct in-force vs historical section).
6. Hook handles in-force → historical migration when an ADR transitions `accepted` → `superseded` (entry moves sections).
7. Hook subprocess failure leaves README unchanged + emits stderr; exit code does NOT block the body edit.
8. Hook opt-out via `ARCHITECT_AUTO_UPDATE_COMPENDIUM=0` self-suppresses with stderr message.
9. `packages/architect/hooks/hooks.json` registers the hook on PostToolUse:Edit + PostToolUse:Write matchers scoped to `docs/decisions/*.md` (excluding `README.md`).

### Story B — Implement architect-readme-pairing-check.sh (pre-commit hook)

- **Locus**: `packages/architect/hooks/architect-readme-pairing-check.sh` (new file).
- **Trigger**: PreToolUse:Bash matching `git commit` invocations (consistent with the existing `architect-compendium-refresh-discipline.sh` surface this hook replaces).
- **Assertion**: `git diff --cached --name-only` filtered for `docs/decisions/*.md` (excluding `README.md`) MUST be accompanied by `docs/decisions/README.md` in the same staged diff. If a commit edits any ADR body but does NOT also edit README, the hook DENIES the commit with a clear directive to re-run the edit (which would re-trigger Story A's PostToolUse hook + pair the README change).
- **Replaces**: ADR-077's Confirmation criterion (g) drift gate / bats test 2145 (Story C retires the bats; Story D retires the existing PreToolUse refresh-discipline hook). Story B is the replacement.

**Acceptance criteria for Story B** (each verifiable by a bats fixture in `packages/architect/hooks/test/architect-readme-pairing-check.bats`):
1. Hook denies commit when staged diff contains `docs/decisions/<NNN>-*.md` body change without `docs/decisions/README.md`.
2. Hook permits commit when staged diff contains both ADR body + README changes.
3. Hook permits commit when staged diff contains README change only (e.g. compendium-only edits).
4. Hook permits commit when staged diff contains no ADR-touching changes.
5. Hook denial message names the specific ADR file(s) missing pairing + the directive to re-run the edit.
6. Hook is registered in `packages/architect/hooks/hooks.json` as PreToolUse:Bash matching `git commit` (or sibling commit-shape surface).

### Story C — Retire generate-decisions-compendium.sh + bats test 2145

- **Locus**: `packages/architect/scripts/generate-decisions-compendium.sh` + `packages/architect/scripts/test/generate-decisions-compendium.bats` test 2145 (idempotency / drift gate).
- **Mechanism**: the script gains a stderr deprecation notice on every invocation citing ADR-078 (per ADR-078 Confirmation criterion j). The script remains callable as a backstop / migration tool for **one release cycle** post-Story A landing. After the backstop window (one minor-version cycle of `@windyroad/architect`), the script is removed entirely and its bats coverage retired.
- **Bats test 2145** (`committed compendium matches generator output`) is marked `skip` with a TODO referencing ADR-078's reassessment date as soon as Story A lands; the test is removed entirely with the script.
- **Backstop rationale**: gives adopters one release cycle to migrate from script-driven compendium regeneration to hook-driven. Per ADR-078 § "Architectural relationship between body and README under Option 9".

**Acceptance criteria for Story C**:
1. Script emits stderr deprecation notice on every invocation citing ADR-078 (criterion j).
2. Bats test 2145 marked `skip` with ADR-078 TODO reference.
3. Backstop window documented in `@windyroad/architect` CHANGELOG.
4. Removal commit deletes script + bats + CHANGELOG entry one minor cycle after Story A lands.

### Story D — Retire architect-compendium-refresh-discipline.sh

- **Locus**: `packages/architect/hooks/architect-compendium-refresh-discipline.sh` + its hooks.json registration + its bats fixtures.
- **Mechanism**: hook is deleted in the same commit it is removed from hooks.json; bats fixtures asserting refresh-discipline behaviour are removed. Story B's pairing-check hook is the structural replacement (every commit touching `docs/decisions/<NNN>-*.md` body must touch `docs/decisions/README.md`).
- **Gated on**: Story A landing AND Story B landing AND one session of dogfood-confirmed Story B firing correctly in this repo.
- **Rationale**: Option 9's PostToolUse hook makes drift structurally impossible at the edit boundary; the refresh-discipline PreToolUse hook becomes redundant. Keeping both runs PreToolUse twice on every commit + adds friction with no incremental safety.

**Acceptance criteria for Story D**:
1. `packages/architect/hooks/architect-compendium-refresh-discipline.sh` deleted.
2. `packages/architect/hooks/hooks.json` no longer registers the discipline hook.
3. `packages/architect/hooks/test/architect-compendium-refresh-discipline.bats` deleted.
4. One subsequent in-repo session does NOT hit drift between ADR bodies and README (Story A + B dogfood-pass).

### Story E — Verify ADR-077 confirmation criteria reflect as-shipped state + tighten residual aspirational language

- **Locus**: `docs/decisions/077-decisions-compendium-as-token-cheap-load-surface.proposed.md` § Confirmation.
- **Mechanism (per SQ-014-3 lock 2026-06-02)**: ADR-077's Confirmation criteria (b), (g), (h) were **already partially amended 2026-05-31 by the ADR-078 ratification** (the criteria already carry retirement annotations citing ADR-078 and naming the replacement Story-A/B/D surfaces). Story E is therefore a **verify-and-tighten** pass, not a fresh amendment:
  - Walk criteria (b), (g), (h) line by line; confirm each names the as-shipped enforcement surface (Story A PostToolUse hook for (b)+(h); Story B pre-commit pairing for (g)).
  - Strip any residual aspirational language (e.g. "Generator is idempotent" that is still present-tense rather than retirement-annotated; "matches generator output" that should be "matches as-emitted by Story A's hook"; "Skills regenerate after writing" that should be "PostToolUse hook fires on every body edit").
  - Replace any "is retired" stubs with concrete as-shipped enforcement-surface citations: criterion (b) → "Freshness-on-edit invariant enforced by Story A PostToolUse hook firing on Edit/Write to `docs/decisions/<NNN>-*.md`"; criterion (g) → "Pre-commit pairing assertion enforced by Story B PreToolUse:Bash hook on `git commit`"; criterion (h) → "Story A hook fires automatically; manual skill regeneration is the legacy-backstop path retired per SQ-014-2 one-minor-cycle window."
- **Order**: lands AFTER Stories A + B + D are in production (criteria must reflect as-shipped enforcement state, not aspirational). Lands BEFORE Story C's backstop-window-end (Story E's verify-and-tighten provides the SC reference point that Story C's removal commit cites).
- **Same-commit hygiene**: this amendment is itself an ADR body edit, so per Story B it must pair with a `docs/decisions/README.md` regeneration (Story A's hook handles this automatically on commit).

**Acceptance criteria for Story E**:
1. ADR-077 § Confirmation criteria (b), (g), (h) updated to reference the as-shipped Story A / Story B enforcement.
2. `docs/decisions/README.md` ADR-077 entry refreshed via Story A's hook (validates Story A is firing correctly on dogfood).
3. ADR-077's `amended:` frontmatter field updated.

## Sequencing

Stories land in dependency order, ratified at `/wr-itil:manage-rfc 014 accepted`:

```
Story A (PostToolUse hook + claude -p subprocess + Edit application + staging)
  ↓
Story B (pre-commit pairing check) — depends on Story A's README writes being correct
  ↓
[ dogfood window — one full in-repo session must exercise Stories A + B without manual recovery ]
  ↓
Story D (retire architect-compendium-refresh-discipline.sh) — depends on Story B landing
  ↓
Story E (amend ADR-077 confirmation criteria) — depends on Stories A + B + D in production
  ↓
[ backstop window — one minor-version release cycle ]
  ↓
Story C (retire generate-decisions-compendium.sh + bats test 2145) — depends on the backstop window
```

Story C is the latest because it removes the migration tool adopters may still call during the backstop window. Story E is the formal Confirmation-criteria amendment (load-bearing for ADR-077 conformance) and lands as the second-to-last commit.

## Test and eval coverage strategy

- **Bats fixtures**: each new hook gets a `packages/architect/hooks/test/<hook-name>.bats` covering the acceptance criteria above. Behavioural (asserts on hook output / side-effects / denial messages), not structural (no grep on hook source per `feedback_behavioural_tests`).
- **Claude `-p` subprocess testing**: Story A's hook spawns a real `claude -p` invocation per the AFK iteration-worker pattern (briefing entry "AFK iteration-workers use `claude -p` subprocess dispatch"). **SQ-014-1 lock 2026-06-02: PATH-priority fake-claude shim.** Bats fixtures stub the subprocess with a fixed-response `claude` shim placed first on `PATH` (adopter-portable per ADR-049 / JTBD-301). The `CLAUDE_P_AVAILABLE` real-subprocess CI lane is OUT of scope for Phase 1; it remains a follow-on path if real-subprocess integration coverage becomes necessary post-Phase-1.
- **Adopter-portable tests**: hook tests run from a fresh-install marketplace cache in an arbitrary adopter project root (ADR-049 / JTBD-301 promise). Fixtures must not reference `packages/architect/...` repo-relative paths.
- **Dogfood**: Phase 1 dogfoods on this same repo's `docs/decisions/` corpus — the first ratified `human-oversight: confirmed` substantive change post-Story-A landing triggers compendium update via the new hook, and Story B's pairing check catches any drift.

## JTBD anchors (per jtbd-lead verdict 2026-06-02)

- **Primary**: JTBD-001 (Enforce Governance Without Slowing Down) — the new hooks enforce compendium currency per-edit; JTBD-001's 2026-05-05 amendment explicitly covers "multi-commit coordinated changes governed at the change-set level".
- **Secondary**: JTBD-008 (Decompose a Fix Into Coordinated Changes) — RFC-014 IS the decomposition vehicle for Phase 1.
- **Tertiary** (optional): JTBD-002 (Ship AI-Assisted Code with Confidence) — compendium currency contributes to decision-load confidence per ADR-077.

Populate `jtbd: [JTBD-001, JTBD-008]` at `/wr-itil:manage-rfc 014 accepted`; consider JTBD-002 if tertiary anchoring is desired.

## Tasks

- [ ] **Story A** — Implement `packages/architect/hooks/architect-compendium-update-entry.sh` + `packages/architect/hooks/test/architect-compendium-update-entry.bats` + register in `packages/architect/hooks/hooks.json` (PostToolUse:Edit + PostToolUse:Write on `docs/decisions/*.md` excluding `README.md`). Acceptance criteria 1–9 above.
- [ ] **Story B** — Implement `packages/architect/hooks/architect-readme-pairing-check.sh` + `packages/architect/hooks/test/architect-readme-pairing-check.bats` + register in `packages/architect/hooks/hooks.json` (PreToolUse:Bash on `git commit`). Acceptance criteria 1–6 above.
- [ ] **Dogfood window** — one full in-repo session exercising Stories A + B without manual recovery. Document on the RFC's commit trail.
- [ ] **Story D** — Delete `packages/architect/hooks/architect-compendium-refresh-discipline.sh` + remove from `hooks.json` + remove `packages/architect/hooks/test/architect-compendium-refresh-discipline.bats`. Acceptance criteria 1–4 above.
- [ ] **Story E** — Amend ADR-077 Confirmation criteria (b), (g), (h) + bump `amended:` frontmatter. Acceptance criteria 1–3 above.
- [ ] **Backstop window** — one minor-version release cycle of `@windyroad/architect` with Stories A + B in production.
- [ ] **Story C** — Add stderr deprecation notice to `packages/architect/scripts/generate-decisions-compendium.sh` + mark bats test 2145 `skip` + (post-backstop) delete script + bats + CHANGELOG entry. Acceptance criteria 1–4 above.

## Commits

(maintained automatically — populated by the commit-message RFC trailer hook per ADR-060 Phase 1 item 12)

## Related

(captured via /wr-itil:capture-rfc; expand at next /wr-itil:manage-rfc invocation)

- **P337** — driving problem ticket; § Fix Strategy enumerates the 5-story anticipated decomposition.
- **ADR-078** — ratified architectural decision (Option 9, human-oversight: confirmed 2026-05-31); this RFC is its delivery vehicle.
- **ADR-077** — the compendium ADR; confirmation criteria (b), (g), (h) scheduled for amendment in Story E.
- **ADR-060** — Problem-RFC-Story framework; this RFC scopes a multi-commit fix per JTBD-008.
- **P339** — substance-confirm-before-build prior occurrence on the same ADR-078 (lineage; informs how this RFC's stories should land — each at architect-confirmed substance before implementation).
