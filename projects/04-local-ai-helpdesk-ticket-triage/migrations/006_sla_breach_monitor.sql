BEGIN;
ALTER TABLE helpdesk.notification_outbox ADD COLUMN IF NOT EXISTS notification_type text NOT NULL DEFAULT 'acknowledgment';
ALTER TABLE helpdesk.notification_outbox DROP CONSTRAINT IF EXISTS notification_outbox_type_check;
ALTER TABLE helpdesk.notification_outbox ADD CONSTRAINT notification_outbox_type_check CHECK (notification_type IN ('acknowledgment','sla_breach'));
CREATE TABLE IF NOT EXISTS helpdesk.sla_breaches (sla_breach_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid NOT NULL UNIQUE REFERENCES helpdesk.tickets(ticket_id), detected_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS sla_breaches_detected_idx ON helpdesk.sla_breaches(detected_at);
GRANT SELECT, INSERT ON helpdesk.sla_breaches TO helpdesk_app;
COMMIT;
