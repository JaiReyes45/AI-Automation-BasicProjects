BEGIN;

INSERT INTO lead_crm.companies (
    id,
    display_name,
    normalized_name,
    domain,
    country_code
)
VALUES (
    '10000000-0000-4000-8000-000000000001',
    'Synthetic Constraint Company',
    'synthetic constraint company',
    'constraint-company.example',
    'PH'
);

INSERT INTO lead_crm.contacts (
    id,
    company_id,
    first_name,
    last_name,
    email_original,
    email_normalized
)
VALUES (
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'Test',
    'Contact',
    'test@constraint-company.example',
    'test@constraint-company.example'
);

DO $$
BEGIN
    INSERT INTO lead_crm.contacts (
        company_id,
        first_name,
        last_name,
        email_original,
        email_normalized
    )
    VALUES (
        '10000000-0000-4000-8000-000000000001',
        'Duplicate',
        'Contact',
        'test@constraint-company.example',
        'test@constraint-company.example'
    );

    RAISE EXCEPTION 'Duplicate email was incorrectly accepted';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'PASS: duplicate normalized email rejected';
END;
$$;

INSERT INTO lead_crm.lead_submissions (
    id,
    submission_id,
    correlation_id,
    source,
    submitted_at,
    raw_payload,
    payload_hash
)
VALUES (
    '10000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000203',
    'test_client',
    NOW(),
    '{"synthetic": true}'::JSONB,
    'constraint-hash-001'
);

DO $$
BEGIN
    INSERT INTO lead_crm.lead_submissions (
        submission_id,
        correlation_id,
        source,
        submitted_at,
        raw_payload,
        payload_hash
    )
    VALUES (
        '10000000-0000-4000-8000-000000000103',
        '10000000-0000-4000-8000-000000000204',
        'test_client',
        NOW(),
        '{"synthetic": true}'::JSONB,
        'constraint-hash-002'
    );

    RAISE EXCEPTION 'Duplicate submission ID was incorrectly accepted';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'PASS: duplicate submission ID rejected';
END;
$$;

DO $$
BEGIN
    INSERT INTO lead_crm.lead_submissions (
        submission_id,
        correlation_id,
        source,
        submitted_at,
        raw_payload,
        payload_hash,
        lead_score
    )
    VALUES (
        '10000000-0000-4000-8000-000000000104',
        '10000000-0000-4000-8000-000000000205',
        'test_client',
        NOW(),
        '{"synthetic": true}'::JSONB,
        'constraint-hash-003',
        101
    );

    RAISE EXCEPTION 'Out-of-range lead score was incorrectly accepted';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'PASS: out-of-range lead score rejected';
END;
$$;

DO $$
BEGIN
    INSERT INTO lead_crm.activities (
        activity_type,
        channel,
        direction
    )
    VALUES (
        'NOTE',
        'SYSTEM',
        'INTERNAL'
    );

    RAISE EXCEPTION 'Orphan activity was incorrectly accepted';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'PASS: orphan activity rejected';
END;
$$;

ROLLBACK;
