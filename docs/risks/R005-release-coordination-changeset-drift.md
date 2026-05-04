# R005: Release-coordination / changeset queue drift

The monorepo ships ~10 plugins via Changesets; each plugin is independently versioned but often coupled. Drift takes several forms: a changeset bumps plugin A without a coupled changeset for dependent plugin B; multiple accumulated `.changeset/*.md` files trigger an unintended-shape release-PR; a Case-1 multi-slice WIP changeset that should have stayed in `docs/changesets-holding/` leaks into `.changeset/` and auto-publishes; a "patch" bump on a SKILL.md amendment that's actually behavioural (sub-class of R006 semver violation).

Cross-plugin coupling is structurally common because agentic compositions span plugin boundaries (a SKILL.md in `wr-itil` invokes an agent in `wr-risk-scorer` invokes a hook that writes a queue file consumed by another `wr-itil` skill).

## Controls

- **`packages/itil/hooks/itil-changeset-discipline.sh`** (P141) — gates `git commit` on `packages/*/source` change without `.changeset/*.md`. Bypass requires explicit `BYPASS_CHANGESET_GATE=1` env var.
- **`docs/changesets-holding/`** (ADR-042 Rule 7) — held-area for multi-slice WIP changesets that aren't ready to ship. Per-changeset row in README documents reinstate trigger.
- **ADR-042 auto-apply remediations** — orchestrator auto-applies `move-to-holding` when push residual exceeds appetite.
- **ADR-014 single-commit grain** — pairs source change with its changeset in one commit; minimises blast-radius per commit.
- **`docs/changesets-holding/README.md`** "Currently held" + "Recently reinstated" tables — audit trail for which changesets are held and when reinstated.

## Watch-out

- "Bundled-changeset push surprise" (multiple pending bumps land together via release-PR) is NORMAL when bumps are semantically independent — don't flag this as a risk just because the queue has N entries.
- Held-area inventory >5 concurrent signals dogfood pipeline congestion (steady-state for this project is ~3).
- Cross-commit coupling (a feature spanning 2-3 commits, each with its own changeset) bypasses the per-commit gate — the gate sees one slice at a time. Manual review is the only catch.
- Sub-class: a `chore`-bumped changeset that's actually `feat` (or `feat` that's actually `feat!`/breaking) — under-classification. R006 catches this for the publish-boundary specifically; here it's the changeset-prose-vs-actual-change discipline.
