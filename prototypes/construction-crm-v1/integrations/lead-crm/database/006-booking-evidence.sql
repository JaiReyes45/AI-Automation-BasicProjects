BEGIN;
ALTER TABLE lead_crm.outbox_jobs DROP CONSTRAINT outbox_jobs_job_type_check;
ALTER TABLE lead_crm.outbox_jobs ADD CONSTRAINT outbox_jobs_job_type_check CHECK(job_type IN('QUALIFY_LEAD','CRM_SYNC','BOOKING_RECONCILE','SALES_NOTIFICATION','FOLLOW_UP'));
ALTER TABLE lead_crm.appointments ADD COLUMN evidence_hash TEXT;
CREATE TABLE lead_crm.booking_cursors(provider TEXT PRIMARY KEY,cursor BIGINT NOT NULL DEFAULT 0,updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
INSERT INTO lead_crm.schema_migrations(version,description) VALUES('006','Verified booking evidence and reconciliation cursors');
COMMIT;
