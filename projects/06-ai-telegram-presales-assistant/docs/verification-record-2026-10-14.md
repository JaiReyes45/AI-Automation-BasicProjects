# Local verification record — 2026-10-14

Engine SHA256: `05f17e4c7644a5be974364ee92dff6e5ae237d3da0f7725ae621166fb6ede19f`.
Environment: project-isolated n8n 2.34.5, PostgreSQL 16, local Ollama qwen2.5:3b; Ubuntu/WSL and Windows Cloudflare Quick Tunnel.

Verified by tool execution:

- 27 engine/custom-intake tests passed using the live approved catalog.
- Isolated SQL rollback suite passed, including migration 003 twice.
- Concurrent disposable-database suite passed; all 22 prior table snapshots matched after synthetic cleanup.
- Existing migrations 001/002 preserved; 003–006 applied. Catalog: 25 services, four packages, ten adjustments.
- Final source imported and published; n8n restarted. Workflows 00–09 active; 10–12 manual.
- Post-deployment native n8n subworkflow checks passed: greeting, PHP 6,000–12,000 deterministic estimate, and real local-model CRM discovery.
- Temporary standard `lastNode` HTTP/PostgreSQL probe: successful response after 1.1 seconds including one-second database delay; database failure returned HTTP 500. Probe unpublished afterward.
- Actual custom intake rejected unauthenticated local and public requests with HTTP 403.
- Real Telegram `/start` and discovery messages completed once each; their replies were `sent` with Telegram message IDs. Observed acceptance-to-delivery times: 6.6 and 67.5 seconds. This is not a read receipt.
- Telegram confirmed a separately labelled owner setup notification. This was not a real lead/handoff ticket.
- Disposable-database administrator create/update/approve/deactivate/audit and invalid-field rejection passed; only that test's synthetic records were removed afterward.
- All 13 public workflow exports are inactive, credential-free and contain the current embedded engine. Private environment/binding files are Git-ignored. No commit or push performed.
- Pre-change database/workflow backups copied to the Ubuntu project's private `.runtime/backups/` directory; do not publish them.

Remaining acceptance: full live estimate → consent → contact → ticket-correlated owner notification; sanitized portfolio screenshots. Actual authenticated custom-intake behavior during a database outage was not tested; the standard HTTP mechanism and custom authentication were tested separately. Other partial cases remain explicitly listed in the test matrix. This local portfolio demonstration is not production-certified.

Keep Docker, Ollama and the background tunnel running during testing. Quick Tunnel addresses change when the tunnel is recreated; local AI responses can take about a minute. Never blindly resend an uncertain Telegram delivery.
