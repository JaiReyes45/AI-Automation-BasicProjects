# Phase 7 — HubSpot Developer Test-Account Integration

## Public repository state

Workflow `20 - HubSpot CRM Sync Template` is exported inactive and contains no
credential reference or token. The local configured version has been tested;
the sanitized public export prevents accidental calls after import.

## What the workflow prepares

- Contact upsert keyed by normalized email.
- Company search followed by create or update, using a deterministic company key
  when no dependable website domain is available.
- Deal search followed by create or update only for HOT leads.
- Contact-to-company and deal-to-contact/company associations.
- PostgreSQL `crm_sync_records` rows provide idempotency and traceability.

## Credential setup in n8n

Use only a HubSpot developer test account.

1. In HubSpot, create a private app for the test account.
2. Grant only the CRM object scopes needed for contacts, companies, and deals.
3. Copy the token once.
4. In the n8n browser UI, open **Credentials** and create a Header Auth or
   HubSpot credential. Store the token there, never in a Set or Code node.
5. Open each HubSpot HTTP node, select the credential, and use credential-based
   Header Auth. Do not place the token in a Set or Code node.
6. Keep the imported workflow inactive and test one synthetic lead manually.
7. Verify the returned contact, company, deal, and association IDs before
   activating the complete orchestrator.

## Required review before activation

- Confirm only synthetic contacts and companies are present.
- Confirm rerunning the same submission updates rather than duplicates.
- Confirm a WARM/COLD lead does not create a deal.
- Confirm a HOT lead creates at most one deal.
- Confirm 429 and 5xx responses create retryable outbox failures.
- Confirm 400/401/403 responses stop and require human review.

The local test account passed contact creation/update, company creation/update,
HOT-deal creation/update, and contact/company/deal association checks. A full
synthetic run ended with PostgreSQL status `CRM_SYNCED`. Repository users must
repeat these checks with their own developer test account before activation.
