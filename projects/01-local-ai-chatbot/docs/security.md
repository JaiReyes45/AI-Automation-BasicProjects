# Security and privacy

## Current boundary

The intended design is local: n8n and Ollama run in the local Docker
environment. That avoids sending prompts to a hosted AI provider, but local
operation does not make sensitive data automatically safe.

## Rules

- Do not submit real customer data, passwords, tokens, or private documents.
- Keep `.env` files and n8n credentials outside Git.
- Bind local development services to localhost unless exposure is explicitly reviewed.
- Inspect workflow exports before committing them for embedded credential data.

## Known gaps

The export does not show authentication, authorization, rate limiting, content
filtering, retention controls, or audit logging. Do not present this workflow
as a public-facing chat application.
