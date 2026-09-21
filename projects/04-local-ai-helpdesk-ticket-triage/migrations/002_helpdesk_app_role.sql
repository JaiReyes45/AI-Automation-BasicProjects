\if :{?helpdesk_db_password}
\else
\quit 2
\endif

SELECT 'CREATE ROLE helpdesk_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'helpdesk_app')
\gexec

ALTER ROLE helpdesk_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION PASSWORD :'helpdesk_db_password';

REVOKE ALL ON SCHEMA helpdesk FROM PUBLIC;
GRANT USAGE ON SCHEMA helpdesk TO helpdesk_app;

GRANT SELECT ON helpdesk.routing_queues, helpdesk.sla_policies TO helpdesk_app;
GRANT SELECT, INSERT, UPDATE ON helpdesk.tickets TO helpdesk_app;
GRANT INSERT ON helpdesk.ticket_events TO helpdesk_app;
GRANT SELECT, INSERT, UPDATE ON helpdesk.classification_runs TO helpdesk_app;
GRANT SELECT, INSERT, UPDATE ON helpdesk.notification_outbox TO helpdesk_app;
GRANT SELECT, INSERT, UPDATE ON helpdesk.failed_jobs TO helpdesk_app;
