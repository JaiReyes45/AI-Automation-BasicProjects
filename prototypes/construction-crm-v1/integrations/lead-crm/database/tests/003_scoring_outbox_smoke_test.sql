BEGIN;

WITH company_row AS (
    INSERT INTO lead_crm.companies (display_name, normalized_name, domain, country_code)
    VALUES ('Synthetic Phase Five Co', 'synthetic phase five co', 'phase-five.example.test', 'PH')
    RETURNING id
), contact_row AS (
    INSERT INTO lead_crm.contacts (
        company_id, first_name, last_name, email_original, email_normalized, job_title
    )
    SELECT id, 'Jamie', 'Tester', 'jamie@phase-five.example.test',
           'jamie@phase-five.example.test', 'Director'
    FROM company_row
    RETURNING id, company_id
), submission_row AS (
    INSERT INTO lead_crm.lead_submissions (
        submission_id, correlation_id, company_id, contact_id, source, submitted_at,
        email_normalized, message, consent, raw_payload, normalized_payload, payload_hash,
        processing_status, lead_score, qualification, scoring_rule_version, ai_confidence,
        ai_extraction
    )
    SELECT
        '51000000-0000-4000-8000-000000000001'::uuid,
        '52000000-0000-4000-8000-000000000001'::uuid,
        company_id, id, 'test_client', NOW(), 'jamie@phase-five.example.test',
        'Synthetic invoice approval automation request.', true,
        '{"synthetic":true}'::jsonb, '{"synthetic":true}'::jsonb,
        repeat('a', 64), 'CRM_SYNC_PENDING', 100, 'HOT', 'v1', 0.950,
        '{"schema_version":"1.0","service_category":"invoice_approval_automation","purchase_timeline":"within_30_days","decision_maker_status":"decision_maker","location_country_code":"PH","need_summary":"Synthetic invoice approval automation request for controlled testing.","confidence":0.95}'::jsonb
    FROM contact_row
    RETURNING id, correlation_id
), review_row AS (
    INSERT INTO lead_crm.review_queue (submission_id, reason_code, reason_detail)
    SELECT id, 'SYNTHETIC_REVIEW_TEST', '{"synthetic":true}'::jsonb FROM submission_row
    RETURNING id
), outbox_row AS (
    INSERT INTO lead_crm.outbox_jobs (
        idempotency_key, submission_id, job_type, destination, payload, max_attempts
    )
    SELECT 'test:phase5:notification', id, 'SALES_NOTIFICATION', 'mailpit',
           '{"synthetic":true,"simulate_failure_until":1}'::jsonb, 3
    FROM submission_row
    RETURNING id
), sync_row AS (
    INSERT INTO lead_crm.crm_sync_records (
        submission_id, provider, object_type, local_record_id, request_fingerprint
    )
    SELECT id, 'HUBSPOT', 'CONTACT', id, 'synthetic-contact-fingerprint'
    FROM submission_row
    RETURNING id
)
SELECT
    (SELECT count(*) FROM review_row) AS review_rows,
    (SELECT count(*) FROM outbox_row) AS outbox_rows,
    (SELECT count(*) FROM sync_row) AS crm_sync_rows;

DO $$
DECLARE
    job lead_crm.outbox_jobs%ROWTYPE;
BEGIN
    SELECT * INTO job
    FROM lead_crm.outbox_jobs
    WHERE idempotency_key = 'test:phase5:notification';

    IF job.status <> 'PENDING' OR job.attempt_count <> 0 THEN
        RAISE EXCEPTION 'Unexpected initial outbox state';
    END IF;

    UPDATE lead_crm.outbox_jobs
    SET status = 'RETRY', attempt_count = 1, last_error = 'synthetic transient failure'
    WHERE id = job.id;

    UPDATE lead_crm.outbox_jobs
    SET status = 'DEAD_LETTER', attempt_count = max_attempts,
        last_error = 'synthetic exhausted failure'
    WHERE id = job.id;

    UPDATE lead_crm.outbox_jobs
    SET status = 'PENDING', attempt_count = 0, available_at = NOW(),
        locked_at = NULL, last_error = NULL
    WHERE id = job.id AND status = 'DEAD_LETTER';

    IF NOT EXISTS (
        SELECT 1 FROM lead_crm.outbox_jobs
        WHERE id = job.id AND status = 'PENDING' AND attempt_count = 0
    ) THEN
        RAISE EXCEPTION 'Replay did not restore the job';
    END IF;

    RAISE NOTICE 'PASS: outbox retry, dead-letter, and replay transitions';
END;
$$;

ROLLBACK;
