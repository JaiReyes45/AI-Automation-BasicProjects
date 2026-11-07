-- Run once as provisioner after migrations. These are NOLOGIN groups; grant a
-- group to a separately created deployment login. Never use the provisioner at runtime.
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='construction_gateway') THEN CREATE ROLE construction_gateway NOLOGIN; END IF;
IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='construction_worker') THEN CREATE ROLE construction_worker NOLOGIN; END IF; END $$;
GRANT USAGE ON SCHEMA lead_crm TO construction_gateway,construction_worker;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA lead_crm TO construction_gateway,construction_worker;
GRANT SELECT,INSERT,UPDATE ON lead_crm.lead_submissions,lead_crm.lead_receipts,lead_crm.owner_tokens TO construction_gateway;
GRANT SELECT,INSERT ON lead_crm.owner_bootstrap,lead_crm.audit_events,lead_crm.scene_events,lead_crm.policy_decisions,lead_crm.outbox_jobs,lead_crm.event_inbox TO construction_gateway;
GRANT SELECT ON lead_crm.scene_checkpoints,lead_crm.appointments,lead_crm.review_queue,lead_crm.crm_sync_records TO construction_gateway;
GRANT SELECT,INSERT,UPDATE ON lead_crm.lead_submissions,lead_crm.companies,lead_crm.contacts,lead_crm.opportunities,lead_crm.activities,lead_crm.appointments,lead_crm.outbox_jobs,lead_crm.crm_sync_records,lead_crm.qualification_claims,lead_crm.extraction_cache,lead_crm.review_queue,lead_crm.integration_connections,lead_crm.extraction_allowances,lead_crm.lead_provider_links,lead_crm.booking_cursors TO construction_worker;
GRANT SELECT,INSERT ON lead_crm.audit_events,lead_crm.policy_decisions,lead_crm.scene_events,lead_crm.event_inbox TO construction_worker;
GRANT SELECT ON lead_crm.scene_checkpoints TO construction_worker;

GRANT UPDATE(status,attempt_count,available_at,version,needs_reconciliation) ON lead_crm.outbox_jobs TO construction_gateway;
GRANT UPDATE(status,version,resolved_at) ON lead_crm.review_queue TO construction_gateway;
