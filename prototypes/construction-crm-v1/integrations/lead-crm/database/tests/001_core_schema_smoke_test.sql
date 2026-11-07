BEGIN;

INSERT INTO lead_crm.companies (
    id,
    display_name,
    normalized_name,
    domain,
    country_code
)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'Northstar Retail Systems',
    'northstar retail systems',
    'northstar-retail.example',
    'PH'
);

INSERT INTO lead_crm.contacts (
    id,
    company_id,
    first_name,
    last_name,
    email_original,
    email_normalized,
    job_title
)
VALUES (
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000001',
    'Maya',
    'Santos',
    'Maya.Santos@example-business.test',
    'maya.santos@example-business.test',
    'Operations Director'
);

INSERT INTO lead_crm.lead_submissions (
    id,
    submission_id,
    correlation_id,
    company_id,
    contact_id,
    source,
    submitted_at,
    email_normalized,
    message,
    consent,
    raw_payload,
    normalized_payload,
    payload_hash
)
VALUES (
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000203',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    'gmail',
    NOW(),
    'maya.santos@example-business.test',
    'We want to automate invoice approvals for our synthetic company.',
    TRUE,
    '{"synthetic": true}'::JSONB,
    '{"synthetic": true}'::JSONB,
    'synthetic-test-hash-001'
);

INSERT INTO lead_crm.opportunities (
    id,
    company_id,
    primary_contact_id,
    originating_submission_id,
    name,
    relationship_type
)
VALUES (
    '00000000-0000-4000-8000-000000000004',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    'Synthetic Invoice Automation',
    'NEW_BUSINESS'
);

INSERT INTO lead_crm.activities (
    id,
    company_id,
    contact_id,
    submission_id,
    opportunity_id,
    activity_type,
    channel,
    direction,
    external_provider,
    external_message_id,
    external_thread_id,
    subject,
    summary
)
VALUES (
    '00000000-0000-4000-8000-000000000005',
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003',
    '00000000-0000-4000-8000-000000000004',
    'EMAIL',
    'GMAIL',
    'INBOUND',
    'gmail',
    'synthetic-message-001',
    'synthetic-thread-001',
    'Synthetic automation enquiry',
    'Synthetic inbound lead for schema testing.'
);

INSERT INTO lead_crm.audit_events (
    correlation_id,
    submission_id,
    event_type,
    actor_type,
    to_status
)
VALUES (
    '00000000-0000-4000-8000-000000000203',
    '00000000-0000-4000-8000-000000000003',
    'lead.received',
    'WORKFLOW',
    'RECEIVED'
);

SELECT 'companies' AS entity, COUNT(*) AS test_count
FROM lead_crm.companies
WHERE id = '00000000-0000-4000-8000-000000000001'
UNION ALL
SELECT 'contacts', COUNT(*)
FROM lead_crm.contacts
WHERE id = '00000000-0000-4000-8000-000000000002'
UNION ALL
SELECT 'lead_submissions', COUNT(*)
FROM lead_crm.lead_submissions
WHERE id = '00000000-0000-4000-8000-000000000003'
UNION ALL
SELECT 'opportunities', COUNT(*)
FROM lead_crm.opportunities
WHERE id = '00000000-0000-4000-8000-000000000004'
UNION ALL
SELECT 'activities', COUNT(*)
FROM lead_crm.activities
WHERE id = '00000000-0000-4000-8000-000000000005'
UNION ALL
SELECT 'audit_events', COUNT(*)
FROM lead_crm.audit_events
WHERE submission_id = '00000000-0000-4000-8000-000000000003';

ROLLBACK;
