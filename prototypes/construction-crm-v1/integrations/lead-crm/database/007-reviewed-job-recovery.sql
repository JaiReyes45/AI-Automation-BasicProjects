BEGIN;
ALTER TABLE lead_crm.review_queue ADD COLUMN job_id UUID REFERENCES lead_crm.outbox_jobs(id) ON DELETE RESTRICT;
ALTER TABLE lead_crm.review_queue ALTER COLUMN submission_id DROP NOT NULL;
ALTER TABLE lead_crm.review_queue ADD CONSTRAINT review_has_subject CHECK(submission_id IS NOT NULL OR job_id IS NOT NULL);
ALTER TABLE lead_crm.review_queue DROP CONSTRAINT review_queue_submission_id_reason_code_status_key;
CREATE UNIQUE INDEX review_queue_lead_open_unique ON lead_crm.review_queue(submission_id,reason_code) WHERE status='OPEN' AND job_id IS NULL;
CREATE UNIQUE INDEX review_queue_job_open_unique ON lead_crm.review_queue(job_id) WHERE status='OPEN' AND job_id IS NOT NULL;
INSERT INTO lead_crm.schema_migrations(version,description) VALUES('007','Visible provider reviews and audited bounded job recovery');
COMMIT;
