# Workflow exports

This directory holds sanitized n8n workflow exports used by the shared Docker
Compose environment. It is mounted into the n8n container as `/workflows` for
local import commands.

## Layout

- `04-local-ai-helpdesk-ticket-triage/` contains the source and consolidated helpdesk exports.
- `05-ai-lead-crm-automation/` is reserved for public-safe exports as that project is implemented.

Projects 01–03 retain their exports inside their own project folders so those
early learning projects remain self-contained. Do not move existing exports
only for consistency; update their documentation and import paths together if
a future migration is needed.

Before committing an export, remove credentials and check that it contains no
secret values or real personal data.
