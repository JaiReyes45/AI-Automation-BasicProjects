BEGIN;

DO $constraints$
DECLARE
  ticket_uuid uuid;
  failed_job_uuid uuid;
  claimed_attempt integer;
BEGIN
  BEGIN
    INSERT INTO helpdesk.tickets(idempotency_key, requester_email, subject, description)
    VALUES (repeat('a', 64), 'test@example.test', '', 'valid description');
    RAISE EXCEPTION 'empty subject was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO helpdesk.tickets(idempotency_key, requester_email, subject, description)
  VALUES (repeat('b', 64), 'test@example.test', 'Valid subject', 'Valid description')
  RETURNING ticket_id INTO ticket_uuid;

  BEGIN
    INSERT INTO helpdesk.tickets(idempotency_key, requester_email, subject, description)
    VALUES (repeat('b', 64), 'other@example.test', 'Duplicate', 'Valid description');
    RAISE EXCEPTION 'duplicate idempotency key was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    UPDATE helpdesk.tickets SET priority = 'P5' WHERE ticket_id = ticket_uuid;
    RAISE EXCEPTION 'invalid priority was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE helpdesk.tickets SET assigned_queue = 'not_a_queue' WHERE ticket_id = ticket_uuid;
    RAISE EXCEPTION 'unknown queue was accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    UPDATE helpdesk.tickets SET confidence = 1.01 WHERE ticket_id = ticket_uuid;
    RAISE EXCEPTION 'out-of-range confidence was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO helpdesk.notification_outbox(ticket_id, idempotency_key)
  VALUES (ticket_uuid, repeat('c', 64));

  BEGIN
    INSERT INTO helpdesk.notification_outbox(ticket_id, idempotency_key)
    VALUES (ticket_uuid, repeat('c', 64));
    RAISE EXCEPTION 'duplicate notification key was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO helpdesk.failed_jobs(ticket_id, stage, failure_class, error_code)
    VALUES (ticket_uuid, 'test', 'invalid', 'test_error');
    RAISE EXCEPTION 'invalid failure class was accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO helpdesk.failed_jobs(ticket_id, stage, failure_class, error_code, replay_context, idempotency_key)
  VALUES (ticket_uuid, 'classification', 'retryable', 'synthetic_retry', jsonb_build_object('version', 1, 'idempotency_key', repeat('b', 64)), repeat('b', 64))
  RETURNING failed_job_id INTO failed_job_uuid;

  UPDATE helpdesk.failed_jobs
  SET attempt_count = attempt_count + 1
  WHERE failed_job_id = failed_job_uuid AND terminal = false AND resolved_at IS NULL AND attempt_count < 3
  RETURNING attempt_count INTO claimed_attempt;
  IF claimed_attempt <> 1 THEN RAISE EXCEPTION 'failed-job claim did not increment once'; END IF;

  UPDATE helpdesk.failed_jobs SET resolved_at = now(), terminal = true WHERE failed_job_id = failed_job_uuid;
  UPDATE helpdesk.failed_jobs SET attempt_count = attempt_count + 1
  WHERE failed_job_id = failed_job_uuid AND terminal = false AND resolved_at IS NULL
  RETURNING attempt_count INTO claimed_attempt;
  IF FOUND THEN RAISE EXCEPTION 'resolved failed job was claimed again'; END IF;

  INSERT INTO helpdesk.sla_breaches(ticket_id) VALUES (ticket_uuid);
  BEGIN
    INSERT INTO helpdesk.sla_breaches(ticket_id) VALUES (ticket_uuid);
    RAISE EXCEPTION 'duplicate SLA breach was accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END
$constraints$;

SELECT 'database constraint tests passed' AS result;
ROLLBACK;
