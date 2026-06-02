# Problem 152: No pressure or nudge for keeping documentation up to date — README narrative drifts from package behaviour silently because no gate, hook, or advisory applies pressure on doc-content currency

**Status**: Verifying
**Reported**: 2026-05-02
**Priority**: 15 (High) — Impact: Significant (3) x Likelihood: Almost certain (5)
**Effort**: L — net-new ADR codifying the doc-currency pressure mechanism (JTBD-anchored anchor for what the doc must express + how drift is detected) + at-least-one detector / advisory script per ADR-040 declarative-first precedent + possibly a follow-on hook (R6-gated per ADR-044 escalation pattern, like P131 Phase 1 / Phase 2). Bounded if the JTBD-anchored mechanism reuses existing infrastructure (the project already has `docs/jtbd/<persona>/` per-job files, advisory script precedent in `packages/retrospective/scripts/check-tickets-deferred-cause.sh` and `packages/itil/scripts/check-problems-readme-budget.sh`); XL if the generalization to adopter-project surfaces (marketing HTML, public docs, changelog narrative) is in-scope for the same ticket.

**WSJF**: (15 × 1.0) / 4 = **3.75**

> Surfaced 2026-05-02 by user during a `/wr-itil:work-problems` AFK loop iter 2 (P151 working its known-error transition): *"there is nothing that provide pressure or nudges for us keeping the documentation up to date. In this case it's the readme files, but for other projects it could be marketing HTML pages. The problem is that the docs become out of date very quickly. When looking at solutuons for this, leverage the JTBD pages so we can help the reader understand the value through the jobs it helps them do"*. Sibling concern to P137 (semantic ID-leak in published artifacts) and P151 (executable-path-leak in published artifacts) — all three are about adopter-facing content quality, but on three different axes: P137 is **semantic correctness** (does the cited ID resolve to what the prose claims?), P151 is **executable correctness** (does the bash command actually run?), P152 is **currency** (does the prose still describe what the package actually does?). They compose; none substitutes for the others.

## Description

The project has a well-developed pressure stack for keeping CODE in sync with documented decisions and contracts:

- `wr-architect:agent` enforces architecture compliance against `docs/decisions/` ADRs.
- `wr-jtbd:agent` enforces JTBD alignment against `docs/jtbd/` job files.
- `wr-risk-scorer:pipeline` scores commit/push/release risk against `RISK-POLICY.md`.
- `wr-style-guide:agent` enforces visual styling conformance against `docs/STYLE-GUIDE.md`.
- `wr-voice-tone:agent` enforces user-facing copy conformance against `docs/VOICE-AND-TONE.md`.
- The TDD enforcement hook gates implementation edits on red/green test state.
- The just-shipped `itil-changeset-discipline.sh` hook (P141, iter 1 of this AFK loop) gates `git commit` on the staged set actually carrying a changeset entry when publishable surface drifts.
- `manage-problem` Step 0 reconciliation script (`packages/itil/scripts/reconcile-readme.sh`) checks that `docs/problems/README.md` stays in sync with on-disk ticket inventory; drift halts the skill until reconciled.

This stack is dense, well-thought-out, and effective for code drift — every commit goes through a stack of gates that catch divergence early. But there is **NO equivalent stack for doc-content drift**. The documentation that ships to npm under each `@windyroad/*` package — package-level READMEs, plugin-level READMEs, top-level project README, plugin marketplace listing copy — has no analogous gate, no analogous detector, no analogous advisory script, no analogous nudge. It is hand-maintained, drift-prone, and currently relies entirely on memory + occasional manual review.

The user's framing — *"leverage the JTBD pages so we can help the reader understand the value through the jobs it helps them do"* — is load-bearing for the fix shape. JTBD framing is not just internal-persona accounting; it is the lens through which an adopter (human or AI agent) can quickly see "this skill exists because of THESE jobs". If documentation is anchored on JTBD, two things become possible:

1. **The doc's content has a stable source of truth.** A skill's README section can be derived from / cross-checked against the JTBD job files that motivate the skill. Drift becomes detectable: if the JTBD changes (job removed, persona changed, evidence updated) and the README does not, the gate fires.
2. **The reader sees value, not just feature description.** Currently every plugin's README leads with "what the skill does"; a JTBD-anchored README leads with "what jobs this helps the reader do". The plugin-user persona's defining constraint (low context on repo internals; AI agent as primary interface) is exactly the audience that benefits most from job-framed value description.

The same shape generalises beyond READMEs:

- **Adopter project marketing HTML** — public-facing copy on a SaaS / OSS landing page drifts from the actual product feature set. Same currency problem, different surface.
- **Adopter project changelog narrative** — release notes in `CHANGELOG.md` or release-page copy drift from what the release actually shipped. Sibling currency problem.
- **Adopter project public docs** — `docs/` markdown / Docusaurus / etc. drifts from current product behaviour.

The ticket's core scope is `@windyroad/*` plugin READMEs (the user's primary observation point); the generalization to adopter contexts is in-scope for the ADR design phase (architect should decide whether the mechanism is plugin-internal or cross-project per ADR-002 / ADR-003 / ADR-049 plugin-boundary class).

## Symptoms

- A `@windyroad/itil` adopter reads the package's npm description / README and sees a feature list that may be: (a) accurate as of the README's last commit, (b) accurate as of the README's last `chore: version packages` release, (c) wholly accurate as of right now — the adopter has no way to tell which.
- A skill within a plugin gains a new step / amendment / sub-block (e.g. P124 mtime-selection regression recovery in `manage-problem` Step 2 substep 7, P144 ADR-048 recovery procedure, P141 changeset-discipline hook just shipped) but the plugin's package-level README is not updated to reflect the new behaviour. The README continues to describe the prior shape. There is no detector, no gate, no nudge.
- A skill is renamed or split (P071: `manage-problem list / review / work / <NNN> <status>` split into `list-problems` / `review-problems` / `work-problem` / `transition-problem`) and the package README's invocation examples drift. There is no detector that says "the README cites `manage-problem list` but that subcommand is deprecated".
- An ADR is amended (e.g. ADR-013 amended by ADR-044 framework-resolution boundary) and the plugin READMEs that cite ADR-013 are not refreshed. Adopter agents reading those READMEs in `node_modules/` see the un-amended framing.
- A JTBD job file is rewritten (e.g. JTBD-006 reframed; JTBD-101 added) and the plugins serving that job are not refreshed. The README still describes the old job framing.
- The `@windyroad/*` ecosystem ships 11+ plugins on npm; a sibling-project survey (P033 evidence) shows 99% of adopter projects have at least one drift between README narrative and actual installed behaviour, with no detection in place to surface the gap.
- The doc-currency-drift failure mode is **silent** — there is no commit-time, push-time, or release-time signal. The drift accumulates between releases; release-time is when adopters re-encounter it via `npm install`, but by then the drift has already shipped.

## Workaround

None at the source level. Adopter-side workarounds:

- Adopter could compare the plugin's README against the actual SKILL.md / hook scripts / agent definitions in `node_modules/@windyroad/<plugin>/` to detect drift manually. Heavyweight, brittle, requires knowledge of the plugin internals — exactly the context the plugin-user persona is defined as lacking.
- Adopter could rely on changelog narrative and ignore the README. Loses the README's intended audience-framing value.
- Adopter could maintain a private fork of the plugin with corrected docs. Defeats the plugin model.

Source-side temporary workarounds (until P152 fix lands):

- Reviewer scans READMEs ad-hoc on each release. Manual, drift-rate-vs-release-rate likely > 1 so drift wins.
- Pre-release checklist enforces README review. Manual; the user's framing of P152 is precisely "there is nothing that provide pressure or nudges" — a checklist is not a nudge mechanism.
- Periodic `manage-problem review` retros could surface README staleness as a meta-observation. Already de facto happens but inconsistently.

None of these are reasonable as a long-term fix. The core observation is that the project has invested heavily in pressure mechanisms for code drift and zero in pressure mechanisms for doc-content drift, leaving an asymmetric audit posture where one side of the work is gated end-to-end and the other side is hand-maintained.

## Impact Assessment

- **Who is affected**: The **plugin-user persona** (`docs/jtbd/plugin-user/persona.md`) — every adopter project reading any `@windyroad/*` plugin's README, plugin marketplace listing, or top-level project README. Generalises (per the user's framing) to adopter projects' own marketing HTML / public docs / changelog narrative — same persona constraints (low context on internals; AI agent as primary interface) make doc currency more critical for AI-agent-mediated audiences than for traditional human readers who can spot drift through experience.
- **Frequency**: Continuous — drift accumulates from every commit that changes behaviour without an accompanying README refresh. The just-shipped P141 changeset-discipline hook adds a new commit-time gate; the existing `@windyroad/itil` README does not yet describe it. This is one example among many; the rate is bounded by the rate of behaviour change × the rate of README refresh, with the former generally exceeding the latter.
- **Severity**: Significant — installed plugins describe themselves inaccurately to the adopter, eroding adopter trust + leading to wrong invocation patterns + obscuring the real value the plugin provides. Per RISK-POLICY Impact-3 ("...some adopters confused or misled, no data corruption, recoverable...") — adopter has a path to correct understanding (read the source) but the plugin's own README failed in its primary job (telling the adopter what the plugin does). Impact-4 boundary considered: drift severe enough to cause adopter to invoke the wrong skill or misconfigure could escalate; current evidence is at Significant.
- **Likelihood**: Almost certain — known gap, no controls in place, drift accumulates from every commit that doesn't refresh the corresponding README section. Matches RISK-POLICY Likelihood-5 verbatim ("Known gap, no controls in place, or previously observed failure mode"). 11+ shipped `@windyroad/*` plugins; READMEs across all of them are hand-maintained.
- **Analytics**: Empirical evidence available without further investigation:
  - `@windyroad/itil@0.23.1` (current version on npm) was published before P141's changeset-discipline hook landed; the package's README cannot describe the just-shipped hook. Drift-instance #1.
  - P124 / P144 recovery procedures (substep 7 in manage-problem SKILL.md) shipped to npm via prior releases; the plugin README does not summarise them. Drift-instance #2.
  - P141 fold-fix Verifying status this session shipped a new pressure surface; no README summary exists. Drift-instance #3.
- **Concrete user-cited evidence (2026-05-02)**: this very AFK loop session — iter 1 shipped a new PreToolUse:Bash hook (changeset-discipline) and 21 new bats; the `@windyroad/itil` package README.md does not describe the new hook. Iter 2 transitioned P151 with the bin/-on-PATH resolution shape; the package README has no "how to invoke published-skill scripts" section. The user surfaced the broader pattern after observing the pattern across iters.

## Root Cause Analysis

### Preliminary Hypothesis

The pressure-stack architecture in this project is decision-anchored: every gate (architect / JTBD / risk-scorer / style-guide / voice-tone / TDD / changeset-discipline) cross-checks new edits against a canonical source of truth (`docs/decisions/`, `docs/jtbd/`, `RISK-POLICY.md`, etc.). For code drift this works because the gates fire on every Edit/Write/Bash/commit; the canonical source is consulted; the deny-or-allow decision happens deterministically.

For doc-content drift, the missing piece is **no canonical source of truth that the README content must conform to**. A README is hand-authored prose; there is no `docs/decisions/`-equivalent for "what should this skill's README say". So even if a hook fires on README edits, there is nothing to gate against.

The user's specific framing — *"leverage the JTBD pages so we can help the reader understand the value through the jobs it helps them do"* — proposes the answer: **JTBD job files become the canonical source of truth for README narrative**. The mechanism shape:

1. **Each plugin's README has a JTBD-anchored structure** — every skill / agent / hook documented in the README cross-references the JTBD job(s) it serves. The README's "what this plugin does" section is derived from / cross-checked against the JTBD job files.
2. **A drift detector compares README JTBD anchors to current JTBD job files** — when a job is amended, added, or removed, the detector surfaces "README cites JTBD-006 but JTBD-006 was rewritten 2026-04-29; README has not been updated since then" or "README does not cite any JTBD; new JTBD-101 added 2026-04-21 with no README presence".
3. **The detector starts as advisory** (per ADR-040 declarative-first / P131 Phase 1 / P135 R6 escalation pattern) — emit a per-package "RETRO YYYY-MM-DD doc-currency package=<name> drift=<count> details=...." line on each retro / each release. If the drift count trends above a threshold across N consecutive releases, escalate to a load-bearing hook.
4. **Generalize the mechanism beyond READMEs** — for adopter projects whose canonical source of truth is a `docs/jtbd/` or `docs/decisions/` tree, the same JTBD-anchored detector applies. For adopter projects with marketing HTML / public docs / changelog narrative, the source-of-truth anchor needs adopter-specific configuration (likely a JTBD-equivalent in their own tree, or a config pointer in the adopter's `package.json` / `.windyroad/` directory).

Candidate fix shapes to explore in the architect-design phase:

1. **JTBD-anchored README template + drift detector** — the primary user-proposed shape. Defines a README structure where every skill/agent/hook entry cross-references its JTBD jobs, then provides a detector that checks the cross-reference is current.
2. **README-section-marker comments + content-derived diffs** — README sections carry HTML comment markers naming the SKILL.md / hook source they describe; on every commit, the detector compares README section text against the source markers and flags drift.
3. **Generated READMEs with hand-edited prose layers** — the README is partially generated from SKILL.md / JTBD / package.json metadata, with hand-edited prose layers for the human-friendly narrative. Drift is impossible by construction for the generated portion; the hand-edited portion still drifts but is bounded.
4. **Doc-staleness retro detection** — `/wr-retrospective:run-retro` Step 2b pipeline-instability scan extends to look for README-vs-source drift signals (commits that change SKILL.md / hook .sh / plugin.json without changing the corresponding README). Lightest-weight; declarative; surfaces in retros not gates.

### Investigation Tasks

- [ ] Confirm `docs/jtbd/<persona>/<job>.md` structure and content shape across the existing project — is it stable enough to be a canonical source of truth, or does it itself drift? (P136 ADR-044 alignment audit may already cover this.)
- [ ] Survey existing `@windyroad/*` package READMEs — quantify the actual drift between current README narrative and current plugin behaviour. Establishes the baseline drift rate for measurement.
- [ ] Architect review — codify the chosen mechanism as an ADR (likely sibling to ADR-040 declarative-first, ADR-044 framework-resolution, ADR-013 Rule 6 fail-safe). Decide whether the ticket's scope is `@windyroad/*` plugin READMEs only, or generalises to adopter project surfaces (marketing HTML / public docs / changelog narrative).
- [ ] Architect decision — does the JTBD anchoring constraint require a structural README template change (e.g. mandatory "## Jobs This Helps You Do" section in every package README) or is it advisory-only initially?
- [ ] Phase 1 (per ADR-040 declarative-first precedent): SKILL.md amendment + JTBD-anchored README structure documented + detector script (advisory, exit 0 always). No hook.
- [ ] Phase 2 (R6-gated per ADR-044 escalation pattern): if the advisory script surfaces ≥2 drift instances across 3 consecutive releases without correction, escalate to a load-bearing hook. Match the P131 Phase 1 → Phase 2 trajectory.
- [ ] Behavioural bats per ADR-005 + P081 — assert the detector flags a synthetic drift case (README with stale JTBD reference) and passes a synthetic-clean case.
- [ ] Generalize to adopter-project surfaces — file as a follow-on ticket (P152-adopter-surfaces) or scope into this one per architect decision.
- [ ] Retroactive: refresh existing `@windyroad/*` READMEs to be JTBD-anchored as the first content pass after the mechanism lands. The retroactive pass IS the validation that the mechanism scales.

## Dependencies

- **Blocks**: (none directly — but adopter trust + plugin-user persona's "don't lie about what you do" expectation depends on this)
- **Blocked by**: (none — independent of P137 / P151 / P087 even though they compose; either can land first. P136 (ADR-044 alignment audit) is upstream-related but does not strictly block — P136's output may inform the JTBD anchoring decision but P152 can choose its anchoring shape independently)
- **Composes with**: P137 (Plugin-published artifacts reference internal ADR/JTBD/P-IDs — same plugin-boundary leakage class, semantic correctness axis); P151 (Published skills reference repo-relative script paths — same plugin-boundary leakage class, executable correctness axis); P087 (No maturity / battle-hardening signal — same adopter-facing-content-quality family, different axis: P087 is static maturity-label, P152 is currency-drift-pressure); P097 (SKILL.md size pressure — composes-with on the "generated vs hand-edited" candidate fix shape); P136 (ADR-044 alignment audit master — JTBD-as-source-of-truth depends on JTBD itself being kept current)

## Related

- P137 (`docs/problems/137-published-plugin-artifacts-reference-internal-ids-confuses-adopter-agents.open.md`) — sibling on adopter-facing content quality (semantic correctness axis); both leak windyroad-internal artifacts through the plugin boundary.
- P151 (`docs/problems/151-published-skills-reference-repo-relative-script-paths.known-error.md`) — sibling on adopter-facing content quality (executable correctness axis); just transitioned to Known Error this session with bin/-on-PATH resolution selected.
- P087 (`docs/problems/087-no-maturity-signal-for-plugin-features.open.md`) — sibling on adopter-facing content quality (maturity-label axis); user-observed the same READMEs from a different angle.
- P136 (`docs/problems/136-adr-044-alignment-audit-master.open.md`) — JTBD-as-source-of-truth depends on JTBD content itself being current; P136's audit informs the anchoring shape.
- P097 (`docs/problems/097-skill-md-runtime-vs-maintainer-content-mixed.open.md`) — composes-with on the "generated vs hand-edited" candidate fix shape — generated content reduces drift but bloats SKILL.md / READMEs.
- ADR-040 (`docs/decisions/040-declarative-first-then-enforce.md`) — Phase 1 advisory / Phase 2 R6-gated escalation pattern.
- ADR-044 (`docs/decisions/044-decision-delegation-contract.proposed.md`) — framework-resolution boundary informs whether the doc-currency mechanism is silently agent-decided or surfaced via deviation-candidate.
- P131 (`docs/problems/131-agents-write-project-generated-artefacts-under-claude-config-space.verifying.md`) / P135 (`docs/problems/135-decision-delegation-contract-master.verifying.md`) — Phase 1 declarative / Phase 2 hook escalation precedents this ticket should follow.
- `docs/jtbd/plugin-user/persona.md` — defines the persona constraints (low context on repo internals; AI agent as primary interface) that make doc currency disproportionately load-bearing.
- `packages/retrospective/scripts/check-tickets-deferred-cause.sh` — advisory-only-then-escalate precedent (P148 fix; same shape this ticket's Phase 1 detector should adopt).
- `packages/itil/scripts/check-problems-readme-budget.sh` — advisory-only precedent (P134 hard-ceiling surface; same shape).

## Fix Released — Phase 1 (2026-05-03 iter 11)

Phase 1 of the JTBD-anchored README mechanism shipped via `@windyroad/retrospective` minor bump (changeset `p152-jtbd-anchored-readme-drift-advisory`). Concretely:

- **ADR-051** (`docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`) — codifies the normative rule (every `@windyroad/*` plugin README MUST cite at least one `JTBD-\d{3}` ID that resolves under `docs/jtbd/<persona>/JTBD-NNN-*.md`) plus the recommended `## Jobs to be Done` section structure with persona-grouped subsections. Considered options D1/D2/D3/D4 with D2 chosen.
- **JTBD-302** (`docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`) — new plugin-user job *Trust That the README Describes the Plugin I Just Installed*, the load-bearing persona-anchored job ADR-051's rule serves.
- **JTBD-007 amendment** (`docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md`) — currency expansion from code-currency to doc-content-currency; new Desired Outcome bullet + Related decisions section citing ADR-051.
- **Advisory detector** — `packages/retrospective/scripts/check-readme-jtbd-currency.sh` walks `packages/*/README.md`, greps for `JTBD-\d{3}` citations, resolves against `docs/jtbd/`, and emits `README package=<name> has_jtbd_anchor=<yes|no> cited_jobs=<N> known_jobs=<M> drift_hints=<csv>` lines + a `TOTAL packages=<N> with_jtbd=<M> drift_instances=<K>` summary. Drift hints vocabulary: `missing-jtbd-section`, `stale-jtbd-citation`, `deprecated-jtbd-citation`, `skill-inventory-drift`. Exit code always 0 per ADR-013 Rule 6 / ADR-040 declarative-first.
- **Bin shim** per ADR-049 — `packages/retrospective/bin/wr-retrospective-check-readme-jtbd-currency` (3-line `exec` wrapper; resolves on `$PATH` in marketplace-installed sessions).
- **Behavioural bats** — `packages/retrospective/scripts/test/check-readme-jtbd-currency.bats` (12 tests covering drift / clean / stale-ID / deprecated-only / inventory-drift / multi-package / no-readme cases; all GREEN). Per ADR-005 + P081 (no structural greps on detector source).

**Empirical first-run baseline** (2026-05-03):

```
README package=agent-plugins   has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=architect       has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section,skill-inventory-drift
README package=c4              has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=connect         has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=itil            has_jtbd_anchor=yes cited_jobs=1 known_jobs=1 drift_hints=skill-inventory-drift
README package=jtbd            has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section,skill-inventory-drift
README package=retrospective   has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section,skill-inventory-drift
README package=risk-scorer     has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=style-guide     has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=tdd             has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=voice-tone      has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
README package=wardley         has_jtbd_anchor=no  cited_jobs=0 known_jobs=0 drift_hints=missing-jtbd-section
TOTAL packages=12 with_jtbd=1 drift_instances=12
```

Confirms the Symptoms section's empirical claim: 12/12 plugins flagged with `drift_instances=12`; only 1/12 plugins (`itil`) has any JTBD anchor at all (and even that one has `skill-inventory-drift` from documenting 2 of 16+ shipped skills). The mechanism is working as designed.

**Out of scope for Phase 1 (filed as follow-on work)**:

- **Retroactive content refresh** of the 12 plugin READMEs to JTBD-anchored shape — separate ticket. The retroactive pass IS the empirical validation that the mechanism scales; it follows mechanism shipping rather than co-shipping with it (per the iter-1 P141 / iter-2 P151 mechanism-first pattern).
- **Wiring the detector into `/wr-retrospective:run-retro` Step 2b** — deferred until the detector is empirically validated against current READMEs.
- **Generalisation to adopter-project surfaces** (marketing HTML, public docs, changelog narrative) — separate decision, source-of-truth anchor likely differs.
- **Walking `.github/ISSUE_TEMPLATE/*.yml`** per JTBD-lead's Phase 1.5 recommendation — separate scope.
- **Phase 2 R6-gated load-bearing hook** — escalates if `drift_instances ≥ 2` across 3 consecutive `chore: version packages` releases without correction (criterion documented in ADR-051 §7 Confirmation; mechanism-checkable per the per-release detector output).

**Verification path**: this transitions to Verifying once the changeset releases via `push:watch` + `release:watch` and a fresh adopter session can invoke `wr-retrospective-check-readme-jtbd-currency` from the marketplace-installed cache. Post-release, expect transition to Closed once the next AFK iter or retro confirms the bin shim resolves on `$PATH` in a clean adopter session.
