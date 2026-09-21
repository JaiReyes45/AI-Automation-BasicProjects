BEGIN;
ALTER TABLE helpdesk.failed_jobs ADD COLUMN IF NOT EXISTS replay_context jsonb NOT NULL DEFAULT jsonb_build_object();
ALTER TABLE helpdesk.failed_jobs ADD COLUMN IF NOT EXISTS idempotency_key char(64);
CREATE INDEX IF NOT EXISTS failed_jobs_stage_retry_idx ON helpdesk.failed_jobs(stage,terminal,next_retry_at);
COMMIT;
