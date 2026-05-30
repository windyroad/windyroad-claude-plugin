---
"@windyroad/itil": patch
---

fix(itil): capture-problem SKILL.md path template names per-state-subdir layout per ADR-031 (closes P281 capture-problem-specific sub-shape)

The `wr-itil:capture-problem` skill's Step 4-5-6 prose previously named the pre-ADR-031 flat shape `docs/problems/<NNN>-<slug>.open.md`. Adopter agents that follow SKILL.md templates literally landed new tickets at the flat path (observed in a downstream adopter repo) despite ADR-031 (per-state-subdir layout) having been ratified.

Refreshed three path declarations + supporting prose in `packages/itil/skills/capture-problem/SKILL.md`:
- Step 4 `**File path**:` declaration now names `docs/problems/open/<NNN>-<kebab-title>.md`.
- Step 5 `Write` target now names `docs/problems/open/<NNN>-<kebab-title>.md`.
- Step 6 `git add` target now names `docs/problems/open/<NNN>-<kebab-title>.md`.

Added 4 behavioural bats tests (P281 regression guards, per ADR-052 § Surface 2 escape-hatch) asserting the SKILL.md contract surface conforms to the ratified ADR-031 layout going forward.

Sibling-SKILL drift (manage-problem Step 4, review-problems, transition-problem(s), reconcile-readme, capture-rfc) tracked separately under P329.
