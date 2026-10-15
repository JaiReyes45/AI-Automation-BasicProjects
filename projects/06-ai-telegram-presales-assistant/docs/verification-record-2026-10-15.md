# Verification record — 2026-10-15

Timezone: Asia/Manila. Status: implemented local portfolio demo; acceptance testing
in progress. This record supersedes earlier test-count and source-fingerprint
claims, not the remaining limitations in the test matrix.

## Current source

`runtime/engine.js` SHA-256:

```text
3cdbfa07e252be3d9545ee2877ca30e56984c10ff32393c92a570bb85b8ceecb
```

The generated source exports contain 12 matching engine embeddings across 13
inactive workflows. Only relevant live workflows were republished during fixes;
source exports are independent of deployed workflow history.

## Verified before repository preparation

- 42 engine/intake tests passed using the approved local catalog.
- Requirement reclassification preserves saved answers; old estimates are invalidated.
- Explicit manual/no-app answers advance instead of repeating the applications question.
- Four-turn native restaurant discovery passed through installed subworkflows.
- Native transport and healthcare-administration discovery checks passed. The
  healthcare probe first exposed category drift; targeted follow-up field binding
  and exact platform selection fixed it, and the probe was rerun successfully.
- Deterministic PHP 6,000–12,000 estimate regression passed.
- Local and public health endpoints returned HTTP 200 during the preceding check.

The native conversation probes used synthetic data and local Ollama for open-ended
turns. They did not send Telegram messages or create customer records. Unit tests
also cover education, retail, and construction examples; these do not establish
exhaustive industry support or healthcare compliance.

## Remaining acceptance work

- Full live estimate → consent → contact → ticket-correlated owner notification.
- Authenticated custom-intake behavior during an actual database outage.
- Broader adversarial, boundary, model-failure, and network-failure testing.
- Reviewed synthetic screenshots and final demonstration capture.

Local model latency and occasional misunderstanding remain limitations. A temporary
HTTPS tunnel requires its own running process. No exactly-once external delivery,
production-readiness, or final commercial quotation guarantee is claimed.

## Publication boundary

Preparation checks rerun on 2026-10-15: all 42 engine/intake tests passed, the
isolated database rollback harness passed (including repeated runtime migration),
and all 13 inactive credential-free exports matched the current engine. Staged
source checks found no token/private-key/live-tunnel patterns, configured secret
values, private runtime artifacts, or unresolved relative Markdown links.
`git diff --cached --check` passed. These are scoped checks, not a security audit
or a fresh full installation/reproduction test.

Only reviewed project source, documentation, placeholder configuration, tests, and
inactive workflow exports belong in Git. `.env`, `.runtime`, logs, database dumps,
tokens, owner identifiers, and customer screenshots remain excluded. No real
customer data should be needed to reproduce the documented tests.
