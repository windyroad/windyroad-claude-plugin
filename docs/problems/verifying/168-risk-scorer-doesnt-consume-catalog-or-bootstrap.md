# Problem 168: Risk-scorer doesn't consume `docs/risks/` catalog or bootstrap from `.risk-reports/`

**Status**: Verification Pending
**Reported**: 2026-05-04
**Fix Released**: 2026-05-04 (commits ab73328 + af5447c + 8edaf7b; @windyroad/risk-scorer minor bump in `.changeset/wr-risk-scorer-p168-consume-catalog-and-bootstrap.md` ready for next release)
**Priority**: 3 (Low) — Impact: 3 x Likelihood: 1
**Effort**: XL (re-rated 2026-05-04: M → XL post-architect-review — 8 distinct edits across new ADR-058, ADR-047 amendment, new bootstrap-catalog skill, install-updates Step 6.5 extension, pipeline.md consume-catalog protocol, create-risk flag extension, orchestrator auto-invoke, wipe pass; ~2 commits per ADR-014; spans 2+ iterations)
**WSJF**: 0.75 (Severity 3 × Known Error multiplier 2.0 / Effort XL divisor 8)

## Description

User direction (2026-05-04, follow-up to P167): the risk-scorer agent should:

(a) **Bootstrap-from-empty**: when `docs/risks/` is empty (or has only README + TEMPLATE), walk `.risk-reports/` to derive and document the risk classes previously surfaced. One-time pass, transparent to the user — same job ADR-047 Phase 3 deferred.

(b) **Consume-catalog on every per-action assessment**: READ `docs/risks/` first, filter to risks applicable to THIS action, assess whether documented controls are in effect for this action, compute residual against the **same 4/Low appetite**, append any newly-conceived risk classes back to the catalog (ADR-047 Phase 2 back-channel).

Today the agent does **neither**. Every commit/push/release/external-comms assessment regenerates risk classes from scratch. The gap-analysis Explore agent (invoked from P167's session) found ~327 unique risk titles across 181 reports clustering into 12-14 themes — order-of-magnitude duplication of the same risk-class derivation effort, with no carry-forward.

User's framing: this is wasted effort plus a missed-risk-class hazard. The agent might omit a risk it has surfaced before because it didn't think of it this assessment.

The catalog framing landed in `RISK-POLICY.md` commit `9e339d0` (new `## Risk Catalog` section) — the policy now describes the consume-catalog and bootstrap-from-empty workflow explicitly. But no agent implements it.

User direction also includes **wiping the existing 6 R<NNN> entries before bootstrap** so:
- The bootstrap behaviour can be tested on an empty catalog.
- The existing entries (authored under pre-correction conservatism — particularly RC2 controls undercredited per P167) are replaced with bootstrap-derived entries that apply the new `## Control Composition` rule (RISK-POLICY.md commit `9e339d0`).

This ticket **supersedes** P167's original Phase 1-3 plan (manual R007-R011 authoring + R002/R005 extensions + R001-R006 re-rate). The bootstrap approach replaces all three.

## Symptoms

- 6 standing risks in `docs/risks/`, but ~327 unique risk titles across 181 `.risk-reports/` — register coverage is ~1.8% of surfaced risk classes (RC1 from P167, empirically confirmed).
- Per-action assessments regenerate risk classes from scratch on each invocation; no continuity across sessions.
- Same risk classes surface repeatedly (e.g. "ADR drift", "hook regression", "register drift") with the agent re-deriving the assessment each time.
- Risk classes that haven't been documented can be missed in a later assessment if the agent doesn't think of them.
- Authoring 6 standing risks manually under pre-correction conservatism produced residuals that mostly read above appetite (R001:9, R002:8, R003:5, R004:6, R005:12, R006:8) — gap analysis from P167 attributes this to RC1+RC2 (sparse coverage + undercredited controls), both of which the bootstrap approach is positioned to address structurally.

## Workaround

**Current state IS the workaround**: agent regenerates risk classes from scratch on every per-action assessment. Operationally functional — gates still fire, residuals still compute, the missed-risk-class hazard is the latent failure mode rather than a hard break. Wasted-effort cost is the daily friction; missed-class hazard is the gate-correctness risk. No interim mitigation beyond status quo until the bootstrap + consume-catalog implementation lands per ADR-058 (forthcoming, see ## Fix Strategy).

## Impact Assessment

- **Who is affected**: plugin-maintainer (every commit / push / release pays the regeneration cost), tech-lead persona reading risk reports (sees the same risk classes re-derived inconsistently across assessments), solo-developer persona governance flow (per-action assessments under-leverage the persistent catalog and may miss risk classes).
- **Frequency**: every per-action risk assessment — typically multiple per session. 181 cumulative reports observed in this project alone.
- **Severity**: Medium — wasted compute + cognitive load every assessment, plus the missed-risk-class hazard. False-negative on a risk class the agent "forgets to think of" can let an action proceed when it should have been gated.
- **Analytics**: count of distinct risk titles per `.risk-reports/` entry vs catalog size; ratio measures the regeneration-vs-reuse efficiency.

## Root Cause Analysis

The risk-scorer agent (`packages/risk-scorer/agents/pipeline.md`) reads pipeline state and emits `RISK_SCORES:` + `RISK_REGISTER_HINT:` on every per-action assessment, but does NOT read `docs/risks/` to consume the catalog and does NOT bootstrap the catalog from `.risk-reports/`. The pure-scorer contract (ADR-015, ADR-042) means the agent's tool grant is `Read + Glob` only — it cannot write the catalog itself, so the autonomy boundary deferred to ADR-047 is the load-bearing design question.

The catalog framing in `RISK-POLICY.md` `## Risk Catalog` (commit `9e339d0`) describes the consume-catalog + bootstrap workflow at policy layer, but no agent / skill / hook implements it. Existing surfaces:

- `RISK_REGISTER_HINT:` (ADR-056 3-column shape with risk-slug dedupe key) — the surface the pipeline already emits when register-worthy risks fire. Currently consumed post-loop by orchestrators that may invoke `/wr-risk-scorer:create-risk` with prefill.
- `/install-updates` Step 6.5 (ADR-047 Phase 1) — scaffolds empty `docs/risks/` directory + README + TEMPLATE when `RISK-POLICY.md` is present. Does NOT populate.
- `/wr-risk-scorer:create-risk` skill — interactive authoring flow for hand-curated entries. No prefill from hint.

ADR-047 Phase 2 (back-channel: pipeline writes new entries when reports identify register-worthy risks) and Phase 3 (one-time backfill from `.risk-reports/` corpus) were explicitly deferred for "architect-design depth (autonomy boundary, dedupe-by-risk-name, evidence-log appending, marker-driven backfill gating)" — those concerns are the substantive design questions architect review (below) resolves.

### Investigation Tasks

- [x] Re-rate Priority and Effort — **DONE 2026-05-04**: Effort M → XL (architect breakdown: 8 distinct edits). WSJF re-computed 1.5 → 0.75.
- [x] Architect review: bootstrap-from-empty + consume-catalog design contracts — **DONE 2026-05-04** (see `## Architect Review` below).
- [x] JTBD review: persona-job mapping + persona-specific outcomes + autonomy trade-off — **DONE 2026-05-04** (see `## JTBD Review` below).
- [x] Decide: wipe scope — **DONE 2026-05-04** (architect Verdict I + JTBD Verdict J4 align): wipe in a separate commit AFTER bootstrap skill + consume-catalog edits land and validate; user-direction discharged via two-pass validation (run on populated catalog as smoke test, then wipe + re-bootstrap, compare coverage).
- [x] Decide: agent ownership — **DONE 2026-05-04** (architect Verdict G): bootstrap → new `/wr-risk-scorer:bootstrap-catalog` skill; consume-catalog → extend `wr-risk-scorer:pipeline` agent; auto-write → orchestrator-side auto-invocation of `/wr-risk-scorer:create-risk` with prefill flags (preserves pure-scorer contract).
- [x] Decide: ADR shape — **DONE 2026-05-04** (architect Verdict H): NEW sibling ADR (ADR-058 or next free slot); one-line forward-pointer amendment to ADR-047's `## Out of Scope` section. P167's "ADR-047 amendment" verdict applies only to the narrower gap-analysis-methodology concern, NOT to P168's behaviour-design scope.
- [ ] Author ADR-058: "Consume-catalog and bootstrap-from-reports for the standing-risk register" — covers verdicts B/C/D/E/F/G as Decision Outcome. ~300-400 lines.
- [ ] Implement `/wr-risk-scorer:bootstrap-catalog` skill — SKILL.md + REFERENCE.md + bats fixture. ~250 lines + tests.
- [ ] Implement consume-catalog protocol in `packages/risk-scorer/agents/pipeline.md` — hybrid filter (slug-token-match primary, free-form judgement fallback) + residual reconciliation (per-action residual in `RISK_SCORES:`, catalog baseline in risk-item block). ~40-line edit + behavioural test.
- [ ] Extend `/wr-risk-scorer:create-risk` skill — accept `--slug` and `--prefill` flags for orchestrator-driven prefilled invocation. ~30-line edit.
- [ ] Wire orchestrator auto-invocation of `/wr-risk-scorer:create-risk` on `RISK_REGISTER_HINT:` per ADR-042 Rule 5 / ADR-013 Rule 5 (policy-authorised silent proceed under the catalog framing in `RISK-POLICY.md`).
- [ ] Extend `/install-updates` Step 6.5 — auto-trigger bootstrap when catalog is empty AND `RISK-POLICY.md` is present + `.risk-reports/` is non-empty. ~20-line edit + bats fixture extension.
- [ ] Amend ADR-047 — one-line forward pointer in `## Out of Scope` naming the new ADR as Phase 2/3 successor.
- [ ] Wipe pass (separate commit, AFTER 1-7 land and validate): retire R001-R006 → re-run bootstrap → compare coverage → ADR-014 commit.
- [ ] Create reproduction test: register-coverage assertion — bootstrap output must produce ≥80% of `.risk-reports/` themes with a corresponding R<NNN> entry. Lives as Confirmation criterion in ADR-058.
- [ ] Test bootstrap on populated catalog (smoke test) AND on empty catalog (post-wipe).

## Architect Review

Architect verdict: **ISSUES FOUND** (substantive design review; XL scope; ~8 distinct edits across 2 commits).

**A. Bootstrap firing surface** — A4 (new `/wr-risk-scorer:bootstrap-catalog` skill) + A6 (auto-trigger from `/install-updates` Step 6.5). Mirrors ADR-036 dual-surface scaffold pattern. Rejects A1 (SessionStart violates ADR-040 read-mostly), A2 (pipeline is pure-scorer per ADR-015), A3 (marker complexity ADR-047 explicitly avoided), A5 (conflates create-risk with bootstrap, same discoverability gap as the 99% miss rate ADR-047 fixed).

**B. Dedupe mechanism** — reuse the ADR-056 risk-slug as the dedupe key. NOT a new architectural decision; the slug IS the dedupe-by-risk-name primitive ADR-047 deferred. Bootstrap walks `.risk-reports/*.md` once, computes slug per ADR-056 rules, emits one R<NNN> per unique slug. Theme-clustering is post-hoc human reading, NOT the dedupe primitive.

**C. Threshold for "warrants standing entry"** — ANY slug seen ≥1 time. NO frequency or severity floor. User direction (verbatim ADR-047 line 18) is unconditional. Low-frequency-high-severity classes are exactly what the catalog must NOT miss. Noisy entries are cheaper to retire than gaps are to fill. Quality control is the Control Composition re-rate discipline, not a creation threshold.

**D. Citation back to `.risk-reports/`** — REQUIRED. Bootstrap-derived entries MUST carry inline `## Source Evidence` block citing originating reports. ADR-026 grounding pattern. Provenance is load-bearing — without it, future reviewers can't tell hand-authored vs bootstrap-derived. Citations may go dangling at 7-day report cleanup; that's acceptable (grounding-at-time-of-write is what ADR-026 requires).

**E. Consume-catalog protocol** — hybrid filter (slug-token-matching against diff content as primary; free-form judgement fallback for non-matching slugs). Residual reconciliation: report THIS-action's residual in `RISK_SCORES:` (per-action by contract); log catalog's lifetime-baseline residual + this-action's residual separately in the report body's risk-item block. Tiny extension to `pipeline.md` lines 79-87 — add `Catalog baseline:` line citing R<NNN>.

**F. Newly-conceived classes back to catalog** — PRESERVE existing `RISK_REGISTER_HINT:` surface as the agent's contribution. Do NOT auto-write from pipeline (breaks ADR-015 pure-scorer contract). The orchestrator that consumes the hint may auto-invoke `/wr-risk-scorer:create-risk` with prefill flags under ADR-013 Rule 5 + ADR-042 mandate (catalog framing IS the policy authorisation; ADR-044 framework-resolution boundary applies). Concrete: extend `/wr-risk-scorer:create-risk` with `--slug` and `--prefill` CLI flags; orchestrator calls programmatically; existing AskUserQuestion-driven authoring path preserved for human invocation.

**G. Agent ownership split**:
- Bootstrap → new `/wr-risk-scorer:bootstrap-catalog` skill (per A4) + auto-trigger from `/install-updates` Step 6.5 (per A6).
- Consume-catalog → extends `wr-risk-scorer:pipeline` agent prompt (mechanical edit; no new agent).
- Auto-write → orchestrator-side auto-invocation of `/wr-risk-scorer:create-risk` with prefill flags (mechanical extension; no new skill).

Different invocation cadences (one-shot per project lifetime / per-action / per-pipeline-run-with-hint) → distinct surfaces per ADR-015 skill/agent boundary.

**H. ADR shape** — NEW sibling ADR (ADR-058 or next free slot). NOT in-place amendment of ADR-047. ADR-047's frame is narrowly the directory-scaffold (Phase 1); promoting Phase 2 + Phase 3 in-place would require rewriting Context/Decision-Drivers/Considered-Options/Decision-Outcome/Confirmation/Reassessment — effectively a new ADR with the same number. ADR-047's Reassessment Criteria (line 178) already anticipates Phase 2 as a future ADR. P167's "amend ADR-047" verdict was for narrower gap-analysis-methodology scope; doesn't extend to P168. ADR-047 gets only a one-line forward-pointer in `## Out of Scope`.

**I. Wipe scope** — split. Wipe R001-R006 in a SEPARATE transition step AFTER ADR-058 + bootstrap skill + consume-catalog edits land and validate. Reasoning: wipe-before risks a window of zero coverage if implementation takes 2 iterations (violates ADR-042 never-release-above-appetite principle applied to assessment surface). Wipe-after enables two-pass validation: (1) run bootstrap on populated catalog as smoke test, diff against R001-R006; (2) `git mv R001-R006.active.md → R001-R006.retired.md`; (3) run bootstrap on empty catalog; (4) compare coverage. User direction (P168 description line 26-27) is discharged; only timing differs.

**Effort sizing**: **XL.** Aggregate breakdown (architect's per-edit M-equivalent):
- ADR-058 authoring: ~half-day (M alone)
- bootstrap-catalog skill (SKILL.md + REFERENCE.md + templates + bats): ~full-day (M alone)
- pipeline.md consume-catalog (filter + reconciliation + behavioural test): ~half-day (S-M)
- create-risk flag extension + orchestrator wire: ~half-day (S-M)
- install-updates Step 6.5 extension + bats: ~quarter-day (S)
- wipe + re-bootstrap validation: ~quarter-day (S)
- Aggregate: 5×M-equivalent across 2+ iterations. **Recommend scope-expansion AskUserQuestion** (ADR-044 Category 2 deviation-approval) — current ticket Effort "M (deferred)" was significantly under-sized.

## JTBD Review

JTBD verdict: **PASS** — change serves JTBD-001 (Enforce Governance Without Slowing Down) primary, JTBD-202 (Run Pre-Flight Governance Checks Before Release or Handover) secondary, JTBD-006 (Progress the Backlog While I'm Away) co-secondary (AFK-safety binding constraint), JTBD-007 (Keep Plugins Current Across Projects) touched at bootstrap surface. No persona gap; no job gap.

**J1. Persona-job mapping** — JTBD-001 primary (missed-risk-class hazard IS a JTBD-001 desired-outcome failure: "Every edit reviewed against relevant policy before it lands" — solo-developer/JTBD-001 line 16). JTBD-202 secondary (catalog IS the structured/auditable/ISO-citable artefact JTBD-202 calls for: "Assessments produce a structured, auditable report" — tech-lead/JTBD-202 line 19). JTBD-006 co-secondary, NOT applicable-only — `/wr-itil:work-problems` invokes risk-scorer every loop iteration; bootstrap that prompts for input would silently halt the AFK loop, violating JTBD-006 line 18 "Decisions that would normally require my input are resolved using safe defaults". JTBD-201 audit-trail is **tangential not tertiary** — `docs/risks/` is governed by JTBD-202 audit constraints, not JTBD-201 incident-response constraints.

**J2. Persona-specific desired outcomes**:
- **plugin-maintainer**: cognitive-load reduction first (JTBD-001 "manually police AI output" pain in solo-developer/persona.md:21), latency second, hit-rate as success metric (target: catalog hit-rate >70% on second-and-subsequent assessments).
- **tech-lead**: coverage completeness with traceable provenance — ISO 31000/27001 reviewers care about (a) coverage of risk universe, (b) provenance/citation, (c) change history. Bootstrap source-evidence block + git history on `docs/risks/` discharge (b) and (c) directly; coverage is the harder problem this design solves.
- **solo-developer (per-action gates)**: correct-block-rate (true positives) with low false-positive friction. JTBD-001 60-second budget (line 18) is the friction ceiling. Consume-catalog must improve true-positive rate WITHOUT inflating false positives.

**J3. Missed-risk-class hazard classification** — BOTH JTBD-001 compliance failure AND JTBD-202 audit-trail failure, but JTBD-001 is load-bearing. Mechanism: agent omits known class → wrong gate verdict → governance step skipped (JTBD-001 violation) → register understates risk surface (JTBD-202 audit consequence). Fix the JTBD-001 mechanism (consume-catalog) and the JTBD-202 audit consequence is fixed for free. Implementation effort goes to consumption pipeline, NOT separate audit-export pipeline.

**J4. Wipe-and-rebuild scope** — JTBD-001 alignment reset (NOT a JTBD-201 audit-trail break). JTBD-201 is incident audit (`I###` namespace), not register audit; `docs/risks/` is governed by JTBD-202's traceable-provenance requirements which git history discharges naturally. R001-R006 encode pre-correction conservatism; keeping them is JTBD-001 misalignment. **Recommendation**: do the wipe in this ticket as an atomic commit pair (1: wipe pre-Control-Composition entries citing P167 + policy correction; 2: bootstrap from `.risk-reports/` corpus) — makes the rebuild legible to JTBD-202 due-diligence readers via `git log`. **Caveat**: `rg 'R00[1-6]' docs/problems/` pass before wipe to detect dangling references in closed tickets. (Note: architect Verdict I prefers wipe in a separate transition AFTER ADR-058 lands and validates; JTBD verdict aligns on the wipe being in scope, just timing differs — defer to architect's two-pass-validation timing.)

**J5. Auto-write vs surface-only** — AUTO-WRITE (with discoverability via commit message + `RISK_REGISTER_HINT:` echo). JTBD-006 line 29 "Trusts the agent to make routine decisions" is decisive — adding a register entry when per-action assessment surfaced it for the first time IS a routine decision. Surface-only re-introduces P168's exact failure mode (orchestrator doesn't act → class forgotten → next assessment regenerates). Mitigations against JTBD-202 audit-trail-gap: (a) auto-written entries cite originating per-action assessment + gate-action context + matching `.risk-reports/` files; (b) auto-write commits in separate boundary from triggering action; (c) `RISK_REGISTER_HINT: added R<NNN> <title>` echo preserves discoverability. **Note**: architect Verdict F holds the auto-write at the orchestrator side (preserves pipeline pure-scorer contract); JTBD endorses the auto-write *behaviour* — orchestrator-side execution discharges both verdicts.

**J6. Bootstrap one-time-backfill UX** — install-updates time (Phase 3 rides Phase 1's scaffold step), with a fallback nudge at first per-action assessment for users who skipped install-updates. Install-updates Step 7 final report fits JTBD-007 line 19 "The process reports what changed" naturally — bootstrap line item ("Risk register: bootstrapped 12 entries from 164 reports across 14 themes") fits cleanly. Lazy-bootstrap-at-first-assessment is JTBD-006-hostile (164-report theme-derivation inside hook-triggered assessment blows the 60-second budget). On-demand skill invocation is JTBD-005-shaped but P168 isn't an on-demand-assessment job, it's register-maintenance. **Recommended layering**: install-updates Phase 3 primary surface; per-action assessment carries gentle nudge ("Risk register is empty; run `/install-updates` to bootstrap from `.risk-reports/`") if user invoked risk-scorer before install-updates — preserves AFK-safety (nudge doesn't halt loop).

**Persona-centring**: implementation centres on solo-developer JTBD-001 desired outcomes, with JTBD-006 (AFK-safety) and JTBD-202 (audit-grade output shape) as binding constraints. NOT split across personas. JTBD-001 is the load-bearing concern; everything downstream (audit shape, AFK safety, install-updates surfacing) is a constraint on HOW the JTBD-001 fix lands. Splitting along persona lines (e.g., separate tech-lead-only `/wr-itil:export-risk-register` skill) would be premature; defer to a separate ticket if real tech-lead pull emerges.

## Smoke-Test Finding (2026-05-04, post-Commit-2)

Pre-wipe rg scan + corpus inspection ran during the architect-verdict-I2 smoke-test pass. Two findings defer Commit 3 (wipe + re-bootstrap) to a future user-driven session:

1. **Dangling-reference density**: `rg 'R00[1-6]' docs/problems/` surfaced cross-references to R001 and R005 from at least 5 tickets (P158 closed, P102 verifying, P110 verifying, P162 open, P159 verifying). Wiping without first annotating those tickets would break the audit-trail-readable cross-link surface JTBD verdict J4 caveat anticipated. The annotation pass is itself a separate ADR-014-grain commit (~5 ticket file edits with the canonical "register reset 2026-05-04 per P167; see git history" note).

2. **Corpus is mostly pre-ADR-056**: of 164 `.risk-reports/*.md` files, **only 1 carries a structured `RISK_REGISTER_HINT:` block** (the post-ADR-056 hint format the bootstrap-catalog skill consumes deterministically). The remaining 163 reports require LLM-walking per the SKILL.md fallback path (parse risk-item descriptions, compute slugs per ADR-056 rules) — a multi-hundred-tool-call pass impractical to run inline in a single agent session.

**Net effect of wiping now**: replace 6 hand-curated R001-R006 entries (under pre-correction conservatism but referenced by 5+ tickets) with ~1 deterministically-derived entry plus 0-12 LLM-walked entries depending on how aggressively a future bootstrap pass walks the 163 unhinted reports. This is a NET LOSS of register coverage in the short term — the architect-verdict-I2 two-pass validation assumed the bootstrap output would COVER R001-R006's surfaced classes; the smoke-test finding refutes that assumption for this corpus at this maturity.

**Commit 3 deferred**. Reinstate triggers (any of):

- **Corpus matures**: 30+ days post-ADR-056 release accumulates a critical mass of hint-bearing reports (e.g. ≥20 unique slugs surfaced via `RISK_REGISTER_HINT:`). At that point, the bootstrap's deterministic path covers the catalog without LLM-walk dependency.
- **User-driven LLM-walk pass**: user invokes `/wr-risk-scorer:bootstrap-catalog` interactively in a dedicated session, walks the 163 unhinted reports, and validates the output covers R001-R006's surfaced classes before authorising the wipe.
- **Dedicated bootstrap script**: `packages/risk-scorer/scripts/bootstrap-catalog.sh` (per ADR-049 plugin-bundled scripts; deferred from Commit 2) extends the SKILL.md's deterministic path to handle pre-ADR-056 reports via heuristic slug derivation. This is itself an XL extension of ADR-059 and warrants its own ADR / iteration.

The deferral does NOT prevent ADR-059 Commit 1 + Commit 2 from being released — the runtime contract is complete; only the historical-backfill validation is deferred. The held changeset (`docs/changesets-holding/wr-risk-scorer-p168-consume-catalog-and-bootstrap.md`, commit `e18c4fa`) remains held until the wipe-or-defer decision is finalised.

**Update 2026-05-06 (RFC-001 retro)**: Commit 3 itself shipped as `8edaf7b` (see `## Fix Released`); the still-deferred sub-component — heuristic-slug derivation for pre-ADR-056 reports (referred to as "Commit 3'") — is now tracked at change-set level under `docs/rfcs/RFC-001-pipeline-consume-catalog-and-bootstrap-from-reports.verifying.md` § Deferred Scope. Reinstate triggers above remain authoritative; RFC-001 references them rather than duplicating.

## Fix Strategy

Synthesised from architect + JTBD verdicts. Two-commit shape per ADR-014 grain; XL multi-iteration scope.

**Commit 1 — design + steady-state surfaces** (~5 paths):

1. **ADR-058** (next free ADR slot): "Consume-catalog and bootstrap-from-reports for the standing-risk register" — Decision Outcome covers architect verdicts B/C/D/E/F/G; Decision Drivers cite JTBD-001 primary + JTBD-006/202 binding; Considered Options cite the rejected A1/A2/A3/A5 alternatives; Confirmation criteria cite the bats fixture targets + the ≥80% theme-coverage assertion.
2. **ADR-047 amendment** — one-line forward pointer in `## Out of Scope` naming ADR-058 as Phase 2/3 successor.
3. **`packages/risk-scorer/agents/pipeline.md`** — extend with consume-catalog protocol (hybrid filter — slug-token-match primary, free-form judgement fallback) + residual reconciliation (`Catalog baseline:` line in risk-item block citing R<NNN>; `RISK_SCORES:` carries per-action residual). Pure-scorer contract preserved.
4. **`packages/risk-scorer/skills/create-risk/SKILL.md`** — accept `--slug` and `--prefill` flags for orchestrator-driven prefilled invocation per architect Verdict F. Existing AskUserQuestion-driven authoring path preserved for human invocation.
5. **Orchestrator auto-invocation** of `/wr-risk-scorer:create-risk` on `RISK_REGISTER_HINT:` consumption sites — wherever the hint is consumed today (post-loop in pipeline-driven flows), add the auto-invoke path under ADR-013 Rule 5 + ADR-042 Rule 5 (catalog framing IS the policy authorisation per ADR-044 framework-resolution boundary).

**Commit 2 — bootstrap surface + install-updates auto-trigger** (~3 paths):

6. **New `/wr-risk-scorer:bootstrap-catalog` skill** — SKILL.md + REFERENCE.md + templates + bats fixture. Walks `.risk-reports/*.md`, computes ADR-056 slug per report, emits one R<NNN>-`<slug>`.active.md per unique slug with `## Source Evidence` block citing originating files. Idempotent (file-existence test); user-invocable on-demand; consumed by install-updates auto-trigger.
7. **`scripts/repo-local-skills/install-updates/SKILL.md` Step 6.5 extension** — auto-trigger `/wr-risk-scorer:bootstrap-catalog` when catalog is empty (only `README.md` + `TEMPLATE.md` present from ADR-047 Phase 1 scaffold) AND `RISK-POLICY.md` is present AND `.risk-reports/` is non-empty. Final-report integration shows bootstrap rows alongside scaffold rows. Per-sibling consent gate from Phase 1 covers this auto-trigger (no new consent surface).
8. **Bats fixture extensions** — for both new skill and install-updates Step 6.5, covering: empty-catalog bootstrap; populated-catalog smoke test; idempotency (re-run produces zero diff); slug-collapse correctness; source-evidence block presence; ≥80% theme-coverage assertion.

**Commit 3 — wipe + re-bootstrap validation pass** (separate commit per ADR-014, AFTER commits 1-2 land and validate; per architect Verdict I two-pass timing):

9. `rg 'R00[1-6]' docs/problems/` — detect dangling references; annotate or preserve IDs in rebuild as needed.
10. `git mv docs/risks/R00{1..6}-*.active.md → docs/risks/R00{1..6}-*.retired.md` with retire-reason "superseded by bootstrap-derived entries (ADR-058) post pre-Control-Composition reset".
11. Run `/wr-risk-scorer:bootstrap-catalog` on now-empty catalog. Compare bootstrap-derived coverage against the retired R001-R006 set. If gaps surface, file follow-up tickets against ADR-058 Reassessment Criteria.
12. `chore(risks): wipe pre-Control-Composition register entries (P167 alignment)` + `feat(risks): bootstrap register from .risk-reports/ corpus (closes P168)` — atomic two-commit pair per JTBD Verdict J4.

## Dependencies

- **Blocks**: (P167's investigation tasks for R007-R011 / R002+R005 extensions / R001-R006 re-rate are all superseded by this ticket; P167's status itself is not blocked but its substantive remaining work is delegated here)
- **Blocked by**: (none — design work can begin immediately; the wipe step depends on the bootstrap behaviour being designed first)
- **Composes with**: P167 (driver — captures the symptom this ticket addresses), P033 (created the register; this ticket is its Phase 2/3 promote-to-active), P034 (cross-project risk-report aggregation; sibling), P102 (register invocation surface), P110 (pipeline back-channel hint — this ticket is the implementation), ADR-047 (Phase 2 + Phase 3 deferred to follow-up; this ticket promotes both).

## Related

- `RISK-POLICY.md` — `## Risk Catalog` section (commit `9e339d0`) describes the consume-catalog + bootstrap workflow this ticket implements.
- `RISK-POLICY.md` — `## Control Composition` section (commit `9e339d0`) is the rule the bootstrap will apply when computing residuals for derived entries.
- `docs/problems/167-risk-register-aggregate-reads-as-dont-ship.open.md` — driver / parent ticket. P167's Update section names this ticket as the substantive successor.
- `docs/decisions/047-install-updates-scaffolds-governance-artefacts.proposed.md` — Phase 2 (back-channel) and Phase 3 (one-time backfill) explicitly deferred there; this ticket promotes both to active work per user direction.
- `.risk-reports/` — 181 concrete reports that the bootstrap pass will walk.
- Sibling Explore agent gap-analysis output (P167's session, 2026-05-04) identified 12-14 distinct themes; that analysis is a useful starting point for the bootstrap deduplication design.
- Captured via /wr-itil:capture-problem; substantive design ticket — superseder of P167's original Phase 1-3 plan.

## RFCs

| RFC | Status | Title |
|-----|--------|-------|
| RFC-001 | verifying | Pipeline consume-catalog and bootstrap-from-reports — multi-commit retrofit |

## Fix Released

Released across three coordinated commits per ADR-059 + user direction 2026-05-04:

- **Commit 1** (ab73328): pipeline.md consume-catalog protocol + create-risk `--slug` / `--prefill` flag-driven path + 30 bats. Pure-scorer contract preserved (`Read + Glob` only).
- **Commit 2** (af5447c): bootstrap-catalog skill + install-updates Step 6.5.1 auto-trigger + 29 bats. On-demand surface for one-shot bootstrap.
- **Commit 3** (8edaf7b): WIPE R001-R006 + TEMPLATE.md + README.md + install-updates risk-register templates + broken markdown references in P158/P159 (per user direction "FFS WIPE THE RXXX risks ... THEY ARE WRONG"). Wrote `packages/risk-scorer/scripts/extract-risks-from-reports.sh` (~270 lines, two-phase: Phase 1 deterministic extraction from RISK_REGISTER_HINT bullets; Phase 2 LLM-walk of unhinted reports via bootstrap-catalog SKILL.md Step 1b). Wrote 17 behavioural bats. Generated R007 (first bootstrap-derived entry from this repo's actual corpus). Generated docs/risks/README.md. Reinstated the held P168 changeset. Entry shape lives in the create-risk skill + extractor (per user direction "There shouldn't be a template in the directory, because that should be part of the risk creation/capture skill that the extractor uses").

@windyroad/risk-scorer minor bump in `.changeset/wr-risk-scorer-p168-consume-catalog-and-bootstrap.md`. Awaiting user verification.

User-verifiable behaviour:
- Run `/wr-risk-scorer:assess-wip` against any change. Verify pipeline emits `Catalog match:` and `Catalog baseline:` lines in risk-item blocks. Verify `CATALOG_HIT_RATE: matched=N missed=M` line appears.
- Run `wr-risk-scorer-extract-risks-from-reports --dry-run` to observe corpus extraction without writes.
- Run `/wr-risk-scorer:bootstrap-catalog` to walk the unhinted .risk-reports/ corpus via Phase 2 LLM-walk and populate docs/risks/ with derived entries.
- Run `/install-updates` against a sibling project with RISK-POLICY.md + .risk-reports/ but empty docs/risks/. Verify Step 6.5 bootstrap fires; Step 7 final report shows bootstrap row.
