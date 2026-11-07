BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS lead_crm;

CREATE TABLE lead_crm.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    domain TEXT,
    country_code CHAR(2),
    lifecycle_stage TEXT NOT NULL DEFAULT 'PROSPECT'
        CHECK (lifecycle_stage IN (
            'PROSPECT',
            'ACTIVE_CLIENT',
            'FORMER_CLIENT'
        )),
    first_customer_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (length(trim(display_name)) BETWEEN 1 AND 150),
    CHECK (country_code IS NULL OR country_code ~ '^[A-Z]{2}$')
);

CREATE UNIQUE INDEX companies_domain_unique
    ON lead_crm.companies (lower(domain))
    WHERE domain IS NOT NULL;

CREATE TABLE lead_crm.contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL
        REFERENCES lead_crm.companies(id)
        ON DELETE RESTRICT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email_original TEXT NOT NULL,
    email_normalized TEXT NOT NULL UNIQUE,
    job_title TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (length(trim(first_name)) BETWEEN 1 AND 100),
    CHECK (length(trim(last_name)) BETWEEN 1 AND 100),
    CHECK (email_normalized = lower(trim(email_normalized))),
    CHECK (length(email_normalized) BETWEEN 3 AND 320)
);

CREATE TABLE lead_crm.lead_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL UNIQUE,
    correlation_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),

    company_id UUID
        REFERENCES lead_crm.companies(id)
        ON DELETE RESTRICT,
    contact_id UUID
        REFERENCES lead_crm.contacts(id)
        ON DELETE RESTRICT,
    duplicate_of_id UUID
        REFERENCES lead_crm.lead_submissions(id)
        ON DELETE RESTRICT,

    source TEXT NOT NULL
        CHECK (source IN (
            'website_form',
            'demo_form',
            'test_client',
            'gmail'
        )),
    submitted_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    email_normalized TEXT,
    message TEXT,
    consent BOOLEAN,
    raw_payload JSONB NOT NULL,
    normalized_payload JSONB,
    payload_hash TEXT NOT NULL,

    processing_status TEXT NOT NULL DEFAULT 'RECEIVED'
        CHECK (processing_status IN (
            'RECEIVED',
            'VALIDATING',
            'INVALID',
            'DUPLICATE',
            'AI_PENDING',
            'ANALYZING',
            'SCORING',
            'QUALIFIED_HOT',
            'QUALIFIED_WARM',
            'QUALIFIED_COLD',
            'CRM_SYNC_PENDING',
            'CRM_SYNCED',
            'ROUTED',
            'FOLLOW_UP_PENDING',
            'FOLLOW_UP_SENT',
            'SYNC_FAILED',
            'REVIEW_REQUIRED'
        )),

    lead_score INTEGER
        CHECK (lead_score BETWEEN 0 AND 100),
    qualification TEXT
        CHECK (qualification IN ('HOT', 'WARM', 'COLD')),
    scoring_rule_version TEXT,
    ai_confidence NUMERIC(4,3)
        CHECK (ai_confidence BETWEEN 0 AND 1),
    ai_extraction JSONB,
    validation_errors JSONB NOT NULL DEFAULT '[]'::JSONB
        CHECK (jsonb_typeof(validation_errors) = 'array'),

    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        email_normalized IS NULL
        OR email_normalized = lower(trim(email_normalized))
    ),
    CHECK (duplicate_of_id IS NULL OR duplicate_of_id <> id)
);

CREATE INDEX lead_submissions_email_idx
    ON lead_crm.lead_submissions (email_normalized);

CREATE INDEX lead_submissions_status_idx
    ON lead_crm.lead_submissions (processing_status);

CREATE TABLE lead_crm.opportunities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL
        REFERENCES lead_crm.companies(id)
        ON DELETE RESTRICT,
    primary_contact_id UUID NOT NULL
        REFERENCES lead_crm.contacts(id)
        ON DELETE RESTRICT,
    originating_submission_id UUID NOT NULL UNIQUE
        REFERENCES lead_crm.lead_submissions(id)
        ON DELETE RESTRICT,

    name TEXT NOT NULL,
    relationship_type TEXT NOT NULL DEFAULT 'NEW_BUSINESS'
        CHECK (relationship_type IN (
            'NEW_BUSINESS',
            'RETURNING_CLIENT'
        )),
    sales_stage TEXT NOT NULL DEFAULT 'NEW'
        CHECK (sales_stage IN (
            'NEW',
            'QUALIFIED',
            'DISCOVERY',
            'PROPOSAL',
            'WON',
            'LOST'
        )),

    estimated_value NUMERIC(12,2)
        CHECK (estimated_value IS NULL OR estimated_value >= 0),
    currency CHAR(3) DEFAULT 'PHP'
        CHECK (currency ~ '^[A-Z]{3}$'),

    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        (sales_stage IN ('WON', 'LOST') AND closed_at IS NOT NULL)
        OR
        (sales_stage NOT IN ('WON', 'LOST') AND closed_at IS NULL)
    )
);

CREATE INDEX opportunities_company_idx
    ON lead_crm.opportunities (company_id);

CREATE INDEX opportunities_stage_idx
    ON lead_crm.opportunities (sales_stage);

CREATE TABLE lead_crm.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    company_id UUID
        REFERENCES lead_crm.companies(id)
        ON DELETE RESTRICT,
    contact_id UUID
        REFERENCES lead_crm.contacts(id)
        ON DELETE RESTRICT,
    submission_id UUID
        REFERENCES lead_crm.lead_submissions(id)
        ON DELETE RESTRICT,
    opportunity_id UUID
        REFERENCES lead_crm.opportunities(id)
        ON DELETE RESTRICT,

    activity_type TEXT NOT NULL
        CHECK (activity_type IN (
            'EMAIL',
            'NOTE',
            'MEETING',
            'CRM_SYNC',
            'STATUS_CHANGE',
            'NOTIFICATION'
        )),
    channel TEXT NOT NULL
        CHECK (channel IN (
            'GMAIL',
            'MAILPIT',
            'TELEGRAM',
            'HUBSPOT',
            'SYSTEM'
        )),
    direction TEXT NOT NULL
        CHECK (direction IN (
            'INBOUND',
            'OUTBOUND',
            'INTERNAL'
        )),

    external_provider TEXT,
    external_message_id TEXT,
    external_thread_id TEXT,
    subject TEXT,
    summary TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB
        CHECK (jsonb_typeof(metadata) = 'object'),

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        company_id IS NOT NULL
        OR contact_id IS NOT NULL
        OR submission_id IS NOT NULL
        OR opportunity_id IS NOT NULL
    )
);

CREATE UNIQUE INDEX activities_external_message_unique
    ON lead_crm.activities (
        external_provider,
        external_message_id
    )
    WHERE external_provider IS NOT NULL
      AND external_message_id IS NOT NULL;

CREATE INDEX activities_contact_idx
    ON lead_crm.activities (contact_id, occurred_at DESC);

CREATE INDEX activities_company_idx
    ON lead_crm.activities (company_id, occurred_at DESC);

CREATE TABLE lead_crm.audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    correlation_id UUID NOT NULL,
    submission_id UUID
        REFERENCES lead_crm.lead_submissions(id)
        ON DELETE RESTRICT,

    event_type TEXT NOT NULL,
    actor_type TEXT NOT NULL
        CHECK (actor_type IN (
            'WORKFLOW',
            'HUMAN',
            'SYSTEM',
            'EXTERNAL_API'
        )),
    from_status TEXT,
    to_status TEXT,
    event_data JSONB NOT NULL DEFAULT '{}'::JSONB
        CHECK (jsonb_typeof(event_data) = 'object'),

    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (length(trim(event_type)) > 0)
);

CREATE INDEX audit_events_correlation_idx
    ON lead_crm.audit_events (correlation_id, occurred_at);

CREATE INDEX audit_events_submission_idx
    ON lead_crm.audit_events (submission_id, occurred_at);

CREATE FUNCTION lead_crm.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER companies_set_updated_at
    BEFORE UPDATE ON lead_crm.companies
    FOR EACH ROW
    EXECUTE FUNCTION lead_crm.set_updated_at();

CREATE TRIGGER contacts_set_updated_at
    BEFORE UPDATE ON lead_crm.contacts
    FOR EACH ROW
    EXECUTE FUNCTION lead_crm.set_updated_at();

CREATE TRIGGER lead_submissions_set_updated_at
    BEFORE UPDATE ON lead_crm.lead_submissions
    FOR EACH ROW
    EXECUTE FUNCTION lead_crm.set_updated_at();

CREATE TRIGGER opportunities_set_updated_at
    BEFORE UPDATE ON lead_crm.opportunities
    FOR EACH ROW
    EXECUTE FUNCTION lead_crm.set_updated_at();

CREATE TABLE lead_crm.schema_migrations (
    version TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO lead_crm.schema_migrations (
    version,
    description
)
VALUES (
    '001',
    'Core CRM schema'
);

COMMIT;
