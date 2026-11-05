#!/usr/bin/env bash
# Creates or updates the disposable least-privilege helpdesk_app role.
# The password is read privately and is never written to disk or shell history.
set -euo pipefail

read -rsp "Enter HELPDESK_DB_PASSWORD from .env: " helpdesk_role_password
printf '\n'

export helpdesk_role_password
trap 'unset helpdesk_role_password' EXIT

docker compose exec -T -e helpdesk_role_password postgres sh -c \
  'exec psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v helpdesk_db_password="$helpdesk_role_password"' \
  < projects/04-local-ai-helpdesk-ticket-triage/migrations/002_helpdesk_app_role.sql
