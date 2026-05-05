---
"@windyroad/risk-scorer": minor
---

P064: external-comms risk-leak gate covering gh issue/pr, security-advisories, npm publish, and `.changeset/*.md` author surface

`@windyroad/risk-scorer` gains a PreToolUse gate on outbound prose tool calls so confidential-information leaks are caught before they reach an external surface. Implements the risk-evaluator half of ADR-028 amended; the voice-tone half (P038) remains owned by `@windyroad/voice-tone` and ships independently.

- New canonical hook `packages/shared/hooks/external-comms-gate.sh` + helper `packages/shared/hooks/lib/leak-detect.sh` (regex pre-filter for credentials, business-context-paired financial figures, business-context-paired user counts).
- Per-package synced copy at `packages/risk-scorer/hooks/external-comms-gate.sh` and `packages/risk-scorer/hooks/lib/leak-detect.sh` per ADR-017 duplicate-script pattern. New `scripts/sync-external-comms-gate.sh` + `npm run sync:external-comms-gate` / `npm run check:external-comms-gate`. CI now runs the drift check.
- Gate matches: `gh issue create|comment|edit`, `gh pr create|comment|edit`, `gh api .../security-advisories`, `gh api .../comments`, `npm publish`, and `PreToolUse:Write|Edit` on `.changeset/*.md` (P073 — gated at author time so leaks never reach CHANGELOG.md / Release PR / npm tarball).
- Hybrid leak-pattern flow per architect verdict on the P064 iteration: regex pre-filter denies hard-fail patterns (credentials, prod-URL prefixes, business-context-paired metrics) immediately; ambiguous prose is delegated to the new `wr-risk-scorer:external-comms` subagent for context-aware review against `RISK-POLICY.md` Confidential Information classes.
- New subagent type `wr-risk-scorer:external-comms` (`packages/risk-scorer/agents/external-comms.md`) emits structured `EXTERNAL_COMMS_RISK_VERDICT: PASS|FAIL` + `EXTERNAL_COMMS_RISK_KEY: <sha256>` consumed by the existing `risk-score-mark.sh` PostToolUse hook (extended to write the per-draft `external-comms-reviewed-<sha>` marker).
- New on-demand skill `/wr-risk-scorer:assess-external-comms` (`packages/risk-scorer/skills/assess-external-comms/SKILL.md`) per ADR-015 — pre-satisfies the marker for a draft outside a hook trigger.
- `BYPASS_RISK_GATE=1` env var override (consistent with `git-push-gate.sh`); `RISK-POLICY.md`-absent → advisory-only mode (graceful adoption per ADR-008 / ADR-025).
- Behavioural bats coverage: `packages/risk-scorer/hooks/test/external-comms-gate.bats` (12 assertions across surface match, hard-fail leak deny, marker permit, BYPASS, advisory-only, changeset/non-changeset paths). Canonical-shape contract `packages/shared/test/external-comms-gate-canonical.bats` (11 assertions). Drift coverage `packages/shared/test/sync-external-comms-gate.bats` (7 assertions, mirrors P095 + P026).
- Composite-marker scheme (combining a future `wr-voice-tone:external-comms` verdict with the risk verdict against the same draft) is intentionally deferred until P038 ships its evaluator. Both gates compose at the `PreToolUse:Bash` matcher level when both packages are installed; promotion to the composite marker is a localised follow-up in the canonical hook.

Closes P064 → Verification Pending. JTBD-001 (Enforce Governance Without Slowing Down), JTBD-101 (Extend the Suite with Clear Patterns), JTBD-201 (Restore Service Fast with an Audit Trail). ADR-028 amended; ADR-017 distribution pattern extended to `hooks/`.
