# Project 07 workflow exports

Four inactive workflows are installed locally and tested with synthetic messages.

| File | Purpose |
|---|---|
| 01-synthetic-intake.json | Generate a sample email; classify, match, persist, inspect decision |
| 02-simulated-label-delivery.json | Deliver durable label jobs to the local simulated mailbox |
| 03-controlled-scenario.json | Verify duplicates, interview advancement, failure, recovery |
| 04-expected-failure.json | Verify malformed input reaches the explicit failure branch |

No OAuth credentials, tokens, execution data, or real email are embedded. A
non-secret credential reference points to the local engine's HTTP Header Auth
credential. Configure it with scripts/import_n8n.py. The JSON files are not an
automatic backup of edits made in n8n. See docs/docker-setup.md and
 docs/workflow-contract.md. Real Gmail ingestion and labeling are D3.2, not enabled.
