---
status: "proposed"
date: 2026-05-25
human-oversight: confirmed
oversight-date: 2026-05-25
decision-makers: [Tom Howard]
consulted: [wr-architect:agent, wr-jtbd:agent]
informed: [Windy Road plugin users]
reassessment-date: 2026-08-25
supersedes: [051-jtbd-anchored-readme-with-drift-advisory]
---

# ADR-069: Plugin READMEs market to their primary persona's problem — derived from the JTBD, not cited by ID

## Decision Outcome

Every `@windyroad/*` plugin README MUST **market to its primary persona** — name the persona and the concrete problem the plugin solves for them — with value framing **derived from the JTBD content** (`docs/jtbd/<persona>/`). READMEs **MUST NOT cite JTBD job IDs** (`JTBD-\d{3}`): the ID is internal-governance plumbing in a persona-facing document. The JTBD is the source the README markets from, never the thing the README prints.

Two binding precedents from the superseded ADR-051 (both introduced by its 2026-05-04 P159 amendment) are **carried forward as live normative content** — this ADR is now their home:

- **(a) The prose-weaving anti-pattern**: the bolt-on `## Jobs to be Done` tail-section is rejected as compliance theatre — it absolves the lead prose of doing the value-framing, and the adopter forms their value model from the un-framed lead prose before the tail section arrives. Value framing belongs woven into the lead prose where adopters are already reading; per-skill value is woven into the existing skills/commands prose.
- **(b) The load-bearing-from-the-start for drift class principle**: for mechanical, detectable, structurally-bounded code/doc drift, gate at commit time rather than advisory-then-escalate. ADR-069 **remains an exemplar** of (b): it keeps a load-bearing-from-the-start commit gate — now scoped to skill-inventory-drift. Citations to (a)/(b) (e.g. ADR-060 lines 54/641, P161) resolve to this ADR.

The README currency gate is **retained but narrowed to skill-inventory-drift only**: the PreToolUse:Bash commit-hook (`packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh`) + detector (`packages/retrospective/scripts/check-readme-jtbd-currency.sh`) gate `git commit` on whether every directory under `packages/<plugin>/skills/` is named in that plugin's README. The JTBD-ID requirement (the `missing-jtbd-section` / `stale-jtbd-citation` / `deprecated-jtbd-citation` hints and the `JTBD-\d{3}` anchor) is **removed**. README marketing quality is now prose reviewed by `wr-jtbd:agent`, not machine-gated.

This is a **reject/supersede** of ADR-051 Option D2 (cite-the-ID + hook-enforce-the-ID), recorded through user-pinned direction during the P283/ADR-066 oversight drain:

> *"The intention was not for the README to cite the JTBDs. The idea is that based on the JTBD, the README could market the plugin to the persona and the problem it solves for them. The current approach fails that miserably."*

ADR-051 is marked `status: superseded`.

The 12 existing plugin READMEs **are rewritten** as part of P294 (this change) — the `## Jobs to be Done` bolt-on sections and JTBD-ID citations are removed and each plugin's primary-persona problem is woven into its lead prose. They are NOT left in place.

## Context and Problem Statement

ADR-051 chose Option D2: *"Plugin README MUST cite at least one current JTBD job ID; value framing SHOULD derive from JTBD"*, with a load-bearing commit-hook enforcing the ID citation as a cheap drift-detection anchor. Presented for human-oversight confirmation during the P283/ADR-066 drain (2026-05-25), the user rejected the core mechanism (quote above).

The mechanism optimised for detector-simplicity (`grep JTBD-\d{3}` + resolve to filesystem) at the expense of the README's actual job: marketing the plugin to its persona by naming the problem it solves. Every `@windyroad/*` plugin README accreted a `## Jobs to be Done` tail-section citing JTBD IDs — internal plumbing surfaced in a document whose audience (the plugin-user persona: "low context on repo internals; AI agent as primary interface") gains nothing from the ID and is mis-served by the plumbing.

The original driver (P152 — no pressure for documentation currency) was real, and its empirical core was **skill-inventory drift** ("README documents 2 of 16 skills"). That concern survives this supersession; the *JTBD-ID anchor chosen to detect it* does not. The user's standing principle — *"if there is no automatic cadence, it does not happen"* — means the currency gate must not simply be dropped; it must be narrowed to the part that detects real, mechanical drift without polluting the marketing.

## Decision Drivers

- **Plugin-user persona constraint** (`docs/jtbd/plugin-user/persona.md`): "low context on repo internals; AI agent as primary interface." A printed `JTBD-201` is plumbing this reader cannot and need not act on; the *problem named in prose* forms their value model.
- **Marketing-from-the-problem over capability/ID enumeration**: a README that opens with "the problem this solves for you" outperforms one opening with "this plugin exposes N skills" or "serves JTBD-NNN".
- **Automatic-cadence currency must survive** (user principle, reinforced this session): skill-inventory-drift is the mechanical drift class justifying load-bearing-at-commit-time per carried-forward principle (b). Dropping the gate entirely would leave currency to on-demand review, which the user's principle says never happens.
- **VOICE-AND-TONE banned-pattern compliance**: "market to the persona" is NOT marketing-speak. `docs/VOICE-AND-TONE.md` bans "powerful / seamless / robust / industry-leading". Marketing here means naming the persona's concrete problem in plain, precise language.
- **Adopter-facing self-containment** (composes with P294/P298/P296): published artefacts express their substance inline, not by reference to internal IDs meaningless to adopters.
- **Behavioural bats per ADR-052 + P081**: the narrowed detector's behaviour is tested against synthetic inventory-drift / clean fixtures, not against a structural grep of its own source.

## Considered Options

1. **Supersede ADR-051; narrow the gate to skill-inventory-drift only (chosen)** — reject the ID-citation mechanism, keep marketing as JTBD-derived prose, retain the commit-gate for the mechanical inventory-currency concern only.
2. **Supersede ADR-051; drop the currency gate entirely** — rejected: contradicts the user's "no automatic cadence ⇒ never happens" principle; loses the mechanical inventory-drift catch that was P152's empirical core.
3. **Amend ADR-051 in place** — rejected: this reverses (not refines) the chosen mechanism, and ADR-051 was already amended once (P159); a second in-place reversal would leave a file whose Decision Outcome contradicts its own Considered Options. Per ADR-044 category 2, a core-mechanism reversal is a supersede, not an amend.
4. **Status quo (keep ID-citation + hook)** — rejected by the user's drain direction.

## Normative rules

1. Each `packages/<plugin>/README.md` MUST market to its primary persona by naming, in lead prose, the problem the plugin solves — derived from `docs/jtbd/<persona>/`.
2. Plugin READMEs MUST NOT contain `JTBD-\d{3}` citations.
3. Bolt-on `## Jobs to be Done` tail-section rejected (prose-weaving anti-pattern, carried forward live from ADR-051).
4. The commit-hook gates `git commit` on `skill-inventory-drift` only; it fails-open outside a git work tree, in projects without `./packages/`, on detector failure, and on parse error. The `./docs/jtbd/` activation guard is removed (inventory drift does not consult `docs/jtbd/`).
5. Maturity badge (ADR-053 / ADR-063) and JTBD-derived prose both ship to the README's lead-prose region and compose: the badge designates maturity; the prose names the persona's problem. Neither cites a JTBD ID.

## Confirmation

This decision is honoured when:

1. **Behavioural bats pass** (`packages/retrospective/scripts/test/check-readme-jtbd-currency.bats` + `packages/retrospective/hooks/test/retrospective-readme-jtbd-currency.bats`): a synthetic plugin with a `skills/<name>/` directory unmentioned in its README produces `skill-inventory-drift` and a non-zero `drift_instances`; a plugin naming all its skills produces empty `drift_hints`; the hook denies on inventory drift and allows on a clean tree, on BYPASS, and on every fail-open path.
2. **Detector signal vocabulary is inventory-only**: per-package `README package=<name> skills=<N> in_readme=<M> drift_hints=<csv>` where `drift_hints ∈ {"", "skill-inventory-drift"}`, plus `TOTAL packages=<N> drift_instances=<K>`. The `has_jtbd_anchor` / `cited_jobs` / `known_jobs` fields and the JTBD index are removed.
3. **Hook deny is ADR-013 Rule 1 compliant and ≤300 bytes (ADR-045)**: names the offending plugin slug, the mechanical recovery ("name the skill in the README"), and the `BYPASS_JTBD_CURRENCY=1` escape. It MUST NOT instruct the user to cite a JTBD ID.
4. **No `JTBD-\d{3}` citation remains** in any `packages/*/README.md`; each README markets to its primary persona in lead prose.
5. **run-retro Step 2b advisory** is rewired to the inventory-only vocabulary.
6. **Changeset accompanies the change**: `@windyroad/retrospective` minor bump (hook + detector behaviour change). Per ADR-014 / ADR-021 / P141.
7. **ADR-051 is superseded** (`status: superseded`, `superseded-by: [069-...]`, "Superseded by" blockquote with the carry-forward note for (a)+(b)) and ADR-063's binding prose-weaving citations + commit-hook-sibling refs re-home to this ADR; ADR-060 + P161 (b)-citations re-pointed; ADR-053's "JTBD anchor block" phrasing touched up.
8. **Lockstep JTBD-doc currency**: JTBD-302 and JTBD-007 are amended to drop the ID-cross-reference mechanism, so the JTBD docs do not themselves go stale — the exact failure JTBD-302 exists to prevent.

## Consequences

### Good

- READMEs market to the persona's problem — the value the user actually wanted from JTBD-anchoring, without the plumbing.
- Adopter-facing self-containment improves: no internal IDs in a published document (composes with P294/P298).
- Inventory currency keeps its automatic commit-time cadence; the mechanical drift class P152 surfaced is still caught.
- Per-invocation hook cost moves **down**: the JTBD index build and per-ID resolution loop are removed; the detector now does only the skill-directory inventory grep across 12 READMEs.

### Neutral

- **Filename retained, behaviour repurposed.** The detector / hook / bin-shim / bats keep the `jtbd-currency` stem. A rename to `readme-inventory-currency` would ripple into three *mutable* ADRs (054/055/057 cite the stem as live precedent), the ADR-049 three-touch bin-grammar tax, `hooks.json`, `plugin.json`, and run-retro SKILL.md — for a filename an adopter rarely sees (they see the deny message and the header comment, both of which this change rewrites). The name-retention is deliberate; a clean rename is deferred to a future `check-*-currency.sh` family consolidation (see Reassessment).
- README marketing-quality judgement moves to `wr-jtbd:agent` review — the correct home for a judgement the detector could never make (it could only check ID presence, never ID fitness).

### Bad

- The narrowing commit must clear the now-inventory-only gate or use `BYPASS_JTBD_CURRENCY=1` (ADR-051 / ADR-053 Bootstrapping-clause precedent). The current tree reports `drift_instances=0` under inventory-only, so the bootstrap commit clears naturally.
- The detector can confirm a skill is *named* in the README; it cannot confirm the README *markets* the plugin well. That residual judgement moves to `wr-jtbd:agent` review and retros — an accepted trade.

## Reassessment Criteria

- A `check-*-currency.sh` family consolidation arrives (currently `check-readme-jtbd-currency.sh` + `check-plugin-maturity-drift.sh`): that is the natural window to rename `jtbd-currency` → `inventory-currency` and pay the ADR-049 three-touch tax once.
- The inventory grep produces sustained false positives (e.g. a skill intentionally undocumented during a refactor routinely BYPASS-bypassed without remediation): revisit the heuristic.
- The narrowing of a load-bearing drift gate is a data point for **P161** (whether advisory-then-escalate is the right default for drift-class detectors generally).
- Adopter-surface generalisation (marketing HTML, public docs) becomes load-bearing: extend or author a sibling ADR.

## Related

- **P294** — driver problem (ADR-051 is wrong; READMEs should market from the JTBD, not cite IDs). User direction 2026-05-25 during the P283/ADR-066 oversight drain.
- **ADR-051** — superseded by this ADR. The prose-weaving anti-pattern (a) and the load-bearing-from-the-start-for-drift-class driver (b) it introduced are carried forward here as live precedent.
- **ADR-063** — plugin maturity presentation layer; its "(binding)" prose-weaving citations and commit-hook-sibling refs re-home to this ADR. Maturity badge + JTBD-derived prose share the README lead-prose region on orthogonal axes.
- **ADR-060** — Problem-RFC-Story framework; its load-bearing-from-the-start-for-drift-class citations (lines 54/641) re-point to this ADR.
- **ADR-053** — maturity taxonomy / README badge header (the discrete "JTBD anchor block" phrasing is retired in favour of "JTBD-derived value framing").
- **ADR-008** — JTBD directory structure (still the source the README markets from; no longer ID-cited).
- **ADR-013 Rule 1 / Rule 6** — deny-with-recovery + non-interactive fail-safe (the narrowed hook preserves both).
- **ADR-045** — hook injection budget (deny-band ≤300 bytes).
- **ADR-049** — bin/-on-PATH naming grammar (the reason the filename is retained, not renamed).
- **ADR-052 / P081** — behavioural-tests default (the narrowed detector is bats-tested behaviourally).
- **ADR-014 / ADR-021 / P141** — commit grain + changeset discipline.
- **ADR-066** — human-oversight marker + review-decisions drain (this ADR is born `human-oversight: confirmed` via the user-pinned drain direction).
- **P158 / P159 / P161** — the ADR-051 implementation lineage and the open drift-class meta-question.
- **P289** — solo-developer → developer persona rename; the rewritten READMEs use `developer` framing now to front-run it at zero rework.
- **P298 / P296** — sibling adopter-facing-self-containment reworks (strip internal IDs from published artefacts).
- **P303** — architect-gate multi-ADR deadlock surfaced while recording this ADR (verdict-grep + drift-relock + disk-state-review compounding).
- **JTBD-302** — Trust That the README Describes the Plugin I Just Installed (served by marketing-from-the-job; amended in lockstep).
- **JTBD-007** — Keep Plugins Current Across Projects (currency expansion; amended in lockstep).
