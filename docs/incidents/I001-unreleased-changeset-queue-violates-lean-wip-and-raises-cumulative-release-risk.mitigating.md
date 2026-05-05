# Incident I001: Unreleased changeset queue violates lean WIP and raises cumulative release risk

**Status**: Mitigating
**Reported**: 2026-05-06 06:30 UTC
**Severity**: 6 (Medium) — Impact: Minor (2) x Likelihood: Possible (3)
**Scope**: Release pipeline + held cluster (`docs/changesets-holding/`) + downstream adopter risk (latent — adopters running stale plugin behaviour because mitigations haven't graduated yet)

## Timeline

- [2026-04-24 UTC] Symptoms began — first held-cluster entry landed: `wr-itil-p085-assistant-output-gate.md` (commit `ffa75e1`, "fix(itil): P085 — assistant-output gate (ADR-042 auto-apply: changeset held)").
- [2026-04-26 UTC] Cluster grew to 2: `wr-risk-scorer-p064-external-comms-gate.md` (commit `f139ee9`, ADR-042 Rule 2 auto-apply hold).
- [2026-05-04 UTC] Cluster grew to 3: `wr-retrospective-p159-readme-jtbd-currency-hook.md` (commit `c326106`, ADR-042 Rule 2 auto-apply hold).
- [2026-05-05 UTC] Cluster grew to 5: P170 RFC framework Phase 1 hold (commit `8572aa6`) + Slice 3 first-half hold (commit `44217f6`) under ADR-060 finding 12 atomic-graduation contract.
- [2026-05-06 UTC] Cluster grew to 6: P170 RFC framework Slice 3 second-half hold (commit `055d26b`) — current state.
- [2026-05-06 06:30 UTC] Incident declared by user observation: "we have a massive queue of unreleased changes. This goes against lean principles (too much WIP) and increases the cumulative release risk."
- [2026-05-06 07:30 UTC] User refines scope: "I'm not worried about the held items for dogfooding. It's all the other stuff that needs to get to the users." Cluster split-graduation strategy chosen per H3 mitigation.
- [2026-05-06 07:30 UTC] Mitigation attempt: graduate orthogonal-gate `.verifying.md` holds (P064 + P085 + P159) back to `.changeset/`; P170 dogfood cluster (Phase 1 + Slice 3 + Slice 3 second-half) stays held per ADR-060 finding 12 atomic-graduation contract.

## Observations

- [2026-05-06 06:30 UTC] `docs/changesets-holding/` contains **6 entries**, oldest dated 2026-04-24 (P085, age 12 days), newest 2026-05-06 (P170 Slice 3 second-half, age <1 day). Source: `git log --format='%ad' --date=short --diff-filter=A --follow -- docs/changesets-holding/<file>` for each entry.
- [2026-05-06 06:30 UTC] `.changeset/` is **empty** (only `config.json`) — no changesets queued for the next release. Source: `ls .changeset/`.
- [2026-05-06 06:30 UTC] Local has **4 unpushed commits** ahead of `origin/main` (P170 Slice 3 second-half work + held-area move + retro briefing edit + reconcile preflight). Source: `git log origin/main..HEAD`.
- [2026-05-06 06:30 UTC] **Risk-scorer state within appetite**: commit=2 push=2 release=1 (all Very Low — well below Low band 3-4). Source: `wr-risk-scorer:pipeline` invocation immediately preceding incident declaration this session (cf. `RISK_SCORES: commit=2 push=2 release=1` returned in the orchestrator's Step 6.5 release-cadence check).
- [2026-05-06 06:30 UTC] **Releases ARE happening for non-held work**: last npm release was 2026-05-05, PR #114 (commit `419098e` "Merge pull request #114 from windyroad/changeset-release/main"). Recent release cadence: PR #114 (2026-05-05), #113 (2026-05-04), #112 (2026-05-03), #111 (2026-05-03), #109 (2026-05-03). Held cluster does NOT block other release flow (consistent with ADR-042 Rule 7 — held-area is outside `.changeset/` so changesets/action sees no pending changes for those packages and the at-appetite drain executes for whatever is in `.changeset/` only). Source: `git log --grep='Version Packages\|chore: release' --format='%h %ad %s' --date=short`.
- [2026-05-06 06:30 UTC] Held cluster carries **5 of the 6 entries under the explicit ADR-060 finding 12 atomic-graduation contract** for the P170 RFC framework: 3 P170-related (Phase 1 + Slice 3 first-half + Slice 3 second-half) + P064 + P085 + P159. (P168 is an older sibling already released.) Source: `docs/changesets-holding/README.md` "Currently held" + `docs/decisions/060-...accepted.md` finding 12.

## Hypotheses

- [ranked 1] **The held-cluster atomic-graduation contract (ADR-060 finding 12) is operating as designed, but no quantitative WIP-size guard fires when the cluster grows past N entries**, so accumulation is silent until the user observes it as "massive". — Evidence: 6 entries currently held; oldest 12 days; `grep -nE 'WIP|in-flight|hold.count|max.*held|hold.*limit' RISK-POLICY.md docs/decisions/060-*.md docs/changesets-holding/README.md` returns no quantitative threshold (the policy and ADR define WHEN to hold, not HOW MANY held entries trigger graduation pressure). Related ticket: P162 `Codify dogfood-graduation criteria for held changesets — symmetric risk assessment (release-risk vs delay-risk) drives the reinstate decision, not arbitrary calendar guards`. Confidence: **high**.
- [ranked 2] **Cumulative release risk grows nonlinearly with held-cluster size** — graduating 11 changesets at once (6 held + 5 unpushed) is harder to review/test than the same 11 across separate releases. — Evidence: scorer just rated 4 unpushed commits at push=2/release=1 (Very Low); empirically each commit-gate cycle today ran architect+JTBD+style-guide+voice-tone+risk-scorer review independently. The held-cluster eventual graduation will collapse 6 such review cycles into one — review-quality degradation under N=6 vs N=1 is the latent risk. The nonlinearity is observable in P170 Slice 3 first-half SIGTERM event today (single mega-commit hit the XL wall-clock trap that the second-half decomposition discipline avoided — P147). Confidence: **medium**.
- [ranked 3] **The held-cluster discipline lacks a "graduation pressure release valve"** — atomic-graduation contracts are correct for tightly-coupled work (e.g. P170 RFC framework) but unrelated holds (P064, P085, P159) have been pinned in the same cluster by virtue of the cluster being a single graduation unit, even though their gates are independent. — Evidence: 4 of 6 held entries have orthogonal gating criteria (P064 = external-comms-gate behaviour, P085 = assistant-output gate, P159 = retro-readme-jtbd-currency hook, P170 = RFC framework); but `docs/changesets-holding/README.md` "Currently held" treats them as a single graduation cohort. Confidence: **medium-low** — needs review of whether the cluster is actually one graduation unit or multiple.

## Mitigation attempts

- [2026-05-06 07:30 UTC] **Graduate orthogonal-gate `.verifying.md` holds back to `.changeset/`** (H3 mitigation — split cluster into independent graduation cohorts). `git mv` 3 changesets: `wr-risk-scorer-p064-external-comms-gate.md`, `wr-itil-p085-assistant-output-gate.md`, `wr-retrospective-p159-readme-jtbd-currency-hook.md`. P170 dogfood cluster (3 entries) preserved per ADR-060 finding 12 atomic-graduation contract. Reversible via `git mv` back if false-positive emerges. → pending verification (CI green + npm publish success on `push:watch` + `release:watch`).

## Linked Problem

*(none yet — added on restore transition; candidate problems already in backlog: P162 codify-dogfood-graduation-criteria. JTBD review notes the linked Problem ticket should anchor to JTBD-006 (queue-drain outcome) + JTBD-001 (change-set-level governance) in addition to JTBD-201 incident lineage.)*
