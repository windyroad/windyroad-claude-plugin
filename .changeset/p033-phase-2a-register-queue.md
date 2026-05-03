---
"@windyroad/risk-scorer": minor
---

`wr-risk-scorer:pipeline` agent now emits a 3-column `RISK_REGISTER_HINT:` block (`<reason-tag> | <risk-slug> | <prose>`) and the `risk-score-mark.sh` PostToolUse hook parses each bullet and appends one JSONL line per valid entry to `.afk-run-state/risk-register-queue.jsonl`. The queue file is the durable bridge between pipeline-fire and risk-register population — consumer skills (work-problems, manage-problem, install-updates, assess-release) drain it in subsequent iters with dedicated `docs(risks): scaffold ...` commits per ADR-014 commit-grain discipline.

Backward-compatible **dual-parse contract**: the hook accepts both the new 3-column shape AND the legacy 2-column shape (`<reason-tag> | <prose>`), deriving the slug from the reason-tag plus the prose prefix when only two columns are present. In-flight pipeline agents on adopter machines whose prompt cache still emits the 2-column shape continue to enqueue entries — no hint loss during the cache-warm transition.

Pipeline agent stays `Read, Glob`-only (no agent-side write); the hook stays silent on stdout (ADR-045 Pattern 2); the queue artefact lives under `.afk-run-state/` which is already gitignored. 12-test behavioural-fixture bats covers both parse paths, mixed-shape blocks, malformed-bullet skip, append-only semantics, directory creation, and stdout silence — all GREEN with no regression in adjacent suites.

Driver: P033 Phase 2a (`docs/problems/033-no-persistent-risk-register.known-error.md`). Authority: ADR-056 (`docs/decisions/056-risk-register-back-channel-write-contract.proposed.md`). Parent ADR: ADR-047 (Phase 1 scaffolding precondition, landed iter 18). P033 status remains Known Error pending Phase 2b drain steps — Phase 2a closes the trigger gap (queue-write); Phase 2b materialises register files from the queue.
