# Privacy, reset and administration

This is a synthetic portfolio system. Telegram identifiers, redacted messages, requirements, decisions and audit/consent history are stored locally in PostgreSQL. Ollama processes text locally; Telegram and Cloudflare transport traffic. Local model processing does not make the whole communication path local.

Consent must be granted before contact collection. Database intake recognizes an exact `/contact` command after stored consent, saves the address privately, and passes a redacted marker to the worker. The revised engine understands `state.contact_present`, and the SQL claim now supplies that flag. Unit consent checks and SQL contact-marker/withdrawal assertions passed; live Telegram end-to-end verification remains pending. `/decline` clears canonical contact and changes consent; it does not erase historical messages, audit records or previously delivered owner notifications.

`/reset` clears working requirements and pending estimate state while retaining existing consent and historical records. It does not delete the customer or automatically reopen a handed-off conversation. `/delete` records a request and human-review ticket. An operator must review identity, scope, database records, retained history and backups, perform any authorized deletion, and communicate the actual outcome separately. No automatic retention schedule or completed deletion is claimed.

## Owner handoff

The user's own Telegram account is approved and configured privately from the sole existing test customer. A synthetic setup message has Telegram confirmation and created no lead, but is not correlated with a real handoff ticket. Store the identifier only in private `presales.runtime_settings` under `owner_chat_id`; never put it in source, exports, screenshots or model input.

A ticket is durable before delivery is confirmed. Distinguish `ticket recorded`, `owner notification queued`, `Telegram send confirmed` and `person acknowledged`. None implies the next. Without a configured destination, retain the local ticket. Do not promise that a human has seen it or will respond by a deadline.

One ticket-correlated live owner verification remains pending. The setup-message confirmation proves destination reachability only. Correlate the real ticket, owner outbox result and recipient evidence separately; never repeat an uncertain send merely to obtain a screenshot.

## Operator tasks

Use authenticated local tools; no Telegram admin command or public administration webhook is provided. Workflows 10–12 inspect catalog, aggregate metrics and failed work. The local [admin CLI](../scripts/admin.py) is implemented: `catalog`, `handoffs`, `analytics`, `unanswered`, `upsert`, `replay-inbox`, `replay-outbox`, and `resolve-handoff`. Its hard-coded Docker target must match the actual environment. Implementation is established by source inspection; execution and deployment checks remain pending parent evidence.

- Review catalog edits as a transaction with explicit active/approved flags, current rates and audit evidence. Preserve existing operator edits. The current CLI field allowlist does not cover every catalog field or pricing-adjustment table; do not infer a complete catalog editor.
- Resolve a handoff only after review. The CLI reopens the conversation only when no open/acknowledged/in-progress tickets remain. Resetting requirements is a separate action.
- Before replay, inspect the exact failed inbox/outbox record and correlation IDs. For an uncertain send, inspect Telegram privately and explicitly acknowledge possible duplication before replaying. Never automatically replay a sent job.
- Inspect aggregate analytics without exporting raw customer history. The CLI's `unanswered` view counts selected audit events; it is not proof that every counted inquiry lacks a reply.

Keep private `.runtime/` staging out of exports and screenshots. The implementation ignore file excludes it, but ignore rules are not access control and do not remove already tracked files. Public documentation needs only synthetic identifiers and redacted evidence. No push is authorized.

The custom intake trigger must retrieve its bot credential through n8n's encrypted credential store. Keep webhook URLs/paths, authentication secret/header values and credential-bound files private as well. Incoming-request authentication and durable ACK timing require separate tests; credential encryption alone proves neither.

Teaching note: consent permits a particular use of contact data. Reset changes working memory. Deletion changes retained records. These are different operations and must have different confirmations.
