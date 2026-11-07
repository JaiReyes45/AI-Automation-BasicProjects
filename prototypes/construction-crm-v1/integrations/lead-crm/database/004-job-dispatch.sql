BEGIN;
ALTER TABLE lead_crm.outbox_jobs DROP CONSTRAINT outbox_jobs_job_type_check;
ALTER TABLE lead_crm.outbox_jobs ADD CONSTRAINT outbox_jobs_job_type_check CHECK(job_type IN('QUALIFY_LEAD','CRM_SYNC','SALES_NOTIFICATION','FOLLOW_UP'));
CREATE TABLE lead_crm.extraction_allowances(day DATE PRIMARY KEY,used INTEGER NOT NULL CHECK(used>=0));
INSERT INTO lead_crm.schema_migrations(version,description) VALUES('004','Existing-lead qualification dispatch');
COMMIT;
