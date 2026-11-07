BEGIN;
ALTER TABLE lead_crm.outbox_jobs DROP CONSTRAINT outbox_jobs_status_check;
ALTER TABLE lead_crm.outbox_jobs ADD CONSTRAINT outbox_jobs_status_check CHECK(status IN('PENDING','PROCESSING','RETRY','SENT','DEAD_LETTER','REVIEW_REQUIRED'));
ALTER TABLE lead_crm.outbox_jobs ADD COLUMN lease_token UUID,ADD COLUMN lease_until TIMESTAMPTZ,ADD COLUMN worker_id TEXT,ADD COLUMN version INTEGER NOT NULL DEFAULT 0,ADD COLUMN needs_reconciliation BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE lead_crm.crm_sync_records ADD COLUMN effect_state TEXT NOT NULL DEFAULT 'READY' CHECK(effect_state IN('READY','CREATING','UNKNOWN','CONFIRMED'));
CREATE TABLE lead_crm.lead_provider_links(submission_id UUID NOT NULL REFERENCES lead_crm.lead_submissions(id),object_type TEXT NOT NULL,record_id UUID NOT NULL REFERENCES lead_crm.crm_sync_records(id),PRIMARY KEY(submission_id,object_type));
ALTER TABLE lead_crm.review_queue ADD COLUMN version INTEGER NOT NULL DEFAULT 0;
INSERT INTO lead_crm.schema_migrations(version,description) VALUES('005','Leased sole-consumer delivery and external intent reconciliation');
COMMIT;
