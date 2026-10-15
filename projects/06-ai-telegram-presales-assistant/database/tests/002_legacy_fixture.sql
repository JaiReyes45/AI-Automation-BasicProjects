-- Synthetic legacy rows; loaded BEFORE migration in the isolated test schema.
INSERT INTO presales.customers(id,telegram_user_id,consent_status)
  VALUES('86000000-0000-0000-0000-000000000001',86000001,'unknown');
INSERT INTO presales.conversations(id,customer_id,status,last_activity_at) VALUES
  ('86000000-0000-0000-0000-000000000002','86000000-0000-0000-0000-000000000001','closed',now()-interval '1 day'),
  ('86000000-0000-0000-0000-000000000003','86000000-0000-0000-0000-000000000001','active',now());
INSERT INTO presales.messages(id,conversation_id,direction,telegram_update_id,telegram_message_id,text_content) VALUES
  ('86000000-0000-0000-0000-000000000004','86000000-0000-0000-0000-000000000002','incoming',86000001,1,'legacy one'),
  ('86000000-0000-0000-0000-000000000005','86000000-0000-0000-0000-000000000003','incoming',86000002,1,'legacy duplicate preserved');
INSERT INTO presales.conversation_state(conversation_id,state)
  VALUES('86000000-0000-0000-0000-000000000003','{"requirements":{"legacy":true}}');
INSERT INTO presales.outbox_jobs(job_type,payload) VALUES('legacy_job','{"preserve":true}');
