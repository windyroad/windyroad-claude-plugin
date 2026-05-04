# R008: Credentials / secrets in committed files

A file being edited or written contains a credential — API key, auth token, private key, OAuth secret, `.env` value, signed JWT, password — that ends up committed to git. Once pushed, the credential is in git history indefinitely; rotation is the only remediation. Distinct from R001 (confidential disclosure in **outbound prose**) — R008 is **content entering git via Edit/Write**, regardless of whether prose was drafted.

## Recogniser

**Path patterns** (any match → consider this entry):

- `.env`, `.env.local`, `.env.production`, `.env.example` (especially `.example` files which often retain real values)
- `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.crt`, `*.p12`
- `**/secrets.{json,yaml,yml}`, `**/credentials.{json,yaml,yml}`
- `**/test-fixtures/**` (deliberately-fake credentials may pattern-match the regex)
- (any file Edit/Write target — secrets can land in ANY file content, not just designated ones)

**Diff-content keywords** (the secret-leak-gate scans for):

- AWS access keys (`AKIA[A-Z0-9]{16}` shape)
- PEM-format keys (the `BEGIN ... KEY` bracket pattern)
- GitHub tokens (`ghp_*`, `gho_*`, `ghu_*`, `ghs_*`, `ghr_*`)
- Generic `api_key=`, `auth_token=`, `secret_key=` assignments with high-entropy values
- Cloudflare auth keys, Netlify auth tokens
- (any high-entropy string near a credential-context word)

**Anti-patterns** (looks like R008 but isn't):

- The phrase "API key", "auth token", etc. used in prose ABOUT credentials (e.g., this very catalogue entry) — not actual credential content.
- Documenting the regex pattern verbatim — the gate IS sensitive enough that prose-about-the-gate can trigger; paraphrase patterns rather than reproduce them.
- A deliberately-fake test fixture with bypass-rationale comment — use `BYPASS_RISK_GATE=1`.

## Stage applicability

| Stage | Fires? | Notes |
|-------|--------|-------|
| commit | **primary** | Edit/Write surface is where the gate fires |
| push | yes | If pushed, credential reaches public-repo history; rotation mandatory |
| release | yes | If shipped in tarball, scrapers may have already pulled |
| external-comms | no | R001 covers outbound prose; this is committed file |

## Inherent risk

Per `RISK-POLICY.md` (without controls):

- **Impact**: 5 (Severe) — `RISK-POLICY.md` L65: "leaks npm auth tokens via CI logs" is the canonical Severe instance. Committed credentials in a public repo trigger mandatory rotation (financial impact for cloud API keys; security impact for auth tokens; reputational impact across the board).
- **Likelihood**: 3 (Possible) — without controls, accidental commit is common via test fixtures, debugging artefacts, copy-pasted config from local dev.
- **Inherent score**: 15
- **Inherent band**: High

## Controls (control-application table)

| Control | Fires when… | Path # | Band reduction | If absent for THIS action |
|---------|-------------|--------|---------------:|---------------------------|
| `secret-leak-gate.sh` PreToolUse:Edit/Write hook | Edit/Write target's content matches AWS / PEM / GitHub-token / API-key-assignment / Cloudflare / Netlify regex | 1 | -1 likelihood (when fires-and-denies / fires-and-passes-with-no-match) | Bump +1 |
| `.gitignore` filesystem-level exclusion | Target file is in ignore list (`.env`, `*.pem`, `*.key`, `id_rsa`, etc.) | 2 | -1 likelihood | Bump +1 if novel credential file class not yet ignored |
| CI / pre-receive secret scanning (e.g., GitHub Push Protection, gitleaks) | Push event | 3 | -1 likelihood | Bump +1 (no second-line catch) |
| `BYPASS_RISK_GATE=1` env override | User explicitly set env var | n/a (relaxation) | 0 paths | n/a |

Lifetime residual likelihood = 1 (Rare; capped at floor).

## Per-action modulators

Adjust likelihood for THIS action's specifics (composition: max-pessimistic):

| Modifier | Adjustment | Rationale |
|----------|------------|-----------|
| Edit/Write target is a `.env*` file | -1 | `.gitignore` typically covers; gate fires |
| Edit/Write target is a test fixture with deliberately-fake credentials | -1 (with bypass rationale) | False-positive class; gate may catch but bypass is documented |
| Edit/Write target is a config file (`.yaml`, `.json`) NOT in `.gitignore` | +1 | Novel-class risk; gate must catch on content |
| Diff content includes high-entropy string near credential-context word | +1 | Non-pattern-match credential format; gate may false-negative |
| `BYPASS_RISK_GATE=1` was used | +2 | Gate effectively didn't fire; unless user has explicit safe-rationale comment in commit, treat as gate-skip |
| Push is to public repo | +1 (impact-shaping) | Public-repo scrapers compound consequence |

## Residual risk

Residual reflects controls firing-and-passing (per-action lens):

- **Likelihood after controls**: 1 (Rare) — gate + gitignore + CI second-line stack to capped reduction.
- **Residual score**: 5
- **Residual band**: Medium — above appetite.

**Above appetite** because Impact 5 (Severe) caps residual at 5 even with Likelihood 1. No additional detection control will drop residual below 5 (the Impact floor caps it). Treatment is post-incident: rotation-runbook readiness for WHEN-not-IF the gate's false-negative rate eventually fires.

## Watch-out

- Test fixtures that include sample credentials are the canonical false-positive — the regex can't tell a deliberately-fake AWS key from a real one. Document the fixture intent in a comment + use the bypass env-var.
- JWTs and audit-log captures sometimes land in committed audit reports unnoticed; gate catches PEM-bracket key shapes but JWT bodies are higher entropy and may pass.
- This very file initially failed the gate because the description quoted the PEM-bracket pattern verbatim — the gate is sensitive enough that prose-about-the-gate can trigger. Paraphrase patterns rather than reproduce them.
- Once committed AND pushed, rotation is mandatory regardless of subsequent revert — public-repo scrapers will have already pulled.
- Sub-class: a config file (`.env.example`, `config.yaml`) intended to be committed with placeholder values, where the placeholder accidentally retains a real value from local dev. Gate may or may not catch depending on entropy.

## See also

- **Sibling**: R001 (confidential disclosure in outbound prose) — same confidentiality dimension, different surface (committed file vs outbound prose).
- **Generalisation**: R009 (functional defects) — credential-leak is a defect at the file-content level.
- **Drivers / ADRs**: `packages/risk-scorer/hooks/secret-leak-gate.sh` (control implementation; mitigates WR-R2 per its preamble), CLAUDE.md (no specific ADR for this; secret-leak-gate predates the ADR series for this concern).
