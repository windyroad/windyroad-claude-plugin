---
"@windyroad/retrospective": minor
---

P159: ship `retrospective-readme-jtbd-currency.sh` PreToolUse:Bash hook + ADR-051 amendment + Recommended Section Structure rewrite to load-bearing-from-the-start commit-gate with prose-woven framing

Closes the gradualism gap that ADR-051 Phase 1's advisory-only consumption surface left open: the most-common drift class (contributor adds a skill/hook/agent and forgets the README) ships in a commit that does not touch README.md, so a retro-time consumer (P158, `df47ad1`) sees the drift only after the contributor has already committed. The amended Phase 1 ships the load-bearing-from-the-start variant: a PreToolUse:Bash hook on `git commit` runs the existing detector against the post-commit working tree and denies the commit when `drift_instances > 0`. The advisory script + retro Step 2b wiring survive as backup signals.

User correction (P078 capture-on-correction) drove the direction: *"the drift detector shouldn't be part of the retro. It should be something we are always running and fixing"*.

**What ships**

- New PreToolUse:Bash hook `packages/retrospective/hooks/retrospective-readme-jtbd-currency.sh` — fires on `git commit` invocations (substring match catches `git commit -m`, `git commit --amend`, leading `cd && git commit`, `chore: version packages` release commits, etc.); runs `check-readme-jtbd-currency.sh` against the project's `./packages/` + `./docs/jtbd/`; denies with PreToolUse JSON when `TOTAL drift_instances > 0`. Per-invocation deterministic; no marker (mirrors P125 / P141 no-marker precedent — architect-approved when detection cost stays under ~150ms). Truncates the drift_hints CSV to the first hint to bound the deny-band ≤300 bytes for worst-case slug + hint combinations per ADR-045.
- Wired into `packages/retrospective/hooks/hooks.json` as a PreToolUse entry with matcher `"Bash"`.
- BYPASS env: `BYPASS_JTBD_CURRENCY=1` (parallel naming to sibling P141 `BYPASS_CHANGESET_GATE=1`). Fail-open paths per ADR-013 Rule 6: outside a git work tree, in adopter projects without `./packages/` or `./docs/jtbd/`, on detector-script failure, on parse error. Allow path silent-on-pass per ADR-045 Pattern 1.
- Deny redirects to wr-jtbd:agent recovery + hand-edit fallback (graceful degradation when `@windyroad/jtbd` is not installed) per ADR-013 Rule 1.
- 19 behavioural bats `packages/retrospective/hooks/test/retrospective-readme-jtbd-currency.bats` per ADR-052 — drift-detection × 7 (no-anchor, skill-inventory-drift, slug name, recovery path, deny-band, release commits, --amend); allow × 4 (clean, BYPASS, non-Bash, non-commit); fail-open × 5 (outside git tree, no packages/, no docs/jtbd/, empty JSON, malformed JSON); silent-on-pass × 3 (clean tree, non-Bash, non-commit). 19/19 green.

**ADR-051 amendment** (`docs/decisions/051-jtbd-anchored-readme-with-drift-advisory.proposed.md`)

- New Decision Driver: "Load-bearing-from-the-start for drift class" — drift detectors are a different class from design-question / policy detectors; advisory-then-escalate gradualism re-creates the failure mode the detector exists to solve.
- New Normative rule 4: PreToolUse:Bash hook gates `git commit` against the detector.
- Recommended Section Structure clause **rewritten**: bolt-on `## Jobs to be Done` section rejected as anti-pattern; prose-weaving target guidance added (lead value-framing section names JTBD job; per-skill / per-hook / per-agent descriptions name the job they serve); persona-primacy preservation rules carried over (lead prose's value framing reflects primary readership persona); heading vocabulary remains non-normative.
- Confirmation criterion 5 amended: Phase 1 surface is the commit-hook + retro Step 2b advisory backup.
- Confirmation criterion 6 added: hook bats coverage.
- Confirmation criterion 8 amended: original "escalate-after-3-releases" trigger superseded; new trigger monitors load-bearing surface for false-positives + undetected semantic drift + generalisation pressure.
- Reassessment Criteria block refreshed to reflect the load-bearing surface + new generalisation trigger (P161).
- Out-of-scope updated: Phase 2 (12-README prose-weaving refresh) deferred; auto-fix orchestration (wr-jtbd:agent grant-Edit decision) deferred; load-bearing-as-default-for-drift-class generalisation queued at P161.
- Consequences updated: Bad/Good/Neutral sections refreshed for the commit-hook surface; performance budget cited (~80–150ms per commit; ~3s per AFK session).

**JTBD doc edits** (per JTBD agent's Phase 1 acceptance criteria)

- `docs/jtbd/plugin-user/JTBD-302-trust-readme-describes-installed-behaviour.proposed.md`: Desired Outcome bullet 6 rewritten from "advisory in Phase 1, escalates if drift accumulates" to "load-bearing at commit time per P159; retro/release-time advisories ride as backup signals". Related decisions block updated: ADR-051 description refreshed; new entries for P159 + P158.
- `docs/jtbd/solo-developer/JTBD-007-keep-plugins-current.proposed.md`: Desired Outcome line 22 rewritten from "detectable via advisory script" to "enforced at commit time via PreToolUse:Bash hook; retro/release-time advisories ride as backup signals". Related decisions block updated.

**Tactical bootstrap drift fixes** (ADR-053 bootstrapping clause precedent)

- `packages/architect/README.md`: added `/wr-architect:capture-adr` skill mention (clears the existing skill-inventory-drift hint from `d28bd51`).
- `packages/itil/README.md`: added `/wr-itil:capture-problem` skill mention (clears the existing skill-inventory-drift hint from `86e99e5`).
- These are tactical drift-currency fixes, not the strategic Phase 2 prose-weaving refresh (deferred to a separate iter).

Post-fix detector signal: `TOTAL packages=12 with_jtbd=12 drift_instances=0` — bootstrap commit clears the gate naturally without BYPASS.

**Verdicts**

Architect: PASS — proceed with Phase 1 design as scoped. Five advisory observations folded in: hook placement in retrospective confirmed; fire on any `git commit` confirmed; in-place ADR-051 amendment (no supersession); P158 lifecycle Verifying → Closed; deny string graceful-degradation fallback added.

JTBD: PASS — three same-commit doc edits all applied (JTBD-302 + JTBD-007 + ADR-051 amendment carries prose-weaving target guidance + persona-primacy preservation + anti-pattern citation). Re-review after JTBD policy edits also PASS.

**Phase 2-3 explicitly deferred**: 12-README prose-weaving refresh; auto-fix orchestration via wr-jtbd:agent grant-Edit decision. P158 transitions Verifying → Closed (retro wiring survives as backup advisory). P161 filed for the broader drift-class-generalisation observation.

Closes P159
