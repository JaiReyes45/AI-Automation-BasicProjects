BEGIN;
ALTER TABLE helpdesk.notification_outbox
  DROP CONSTRAINT IF EXISTS notification_outbox_status_check;
ALTER TABLE helpdesk.notification_outbox
  ADD CONSTRAINT notification_outbox_status_check
  CHECK (status IN ('pending','sending','sent','failed'));
CREATE INDEX IF NOT EXISTS notification_outbox_claim_idx
  ON helpdesk.notification_outbox(status, created_at)
  WHERE status IN ('pending','failed');
COMMIT;
