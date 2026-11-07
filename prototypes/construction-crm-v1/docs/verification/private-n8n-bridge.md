# Published private n8n bridge verification

Command: `npm.cmd run test:qualification-bridge`.
Evidence: `.scratch/private-bridge/run-6bCXjE/evidence.json`.
Mode: synthetic inputs/model transport; real n8n2.34.5, HTTP and PostgreSQL boundaries.

A new disposable stack imported Header Auth credentials and workflow30, published that workflow with the installed CLI, started n8n, and waited for `/healthz/readiness`. The bridge called the actual private Node qualification adapter against a stored lead.

- Wrong incoming credential returned403.
- Correct request returned200 and `CRM_SYNC_PENDING` with an actual committed audit ID.
- Replayed dispatch returned200 without another model call; total stub calls1.
- No second public intake, fake CRM success, owner n8n change or provider credential was involved.
- Containers and temporary databases were removed after the run.

The initial harness polled only `/healthz`, which became available before n8n finished activating routes and returned an HTML shell to the early request. Waiting for the documented readiness endpoint corrected the test. Deployment worker health dependencies use readiness too.

This satisfies the published private orchestration check. It does not verify a live hosted model, HubSpot account or GHL booking account.


The final review version was rerun against another fresh published private n8n stack and passed the same authenticated terminal-commit and duplicate-replay checks. The actual qualification service health route also has a PostgreSQL-backed process test. Provider extraction remains a stub in this bridge check; a selected always-on model still needs its own capability test.
