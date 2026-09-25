# n8n CLI Operations

Use the n8n CLI as this project's default workflow-management interface.

## Rules

- Run commands from the repository root.
- Keep sanitized workflow JSON in `projects/04-local-ai-helpdesk-ticket-triage/workflows/`.
- Do not export credentials or store passwords in workflow JSON, Git, or shell history.
- Imported workflows must remain inactive. Do not use `--activeState=fromJson`.
- Do not publish a workflow unless the user explicitly approves it.
- Never use `docker compose down -v`.

## Inspect

```bash
docker compose exec -T n8n n8n list:workflow
docker compose exec -T n8n n8n list:workflow --active=false
docker compose exec -T n8n n8n list:workflow --active=true
```

## Import a workflow inactive

The repository `projects/` directory is mounted read-only at `/projects` in the n8n container.

```bash
docker compose exec -T n8n n8n import:workflow \
  --input=/projects/04-local-ai-helpdesk-ticket-triage/workflows/07-failed-job-reprocessing.json
```

The default import behavior deactivates the workflow. Verify with:

```bash
docker compose exec -T n8n n8n list:workflow --active=false
```

The error-capture and reprocessing exports are workflows 06 and 07. Do not
activate their webhooks or the notification schedule during development.

## Execute manually

Only after the required n8n credential exists and the workflow is reviewed:

```bash
docker compose exec -T n8n n8n execute --id=<workflow-id>
```

Use synthetic ticket data only.

## Credentials

The CLI can import credential artifacts, but those artifacts can contain encrypted sensitive data tied to the instance encryption key. This project does not version credential exports.

Create the `helpdesk_app` PostgreSQL credential through a secure approved n8n management path. Do not place `HELPDESK_DB_PASSWORD` in a command, export, or Git file.

## Audit

```bash
docker compose exec -T n8n n8n audit
```
