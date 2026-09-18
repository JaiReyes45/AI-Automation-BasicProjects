# Security and privacy

- n8n and Mailpit bind only to localhost. Ollama and SMTP are internal-only.
- Secrets stay in ignored `.env` or n8n credentials; exports never contain them.
- Inputs are type, length, email, and control-character checked before inference.
- PostgreSQL nodes use parameterized queries and a dedicated least-privilege role is the target configuration.
- Logs use correlation IDs, state, timing, and error codes; they omit raw ticket bodies, tokens, and addresses.
- Ticket content cannot modify the fixed prompt or call tools. JSON schema validation is mandatory.
- Workflow JSON is reviewed before commit for credentials, payloads, URLs, and personal data.
