# Qualification adapter

Production reuses the exact code of the recovered `02-extraction` strict validation node and `03-scoring` deterministic scoring node in `recovered-rules.mjs`. Its generated wrappers include node hashes and have parity tests. The original inactive workflows remain byte-for-byte provenance assets, including synthetic baseline behavior.

Workflow 30 is an inactive, operator-owned narrow bridge: authenticated existing-lead IDs Ã¢â€ â€™ internal adapter Ã¢â€ â€™ durable qualification/review result. The adapter reads the stored enquiry, reserves attempts in PostgreSQL, performs at most two bounded model calls, applies the recovered rules and commits one CRM job. Public intake is never invoked again. No production sales-notification or follow-up job is emitted.

This moves transaction/attempt ownership out of the legacy n8n effect nodes to avoid activating their synthetic delivery paths. Bind separate Header Auth credentials on the webhook and outbound request, PostgreSQL worker credentials on the private adapter, and the private adapter URL in the HTTP node before publishing workflow 30. Neither the n8n editor nor port 8090 should be published.

The optional hosted Ollama adapter uses `/api/generate`, structured format and `num_predict: 512`, with a 15-second deadline. Provider output must pass the recovered strict schema. The [official generate API](https://docs.ollama.com/api/generate) documents structured formats and measured token fields. A deployment must verify its selected model supports the configured output cap. No live provider contract has been exercised here; missing provider produces review and never prevents booking.

Database claims expire after 45 seconds; reservations persist across lost responses and restarts. Cache keys include enquiry facts, schema and model versions. Default shared daily allowance is 100 extraction calls, configurable on the hosted adapter. It must run on always-on infrastructure for laptop-independent operation.

The published private bridge was subsequently verified in a disposable n8n/PostgreSQL stack with generated Header Auth credentials and a model stub. Authentication rejected the wrong credential, qualification returned after its database commit, and replay caused no additional extraction call. See docs/verification/private-n8n-bridge.md. The live hosted-model contract remains pending.
