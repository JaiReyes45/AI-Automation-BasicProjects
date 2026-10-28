-- Durable, independently scoped desktop delivery. No raw pairing or device tokens are stored.
CREATE TABLE IF NOT EXISTS career.notification_pairings (
    code_hash text PRIMARY KEY,
    expires double precision NOT NULL,
    created double precision NOT NULL
);
CREATE TABLE IF NOT EXISTS career.notification_devices (
    id text PRIMARY KEY,
    token_hash text NOT NULL UNIQUE,
    name text NOT NULL,
    created double precision NOT NULL,
    expires double precision NOT NULL,
    last_seen double precision,
    revoked boolean NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS career.notifications (
    id text PRIMARY KEY,
    task_id text NOT NULL REFERENCES career.tasks(id),
    event_key text NOT NULL UNIQUE,
    data jsonb NOT NULL,
    state text NOT NULL DEFAULT 'pending',
    attempts integer NOT NULL DEFAULT 0,
    created double precision NOT NULL,
    next_attempt double precision NOT NULL DEFAULT 0,
    lease_until double precision,
    lease_token text,
    device_id text REFERENCES career.notification_devices(id),
    delivered_at double precision,
    read_at double precision,
    snoozed_until double precision,
    error text
);
CREATE INDEX IF NOT EXISTS notifications_claim ON career.notifications(state,next_attempt,created);
CREATE INDEX IF NOT EXISTS tasks_message_source ON career.tasks((data->>'source_account'),(data->>'source_message_id'));
CREATE INDEX IF NOT EXISTS tasks_open_actor ON career.tasks((data->>'status'),(data->>'actor'));
