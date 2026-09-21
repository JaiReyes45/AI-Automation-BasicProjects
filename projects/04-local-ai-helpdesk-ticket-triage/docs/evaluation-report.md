# Evaluation Report — 2026-09-21

## Measured baseline

| Measure | Result | Method |
|---|---:|---|
| Deterministic validation/routing/SLA cases | 22 passed | `tests/run-tests.js` |
| Static workflow-contract cases | 23 passed | `tests/workflow-contracts.js` |
| Database constraint/replay/SLA transaction | passed | `tests/database-constraints.sql` (rolled back) |
| Live Ollama contract probes | 1 passed | Internal synthetic injection-style request |
| Invalid model-output rate | 0/1 observed | Contract probe only; not statistically meaningful |
| Classification agreement | Not measured | No labelled evaluation set yet |
| Human-review rate | Not measured | No end-to-end execution dataset retained |
| End-to-end latency | Not measured | Inactive webhook/schedule policy prevents payload-injected CLI execution |

## Recovery and safety evidence

The database test verified duplicate idempotency rejection, failed-job
claim-after-resolution rejection, and duplicate SLA-breach rejection. Static
contracts verified all helpdesk exports remain inactive, include the expected
failure/replay/SLA guard nodes, and contain no secret-like configuration fields.

## Limitations

The n8n CLI can execute a workflow by ID but cannot supply a synthetic webhook
payload. Keeping webhooks and schedules inactive therefore prevents a truthful
full-chain run, controlled service outage, and worker retry/reprocessing run.
These are operational acceptance tests to perform only in a disposable test
environment or under an explicit temporary-execution procedure; they are not
claimed as completed by this report.
