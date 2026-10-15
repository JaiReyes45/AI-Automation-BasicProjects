BEGIN;

CREATE SCHEMA IF NOT EXISTS presales;

CREATE TABLE IF NOT EXISTS presales.schema_migrations (
  version text PRIMARY KEY,
  description text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telegram_user_id bigint NOT NULL UNIQUE,
  username text,
  display_name text,
  consent_status text NOT NULL DEFAULT 'unknown'
    CHECK (consent_status IN ('unknown', 'granted', 'denied', 'withdrawn')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES presales.customers(id),
  status text NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'active', 'awaiting_customer', 'awaiting_consent',
                      'qualified', 'handed_off', 'closed', 'expired')),
  current_intent text,
  last_activity_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS conversations_customer_idx
  ON presales.conversations (customer_id, last_activity_at DESC);

CREATE TABLE IF NOT EXISTS presales.conversation_state (
  conversation_id uuid PRIMARY KEY REFERENCES presales.conversations(id) ON DELETE CASCADE,
  state jsonb NOT NULL DEFAULT '{}'::jsonb,
  missing_information jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  direction text NOT NULL CHECK (direction IN ('incoming', 'outgoing')),
  telegram_update_id bigint,
  telegram_message_id bigint,
  message_type text NOT NULL DEFAULT 'text',
  text_content text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (telegram_update_id),
  UNIQUE (conversation_id, telegram_message_id)
);

CREATE INDEX IF NOT EXISTS messages_conversation_idx
  ON presales.messages (conversation_id, created_at);

CREATE TABLE IF NOT EXISTS presales.processed_updates (
  update_id bigint PRIMARY KEY,
  message_id uuid REFERENCES presales.messages(id),
  processed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.services (
  code text PRIMARY KEY,
  category text NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  price_min numeric(12,2),
  price_max numeric(12,2),
  currency char(3) NOT NULL DEFAULT 'PHP',
  delivery_time text,
  active boolean NOT NULL DEFAULT true,
  requires_human boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (price_min IS NULL OR price_min >= 0),
  CHECK (price_max IS NULL OR price_max >= 0),
  CHECK (price_max IS NULL OR price_min IS NULL OR price_max >= price_min)
);

CREATE TABLE IF NOT EXISTS presales.service_packages (
  code text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  price_min numeric(12,2) NOT NULL CHECK (price_min >= 0),
  price_max numeric(12,2) NOT NULL CHECK (price_max >= price_min),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.pricing_adjustments (
  code text PRIMARY KEY,
  name text NOT NULL,
  adjustment_type text NOT NULL CHECK (adjustment_type IN ('fixed_range', 'percentage', 'human_quote')),
  amount_min numeric(12,2),
  amount_max numeric(12,2),
  percentage numeric(6,3),
  active boolean NOT NULL DEFAULT true,
  requires_human boolean NOT NULL DEFAULT false,
  CHECK (amount_min IS NULL OR amount_min >= 0),
  CHECK (amount_max IS NULL OR amount_max >= amount_min),
  CHECK (percentage IS NULL OR percentage >= 0)
);

CREATE TABLE IF NOT EXISTS presales.faqs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question text NOT NULL,
  answer text NOT NULL,
  tags text[] NOT NULL DEFAULT '{}',
  active boolean NOT NULL DEFAULT true,
  approved_by text NOT NULL DEFAULT 'portfolio-owner',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.business_policies (
  code text PRIMARY KEY,
  policy_text text NOT NULL,
  policy_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.estimates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  service_code text REFERENCES presales.services(code),
  package_code text REFERENCES presales.service_packages(code),
  total_min numeric(12,2) NOT NULL CHECK (total_min >= 0),
  total_max numeric(12,2) NOT NULL CHECK (total_max >= total_min),
  currency char(3) NOT NULL DEFAULT 'PHP',
  calculation jsonb NOT NULL DEFAULT '{}'::jsonb,
  disclaimer text NOT NULL,
  status text NOT NULL DEFAULT 'preliminary'
    CHECK (status IN ('preliminary', 'human_review', 'confirmed', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES presales.customers(id),
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  score integer NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'unqualified'
    CHECK (status IN ('unqualified', 'cold', 'warm', 'hot', 'handed_off', 'won', 'lost')),
  reasons jsonb NOT NULL DEFAULT '[]'::jsonb,
  summary text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (conversation_id)
);

CREATE TABLE IF NOT EXISTS presales.handoff_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL REFERENCES presales.conversations(id),
  reason text NOT NULL,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'acknowledged', 'in_progress', 'resolved', 'cancelled')),
  summary text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid REFERENCES presales.conversations(id),
  event_type text NOT NULL,
  actor text NOT NULL CHECK (actor IN ('system', 'ai', 'human')),
  correlation_id text,
  input_reference text,
  output_summary text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS presales.outbox_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  aggregate_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'retry_wait', 'sent', 'dead_letter')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  available_at timestamptz NOT NULL DEFAULT now(),
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS outbox_due_idx
  ON presales.outbox_jobs (available_at, created_at)
  WHERE status IN ('pending', 'retry_wait');

CREATE TABLE IF NOT EXISTS presales.dead_letter_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_type text NOT NULL,
  source_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_message text NOT NULL,
  replay_status text NOT NULL DEFAULT 'pending'
    CHECK (replay_status IN ('pending', 'replayed', 'discarded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  replayed_at timestamptz
);

INSERT INTO presales.schema_migrations (version, description)
VALUES ('001', 'core pre-sales schema')
ON CONFLICT (version) DO NOTHING;

COMMIT;
