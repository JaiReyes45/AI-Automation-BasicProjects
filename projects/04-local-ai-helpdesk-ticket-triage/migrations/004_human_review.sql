BEGIN;
CREATE TABLE IF NOT EXISTS helpdesk.review_tasks (
  review_task_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL UNIQUE REFERENCES helpdesk.tickets(ticket_id),
  status text NOT NULL DEFAULT (chr(111)||chr(112)||chr(101)||chr(110)) CHECK (status IN (chr(111)||chr(112)||chr(101)||chr(110),chr(99)||chr(108)||chr(97)||chr(105)||chr(109)||chr(101)||chr(100),chr(114)||chr(101)||chr(115)||chr(111)||chr(108)||chr(118)||chr(101)||chr(100),chr(99)||chr(97)||chr(110)||chr(99)||chr(101)||chr(108)||chr(108)||chr(101)||chr(100))),
  reason_codes jsonb NOT NULL DEFAULT jsonb_build_array(),
  claimed_by text,
  claimed_at timestamptz,
  resolution text,
  resolved_by text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS review_tasks_open_idx ON helpdesk.review_tasks(status,created_at) WHERE status IN (chr(111)||chr(112)||chr(101)||chr(110),chr(99)||chr(108)||chr(97)||chr(105)||chr(109)||chr(101)||chr(100));
GRANT SELECT, INSERT, UPDATE ON helpdesk.review_tasks TO helpdesk_app;
COMMIT;
