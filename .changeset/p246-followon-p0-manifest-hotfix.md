---
"@windyroad/itil": patch
"@windyroad/retrospective": patch
"@windyroad/architect": patch
"@windyroad/jtbd": patch
"@windyroad/risk-scorer": patch
"@windyroad/tdd": patch
"@windyroad/style-guide": patch
"@windyroad/voice-tone": patch
"@windyroad/wardley": patch
"@windyroad/c4": patch
"@windyroad/connect": patch
---

**P0 hotfix**: Phase 3 retroactive rollout (d33bb7d, shipped as @windyroad/itil@0.35.1 + 10 sibling plugins) wrote per-surface maturity records at top-level `plugin.json` keys (`skills:` / `agents:` / `hooks:` / `commands:`). Claude Code's plugin manifest validator rejects that shape with `Validation errors: hooks: Invalid input, skills: Invalid input`. All 11 plugins were unparseable by `claude plugin install`.

**Fix** (ADR-063 Amendment 2026-05-18): per-surface maturity records nest UNDER the top-level `maturity:` key at `plugin_doc.maturity.<kind>.<name>`. Schema version bumps to "2.0" (path move is NOT additive per ADR-058 §Confirmation #8). Populate script (`packages/itil/scripts/plugin-maturity-populate.sh`) writes to the new nested location; render script (`packages/itil/scripts/plugin-maturity-render.sh`) reads from the new nested location. Defensive cleanup of legacy top-level keys on re-runs. Bats fixtures (populate + render + drift) updated to new shape — 17 + 17 + 14 green. Manifest fix-up applied to all 11 affected plugin.json files.

**Hotfix-class bypass** per ADR-013 Rule 5 (reducing — closes a defect that broke `claude plugin install` for all adopters).
