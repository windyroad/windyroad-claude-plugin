# Problem 060: `push:watch` does not anchor on HEAD sha; may report success on the wrong (prior-sha) workflow

**Status**: Closed
**Reported**: 2026-04-20
**Priority**: 4 (Low) — Impact: Minor (2) x Likelihood: Unlikely (2)
**Effort**: S — one-line change to `package.json` `push:watch` script + bats doc-lint assertion
**WSJF**: 4.0 — (4 × 1.0) / 1

## Description

`npm run push:watch` (defined in root `package.json`) is the sanctioned push path. Its current definition:

```
git push 2>&1 && RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') && gh run watch "$RUN_ID" --exit-status
```

`gh run list --limit 1` returns the **most-recently-STARTED** workflow run, not the workflow run for the sha just pushed. If an older sha's workflow is still in flight at push time, the script watches the **prior** sha's workflow and reports that workflow's final status — not the newly-pushed commit's CI result.

Observed 2026-04-20 AFK iter 4: `push:watch` reported *"Run Release Preview (24642766489) has already completed with 'success'"* — but `24642766489` was the Release Preview for the PRIOR sha `5d9d227`. The pushed commit `8788489` had its OWN CI + Release runs (`24649483413` and `24649483418`) still `in_progress`. The script exited 0 despite the new sha's CI not having finished. I had to manually `gh run watch 24649483413 --exit-status` to actually wait on the new-sha CI.

Same defect class as P054 (release:watch drift hash stability) — both are "script doesn't anchor on the pipeline-state-we-just-caused". Different scripts, different fix.

## Symptoms

- `push:watch` exits 0 while the just-pushed sha's workflows are still `in_progress`.
- Report text references a workflow whose sha does not match `git rev-parse HEAD`.
- AFK orchestrators (work-problems Step 6.5, any auto-release drain) may proceed to `release:watch` or the next iteration before the pushed sha's CI has actually finished.
- Latent failure mode: if the prior sha's workflow was green but the new sha's CI would have failed, the release drain fires on unverified code.

## Workaround

After `push:watch` returns, verify the HEAD-sha's workflows completed:

```bash
gh run list --commit=$(git rev-parse HEAD) --json name,status,conclusion
# Or watch the new-sha runs explicitly:
for RUN_ID in $(gh run list --commit=$(git rev-parse HEAD) --json databaseId --jq '.[].databaseId'); do
  gh run watch "$RUN_ID" --exit-status
done
```

## Impact Assessment

- **Who is affected**: anyone using `npm run push:watch` when an older workflow is still running at push time. Most sessions hit this rarely (the older workflow has to still be running when you push), but AFK loops that push multiple times quickly hit a higher collision rate.
- **Frequency**: race-condition-dependent. Rare for single-commit sessions; likelier for back-to-back AFK iterations or when a release-drain chain is mid-flight.
- **Severity**: Minor — the workaround is immediate and the bug is self-detecting on the next `gh run list` call. No publishable-artefact risk (the release-drain fires on the release queue, which `changesets/action` itself re-validates).
- **Analytics**: observed once (2026-04-20 AFK iter 4). No historical count; the failure is silent unless the operator notices the sha mismatch.

## Root Cause Analysis

### Structural

`package.json` line 27:

```json
"push:watch": "git push 2>&1 && RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId') && gh run watch \"$RUN_ID\" --exit-status"
```

`gh run list --limit 1` orders by `createdAt` descending. The most-recently-CREATED run is usually (but not always) for the most-recent commit. When an older workflow is still starting up or in flight at `git push` time, the "most recent" run can still be an older sha's workflow.

`gh run list` supports `--head-sha` but this script does not use it. Passing `--commit=$(git rev-parse HEAD)` after push would constrain the result set to runs for the pushed commit.

There is also a multi-workflow issue: the repo has 3 workflows that fire on push (`ci.yml`, `release.yml`, `release-preview.yml`). `--limit 1` picks just one of them; the script watches one while the other(s) continue. For "CI green before drain", all three should have completed.

### Fix strategy

Replace the single-run watch with a loop over HEAD-sha runs:

```json
"push:watch": "git push 2>&1 && sleep 5 && for id in $(gh run list --commit=$(git rev-parse HEAD) --branch main --json databaseId --jq '.[].databaseId'); do gh run watch \"$id\" --exit-status; done"
```

The `sleep 5` gives GitHub Actions a moment to enumerate the new sha's runs (they are not instantly listable after `git push`). Tunable if 5s is wrong in practice.

Alternative: keep `--limit 1` behaviour but constrain by sha — `gh run list --commit=$(git rev-parse HEAD) --limit 1`. This would still only watch one workflow, but at least it would be one of the correct sha's workflows.

### Affected files

- `package.json` — one-line change to the `push:watch` script.
- `packages/shared/test/push-watch-anchoring.bats` (NEW, optional) — doc-lint bats assertion that the `push:watch` script contains `--commit=$(git rev-parse HEAD)` so the anchoring doesn't regress.

### Investigation Tasks

- [x] Reproduce: observed 2026-04-20 AFK iter 4; `push:watch` reported success on prior-sha workflow `24642766489` while new-sha CI `24649483413` was still `in_progress`.
- [ ] Decide between `sleep + loop all head-sha runs` (watches every workflow) vs `--head-sha --limit 1` (watches one, loses multi-workflow coverage). Prefer the first.
- [ ] Apply the one-line change to `package.json`.
- [ ] Optional: add bats doc-lint regression test.
- [ ] Verify next AFK loop's push:watch anchors correctly.

## Fix Released

Shipped 2026-04-20 (AFK iter 6 iter 5, commit pending).

- `package.json` — `push:watch` script replaced with:

  ```
  git push 2>&1 && sleep 5 && for id in $(gh run list --commit=$(git rev-parse HEAD) --branch main --json databaseId --jq '.[].databaseId'); do gh run watch "$id" --exit-status || exit $?; done
  ```

  Anchors on HEAD sha (eliminates the `--limit 1` race where prior-sha workflow success was reported). Iterates over all runs for the pushed commit (so all 3 workflows — ci.yml / release.yml / release-preview.yml — are watched). Propagates exit code from any failing run via `|| exit $?` so ADR-018/ADR-020's release-drain gate sees real CI outcomes. The 5s sleep gives GitHub Actions time to enumerate runs for the new sha.
- `packages/shared/test/push-watch-anchoring.bats` — NEW. 6 doc-lint structural assertions (Permitted Exception per ADR-005) regression-guarding the anchoring pattern, the exit-code propagation, and the P060 `--limit 1` antipattern.

Architect review PASSED with one critical advisory (exit-code propagation) which was incorporated as `|| exit $?`. JTBD review PASSED (primary JTBD-006: audit trail across AFK iterations; secondary JTBD-002 and JTBD-201).

Awaiting user verification: next `npm run push:watch` invocation — the watched runs should have sha matching `git rev-parse HEAD`, all 3 workflows should be watched, and any failing workflow should cause non-zero exit.

## Related

- **P054** — `release:watch` drift-hash stability. Same defect class (script doesn't anchor on the pipeline state it just caused), different script. P054 is Verification Pending.
- **BRIEFING.md** — new line added 2026-04-20 covering the race and the workaround, pointing at this ticket.
- **`package.json` `push:watch` script** — the fix target.
- **ADR-020 auto-release** — the release-drain in work-problems Step 6.5 consumes push:watch's exit code; anchoring matters for release-drain correctness.
