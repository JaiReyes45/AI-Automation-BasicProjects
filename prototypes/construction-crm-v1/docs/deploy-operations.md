# Deploy always-on operations

This is a reviewable deployment template. No cloud service, DNS record, provider credential or repository publication is created by packaging it. Live HubSpot/GHL and hosted-model capability tests remain required before production activation.

Use an always-on Linux host with Docker Compose, a public domain and inbound TCP 80/443. Caddy provides HTTPS. PostgreSQL, the worker, qualification adapter and n8n have no published ports. The local coding runner is not part of this Compose stack. The edge network uses `172.30.94.0/24`; change the subnet, fixed proxy address and `TRUSTED_PROXIES` together if it conflicts with another network.

Generate private deployment files once from the repository root:

```powershell
npm.cmd --prefix services/operations ci --ignore-scripts
npm.cmd --prefix services/operations run setup -- --directory .private-operations
Copy-Item deploy/.env.example deploy/.env
```

Set your domain, scheduling URL, verified GHL IDs and hosted model endpoint in `deploy/.env`. Keep `.private-operations/` and `deploy/.env` out of source control. Back up the encryption key before starting. Windows operators must restrict the private directory's NTFS permissions; file mode `0600` alone is not an ACL guarantee.

After the host/domain and concrete deployment are approved, run these commands on that host:

```sh
docker compose --env-file deploy/.env -f deploy/compose.yaml up -d db
docker compose --env-file deploy/.env -f deploy/compose.yaml --profile manage run --rm manage node services/operations/src/manage.mjs migrate
docker compose --env-file deploy/.env -f deploy/compose.yaml --profile manage run --rm manage node services/operations/src/manage.mjs provision
docker compose --env-file deploy/.env -f deploy/compose.yaml --profile manage run --rm manage node services/operations/src/manage.mjs bootstrap --output /operator-secrets/owner_token
docker compose --env-file deploy/.env -f deploy/compose.yaml up -d gateway qualification n8n
```

Migrations/provisioning use a separate provisioner. Gateway and worker use different logins and restricted database groups. Bootstrap is one-time; owner tokens expire after 30 days. Read the new token privately and configure the local dashboard environment. Never paste provider tokens into a chat, source file or booking URL.

Import inactive workflow `30-qualify-existing-lead.json` into your private n8n instance. Configure Header Auth on the webhook using `qualification_workflow_token`; configure the outgoing request's Header Auth using `internal_adapter_token`. Both use the header `Authorization: Bearer <private value>`. The outgoing node targets `http://qualification:8090/internal/qualification`. Publish only after a stored-lead synthetic test proves the terminal database result. Then start `worker edge` with the same Compose command. The worker waits for n8n readiness and the qualification adapter health check. The original 04/05 synthetic consumers stay inactive. Access the editor through an authenticated private operator connection; do not add an edge route to it.

The optional hosted Ollama endpoint must be independent of the laptop. Set `OLLAMA_URL` and `EXTRACTION_MODEL`; verify its 512-output-token cap and 15-second response deadline with the selected model. Without a provider, enquiries enter review and booking remains available. The shared extraction allowance defaults to 100 calls/day; at most one repair is reserved per lead.

Configure HubSpot using a reviewed service key with contacts/companies/deals read/write scopes. Supply exact pipeline, unscheduled stage, and unique deal-correlation property IDs. Scheduled-stage updates stay disabled by default and require an existing eligible deal plus a current verified appointment. Store a provider credential from private files:

```sh
node services/operations/src/manage.mjs configure --provider HUBSPOT --token-file /private/hubspot-token --config-file /private/hubspot-config.json
```

Run that management command with the worker database URL and stable encryption key. It stores an AES-GCM envelope as **UNVERIFIED**. A controlled test-account capability run with actual returned IDs must precede activation; configuration alone never sets VERIFIED. GHL similarly requires the configured sub-account/calendar, `calendars/events.readonly`, and optional `contacts.readonly`. Subscribe marketplace appointment events to `/v1/integrations/ghl/callback`; verify current Ed25519 signature behavior and create/cancel/reschedule with an owner-controlled test inbox. The supplied widget link remains the calendar; the app does not invent availability.

Public endpoints: `/`, `/v1/config`, `POST /v1/leads`, bounded `/v1/receipts/:token`, and signed GHL callback. `/v1/owner/*` requires an expiring owner bearer token over HTTPS. No CORS bypass, public database port, public n8n editor, model key in the browser or cloud-to-local coding endpoint is provided.

Worker defaults: one job per tick, one-second idle poll, 60-second lease, 15-second heartbeat and 45-second adapter deadline. Uncertain effects reconcile before another create. Auth failures or unresolved effects enter review; retries are bounded. Confirmed booking and failed CRM delivery remain separate states.

Run encrypted off-host logical backups using the provisioner through a private maintenance connection, and test restore into a new database. Preserve PostgreSQL data, n8n data and its encryption key, provider envelopes and the operations encryption key together. Pin and verify container digests for your deployment; the Node and Caddy tags in this template have not been built/deployed as part of the local pilot.


Public receipt observation uses a separate 60-reads/minute address budget; lead submissions retain their 10-writes/minute budget. Both limits are configurable in the deployment environment. Receipt polling defaults to ten seconds, honors rate-limit recovery delays, backs off after transient failures and pauses after thirty minutes with a manual Check status action. CRM completion never stops observation of later appointment changes.

Provider jobs stopped for review appear in the owner review queue. Retry with reconciliation is an explicit, versioned, audited owner action; it preserves unknown provider effects and never authorizes a blind duplicate create. The seventh additive migration installs the review/job linkage and open-review uniqueness constraints.

Scheduled-stage eligibility is checked both when a canonical appointment arrives and after a deal mapping is confirmed. The worker reads the current verified integration policy; updates stay disabled by default. A cancellation detected after the remote deal read prevents the scheduled write. If booking evidence changes during an already in-flight provider write, the result enters review and records the observed remote stage. The adapter does not automatically reverse that write, because that could overwrite a later manual stage. Provider-side atomic compare-and-set is not established by the fixture tests.
