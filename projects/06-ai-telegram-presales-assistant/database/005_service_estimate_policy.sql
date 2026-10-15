BEGIN;
INSERT INTO presales.business_policies(code,policy_text,policy_value,approved)
VALUES ('automatic_service_routes','Service ranges drive preliminary estimates; package starting prices are informational (user choice). Narrow standard scope only.',
'{"routes":[{"category":"workflow_automation","service_code":"workflow_simple","max_applications":2,"included":{"applications":2}},{"category":"workflow_automation","service_code":"workflow_intermediate","max_applications":3,"included":{"applications":3}},{"category":"crm_automation","service_code":"crm_data_entry","max_applications":2,"included":{"applications":2}},{"category":"ai_chatbot","service_code":"telegram_faq_ai","max_applications":1,"included":{"applications":1,"ai":true}}],"unknown_or_custom_scope":"human_review","packages_informational_only":true}',true)
ON CONFLICT(code) DO NOTHING;
UPDATE presales.business_policies SET policy_value=policy_value||'{"packages_informational_only":true,"estimate_basis":"approved_service_ranges"}'::jsonb
WHERE code='pricing_config';
INSERT INTO presales.schema_migrations(version,description) VALUES ('005','User-approved service-range estimate strategy') ON CONFLICT DO NOTHING;
COMMIT;
