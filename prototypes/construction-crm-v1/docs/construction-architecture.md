# Construction CRM architecture

[System architecture diagrams](diagrams/construction-crm-architecture.html) preserve the approved high-level design. The implementation uses two independent trust zones:

1. Local Node/SQLite dashboard and bounded Codex runner. Build task DAGs, exact runtime approvals, real verifier evidence and a pure Canvas projection. The listener binds to loopback only.
2. Hosted Node/PostgreSQL gateway, sole leased outbox worker, private n8n bridge and private bounded qualification adapter. Public enquiry receipts survive local shutdown. The local server reads sanitized hosted state through outbound HTTPS.

The user-selected GHL calendar replaces the plan’s default HubSpot Meetings widget. The existing calendar supplies availability; trusted GHL server reads/signatures supply confirmation. HubSpot remains the CRM destination. Missing provider authority is an explicit unverified/review state.

Production qualification reuses the exact recovered extraction validator and deterministic scoring node code inside a transaction-owning Node adapter. Inactive n8n workflow30 bridges existing lead IDs to that adapter and waits for durable terminal state. Legacy synthetic consumers remain inactive. See [qualification adapter](qualification-adapter.md).

Data stores remain separate. Canonical allowlisted events carry IDs/status/evidence only; the scene never receives customer names, email addresses, provider credentials, prompts or model reasoning. Renderer time changes decorative positions only. Cloud events cannot dispatch local tasks. Event retention preserves a checkpoint and reconnect cursor.

The deployment template exposes HTTPS only at Caddy. Database, worker, model adapter and n8n editor have no public ports. Operator secrets are stable file-backed deployment material. Source releases and static demos contain no live authority.
