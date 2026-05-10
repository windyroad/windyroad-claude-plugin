# Incident I002: Release-pressure and WIP-limit controls not firing — held cluster grew 3 → 13, 32 unpushed commits, 0 pushes in 4 days

**Status**: Mitigating
**Reported**: 2026-05-10 UTC
**Severity**: 15 (High) — Impact: Moderate (3) x Likelihood: Almost certain (5)
**Scope**: Release pipeline + WIP-limit machinery + held cluster (`docs/changesets-holding/`) + all `@windyroad/*` packages with held or unpushed work (itil, retrospective, risk-scorer, architect, jtbd) + plugin-user persona running 4+ day stale plugin behaviour.

**Affected JTBDs** (per JTBD review on declaration):

- **JTBD-201** (Restore Service Fast with an Audit Trail) — primary, owns the incident
- **JTBD-006** (Progress the Backlog While I'm Away) — AFK-loop queue-drain contract is the failure surface; "Between iterations, the loop drains push/release queues when unreleased risk would reach appetite, so risk never silently accumulates across AFK iterations" is exactly what is broken
- **JTBD-007** (Keep Plugins Current Across Projects) — 4-5 day push/release silence means no new version is being shipped, starving the cross-project currency loop at its source
- **JTBD-001** (Enforce Governance Without Slowing Down) — JTBD-001 amendment 2026-05-05 ("Multi-commit coordinated changes ... governed at the change-set level") is the surface mis-firing; ADR-042 auto-apply implements change-set-level governance and is over-firing
- **JTBD-101** (Extend the Suite with New Plugins) — feat/fix work in held + unpushed window (RFC-002 T1-T5, P170 Slice 4 type-classification, etc.) cannot reach npm for downstream adopters
- **JTBD-302** (Trust That the README Describes the Plugin I Just Installed) — adjacent: stale npm releases means installed READMEs describe pre-2026-05-06 behaviour while `main` has moved 32 commits forward

## Timeline

- [2026-05-06 08:00 UTC] I001 mitigation completed — service restored, 3 orthogonal-gate holds graduated, npm release went out (PR #114, 3 packages published). Held cluster reduced 6 → 3.
- [2026-05-06 18:37 UTC] First unpushed commit lands (`688da5c chore(problems): reconcile README — add P174 WSJF Rankings row (P118)`). Push pressure begins to accumulate.
- [2026-05-06 18:48 UTC – 2026-05-10 UTC] 31 further commits land locally; 10 of those are `chore(changeset): move <slug> to holding (ADR-042 Rule 2 + Rule 6)` auto-applies. Held cluster grows monotonically: 3 → 13. `.changeset/` stays empty throughout. No `push:watch` fires. No `release:watch` fires.
- [2026-05-10 UTC] User declares incident: *"something is broken with the pressure to release and limit WIP. There are 32 unpushed commits."*
- [2026-05-10 UTC] User correction on I002 closing report deferral phrasing ("I'll wait for your direction on which mitigation to attempt"): *"mitigations don't belong to me. You are empowered."* Captured as P180 (commit `cd8062f`) — class-of-behaviour pattern at the mid-flow mitigation-selection surface (sibling-but-distinct from session-wrap deferral and inverse-P078 trap).
- [2026-05-10 UTC] **Mitigation attempt: H3 atomic-cohort graduation** — `git mv` 13 holds from `docs/changesets-holding/` back to `.changeset/`. Cohort honors ADR-060 finding 12 atomic-graduation contract. Forward-dogfood Slice 5 (RFC-002 T1-T5) closed. User-comfort signal supplied by I002 declaration + "you are empowered" direction (ADR-044 category-1 direction-setting authority transfer). Reversible: `git mv` back if release fails.

## Observations

- [2026-05-10 UTC] `docs/changesets-holding/` contains **13 entries** — held cluster has more than doubled from I001 declaration's 6 entries, and grew by 10 since I001 restoration (3 → 13). Source: `ls docs/changesets-holding/ | grep -v README | wc -l`.
- [2026-05-10 UTC] `.changeset/` is **empty** (only `config.json` present) — no changesets queued for the next release. Source: `ls .changeset/`.
- [2026-05-10 UTC] **32 unpushed commits** ahead of `origin/main`. Source: `git log @{u}..HEAD --oneline | wc -l`.
- [2026-05-10 UTC] **10 of the 32 unpushed commits are `chore(changeset): move <slug> to holding (ADR-042 Rule 2 + Rule 6)`** — i.e. 31% of commit work in this window is auto-apply hold operations sending changesets to `docs/changesets-holding/` rather than to `.changeset/`. Source: `git log @{u}..HEAD --oneline | grep -E 'chore\(changeset\): move' | wc -l`.
- [2026-05-10 UTC] **Last push to `origin/main` was 2026-05-06** (I001 mitigation chain ending at `6b6ef50`). No push has occurred in 4 days. Source: `git reflog show origin/main` — `1e25d2c refs/remotes/origin/main@{0}: update by push` is the most recent push entry, predates the 32-commit accumulation.
- [2026-05-10 UTC] **Last npm release was 2026-05-05** (per I001 observations — PR #114, 3 packages: `@windyroad/itil@0.26.0` + `@windyroad/retrospective@0.18.0` + `@windyroad/risk-scorer@0.7.0`). No release has occurred in 5 days. Source: I001 incident file Observations § + git log grep for `Version Packages|chore: release`.
- [2026-05-10 UTC] **I001 mitigation (graduate orthogonal-gate holds) did not prevent recurrence** — held cluster regrew 3 → 13 in 4 days, exceeding the pre-I001 ceiling of 6. Source: I001 mitigation log + current `docs/changesets-holding/` count.
- [2026-05-10 UTC] **Substantive feat/fix work is in the unpushed window**, not just docs/retros — examples: `feat(itil): capture-problem Step 1.5 type-classification AskUserQuestion + flag-parse (P170 8c, ADR-060 I2 + JTBD-301)`, `feat(itil,retrospective): widen problem-ticket globs to dual-pattern (RFC-002 T2)`, `feat(architect,jtbd): widen problem-ticket exemption glob to dual-pattern (RFC-002 T1)`, `feat(itil): reconcile-readme.sh dual-tolerant flat + per-state enumeration (RFC-002 T4)`, `fix(itil): reorder git ls-tree flags in manage-problem SKILL.md to satisfy structural test (RFC-002 T2 fix-up)`. These are user-facing plugin behaviour changes that downstream adopters cannot install. Source: `git log @{u}..HEAD --oneline | grep -E '^[a-f0-9]+ (feat|fix)'`.

## Hypotheses

- [ranked 1] **ADR-042 Rule 2 + Rule 6 auto-apply runs on every iteration with no graduation pressure**, so changesets accumulate in holding without ever being graduated back to `.changeset/`. The auto-apply path is one-directional (out to holding) by design; only manual graduation reverses it (as I001 mitigation did). — Evidence: 10 of 32 unpushed commits are `chore(changeset): move ... to holding`; held cluster grew 3 → 13 in 4 days; 0 graduations occurred during that window; `git log @{u}..HEAD --oneline | grep -E 'graduate|reinstate'` returns 0. Confidence: **high**.
- [ranked 2] **The release-cadence drain in `manage-incident` Step 15 (and the equivalent steps in AFK orchestrators per ADR-018 / ADR-020) only fires when `.changeset/` is non-empty** — when every new changeset immediately auto-applies to holding (Rule 2 + Rule 6), the drain condition `.changeset/` non-empty is never met, so `push:watch` + `release:watch` never run, so commits accumulate unpushed AND nothing is published to npm. The push-cadence and release-cadence are gated on the same conjunct (`.changeset/` non-empty) that the auto-apply path keeps empty. — Evidence: `.changeset/` is empty (only `config.json`); 0 pushes in 4 days; 0 npm releases in 5 days; ADR-018 Mechanism step 3 (line 78) and ADR-020 Mechanism step 3 (line 69) literally read "if push and release are both within appetite AND `.changeset/` is non-empty, proceed to the drain action". The first conjunct is met (risk is presumably within appetite for routine work), the second never is. Source: `docs/decisions/018-...md` + `docs/decisions/020-...md` drain conditions. Confidence: **high**. (Architect review confirmed this is a structural defect — see Outstanding Design Question.)
- [ranked 3] **No quantitative WIP-size guard fires when held cluster grows past N entries** — the same gap I001 ranked-1 hypothesis identified, still uncodified per P162. — Evidence: held cluster passed I001's "massive" threshold (6) and reached 13 without any guard firing; `grep -nE 'WIP|in-flight|hold.count|max.*held|hold.*limit' RISK-POLICY.md docs/decisions/060-*.md docs/changesets-holding/README.md` would still return no quantitative threshold (per I001's own observation 7). Linked to P162 `Codify dogfood-graduation criteria for held changesets`. Confidence: **high**.
- [ranked 4] **There is no automated graduation-pressure-release valve** — once an item is in holding, only manual graduation (e.g. I001 mitigation, where the user invoked the skill and explicitly chose split-cluster strategy) brings it back. The system has no mechanism that says "held entry has been here N days OR the cluster has more than N entries → graduate orthogonal-gate ones". — Evidence: 0 spontaneous graduations between 2026-05-06 08:00 (I001 mitigation) and 2026-05-10 (now); `git log --since='2026-05-06 08:00' --until='2026-05-10' --oneline -- docs/changesets-holding/` shows 10 inbound moves and 0 outbound moves. Source: held cluster directory git log. Confidence: **medium-high** — depends on whether ADR-060 finding 12 atomic-graduation contract treats the current cluster as one tightly-coupled unit (in which case manual graduation IS the design) or as orthogonal cohorts that should graduate independently (in which case the mechanism gap is real).

## Mitigation attempts

- [2026-05-10 UTC] **H3 atomic-cohort graduation** — `git mv` 13 changesets from `docs/changesets-holding/` back to `.changeset/`: `wr-architect-jtbd-rfc-002-t1-glob-widening.md`, `wr-itil-p170-rfc-framework-phase-1.md`, `wr-itil-p170-rfc-framework-phase-1-slice-3.md`, `wr-itil-p170-rfc-framework-phase-1-slice-3-second-half.md`, `wr-itil-p170-slice-4-b7-capture-problem-type-prompt.md`, `wr-itil-p170-slice-4-b7-type-tag-bulk-migration.md`, `wr-itil-p178-skip-state-machine-gates-capture.md`, `wr-itil-p179-defer-discipline-capture.md`, `wr-itil-retrospective-rfc-002-t2-dual-tolerant-skill-globs.md`, `wr-itil-rfc-002-t2-fixup-flag-order-for-structural-test.md`, `wr-itil-rfc-002-t3-bats-dual-tolerant-coverage.md`, `wr-itil-rfc-002-t4-reconcile-readme-dual-tolerant.md`, `wr-risk-scorer-rfc-002-t5-bulk-migration.md`. Cohort honors ADR-060 finding 12 atomic-graduation contract (full cohort, not split). Reinstate triggers met: forward-dogfood Slice 5 (RFC-002 T1-T5) closed (commits `9fef067`, `0795e91`, `a75ae3f`, `822c794`, `b5af550`, `e31bd6a`); user-comfort signal supplied by I002 declaration + verbatim "you are empowered" direction (ADR-044 category-1 authority transfer). Reversible via `git mv` back to holding if release:watch fails. → pending verification: `npm run push:watch` + `npm run release:watch` complete with CI green and 5 packages published (`@windyroad/itil`, `@windyroad/risk-scorer`, `@windyroad/architect`, `@windyroad/jtbd`, `@windyroad/retrospective`).

## Outstanding Design Questions

Surfaced by architect review at I002 declaration (do not block declaration; track via P162 Fix Strategy or sibling problem):

- **Drain-condition empty-conjunct coupling across ADR-018 / ADR-020 / ADR-042 / ADR-060** — the conjunction of these four decisions creates the failure mode I002 observes:
  1. ADR-042 Rule 2 moves changesets out → `.changeset/` stays empty.
  2. The empty `.changeset/` defeats both ADR-018 and ADR-020 drain conditions → no `release:watch` fires.
  3. With `release:watch` not firing, push-cadence has no forcing function either (32 unpushed commits since 2026-05-06).
  4. ADR-060 finding 12 atomic-graduation contract pins the cohort but provides no graduation-pressure mechanism for non-RFC-shaped held entries.
  5. P162 has been Open since 2026-05-04 with WSJF 6.0 but no released ADR — the outflow contract that would re-pressurise `.changeset/` doesn't exist yet.

  No single ADR is wrong in isolation; the defect is the **interaction**. Three remediation options identified by the architect:
  - Amend ADR-018 + ADR-020 drain condition: change "AND `.changeset/` non-empty" to "AND (`.changeset/` non-empty OR `docs/changesets-holding/` carries graduatable entries)". The agent then evaluates graduation per P162's contract before re-checking drain.
  - Amend ADR-042 Rule 2/6 auto-apply scope: gate Rule 2 auto-apply on a WIP-size guard (e.g. "do not auto-apply move-to-holding when held cluster ≥ N entries; route to halt + AskUserQuestion instead").
  - Amend ADR-060 finding 12: extend the atomic-graduation contract to require a periodic graduation-pressure check.

  The natural host is P162's Phase 1 ADR (extending its Fix Strategy with the drain-condition amendment as Phase 1b), since P162 already covers WIP-size + graduation criteria but not the empty-conjunct coupling explicitly.

## Linked Problem

*(none yet — added on restore transition)*

The pre-existing **P162** (`Codify dogfood-graduation criteria for held changesets — symmetric risk assessment (release-risk vs delay-risk) drives the reinstate decision, not arbitrary calendar guards`) is the most likely linkage candidate, since it covers ranked-1 + ranked-3 + ranked-4 hypotheses. I001 already linked to P162; I002 is the same problem class re-manifesting at higher amplitude despite I001 mitigation. The restore-transition (Step 8 → `/wr-itil:restore-incident`) will resolve linkage and may extend P162's Fix Strategy to cover ranked-2 (drain-condition empty-conjunct coupling), per the Outstanding Design Question above.
