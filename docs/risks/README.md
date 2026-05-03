# Risk Register

> ISO 31000 / ISO 27001 standing-risk inventory. Per-risk files live alongside this index.
> Last reviewed: 2026-05-03

## Purpose

This directory is the **persistent risk register** for the Windy Road Agent Plugins suite. It is distinct from:

- `RISK-POLICY.md` — defines the *criteria* (impact/likelihood scales, appetite, treatment principles).
- `.risk-reports/` — ephemeral **per-change** pipeline risk reports produced by the risk-scorer on each commit/push/release. Auto-deleted after 7 days.
- `docs/problems/` — ITIL problem management (concrete defects and their fixes).

The risk register captures **standing risks** — risks that persist across changes and require ongoing treatment. Each risk has an owner, treatment plan, inherent and residual scores, and review date.

## ISO Mapping

| ISO Clause | Artefact in this repo |
|------------|-----------------------|
| ISO 31000 § 6.4.2 — Risk treatment | Each risk file's `Treatment` section |
| ISO 31000 § 6.4.3 — Residual risk | Each risk file's `Residual Score` section |
| ISO 31000 § 6.5 — Monitoring and review | `Review date` field + periodic review pass |
| ISO 27001 § 6.1.2 — Risk assessment | Risks tagged `category: infosec` |
| ISO 27001 § 6.1.3 — Risk treatment / SoA | `Treatment` + `Controls` sections |

## Structure

- One file per risk: `R<NNN>-<kebab-case-title>.<status>.md`
- Status suffixes: `.active.md`, `.accepted.md` (consciously tolerated), `.retired.md` (no longer relevant)
- Risks retired, not deleted — historical record is preserved
- Cross-references to `docs/problems/P<NNN>` and `docs/decisions/ADR-<NNN>` welcome

Template: `TEMPLATE.md`

## Register

| ID | Title | Category | Inherent | Residual | Treatment | Owner | Review |
|----|-------|----------|----------|----------|-----------|-------|--------|
| [R001](R001-confidential-info-leak-via-public-repo-push.active.md) | Confidential information leak via public-repo push | infosec | 12 (High) | 9 (Medium) | Mitigate | plugin-maintainer | 2026-10-22 |
| [R002](R002-hook-regression-breaks-installed-user-workflow.active.md) | Hook regression breaks installed users' workflow | operational | 12 (High) | 8 (Medium) | Mitigate | plugin-maintainer | 2026-11-03 |
| [R003](R003-installer-corrupts-user-claude-code-config.active.md) | Installer corrupts user's Claude Code config | operational | 10 (High) | 5 (Medium) | Mitigate | plugin-maintainer | 2026-11-03 |
| [R004](R004-cross-package-version-drift-or-publish-failure-breaks-install.active.md) | Cross-package version drift or publish failure breaks install | delivery | 9 (Medium) | 6 (Medium) | Mitigate | plugin-maintainer | 2026-11-03 |
| [R005](R005-readme-skill-md-prose-drifts-from-runtime-behaviour.active.md) | README / SKILL.md prose drifts from runtime behaviour | brand | 16 (High) | 12 (High) | Mitigate | plugin-maintainer | 2026-11-03 |
| [R006](R006-marketplace-cache-lag-delivers-stale-plugin-behaviour.active.md) | Marketplace cache lag delivers stale plugin behaviour | delivery | 12 (High) | 8 (Medium) | Mitigate | plugin-maintainer | 2026-11-03 |

## Retired

| ID | Title | Retired date | Reason |
|----|-------|--------------|--------|

## Relationship to Other Artefacts

```
RISK-POLICY.md        ──▶ defines impact/likelihood criteria, appetite
      │
      ▼
docs/risks/R<NNN>.*.md ──▶ standing risks, scored against criteria
      │                        │
      │                        ├──▶ treatment cites docs/decisions/ADR-NNN
      │                        └──▶ realised-as links to docs/problems/P<NNN>
      ▼
.risk-reports/*.md    ──▶ per-change pipeline snapshots (ephemeral)
```

## How to Add a Risk

1. Copy `TEMPLATE.md` to `R<NNN>-<title>.active.md` (next free ID).
2. Fill in inherent score using impact × likelihood from `RISK-POLICY.md`.
3. Document controls already in place; compute residual score.
4. Set review date (default: 6 months from creation).
5. Update the "Register" table in this README.
6. Commit with `docs(risks): open R<NNN> <title>`.

## How to Review

On review date, re-assess likelihood and residual score. Update controls as systems evolve. Retire risks that no longer apply (rename to `.retired.md`).
