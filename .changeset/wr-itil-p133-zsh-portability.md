---
"@windyroad/itil": patch
---

P133 — zsh-portability gap in shell-snippet examples. Phase 1 immediate fix at the proximate failure surface (`scripts/repo-local-skills/install-updates/SKILL.md:167`) plus defensive rename in the load-bearing `reconcile-readme.sh` script.

The 2026-04-27 session hit two distinct zsh-vs-bash failures in `/install-updates` Step 7: (1) `local status=...` errored with `read-only variable: status` because zsh has `$status` as a read-only built-in alias for `$?`; (2) `for plugin in $PLUGINS_TO_UPDATE` (where the variable was a space-separated string) silently iterated **once** under zsh because zsh does NOT word-split unquoted variables by default. All 24 install operations were marked `lost` until the wrapper was rewritten to use a bash array.

Changes:

- `scripts/repo-local-skills/install-updates/SKILL.md` Step 6 inner loop now uses bash-array iteration (`PLUGINS_TO_UPDATE=(itil retrospective risk-scorer tdd)` + `for plugin in "${PLUGINS_TO_UPDATE[@]}"`) — portable across bash and zsh. New portability note explains why array form (not unquoted iteration). This is the proximate failure surface that broke the 2026-04-27 session.
- `packages/itil/scripts/reconcile-readme.sh` defensive rename `status` → `ticket_status` at the two assignment sites (lines 65-72 filesystem-truth build phase + lines 174-191 drift-detection loop). Script has a hard `#!/usr/bin/env bash` shebang so it never runs under zsh directly, but the rename eliminates the latent footgun for any future caller that sources or copies the pattern. Inline comment cross-references P133.
- `packages/itil/scripts/test/reconcile-readme.bats` new behavioural regression test (`run env status=junk "$SCRIPT" "$FIXTURE_DIR"`) confirming drift detection is independent of any caller-controlled `status` env var. 17/17 green (16 prior + 1 new).

Audit findings (in-scope but clean — recorded for the verifying-transition note):

- `packages/itil/skills/{work-problems,manage-problem,transition-problem}/SKILL.md` — no bash-isms in fenced shell snippets (greps for `for x in $VAR`, `local status=`, unquoted `${array[@]}` returned no matches).
- `packages/retrospective/skills/run-retro/SKILL.md` — same.
- `packages/itil/hooks/*.sh` and `packages/itil/hooks/lib/*.sh` — all have `#!/bin/bash` shebangs; safe.

Phase 2 (repository-wide audit + remediation) and Phase 3 (CI/pre-commit lint detecting bash-isms in committed snippets) deferred to compose with **P136** (ADR-044 alignment audit master) per architect direction.

Architect ALIGN (no new ADR; alignment with ADR-014 ONE-commit batching, ADR-022 verifying-transition criteria, ADR-030 repo-local-skills source-of-truth governance). JTBD ALIGN (JTBD-001 solo-developer primary fit — silent-failure surface eliminated; JTBD-007 keep-plugins-current direct outcome; JTBD-101 plugin-developer downstream pattern). Style PASS (no UI/visual styling). Voice PASS (no banned patterns).

Transitions P133 Open → Verification Pending per ADR-022.
