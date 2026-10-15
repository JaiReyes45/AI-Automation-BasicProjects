BEGIN;

INSERT INTO presales.services (code, category, name, description, price_min, price_max, delivery_time, requires_human)
VALUES
('consultation_detailed', 'consultation', 'Detailed discovery session', 'Structured discovery session for documenting requirements and constraints.', 1500, 1500, '1 session', false),
('workflow_simple', 'workflow_automation', 'Simple single workflow', 'One workflow with basic conditions and a small number of steps.', 6000, 12000, '3–7 days', false),
('workflow_intermediate', 'workflow_automation', 'Intermediate automation', 'Multi-step automation with validation and transformations.', 15000, 30000, '1–3 weeks', false),
('workflow_advanced', 'workflow_automation', 'Advanced multi-workflow system', 'Connected workflows with more complex orchestration and monitoring.', 35000, 70000, '3–6 weeks', true),
('crm_data_entry', 'crm_automation', 'Basic CRM data-entry automation', 'Automated creation or updating of CRM records from an approved source.', 10000, 18000, '1–2 weeks', false),
('crm_lead_intake', 'crm_automation', 'Lead intake and deduplication', 'Lead capture, validation, duplicate prevention, and routing.', 18000, 30000, '2–3 weeks', false),
('crm_complete', 'crm_automation', 'Complete lead-to-CRM automation', 'End-to-end intake, qualification, synchronization, and audit history.', 30000, 55000, '3–5 weeks', true),
('telegram_faq_ai', 'ai_chatbot', 'Telegram AI FAQ assistant', 'Telegram assistant grounded in an approved FAQ and service catalog.', 15000, 25000, '2–3 weeks', false),
('ai_knowledge_chatbot', 'ai_chatbot', 'AI knowledge-base chatbot', 'AI assistant using an approved knowledge base with confidence checking.', 25000, 45000, '3–5 weeks', true),
('ai_human_handoff', 'ai_chatbot', 'AI customer support with human handoff', 'AI assistant with structured escalation and human review tickets.', 40000, 70000, '4–6 weeks', true),
('workflow_repair', 'maintenance', 'Workflow repair', 'Diagnosis and repair of an existing automation workflow.', 3000, 10000, '1–7 days', false),
('custom_api', 'integration', 'Custom API integration', 'Integration with an API requiring custom authentication or mapping.', 8000, 20000, '1–3 weeks', true),
('standard_integration', 'integration', 'Additional standard integration', 'Connection to an additional supported application.', 3000, 7500, '2–5 days', false),
('maintenance_basic', 'maintenance', 'Basic maintenance', 'Routine maintenance and minor support.', 4000, 4000, 'monthly', false),
('maintenance_standard', 'maintenance', 'Standard maintenance', 'Regular monitoring, maintenance, and support.', 7500, 7500, 'monthly', false),
('maintenance_priority', 'maintenance', 'Priority monitoring and maintenance', 'Priority support with monitoring and faster response.', 12000, 12000, 'monthly', true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description,
  price_min = EXCLUDED.price_min, price_max = EXCLUDED.price_max,
  delivery_time = EXCLUDED.delivery_time, requires_human = EXCLUDED.requires_human,
  active = true, updated_at = now();

INSERT INTO presales.service_packages (code, name, description, price_min, price_max)
VALUES
('starter_automation', 'Starter Automation', 'One workflow, up to two applications, basic conditions, error notification, one revision, and seven days of support.', 7500, 7500),
('business_workflow', 'Business Workflow', 'Up to three applications, multi-step processing, validation, transformations, error handling, audit logging, two revisions, and fourteen days of support.', 18000, 18000),
('ai_assistant', 'AI Assistant', 'One communication channel, approved knowledge base, natural-language responses, persistence, confidence checking, human escalation, two revisions, and fourteen days of support.', 30000, 30000),
('crm_automation', 'CRM Automation', 'Lead intake, validation, duplicate prevention, CRM synchronization, qualification, error handling, and audit history.', 35000, 35000)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name, description = EXCLUDED.description,
  price_min = EXCLUDED.price_min, price_max = EXCLUDED.price_max,
  active = true, updated_at = now();

INSERT INTO presales.pricing_adjustments (code, name, adjustment_type, amount_min, amount_max, percentage, requires_human)
VALUES
('additional_standard_application', 'Additional standard application', 'fixed_range', 3000, 7500, NULL, false),
('custom_api', 'Custom API', 'fixed_range', 8000, 20000, NULL, true),
('ai_feature', 'AI feature', 'fixed_range', 8000, 15000, NULL, true),
('postgresql_database', 'PostgreSQL database', 'fixed_range', 8000, 15000, NULL, false),
('human_handoff', 'Human-handoff system', 'fixed_range', 8000, 15000, NULL, false),
('dashboard_analytics', 'Dashboard or analytics', 'fixed_range', 8000, 20000, NULL, false),
('delivery_under_seven_days', 'Delivery under seven days', 'percentage', NULL, NULL, 25, true),
('additional_revision', 'Additional revision', 'fixed_range', 1500, 3000, NULL, false),
('data_migration', 'Data migration', 'human_quote', NULL, NULL, NULL, true),
('discount', 'Discount', 'human_quote', NULL, NULL, NULL, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name, adjustment_type = EXCLUDED.adjustment_type,
  amount_min = EXCLUDED.amount_min, amount_max = EXCLUDED.amount_max,
  percentage = EXCLUDED.percentage, requires_human = EXCLUDED.requires_human,
  active = true;

INSERT INTO presales.business_policies (code, policy_text, policy_value)
VALUES
('ai_confidence_threshold', 'Minimum confidence for automatic interpretation', '{"threshold": 0.75}'),
('automatic_estimate_ceiling', 'Maximum total for an automatic preliminary estimate', '{"amount": 85000, "currency": "PHP"}'),
('lead_score_bands', 'Deterministic lead score bands', '{"cold_max": 44, "warm_min": 45, "warm_max": 74, "hot_min": 75}'),
('estimate_disclaimer', 'Required disclaimer on every estimate', '{"text": "This is a preliminary, non-binding estimate based on the information currently available. The final quotation will be confirmed after reviewing the complete workflow requirements, integrations, and access requirements."}'),
('external_costs_excluded', 'External costs are excluded unless explicitly listed', '{"excluded": true}')
ON CONFLICT (code) DO UPDATE SET
  policy_text = EXCLUDED.policy_text, policy_value = EXCLUDED.policy_value,
  active = true, updated_at = now();

INSERT INTO presales.faqs (question, answer, tags)
VALUES
('What services do you offer?', 'I help automate workflows, CRM processes, integrations, and AI assistants using approved project requirements.', ARRAY['services', 'overview']),
('Do you provide an exact final price immediately?', 'I can provide only a preliminary, non-binding estimate. A final quotation requires reviewing the complete workflow, integrations, and access requirements.', ARRAY['pricing', 'policy']),
('Are third-party subscriptions included?', 'Third-party subscriptions, hosting, domains, paid APIs, premium CRM features, AI usage, and messaging charges are excluded unless explicitly listed.', ARRAY['pricing', 'exclusions']),
('Can I speak with a human?', 'Yes. Ask for a human at any time and I will prepare a summary for follow-up.', ARRAY['handoff', 'support'])
ON CONFLICT DO NOTHING;

INSERT INTO presales.schema_migrations (version, description)
VALUES ('002', 'approved catalog, pricing adjustments, policies, and FAQs')
ON CONFLICT (version) DO NOTHING;

COMMIT;
