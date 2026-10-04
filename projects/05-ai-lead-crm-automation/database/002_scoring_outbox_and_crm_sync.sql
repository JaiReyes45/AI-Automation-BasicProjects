BEGIN;

CREATE TABLE lead_crm.review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES lead_crm.lead_submissions(id) ON DELETE RESTRICT,
    reason_code TEXT NOT NULL,
    reason_detail JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(reason_detail) = 'object'),
    status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'RESOLVED', 'DISMISSED')),
    assigned_to TEXT,
    resolution_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    UNIQUE (submission_id, reason_code, status)
);

CREATE INDEX review_queue_open_idx
    ON lead_crm.review_queue (created_at)
    WHERE status = 'OPEN';

CREATE TABLE lead_crm.outbox_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key TEXT NOT NULL UNIQUE,
    submission_id UUID REFERENCES lead_crm.lead_submissions(id) ON DELETE RESTRICT,
    job_type TEXT NOT NULL CHECK (job_type IN ('SALES_NOTIFICATION', 'CRM_SYNC', 'FOLLOW_UP')),
    destination TEXT NOT NULL,
    payload JSONB NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'RETRY', 'SENT', 'DEAD_LETTER')),
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 3 CHECK (max_attempts BETWEEN 1 AND 10),
    available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    last_error TEXT,
    external_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX outbox_jobs_due_idx
    ON lead_crm.outbox_jobs (available_at, created_at)
    WHERE status IN ('PENDING', 'RETRY');

CREATE TABLE lead_crm.crm_sync_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES lead_crm.lead_submissions(id) ON DELETE RESTRICT,
    provider TEXT NOT NULL CHECK (provider IN ('HUBSPOT')),
    object_type TEXT NOT NULL CHECK (object_type IN ('CONTACT', 'COMPANY', 'DEAL')),
    local_record_id UUID NOT NULL,
    external_id TEXT,
    sync_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (sync_status IN ('PENDING', 'SYNCED', 'FAILED', 'REVIEW_REQUIRED')),
    request_fingerprint TEXT NOT NULL,
    last_error TEXT,
    last_attempt_at TIMESTAMPTZ,
    synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, object_type, local_record_id),
    UNIQUE (provider, object_type, request_fingerprint)
);

CREATE INDEX crm_sync_records_submission_idx
    ON lead_crm.crm_sync_records (submission_id, object_type);

CREATE TRIGGER outbox_jobs_set_updated_at
    BEFORE UPDATE ON lead_crm.outbox_jobs
    FOR EACH ROW EXECUTE FUNCTION lead_crm.set_updated_at();

CREATE TRIGGER crm_sync_records_set_updated_at
    BEFORE UPDATE ON lead_crm.crm_sync_records
    FOR EACH ROW EXECUTE FUNCTION lead_crm.set_updated_at();

INSERT INTO lead_crm.schema_migrations (version, description)
VALUES ('002', 'Deterministic scoring support, human review, durable outbox, and CRM sync tracking');

COMMIT;
