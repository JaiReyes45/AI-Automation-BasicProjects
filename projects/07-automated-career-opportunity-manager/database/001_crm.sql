CREATE SCHEMA IF NOT EXISTS career;
CREATE TABLE IF NOT EXISTS career.applications(id text PRIMARY KEY, data jsonb NOT NULL, version integer NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS career.messages(account text, id text, envelope jsonb NOT NULL, result jsonb NOT NULL, PRIMARY KEY(account,id));
CREATE TABLE IF NOT EXISTS career.events(id bigserial PRIMARY KEY, application_id text REFERENCES career.applications(id), data jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS career.label_jobs(id bigserial PRIMARY KEY, account text NOT NULL, message_id text NOT NULL, application_id text, labels jsonb NOT NULL, state text NOT NULL DEFAULT 'pending', error text, UNIQUE(account,message_id));
CREATE TABLE IF NOT EXISTS career.sessions(token_hash text PRIMARY KEY, expires double precision NOT NULL);
ALTER TABLE career.label_jobs ADD COLUMN IF NOT EXISTS eligible boolean NOT NULL DEFAULT false;
ALTER TABLE career.label_jobs ADD COLUMN IF NOT EXISTS generation integer NOT NULL DEFAULT 1;
ALTER TABLE career.label_jobs ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0;
ALTER TABLE career.label_jobs ADD COLUMN IF NOT EXISTS next_attempt double precision NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS career.connection(id integer PRIMARY KEY, data jsonb NOT NULL);
ALTER TABLE career.messages ADD COLUMN IF NOT EXISTS revision integer NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS career.tasks(id text PRIMARY KEY, data jsonb NOT NULL, version integer NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS career.audit(id bigserial PRIMARY KEY, kind text NOT NULL, data jsonb NOT NULL);
CREATE INDEX IF NOT EXISTS label_jobs_pending ON career.label_jobs(account,state,next_attempt) WHERE eligible;

CREATE TABLE IF NOT EXISTS career.calendar_events(id text PRIMARY KEY, data jsonb NOT NULL, version integer NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS career.calendar_connection(id integer PRIMARY KEY, data jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS career.actions(id text PRIMARY KEY, kind text NOT NULL, state text NOT NULL, data jsonb NOT NULL, created double precision NOT NULL, lease double precision, lease_token text, attempts integer NOT NULL DEFAULT 0);
