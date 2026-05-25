---
"@windyroad/itil": patch
---

fix(itil): P165 README-refresh gate recognises the `RISK_BYPASS: adr-031-migration` trailer (closes P265)

The `itil-readme-refresh-discipline.sh` commit gate blocked the ADR-031 layout-migration commit — a pure rename (flat `docs/problems/NNN-*.<state>.md` → per-state subdir) that legitimately stages no README refresh, so Step 0a auto-migration of flat-layout adopter trees deadlocked every invocation.

`detect_readme_refresh_required` now accepts the `git commit` command string and allow-lists the registered `RISK_BYPASS: adr-031-migration` trailer (new `_readme_refresh_command_has_bypass_trailer` helper + `_README_REFRESH_BYPASS_TRAILERS` allow-list). The recognition grep is byte-identical to the sibling `risk-score-commit-gate.sh`, so one logical migration commit clears both commit gates. The allow-list keeps the bypass narrow and auditable — a generic `RISK_BYPASS:` match would let any commit self-exempt. Sibling gates P125 (staging-trap) and P141 (changeset-discipline) were swept and carry no equivalent gap.
