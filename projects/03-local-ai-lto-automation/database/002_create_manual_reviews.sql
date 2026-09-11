CREATE TABLE manual_reviews (
    id BIGSERIAL PRIMARY KEY,

    -- Document identity
    document_hash VARCHAR(64) NOT NULL UNIQUE,
    source_filename TEXT NOT NULL,

    -- Qwen's extracted values.
    -- These are nullable because extraction may have failed.
    plate_number VARCHAR(20),
    vehicle_type TEXT,

    mvuc NUMERIC(12,2) CHECK (mvuc >= 0),
    legal_research_fee NUMERIC(12,2) CHECK (legal_research_fee >= 0),
    penalty NUMERIC(12,2) CHECK (penalty >= 0),

    -- Why this document needs human review
    validation_errors TEXT[] NOT NULL,

    -- Review workflow
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);