-- Project 06: complete the original fictional portfolio rate card.
-- Apply AFTER 001, 002 and 003_runtime.sql, after inspection. Do NOT rerun 002:
-- its FAQ INSERT has no question uniqueness constraint and can duplicate FAQs.
-- This file performs no deployment; the parent/operator applies it separately.
-- Source: original "Build Project 06" brief, Introductory fictional rate catalog
-- and Customer-facing packages; approved Phase 1 business-policies.md defaults.
-- The original contains 25 services (4 consultation + 6 workflow/integration/
-- repair + 5 CRM + 6 chatbot + 4 maintenance), 4 packages and 10 adjustments.
-- Existing codes/categories are retained for compatibility with 002.
-- Qualification weights were subsequently approved by the user. The narrow
-- crm_data_entry route is a conservative implementation mapping. Defaults are marked
-- provisional and cannot authorize new rates, package scope or guarantees.
--
-- Consumer contract:
-- services.billing_unit: one_time | monthly | hourly | NULL (unknown -> review).
-- service_packages.pricing_basis: starting_at | fixed | range | human_quote.
-- starting_at: price_min is a floor; price_max=NULL means NO approved upper bound.
-- Never turn a floor into a fixed/range estimate or insert NULL in estimates.
-- inclusions.applications: integer count or JSON null (unknown, NOT zero).
-- inclusions.ai/database/persistence/handoff/reporting: true/false/null.
-- database specifically denotes the PostgreSQL add-on; persistence alone does
-- not include PostgreSQL. Audit history/basic logging does not imply a dashboard.
-- Only explicit true/false values settle feature inclusion. Missing/null -> review
-- when relevant to requested scope; never silently charge an uncertain add-on.
-- Package support_days describes support, never delivery duration.
-- All policy configuration lives in business_policies.policy_value (jsonb).
-- Every consumer must require active AND approved, validate types/schema_version,
-- and route missing/conflicting/unsupported configuration to human review.
-- Preserve user-edited rows, prices, inactive flags and approval decisions.
-- Seed repairs require an exact original row snapshot AND unchanged timestamps.
-- Without an edit history, edits restored to exactly the seed are indistinguishable.
-- Existing service/adjustment requires_human flags are retained conservatively;
-- 002's extra flags were NOT explicit business requirements from the original.

BEGIN;

-- Serialize duplicate applications; table locks also protect question-based FAQ
-- inserts and the snapshot checks against concurrent catalog administration.
SELECT pg_advisory_xact_lock(600004);
LOCK TABLE presales.services, presales.service_packages,
  presales.pricing_adjustments, presales.business_policies, presales.faqs
  IN SHARE ROW EXCLUSIVE MODE;

DO $prerequisites$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '001')
     OR NOT EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '002')
     OR NOT EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '003')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'presales' AND table_name = 'services'
                      AND column_name = 'approved')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'presales' AND table_name = 'business_policies'
                      AND column_name = 'approved') THEN
    RAISE EXCEPTION 'Apply 001, 002 and 003_runtime.sql before 004; do not rerun 002';
  END IF;
END;
$prerequisites$;

ALTER TABLE presales.services
  ADD COLUMN IF NOT EXISTS billing_unit text
    CHECK (billing_unit IN ('one_time', 'monthly', 'hourly'));

-- Unknown existing/custom packages default to human quotation, not a guessed
-- pricing model. Existing price values are not erased by these ALTER statements.
ALTER TABLE presales.service_packages
  ADD COLUMN IF NOT EXISTS pricing_basis text NOT NULL DEFAULT 'human_quote'
    CHECK (pricing_basis IN ('starting_at', 'fixed', 'range', 'human_quote')),
  ADD COLUMN IF NOT EXISTS inclusions jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(inclusions) = 'object');
ALTER TABLE presales.service_packages ALTER COLUMN price_max DROP NOT NULL;

COMMENT ON COLUMN presales.services.billing_unit IS
  'one_time, monthly or hourly; NULL is unknown. Never mix recurring or hourly amounts into a one-time estimate without explicit scope.';
COMMENT ON COLUMN presales.service_packages.pricing_basis IS
  'starting_at is a lower bound, never a guaranteed fixed/range total; human_quote is the safe default for unclassified records.';
COMMENT ON COLUMN presales.service_packages.inclusions IS
  'Version 1: applications integer/null; channels integer/null; ai,database,persistence,handoff,reporting boolean/null. Null means unspecified. database denotes PostgreSQL, not generic persistence.';

DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '004') THEN
    RETURN;
  END IF;

  -- Exact 002 snapshots are used ONLY to recognize untouched seed records.
  CREATE TEMP TABLE catalog_004_original_services (
    code text PRIMARY KEY, category text, name text, description text,
    price_min numeric, price_max numeric, delivery_time text,
    requires_human boolean, billing_unit text
  ) ON COMMIT DROP;
  INSERT INTO catalog_004_original_services VALUES
    ('consultation_detailed', 'consultation', 'Detailed discovery session', 'Structured discovery session for documenting requirements and constraints.', 1500, 1500, '1 session', false, 'one_time'),
    ('workflow_simple', 'workflow_automation', 'Simple single workflow', 'One workflow with basic conditions and a small number of steps.', 6000, 12000, '3–7 days', false, 'one_time'),
    ('workflow_intermediate', 'workflow_automation', 'Intermediate automation', 'Multi-step automation with validation and transformations.', 15000, 30000, '1–3 weeks', false, 'one_time'),
    ('workflow_advanced', 'workflow_automation', 'Advanced multi-workflow system', 'Connected workflows with more complex orchestration and monitoring.', 35000, 70000, '3–6 weeks', true, 'one_time'),
    ('crm_data_entry', 'crm_automation', 'Basic CRM data-entry automation', 'Automated creation or updating of CRM records from an approved source.', 10000, 18000, '1–2 weeks', false, 'one_time'),
    ('crm_lead_intake', 'crm_automation', 'Lead intake and deduplication', 'Lead capture, validation, duplicate prevention, and routing.', 18000, 30000, '2–3 weeks', false, 'one_time'),
    ('crm_complete', 'crm_automation', 'Complete lead-to-CRM automation', 'End-to-end intake, qualification, synchronization, and audit history.', 30000, 55000, '3–5 weeks', true, 'one_time'),
    ('telegram_faq_ai', 'ai_chatbot', 'Telegram AI FAQ assistant', 'Telegram assistant grounded in an approved FAQ and service catalog.', 15000, 25000, '2–3 weeks', false, 'one_time'),
    ('ai_knowledge_chatbot', 'ai_chatbot', 'AI knowledge-base chatbot', 'AI assistant using an approved knowledge base with confidence checking.', 25000, 45000, '3–5 weeks', true, 'one_time'),
    ('ai_human_handoff', 'ai_chatbot', 'AI customer support with human handoff', 'AI assistant with structured escalation and human review tickets.', 40000, 70000, '4–6 weeks', true, 'one_time'),
    ('workflow_repair', 'maintenance', 'Workflow repair', 'Diagnosis and repair of an existing automation workflow.', 3000, 10000, '1–7 days', false, 'one_time'),
    ('custom_api', 'integration', 'Custom API integration', 'Integration with an API requiring custom authentication or mapping.', 8000, 20000, '1–3 weeks', true, 'one_time'),
    ('standard_integration', 'integration', 'Additional standard integration', 'Connection to an additional supported application.', 3000, 7500, '2–5 days', false, 'one_time'),
    ('maintenance_basic', 'maintenance', 'Basic maintenance', 'Routine maintenance and minor support.', 4000, 4000, 'monthly', false, 'monthly'),
    ('maintenance_standard', 'maintenance', 'Standard maintenance', 'Regular monitoring, maintenance, and support.', 7500, 7500, 'monthly', false, 'monthly'),
    ('maintenance_priority', 'maintenance', 'Priority monitoring and maintenance', 'Priority support with monitoring and faster response.', 12000, 12000, 'monthly', true, 'monthly');

  -- Capture eligible rows BEFORE updating any timestamps. Exact equality includes
  -- active/approved, currency and all legacy descriptive and pricing fields.
  CREATE TEMP TABLE catalog_004_untouched_services ON COMMIT DROP AS
  SELECT s.code, o.billing_unit
  FROM presales.services s JOIN catalog_004_original_services o USING (code)
  WHERE s.updated_at = s.created_at AND s.active AND s.approved
    AND s.currency = 'PHP' AND s.billing_unit IS NULL
    AND ROW(s.category, s.name, s.description, s.price_min, s.price_max,
            s.delivery_time, s.requires_human)
        IS NOT DISTINCT FROM
        ROW(o.category, o.name, o.description, o.price_min, o.price_max,
            o.delivery_time, o.requires_human);

  UPDATE presales.services s
  SET delivery_time = NULL, billing_unit = u.billing_unit,
      description = CASE WHEN s.code = 'maintenance_priority'
        THEN 'Priority monitoring and maintenance; response commitments require human confirmation.'
        ELSE s.description END,
      updated_at = now()
  FROM catalog_004_untouched_services u WHERE s.code = u.code;

  -- If a seed was edited, its delivery text and billing remain untouched. The
  -- pricing policy below prohibits using any delivery_time as an auto-guarantee.
  -- No existing rates or requires_human restrictions are overwritten.
  INSERT INTO presales.services
    (code, category, name, description, price_min, price_max, delivery_time,
     requires_human, billing_unit, approved)
  SELECT code, category, name,
    CASE WHEN code = 'maintenance_priority'
      THEN 'Priority monitoring and maintenance; response commitments require human confirmation.'
      ELSE description END,
    price_min, price_max, NULL, requires_human, billing_unit, true
  FROM catalog_004_original_services
  ON CONFLICT (code) DO NOTHING;

  -- Nine missing entries, exactly the original approved fictional rates.
  INSERT INTO presales.services
    (code, category, name, description, price_min, price_max, delivery_time,
     requires_human, billing_unit, approved)
  VALUES
    ('consultation_initial', 'consultation', 'Initial 20-minute consultation', 'Free initial consultation lasting 20 minutes; no project delivery commitment.', 0, 0, NULL, false, 'one_time', true),
    ('workflow_audit', 'consultation', 'Existing workflow audit', 'Audit of an existing workflow.', 3000, 6000, NULL, false, 'one_time', true),
    ('process_map_proposal', 'consultation', 'Written process map and proposal', 'Written process map and proposal.', 2500, 5000, NULL, false, 'one_time', true),
    ('crm_cleanup_mapping', 'crm_automation', 'CRM cleanup or field mapping', 'CRM cleanup or field mapping; data migration requires a separate human quotation.', 8000, 20000, NULL, false, 'one_time', true),
    ('crm_email_notification', 'crm_automation', 'CRM-to-email notification workflow', 'CRM-to-email notification workflow.', 8000, 15000, NULL, false, 'one_time', true),
    ('faq_rule_based', 'ai_chatbot', 'Basic rule-based FAQ bot', 'Basic rule-based FAQ bot.', 8000, 15000, NULL, false, 'one_time', true),
    ('ai_crm_chatbot', 'ai_chatbot', 'AI chatbot with CRM integration', 'AI chatbot with CRM integration.', 50000, 85000, NULL, false, 'one_time', true),
    ('additional_messaging_channel', 'ai_chatbot', 'Additional messaging channel', 'Additional messaging channel for a chatbot.', 10000, 25000, NULL, false, 'one_time', true),
    ('maintenance_out_of_scope', 'maintenance', 'Additional out-of-scope work', 'Additional out-of-scope work, billed per hour; hours require confirmation.', 900, 1500, NULL, false, 'hourly', true)
  ON CONFLICT (code) DO NOTHING;

  CREATE TEMP TABLE catalog_004_packages (
    code text PRIMARY KEY, name text, old_description text,
    description text, starting_price numeric, inclusions jsonb
  ) ON COMMIT DROP;
  INSERT INTO catalog_004_packages VALUES
    ('starter_automation', 'Starter Automation',
     'One workflow, up to two applications, basic conditions, error notification, one revision, and seven days of support.',
     'Starting at PHP 7,500: one workflow, up to two applications, basic conditions, error notification, one revision, and seven days of support.', 7500,
     '{"schema_version":1,"applications":2,"channels":null,"workflows":1,"ai":null,"database":null,"persistence":null,"handoff":null,"reporting":null,"basic_conditions":true,"error_notification":true,"revisions":1,"support_days":7}'),
    ('business_workflow', 'Business Workflow',
     'Up to three applications, multi-step processing, validation, transformations, error handling, audit logging, two revisions, and fourteen days of support.',
     'Starting at PHP 18,000: up to three applications, multi-step processing, validation and transformations, error handling, basic audit logging, two revisions, and fourteen days of support.', 18000,
     '{"schema_version":1,"applications":3,"channels":null,"workflows":null,"ai":null,"database":null,"persistence":null,"handoff":null,"reporting":null,"multi_step_processing":true,"validation":true,"transformations":true,"error_handling":true,"basic_audit_logging":true,"revisions":2,"support_days":14}'),
    ('ai_assistant', 'AI Assistant',
     'One communication channel, approved knowledge base, natural-language responses, persistence, confidence checking, human escalation, two revisions, and fourteen days of support.',
     'Starting at PHP 30,000: one communication channel, approved knowledge base, natural-language responses, conversation persistence, confidence checking, human escalation, two revisions, and fourteen days of support.', 30000,
     '{"schema_version":1,"applications":null,"channels":1,"workflows":null,"ai":true,"database":null,"persistence":true,"handoff":true,"reporting":null,"approved_knowledge_base":true,"natural_language_responses":true,"confidence_checking":true,"revisions":2,"support_days":14}'),
    ('crm_automation', 'CRM Automation',
     'Lead intake, validation, duplicate prevention, CRM synchronization, qualification, error handling, and audit history.',
     'Starting at PHP 35,000: lead intake, validation, duplicate prevention, CRM synchronization, qualification, error handling, audit history, two revisions, and fourteen days of support.', 35000,
     '{"schema_version":1,"applications":null,"channels":null,"workflows":null,"ai":null,"database":null,"persistence":null,"handoff":null,"reporting":null,"lead_intake":true,"validation":true,"duplicate_prevention":true,"crm_synchronization":true,"qualification":true,"error_handling":true,"audit_history":true,"revisions":2,"support_days":14}');

  UPDATE presales.service_packages p
  SET description = o.description, price_max = NULL,
      pricing_basis = 'starting_at', inclusions = o.inclusions, updated_at = now()
  FROM catalog_004_packages o
  WHERE p.code = o.code AND p.updated_at = p.created_at
    AND p.active AND p.approved AND p.pricing_basis = 'human_quote'
    AND p.inclusions = '{}'::jsonb
    AND ROW(p.name, p.description, p.price_min, p.price_max)
        IS NOT DISTINCT FROM
        ROW(o.name, o.old_description, o.starting_price, o.starting_price);

  INSERT INTO presales.service_packages
    (code, name, description, price_min, price_max, pricing_basis, inclusions, approved)
  SELECT code, name, description, starting_price, NULL, 'starting_at', inclusions, true
  FROM catalog_004_packages
  ON CONFLICT (code) DO NOTHING;

  -- Full approved adjustment catalog, inserted only if absent. Extra human-review
  -- flags from 002 remain conservative provisional holds, NOT newly approved
  -- business rules. New custom API/AI/expedited entries use the same safe holds.
  -- Discounts and migration explicitly require human involvement in the brief.
  INSERT INTO presales.pricing_adjustments
    (code, name, adjustment_type, amount_min, amount_max, percentage,
     requires_human, approved)
  VALUES
    ('additional_standard_application', 'Additional standard application', 'fixed_range', 3000, 7500, NULL, false, true),
    ('custom_api', 'Custom API', 'fixed_range', 8000, 20000, NULL, true, true),
    ('ai_feature', 'AI feature', 'fixed_range', 8000, 15000, NULL, true, true),
    ('postgresql_database', 'PostgreSQL database', 'fixed_range', 8000, 15000, NULL, false, true),
    ('human_handoff', 'Human-handoff system', 'fixed_range', 8000, 15000, NULL, false, true),
    ('dashboard_analytics', 'Dashboard or analytics', 'fixed_range', 8000, 20000, NULL, false, true),
    ('delivery_under_seven_days', 'Delivery under seven days', 'percentage', NULL, NULL, 25, true, true),
    ('additional_revision', 'Additional revision', 'fixed_range', 1500, 3000, NULL, false, true),
    ('data_migration', 'Data migration', 'human_quote', NULL, NULL, NULL, true, true),
    ('discount', 'Discount', 'human_quote', NULL, NULL, NULL, true, true)
  ON CONFLICT (code) DO NOTHING;

  -- Baseline approved policies: preserve existing owner edits and deactivations.
  INSERT INTO presales.business_policies (code, policy_text, policy_value, approved)
  VALUES
    ('ai_confidence_threshold', 'Minimum confidence for automatic interpretation', '{"threshold":0.75}', true),
    ('automatic_estimate_ceiling', 'Maximum total for an automatic preliminary estimate', '{"amount":85000,"currency":"PHP"}', true),
    ('lead_score_bands', 'Deterministic lead score bands', '{"cold_max":44,"warm_min":45,"warm_max":74,"hot_min":75}', true),
    ('estimate_disclaimer', 'Required disclaimer on every estimate', '{"text":"This is a preliminary, non-binding estimate based on the information currently available. The final quotation will be confirmed after reviewing the complete workflow requirements, integrations, and access requirements."}', true),
    ('external_costs_excluded', 'External costs are excluded unless explicitly listed', '{"excluded":true}', true),
    ('qualification_weights', 'User-approved qualification weights; maximum score 100',
     '{"service_fit":20,"project_clarity":20,"budget_fit":20,"timeline":10,"decision_authority":10,"urgency":5,"contact_completeness":15,"approved":true}', true),
    ('extraction_config', 'Strict fact extraction; derived technical defaults are provisional',
     '{"schema_version":1,"derived_defaults_provisional":true,"confidence_policy":"ai_confidence_threshold","strict_json":true,"reject_unknown_fields":true,"max_repair_attempts":1,"untrusted_input":true,"unknown_value":null,"require_evidence":true,"allow_model_pricing":false,"allow_model_final_score":false,"allow_model_policy_changes":false,"fields":["intent","requested_service","business_problem","current_manual_process","applications","expected_result","volume","budget","timeline","decision_authority","missing_information","confidence","requires_human"],"invalid_or_repeated_failure_action":"human_handoff","contact_requires_consent":true}', true),
    ('routing_config', 'Deterministic routing with conservative fail-closed behavior',
     '{"schema_version":1,"derived_defaults_provisional":true,"confidence_policy":"ai_confidence_threshold","ceiling_policy":"automatic_estimate_ceiling","low_confidence_operator":"lt","ceiling_comparison":"total_max_gt","human_handoff_reasons":["human_requested","low_confidence","no_approved_match","discount_requested","final_quote_or_contract_requested","sensitive_or_regulated_data","conflicting_requirements","dissatisfied_customer","estimate_ceiling_exceeded","repeated_dependency_failure","invalid_extraction","missing_or_invalid_policy","ambiguous_scope","ambiguous_pricing","human_review_flag","data_migration","custom_crm_scope"],"unknown_action":"human_handoff","hot_lead_action":"create_local_handoff_ticket","notification_delivery_must_be_confirmed":true,"crm":{"approval":"conservative_implementation_default","base_service":"crm_data_entry","max_applications":2,"direction":"email_to_crm","requires_confirmed_standard_integrations":true,"lead_deduplication":false,"qualification":false,"ai":false,"custom_api":false,"database":false,"handoff":false,"reporting":false,"data_migration":false,"use_live_service_price_min_max":true,"package_code":null,"missing_scope_action":"ask_discovery_question","other_crm_action":"human_handoff"}}', true),
    ('qualification_config', 'Deterministic qualification; weights approved, evidence mapping provisional',
     '{"schema_version":1,"weights_policy":"qualification_weights","bands_policy":"lead_score_bands","weights_approved":true,"derived_evidence_mapping_provisional":true,"score_source":"deterministic_code","score_min":0,"score_max":100,"rounding":"integer","missing_or_ambiguous_evidence_points":0,"partial_credit":false,"evidence":{"service_fit":"confirmed_active_approved_service_match","project_clarity":"business_problem_current_process_applications_and_expected_result_confirmed","budget_fit":"explicit_budget_covers_valid_preliminary_total_max","timeline":"explicit_timeline_recorded_without_promising_delivery","decision_authority":"customer_explicitly_confirms_decision_authority","urgency":"customer_explicitly_confirms_urgency","contact_completeness":"consent_granted_and_followup_contact_confirmed"},"unknown_evidence_is_not_negative_fact":true,"missing_or_invalid_weights_action":"human_handoff","hot_action":"create_local_handoff_ticket","warm_action":"invite_consultation","cold_action":"continue_helpful_guidance"}', true),
    ('pricing_config', 'Approved rates with explicit ambiguity handling; no invented package upper bounds or delivery guarantees',
     '{"schema_version":1,"derived_defaults_provisional":true,"currency":"PHP","ceiling_policy":"automatic_estimate_ceiling","disclaimer_policy":"estimate_disclaimer","approved_active_only":true,"price_source":"database_only","starting_at_is_floor":true,"starting_at_without_approved_upper_bound_action":"human_quote","unknown_inclusion_action":"human_quote","unknown_application_limit_action":"human_quote","unclassified_billing_action":"human_quote","recurring_and_hourly_separate":true,"hourly_total_requires_confirmed_hours":true,"support_is_not_delivery":true,"delivery_guarantees_allowed":false,"rush_adjustment":"delivery_under_seven_days","rush_percentage_source":"pricing_adjustments.percentage","rush_fee_is_not_delivery_acceptance":true,"rush_percentage_base_unspecified_action":"human_quote","overlapping_service_and_adjustment_action":"human_quote","do_not_double_charge_included_features":true,"preserve_existing_human_review_flags":true,"legacy_extra_human_flags_provisional":true,"legacy_extra_human_flags_are_owner_approved_rules":false,"external_costs_excluded":["third_party_subscriptions","hosting","domains","ai_usage","paid_apis","premium_crm_features","messaging_charges"],"feature_adjustments":{"applications":"additional_standard_application","custom_api":"custom_api","ai":"ai_feature","database":"postgresql_database","handoff":"human_handoff","reporting":"dashboard_analytics","revisions":"additional_revision"},"additional_channel_service":"additional_messaging_channel","unknown_or_conflicting_rate_action":"human_quote"}', true)
  ON CONFLICT (code) DO NOTHING;

  -- Question-based idempotency: UUID PK conflicts cannot deduplicate FAQ text.
  -- Existing answers (including edited answers) and existing duplicates are left
  -- intact. No uniqueness constraint is added over potentially duplicated data.
  INSERT INTO presales.faqs (question, answer, tags, approved)
  SELECT v.question, v.answer, v.tags, true
  FROM (VALUES
    ('What services do you offer?', 'I help automate workflows, CRM processes, integrations, and AI assistants using approved project requirements.', ARRAY['services','overview']::text[]),
    ('Do you provide an exact final price immediately?', 'I can provide only a preliminary, non-binding estimate. A final quotation requires reviewing the complete workflow, integrations, and access requirements.', ARRAY['pricing','policy']::text[]),
    ('Are third-party subscriptions included?', 'Third-party subscriptions, hosting, domains, paid APIs, premium CRM features, AI usage, and messaging charges are excluded unless explicitly listed.', ARRAY['pricing','exclusions']::text[]),
    ('Can I speak with a human?', 'Yes. Ask for a human at any time and I will prepare a summary for follow-up.', ARRAY['handoff','support']::text[]),
    ('Are package starting prices fixed quotations?', 'Package prices are starting amounts. The complete scope and final quotation require review; no package upper bound or final price is implied.', ARRAY['pricing','packages']::text[]),
    ('How long will delivery take?', 'Delivery timing needs human confirmation after scope review. Package support periods describe support, not delivery deadlines. A rush adjustment does not guarantee acceptance or delivery.', ARRAY['delivery','policy']::text[])
  ) AS v(question, answer, tags)
  WHERE NOT EXISTS (SELECT 1 FROM presales.faqs f WHERE f.question = v.question);

  -- Configuration self-checks do not assert database-wide row counts: operators
  -- may have legitimate additional/inactive/customized entries in these tables.
  IF (SELECT count(*) FROM catalog_004_original_services) <> 16
     OR (SELECT count(*) FROM catalog_004_packages) <> 4 THEN
    RAISE EXCEPTION '004 source catalog cardinality mismatch';
  END IF;

  INSERT INTO presales.schema_migrations (version, description)
  VALUES ('004', 'Complete 25-service original catalog, starting-at package semantics, billing and deterministic policies')
  ON CONFLICT (version) DO NOTHING;
END;
$migration$;

COMMIT;
