---
status: "proposed"
date: 2026-05-30
human-oversight: confirmed
oversight-date: 2026-05-31
amended: 2026-05-31
decision-makers: [Tom Howard]
consulted: []
informed: []
reassessment-date: 2026-08-30
supersedes: []
---

# Compendium Decision Outcome — Progressive Disclosure via MADR-Canonical + Semantic Fallback + Authoring Validator

## Context and Problem Statement

ADR-077 introduced `docs/decisions/README.md` as the architect-agent's "token-cheap load surface for routine compliance review". P337 (driver) surfaced an empirical gap: **43 of 75 ADRs (57%) render in the compendium with no Decision Outcome content at all** — only title, status badge, oversight badge, supersession links, and (if present) related-ADR refs. The reader has Confirmation tests but no statement of what was decided.

Root cause locus: `packages/architect/scripts/generate-decisions-compendium.sh` line 124 (`get_chosen` function) extracts only lines opening with `Chosen` (typically MADR's `Chosen option: "..."` tag). ADRs that use `## Decision Outcome` followed by prose without the `Chosen option:` tag render with no decision content. This is half the corpus.

The user surfaced the gap by direct reading of `docs/decisions/README.md` post the P334 portability fix shipping: *"is there enough information in here to follow the decisions without having to consult the full ADR file. It doesn't look like there is."*

The framing question is **how to progressively disclose decision content in the compendium** — what's the right shape that gives the architect agent enough context for routine compliance review without ballooning the load surface.

Best-practices research (2026-05-30):

- **log4brains** (popular ADR static-site generator): index renders Date + Title + Status only; users click through to per-ADR pages for decision content. Suited for human readers with cheap navigation; ill-suited for AI agents whose "click through" is a Read tool call that defeats the load-cheap purpose.
- **MADR canonical** (the template this project uses): `Chosen option: "{title}", because {justification}` opens Decision Outcome. This IS the canonical single-sentence TL;DR shape. The existing generator extractor targets it correctly for the 32 ADRs that follow MADR-canonical form.
- **"Mature orgs reduce reliance on discipline by structure"** (MADR research finding 2026-05-30): "Mature engineering organizations reduce reliance on discipline by embedding it into structure — making the right behavior easier and architectural risk more visible." Argues against author-backfill alone; favors CI gates / validators.

## Decision Drivers

- P337 surfaced gap is load-bearing: 57% of corpus is non-functional for routine compliance review. ADR-077's confirmation criterion (a) is satisfied formally but defeated empirically for the majority of entries.
- Token-cost ceiling: the compendium MUST stay dominantly under ~15k tokens. Current is ~10k. Any extraction strategy that grows it past ~15k pushes the "routine load" cost into the un-cheap zone.
- AI-agent consumer pattern: the compendium IS the load surface. Click-through (Read tool call per ADR) is the explicit anti-pattern. Every entry must carry enough content for the agent to follow the decision without follow-up reads.
- Generator idempotency: ADR-077 confirmation criterion (b) — running the generator twice produces byte-identical output. Any extraction strategy must remain deterministic.
- Structure over discipline: prefer validator-enforced authoring conventions over reliance on remembering to backfill 75 existing ADRs. Catch the regression at author time, not at review time.
- MADR canonical alignment: the template this repo uses has a recommended Decision Outcome opening shape. Going against it would require inventing a new convention and abandoning MADR alignment.
- Validator friction risk: a too-strict Phase 2 validator becomes the next P327-class friction surface. Architect advisory 2026-05-30 — Phase 2 SHOULD fail-open with a warning (not deny-write) when framing-prose-detection regex misfires on legitimate "After weighing options A and B, we chose X" shapes.
- Cadence-over-discipline for Phase 3 opportunistic upgrades: no automatic cadence = doesn't happen (memory feedback `feedback_automatic_cadence_or_it_doesnt_happen.md`). The opportunistic-upgrade trigger MUST be embedded in an existing cadence-driven surface (the `/wr-architect:review-decisions` ratification drain is the natural locus).

## Considered Options

1. **First sentence of Decision Outcome (semantic boundary)** — extract the first sentence (terminated at `. ` / `.\n` / `! ` / `? `); never truncate mid-sentence. Falls back to second sentence if first is framing prose. Programmatic.
2. **Whole Decision Outcome section, no cap** — emit the full `## Decision Outcome` body; accept uneven growth. Programmatic.
3. **Author-controlled `<!-- @compendium-include start/end -->` markers** — ADR body marks the region the generator should extract; defaults to first sentence when markers absent. Programmatic.
4. **MADR-TL;DR discipline, retroactive** — require every ADR's Decision Outcome to lead with a `Chosen option:` single sentence (MADR-canonical form); backfill 43 non-conforming existing ADRs as a one-time cost. Programmatic with author discipline.
5. **Hybrid section-aware extraction with section-level token budget** — measure tokens per section; include whole section if under budget, fall back to first sentence if over. Programmatic.
6. **MADR-canonical primary + first-sentence fallback + fail-open authoring validator + cadence-embedded opportunistic upgrade** — four-layered programmatic-heuristic approach: generator extracts MADR-canonical `Chosen option:` line when present; falls back to first sentence with framing-prose advance regex; new authoring validator fails-OPEN warning; cadence-embedded opportunistic upgrade in review-decisions drain. **Initially drafted as the recommended option in this ADR's 2026-05-30 first commit; superseded by user direction 2026-05-31 in favour of Option 9.**
7. **LLM-cached `tldr:` frontmatter field** — author runs LLM at write time to produce a single-sentence TL;DR; cached in frontmatter; generator extracts that field programmatically. Drift risk between cached field and edited body.
8. **LLM-emit-TL;DR-in-architect-verdict** — when architect reviews an ADR (already happens on every write per architect gate), agent emits the TL;DR as part of its verdict; PostToolUse hook captures and applies. Three sub-shapes: (8a) cache in frontmatter `tldr:`; (8b) normalize body's `## Decision Outcome` opening to MADR-canonical form (existing generator picks up); (8c) write README entry directly.
9. **(Chosen, user direction 2026-05-31) Architect-on-edit writes README entry directly + auto-fire-on-every-edit** — PostToolUse:Edit/Write on `docs/decisions/*.md` invokes the architect agent with the just-edited body + the current README entry for that ADR; architect emits the updated entry shape (Title + Status + Oversight + `**Decides:**` line + Confirmation line + Related); hook applies architect's output as `Edit` on README; staging is automatic so README change lands in the same commit as the ADR edit. **No programmatic generator. No frontmatter cache. No body normalization. No fail-open validator. No cadence-embedded upgrade step.** Drift is structurally impossible: every body edit triggers a README edit in the same hook chain. Existing 43 non-canonical ADRs migrate the next time each is touched (cadence-driven naturally — every edit IS the cadence).

## Decision Outcome

Chosen option: **"Option 9 — Architect-on-edit writes README entry directly + auto-fire-on-every-edit"**, because it eliminates drift by structural construction (every body edit triggers a same-hook README write), gives every entry LLM-quality semantic TL;DR without regex-heuristic limitations, dissolves the body-authoritative-vs-compendium-derived two-store coordination problem, and migrates the existing 43 non-canonical ADRs naturally through the edit cadence with no backfill obligation.

**Amendment history**:

- **2026-05-30 first commit (`5196e3d`)**: chose Option 6 (programmatic-heuristic with fail-open validator and cadence-embedded upgrade). The `human-oversight: confirmed` marker was applied in this commit per the `/wr-architect:create-adr` Step 5 "born-confirmed write" mechanism. **The ratification claim attached to this commit was bogus**: the Step 5 AskUserQuestion fired bundled draft-acceptance with substance-confirmation (*"ADR-078 review pass — does the problem statement + Decision Outcome (Option 6) capture the situation?"*). The user answered *"Yes, capture as-written"* — confirming the draft was well-written, NOT authorising Option 6 as the substantive choice. The marker mechanism wrote `human-oversight: confirmed` based on that click, not on substance-approval. So commit `5196e3d` shipped a marker that claimed human ratification of Option 6 that never actually occurred. The architect agent reads the marker as proof of ratification per ADR-066 contract; for the period between `5196e3d` and the amendment commit `875569a`, ADR-078 was being treated as ratified by the architect-agent infrastructure on a foundation it did not have.
- **2026-05-31 amendment (commit `875569a` and this body amendment)**: user direction surfaced the bogus ratification — *"I never approved the scripted extraction. You are supposed to run decisions by me"* — and authorised Option 9 explicitly via direct prose direction (*"8 sounds good, but why does it need to insert the tldr into frontmatter? Can it just update the readme?"* + *"we minimise drift if on every ADR edit, we update the readme"* + *"Yes, amend"*). The `oversight-date` was updated to 2026-05-31 and an `amended: 2026-05-31` frontmatter field added. **The current `human-oversight: confirmed` marker reflects the 2026-05-31 substance-confirm event by user direction, NOT the 2026-05-30 draft-acceptance event.** Captured ticket: P339 (substance-question-shape gap at create-adr Step 5) + companion P340 (born-confirmed marker mechanism gap — the marker can be written on draft-acceptance without verifying substance-confirmation; the substance-confirmation pattern requires prose briefing + each option as a selectable option + no ID-as-explainer + informed-decision-without-external-doc-lookup per user direction 2026-05-31).

One implementation phase replaces the three phases of the original Option 6:

**Phase 1 (single phase — architect-on-edit hook)**:

- New PostToolUse hook `packages/architect/hooks/architect-compendium-update-entry.sh` triggers on Edit/Write events targeting `docs/decisions/*.md` (excluding `README.md`).
- The hook spawns a `claude -p` subprocess invoking the architect agent with the just-edited ADR body + the current README entry for that ADR (or empty string if the ADR is new). Prompt asks the agent to emit the updated compendium entry shape: Title, Status badge, Oversight badge, supersession ref if applicable, `**Decides:**` line (one-or-two-sentence semantic TL;DR derived from the body's `## Decision Outcome` section), `**Confirmation:**` line (truncated bullet join from `## Confirmation`), `**Related:**` line (deduped ADR-ID list from the body's `## Related` section and inline mentions).
- Hook captures the architect's emitted entry from the subprocess's JSON `.result` field; applies it as `Edit` on `docs/decisions/README.md` (replacing the existing entry block for that ADR-ID, or inserting a new one in numeric-sort order under the appropriate section: in-force / historical).
- Hook stages the README change automatically so it lands in the same commit as the ADR body change.
- The hook is the SINGLE mechanism — there is no programmatic generator, no frontmatter cache, no body normalization step, no fail-open validator, no cadence-embedded upgrade in the ratification drain.
- The hook is published as part of `@windyroad/architect`; adopter installs receive it via the standard plugin install path. No new ADR-049 shim is required because the hook does not need a `$PATH`-resolved invocation surface — it runs as a hook by the Claude Code runtime.
- Existing 43 non-canonical ADRs migrate the next time each is touched (the hook fires on every edit; cadence-driven naturally).
- Retiring infrastructure:
  - `packages/architect/scripts/generate-decisions-compendium.sh` — retire as load-bearing primary path. Keep as a backstop / migration tool for one release cycle (callable via `wr-architect-generate-decisions-compendium`), then remove. While present, the script's output is no longer ADR-077 confirmation criterion (b) idempotency-bound; it produces a best-effort programmatic render that may differ from the architect-authored entries.
  - `packages/architect/scripts/test/generate-decisions-compendium.bats` — retire idempotency assertion (criterion 2 in the existing bats) once the generator is removed. Drift-gate test 2145 (`committed compendium matches generator output`) gets replaced by the new "every ADR body change in a commit is accompanied by a README change" pre-commit assertion (criterion (g) replacement below).
  - `architect-compendium-refresh-discipline.sh` PreToolUse refresh-discipline hook — retire (it currently denies commits when README is out of sync with bodies; under Option 9 the new PostToolUse hook keeps them in sync by construction).

**Drift safety under Option 9**:

- Pre-commit hook `packages/architect/hooks/architect-readme-pairing-check.sh` asserts: `git diff --cached --name-only` filtered for `docs/decisions/*.md` MUST be accompanied by `docs/decisions/README.md` in the same diff. If a commit edits any ADR body but does NOT also edit README, the hook denies the commit with a clear directive to re-run the edit (which would re-trigger the PostToolUse hook). This is the replacement for ADR-077's confirmation criterion (g).

**Architectural relationship between body and README under Option 9**:

- The per-ADR body remains authoritative (ADR-031 preserved). The architect derives the compendium entry from the body each time the body changes.
- The compendium is no longer "generated from bodies via deterministic programmatic extraction" (ADR-077's original framing). It is "architect-authored per-edit, derived from bodies via LLM extraction".
- Offline reproducibility: re-running architect on every ADR body produces the compendium. Slow (~$1-2 across the whole 76-ADR corpus per run) but possible.
- ADR-077 confirmation criteria amendment (companion change in this same commit):
  - (b) "Generator is idempotent — two runs produce byte-identical output" → **retired**. Replaced by **freshness-on-edit invariant**: every body edit triggers a same-commit README edit.
  - (g) "Committed compendium matches generator output (CI drift gate)" → **retired**. Replaced by **pre-commit pairing assertion**: every commit that edits a `docs/decisions/*.md` body MUST also edit `docs/decisions/README.md`.
  - (h) "Skills regenerate the compendium after writing an ADR" → **retired**. Replaced by the PostToolUse hook firing automatically.
- These three criterion changes formalise the move from "compendium = generated derivation of bodies" to "compendium = architect-authored living view, body remains authoritative".

**Cost model**:

- Per ADR edit: one `claude -p` subprocess invocation against the architect agent. Estimated ~$0.05-0.20 per edit.
- Per typical session: 5-10 ADR edits = ~$0.50-$2.00. Equivalent to ~1-2% of the per-iter LLM cost the AFK orchestrator already runs.
- Per-corpus full re-emit (offline reproducibility check, model migration): 76 ADRs × ~$0.10 = ~$7.60. Bounded.

## Consequences

### Good

- P337 closes structurally: drift between body and compendium becomes impossible (same-hook coupling) rather than detectable-and-fixable.
- LLM-quality TL;DR per entry: no regex-heuristic limitations on sentence-boundary detection, framing-prose advance, or MADR-tag presence. Architect renders entries with semantic understanding of the Decision Outcome.
- Existing 43 non-canonical ADRs migrate naturally via the edit cadence — no mass backfill, no opportunistic-upgrade-in-ratification-drain step, no author-discipline obligation.
- Single mechanism end-to-end: PostToolUse hook + architect agent. No two-store coordination (body + frontmatter cache, or body + README), no programmatic-vs-LLM split, no validator + fallback + cadence chain.
- ADR-031 (body authoritative) preserved: the architect derives the entry from the body; the body is the source of truth.
- Compendium token cost bounded by architect prompt budget: the agent is instructed to emit a one-or-two-sentence `**Decides:**` line; entries stay roughly the same size as the existing canonical-path entries.
- Pre-commit pairing assertion replaces drift gate test 2145 with a structurally simpler check: a commit touching `docs/decisions/*.md` body MUST also touch `docs/decisions/README.md`. Cheap to test; impossible to bypass without explicit intent.
- Eliminates three pieces of existing infrastructure that become unnecessary: the programmatic generator script + bats, the refresh-discipline PreToolUse hook, and the planned Phase 2 fail-open validator. Net code reduction.

### Neutral

- The architect agent is invoked on every ADR body edit (a new automatic trigger). Mechanical / category-4-silent-framework per ADR-044; no user prompt; the hook fires without interaction.
- Cost-per-edit is ~$0.05-0.20 LLM call — bounded but non-zero. Comparable to ~1-2% of typical AFK-iter LLM spend per session.
- Compendium becomes "architect-authored derived view" rather than "programmatically-generated derived view". The deriv-relationship is preserved; the deriv-mechanism changes from awk/regex to LLM.

### Bad

- Offline determinism is lost: re-running the architect across the corpus can produce slightly different prose for each entry across runs (LLM non-determinism). Mitigation: the body is authoritative; the compendium is a derived view; if the user wants byte-stable reproducibility they can capture a known-good compendium and version it.
- Model migration cost: if the architect model changes (e.g. Sonnet → Opus → next-gen), the full 76-ADR corpus needs re-emission to render in the new model's voice. Bounded cost (~$7.60 per full corpus re-emit) but real.
- Architect agent availability: if the architect's LLM call fails (network, quota, model error), the PostToolUse hook's failure-mode needs definition. Open question: does the hook leave the README stale + warn (degraded mode), or block the edit (fail-closed)? Implementation iter resolves; default leans degraded-mode-warn per "fail-open" precedent from the abandoned Option 6.
- New automatic LLM invocation surface: every ADR edit fires a Claude API call. Adopters with API-cost-sensitive setups may need an opt-out mechanism. Implementation iter adds an env-var or settings opt-out.
- Existing 43 non-canonical ADRs continue to render via the OLD compendium (generated 2026-05-30 with the programmatic extractor) until each is touched. Acceptable: the migration cadence is the edit cadence; nothing forces the user to touch ADRs they don't have other reason to touch.

## Confirmation

Concrete, testable criteria — every item must be verifiable by a bats fixture or empirical command:

(a) **PostToolUse hook fires on ADR edit**: a bats fixture edits a `docs/decisions/*.md` body via the Write tool surface; observes the hook firing (stderr signal or log file); confirms `docs/decisions/README.md` is also modified.

(b) **Architect emits the entry shape**: a bats fixture (using a stubbed architect subprocess or `claude -p` integration test) confirms the architect's emit conforms to the expected shape — `### ADR-NNN — <title>` h3 header, Status badge, Oversight badge (if applicable), Supersedes link (if applicable), `**Decides:**` line, `**Confirmation:**` line, `**Related:**` line.

(c) **README pairing assertion enforced at commit**: pre-commit hook `architect-readme-pairing-check.sh` denies commits where any staged `docs/decisions/*.md` body change lacks an accompanying `docs/decisions/README.md` change. Bats fixture: stage a body change without README change → commit denied with clear directive.

(d) **README entry replaced in-place on amendment**: when an existing ADR body is amended, the architect emits the updated entry; the hook applies it as `Edit` (not insert) to replace the existing entry block. Bats fixture asserts no duplicate entries appear.

(e) **New ADR entry inserted at correct sort position**: when a new ADR body is written, the hook inserts the entry in numeric-sort order under the appropriate section (in-force for `proposed` / `accepted`; historical for `superseded` / `rejected` / `deprecated`). Bats fixture asserts ordering.

(f) **Status-based section migration**: when an ADR transitions from `accepted` to `superseded` (or any in-force → historical transition), the hook moves the entry from the in-force section to the historical section in the same edit. Bats fixture asserts migration.

(g) **Existing 43 non-canonical ADRs migrate via edit cadence**: a bats fixture amends one of the currently-empty-Decision-Outcome ADRs (e.g. ADR-002); confirms the architect re-emits the entry with a populated `**Decides:**` line.

(h) **Token cost bound**: post-migration, `wc -w docs/decisions/README.md` × 1.3 ≤ 15000. Confirm in a bats fixture against the architect-authored corpus state.

(i) **Pre-commit hook is the drift-safety primary**: assert the new pairing-check hook is registered in `packages/architect/hooks/hooks.json` as a pre-commit (or PreToolUse:Bash matching `git commit`) hook.

(j) **Programmatic generator deprecation pathway**: `packages/architect/scripts/generate-decisions-compendium.sh` carries a stderr deprecation notice on every invocation citing this ADR; the script's bats test for idempotency (criterion 2 in the existing bats) is marked `skip` with a TODO reference to this ADR's reassessment date.

(k) **Adopter opt-out mechanism**: an `ARCHITECT_AUTO_UPDATE_COMPENDIUM=0` env var (or equivalent settings.json key) disables the PostToolUse hook for adopters with API-cost-sensitive setups. Bats fixture confirms the hook self-suppresses when the opt-out is set; degrades to "user must run `wr-architect-generate-decisions-compendium` manually" with stderr message.

(l) **Failure-mode behaviour**: when the architect subprocess fails (network error, quota exhaustion), the hook logs the failure + leaves the README unchanged (degraded mode) rather than blocking the body edit. A subsequent commit attempt is denied by the pre-commit pairing check, surfacing the failure to the user for manual recovery.

## Pros and Cons of the Options

### Option 1 — First sentence of Decision Outcome (semantic boundary)

- Good: Modest token growth (~3k); no author-discipline backfill needed.
- Good: Sentence boundary respects natural prose structure.
- Bad: Doesn't address the "framing prose" problem (ADRs opening with "This ADR addresses..." emit framing as Decides).
- Bad: No structural enforcement for new ADRs — the gap re-opens with every non-canonical authoring.

### Option 2 — Whole Decision Outcome section, no cap

- Good: Lossless; maximum information per entry.
- Bad: Token growth uneven; some ADRs have multi-paragraph Decision Outcomes that balloon the compendium past the ~15k ceiling.
- Bad: Defeats "routine-load cheap" principle for the long-Decision-Outcome ADRs.

### Option 3 — Author-controlled `<!-- @compendium-include -->` markers

- Good: Per-ADR token-cost tuning; maximum author control.
- Bad: Requires retroactive marker addition across 75 ADRs (the backfill cost the structure-over-discipline principle argues against).
- Bad: Markers are an invented convention; not aligned with MADR or any common ADR practice.
- Bad: Fallback to first sentence still needed when markers absent — adds rather than replaces complexity.

### Option 4 — MADR-TL;DR discipline, retroactive

- Good: Tightest compendium — one MADR-canonical line per ADR.
- Good: Aligns with MADR best-practice "if you want to reduce even further, simply state the chosen option and explain why".
- Bad: Requires backfill of 43 ADRs (one-time but real cost).
- Bad: Relies on author discipline going forward; structure-over-discipline principle argues against.
- Bad: No structural enforcement mechanism named.

### Option 5 — Hybrid section-aware extraction with section-level token budget

- Good: Maximally adaptive — short sections in full, long sections truncated.
- Bad: Most complex generator (three extractors, depth params, per-section budget tracking).
- Bad: Token-per-section accounting is non-trivial to implement deterministically.
- Bad: Same framing-prose problem as Option 1 within the truncated path.

### Option 6 — MADR-canonical primary + first-sentence fallback + fail-open authoring validator + cadence-embedded opportunistic upgrade (SUPERSEDED 2026-05-31)

- Good: Closes P337 by adding extractor coverage; every ADR renders some Decision Outcome.
- Good: MADR alignment preserved (canonical primary path).
- Good: Programmatic generator preserves idempotency.
- Good: Structural enforcement (validator) for new ADRs; structure-over-discipline.
- Good: Fail-open validator avoids P327-class friction.
- Good: No mass backfill required; existing corpus handled by fallback.
- Bad: Drift is detected-and-fixable rather than structurally impossible — body and compendium remain two stores.
- Bad: Regex-heuristic limitations on sentence-boundary detection (abbreviations, URLs) and framing-prose advance regex (incomplete coverage of opening forms).
- Bad: Three-phase implementation (generator + validator + cadence-embedded upgrade) — multiple moving parts to land.
- Bad: Initially recommended by the agent at draft time without user-direction sign-off (P339 captures this surface gap); user direction 2026-05-31 superseded in favour of Option 9.

### Option 7 — LLM-cached `tldr:` frontmatter field

- Good: LLM-quality TL;DR per entry.
- Good: Generator stays programmatic (cached field is deterministic to extract).
- Good: Idempotency preserved.
- Bad: Cache drift between frontmatter `tldr:` and edited Decision Outcome body — needs a drift detector.
- Bad: Author runs LLM at write time as an extra explicit step (or via a hook).
- Bad: New frontmatter field — adopters' tooling may not handle it.

### Option 8 — LLM-emit-TL;DR-in-architect-verdict (three sub-shapes)

- Good: Reuses architect agent's existing LLM round (PreToolUse review verdict).
- Good: No new explicit author step.
- 8a (frontmatter cache): same drift risk as Option 7.
- 8b (body normalization): elegant; body becomes self-describing; existing generator works unchanged. But still two writes per edit (body norm + generator regen).
- 8c (direct README write): simplest mechanism but breaks ADR-077's generated-derivation framing without addressing drift.

### Option 9 — Architect-on-edit writes README entry directly + auto-fire-on-every-edit (CHOSEN, user direction 2026-05-31)

- Good: Drift is structurally impossible (same-hook coupling between body edit and README write).
- Good: LLM-quality TL;DR per entry — no regex heuristic limitations.
- Good: Single mechanism end-to-end — PostToolUse hook + architect agent.
- Good: ADR-031 (body authoritative) preserved.
- Good: Existing 43 non-canonical ADRs migrate naturally via edit cadence.
- Good: Eliminates programmatic generator, refresh-discipline hook, planned Phase 2 validator, Phase 3 ratification-drain upgrade — net code reduction.
- Good: Cost-per-edit is bounded (~$0.05-0.20); per-session is ~1-2% of typical AFK-iter LLM spend.
- Bad: Offline determinism lost; LLM is non-deterministic.
- Bad: Model migration cost: full corpus re-emit per architect-model change (~$7.60).
- Bad: Failure mode needs definition (architect subprocess error → degraded-mode-warn or block? — leans degraded per existing fail-open precedent).
- Bad: New automatic LLM-invocation surface; adopters with API-cost sensitivity need opt-out (env var).

## Reassessment Criteria

Revisit this decision when any of:

- Compendium token cost reaches ~15k (the routine-load ceiling) — re-evaluate whether the architect's per-entry prompt budget needs tightening (e.g., enforce a single-sentence `**Decides:**` line instead of the current one-or-two-sentence allowance).
- Architect-subprocess cost-per-session exceeds ~$5 for a typical 10-edit session — re-evaluate whether the hook should batch or defer, or whether some edit classes (e.g. cosmetic frontmatter-only changes) should opt-out of triggering.
- Architect model change degrades entry quality across the corpus — re-evaluate whether a corpus-wide re-emit needs to be triggered automatically, or whether a freeze-on-current-model strategy is preferable.
- A new ADR-tooling best-practice emerges (e.g., a community-standard programmatic-extraction format that delivers comparable quality without LLM cost) — re-evaluate whether the architect-on-edit mechanism should defer to a programmatic surface for routine extractions.
- Drift gate pre-commit pairing assertion fires false-positives more than once per session — re-evaluate the hook scope (e.g. exclude purely-comment changes to ADR bodies from the pairing requirement).
- Adopter-portability concerns surface: the PostToolUse hook fires `claude -p` which assumes a Claude Code subscription/auth context — re-evaluate whether adopters without that auth context need a fallback (e.g. the programmatic generator stays as the fallback path for unauthenticated environments).
- The compendium load-surface purpose itself shifts (e.g., agents start receiving the full per-ADR set instead of the compendium for routine review) — re-evaluate whether the compendium remains the right load surface or should be deprecated.

Default reassessment: 3 months from approval (2026-08-30).

## Related

- **P337** — driver capture; surfaced by user direct observation 2026-05-30. This ADR closes P337 on Phase 1 + 2 shipping.
- **ADR-077** — Generated decisions compendium as token-cheap load surface. This ADR amends ADR-077's Confirmation criterion (a): every ADR renders Decision Outcome content via canonical-primary / fallback extraction.
- **P334** — sibling generator fix just shipped (BSD/GNU awk substr Unicode portability). Both touch `generate-decisions-compendium.sh`. Phase 1 implementation iter should rebase on `@windyroad/architect@0.12.2` to compose cleanly.
- **P327** — recent friction surface that motivated the fail-open advisory; informs Phase 2 validator UX.
- **ADR-049** — `$PATH`-resolved shim discipline; preserved in Phase 2 via `wr-architect-validate-adr-shape` shim.
- **ADR-064** — Decision-delegation contract; preserved (user pins substance via the AskUserQuestion confirm at Step 5).
- **ADR-066** — Born-confirmed marker; this ADR ships with the marker after the Step 5 user-confirm pass.
- `packages/architect/scripts/generate-decisions-compendium.sh` line 124 — locus of Phase 1 generator change.
- `packages/architect/scripts/test/generate-decisions-compendium.bats` — locus of new bats fixtures (Confirmation criteria b, c, g, h).
- Future: `packages/architect/scripts/validate-adr-shape.sh` — Phase 2 authoring validator script.
- Future: `packages/architect/bin/wr-architect-validate-adr-shape` — Phase 2 ADR-049 shim.
- Future: `packages/architect/hooks/architect-adr-shape-validator.sh` — Phase 2 PreToolUse:Write hook.
- Future: `packages/architect/skills/review-decisions/SKILL.md` Step N amendment — Phase 3 opportunistic-upgrade offer.

### Best-practices research citations (2026-05-30)

- **MADR canonical Decision Outcome form** — `Chosen option: "{title}", because {justification}` per <https://adr.github.io/madr/>; existing extractor targets this shape.
- **log4brains minimalist index pattern** — Date + Title + Status; click-through model per <https://thomvaill.github.io/log4brains/adr/>. Inapplicable for AI-agent load surface where "click-through" is a Read tool call.
- **"Mature orgs reduce reliance on discipline by structure"** — MADR-context research finding 2026-05-30 via WebSearch `MADR architecture decision records decision outcome TL;DR summary discipline`. Source: <https://reflectrally.com/architecture-decision-logs/>. Argues for validator-enforced authoring conventions over backfill.
- **MADR minimal-form recommendation** — *"if you want to reduce even further, simply state the chosen option and explain why you picked it in a short single sentence"* per the MADR template guidance. Validates Option 4's discipline target, although structure-over-discipline argues against mandatory backfill — Option 6 takes the disciplined form as the canonical primary path while the fallback handles non-conforming entries gracefully.
