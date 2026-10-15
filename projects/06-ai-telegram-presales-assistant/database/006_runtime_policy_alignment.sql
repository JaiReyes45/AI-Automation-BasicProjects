-- Metadata alignment with implementation/runtime/engine.js, not a rule change.
-- Parent/operator applies this migration only; never rerun 002, 004 or 005.
-- Preserve all route/rule arrays, prices, weights, bands, thresholds, active flags
-- and approval flags. extraction_config.fields is the sole replaced field array.
-- These configuration notes describe code; editing them does not reconfigure the
-- extraction validator, routing predicates, confirmation flow or score predicates.
-- The runtime consumes automatic_service_routes.routes and approved scalar
-- pricing/scoring policies, while its additional scope checks remain in code.

BEGIN;
SELECT pg_advisory_xact_lock(600006);

DO $alignment$
DECLARE
  extraction_patch jsonb := $extraction_json$
  {
    "fields":["intent","category","business_problem","current_process","expected_result","applications","source_application","destination_application","crm_operation","workflow_complexity","volume","budget","timeline_days","decision_maker","ai","custom_api","database","handoff","reporting","sensitive","conflict","handoff_reason","missing_information","confidence"],
    "configuration_role":"informational_runtime_schema_snapshot",
    "enforcement_source":"runtime/engine.js: extractionSchema and validateExtraction",
    "all_fields_required":true,
    "unknown_value_note":"Use null only for nullable schema properties; use the schema enum values for other unknown facts. The engine enforces types, enums, bounds and additionalProperties=false.",
    "policy_notes":"The engine schema is authoritative. This fields list documents the validator and is not a live configurable extraction rule engine. Changing policy notes does not change accepted model output."
  }
  $extraction_json$::jsonb;

  -- A keyed object documents the existing routes without replacing their array.
  scope_notes jsonb := $scope_json$
  {
    "configuration_role":"informational_runtime_scope_snapshot",
    "scope_approval":"conservative_implementation_default",
    "scope_mapping_explicitly_approved":false,
    "enforcement_source":"runtime/engine.js: preflight, discover and estimate",
    "policy_notes":"The existing routes array supplies candidate services, application caps and included features. Code enforces the predicates described here. This object is informational, not a live rule engine; it does not authorize new scope or change the routes array.",
    "application_count":"Canonicalize names and deduplicate applications before route selection; the documented limits describe the original 005 route array, which this migration preserves even if edited.",
    "workflow_simple":{
      "category":"workflow_automation",
      "workflow_complexity":"basic",
      "max_applications":2
    },
    "workflow_intermediate":{
      "category":"workflow_automation",
      "scope":"basic with exactly 3 applications, or multi_step with at most 3 applications",
      "complex_or_unknown_scope":"no automatic workflow route"
    },
    "crm_data_entry":{
      "category":"crm_automation",
      "max_applications":2,
      "source_allowlist":["gmail","outlook","microsoft 365"],
      "destination_allowlist":["hubspot","salesforce","zoho","pipedrive"],
      "operations":["create","update","create_or_update"],
      "direction":"source email application to destination CRM application",
      "both_endpoints_required_in_canonical_applications":true,
      "required_scope_pattern":"email|inbox|inquir",
      "case_insensitive":true,
      "other_crm_scope":"human_review",
      "optional_features":"Use eligible database adjustment rows and their requires_human flags; legacy routing_config.crm feature flags do not control the engine."
    },
    "telegram_faq_ai":{
      "category":"ai_chatbot",
      "max_applications":1,
      "application_pattern":"telegram",
      "faq_scope_pattern":"faq|frequently asked|answer.{0,40}questions|questions.{0,40}answer",
      "case_insensitive":true,
      "pattern_matching_note":"Current code uses substring/regex matching, not exact Telegram product-name equality.",
      "ai_included":true,
      "other_channel_or_non_faq_scope":"human_review"
    },
    "shared_scope_checks":{
      "scope_text":"business_problem, current_process and expected_result joined with spaces",
      "excluded_scope_pattern":"multi.?workflow|dedup|qualif|score|deal|pipeline|migration",
      "case_insensitive":true,
      "rates":"Use the selected active approved one_time service range and eligible adjustments; preserve human-review flags.",
      "limits":"Missing or invalid rates, rush timelines under seven days and totals above the configured ceiling require review. Read existing rate/threshold policies; no values are changed here."
    },
    "caller_confirmation":{
      "command":"/confirm",
      "exact_standalone_command":true,
      "pending_estimate_required":true,
      "handed_off_conversation_blocks_confirmation":true,
      "discovery_must_be_complete":true,
      "enforcement":"preflight sets c.confirmed and discover checks it; callers must execute that pipeline before estimate. estimate alone does not independently enforce confirmation.",
      "meaning":"Confirmation permits a preliminary estimate, not purchase or delivery acceptance."
    }
  }
  $scope_json$::jsonb;

  qualification_patch jsonb := $qualification_json$
  {
    "configuration_role":"informational_runtime_scoring_snapshot",
    "enforcement_source":"runtime/engine.js: qualify",
    "derived_evidence_mapping_provisional":true,
    "evidence_mapping_approval":"conservative_implementation_default",
    "evidence_mapping_explicitly_approved":false,
    "policy_notes":"The user approved the weights, not these evidence mappings. The following predicates document current code defaults and are not a live scoring rule engine. The existing qualification_weights and lead_score_bands policy values and approvals are unchanged.",
    "evidence":{
      "service_fit":"At least one service in the supplied catalog has category equal to requirements.category; qualify does not independently match a specific service or recheck approval flags.",
      "project_clarity":"requirements.business_problem is truthy and requirements.applications has nonzero length; current_process and expected_result are not required for these points.",
      "budget_fit":"requirements.budget is non-null, state.last_estimate exists, and budget is at least last_estimate.total_max.",
      "timeline":"requirements.timeline_days is at least 7; this does not promise feasibility or delivery.",
      "decision_authority":"requirements.decision_maker is strictly true.",
      "urgency":"requirements.timeline_days is greater than 0 and at most 30; no separate explicit urgency flag is used.",
      "contact_completeness":"state.contact or state.contact_present is truthy; granted consent is separately required before scoring."
    },
    "scoring_prerequisites":{
      "decision_events":["estimate_created","consultation_requested"],
      "consent":"granted",
      "contact":"state.contact or state.contact_present must be truthy",
      "catalog_approval_boundary":"The database retrieval layer supplies the active approved catalog; qualify uses that supplied snapshot."
    },
    "rounding":"none_in_qualify",
    "missing_or_invalid_weights_action":"Absent weights or weights.approved !== true produces score 0, status unqualified and reason scoring_policy_approval_pending; non-finite or negative individual weights are skipped.",
    "calculation_notes":"For each satisfied predicate add its finite nonnegative numeric weight, then cap the sum at 100. Read hot_min and warm_min from existing lead_score_bands; missing bands escalate to qualification_policy_missing.",
    "hot_action":"Create a high-priority hot_lead handoff if none exists; otherwise preserve the existing reason and raise its priority to high.",
    "warm_action":"Set lead status warm; qualify does not independently send a consultation invitation.",
    "cold_action":"Set lead status cold; qualify does not independently send additional guidance."
  }
  $qualification_json$::jsonb;
BEGIN
  -- Fail closed on missing prerequisites; do not recreate tables, reset state,
  -- reseed catalogs or silently mark an incomplete metadata update as applied.
  IF to_regclass('presales.schema_migrations') IS NULL THEN
    RAISE EXCEPTION '006 requires applied migration 003; no schema/state was reset';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '003') THEN
    RAISE EXCEPTION '006 requires applied migration 003; no schema/state was reset';
  END IF;
  IF EXISTS (SELECT 1 FROM presales.schema_migrations WHERE version = '006') THEN
    RETURN;
  END IF;

  LOCK TABLE presales.business_policies IN SHARE ROW EXCLUSIVE MODE;
  IF (SELECT count(*) FROM presales.business_policies
      WHERE code IN ('extraction_config','routing_config','qualification_config',
                     'automatic_service_routes')) <> 4 THEN
    RAISE EXCEPTION '006 requires existing 004/005 policy rows; inspect missing policies rather than reseeding';
  END IF;
  IF EXISTS (SELECT 1 FROM presales.business_policies
             WHERE code IN ('extraction_config','routing_config','qualification_config',
                            'automatic_service_routes')
               AND jsonb_typeof(policy_value) IS DISTINCT FROM 'object')
     OR EXISTS (SELECT 1 FROM presales.business_policies
                 WHERE code = 'routing_config'
                   AND jsonb_typeof(policy_value->'crm') IS DISTINCT FROM 'object')
     OR EXISTS (SELECT 1 FROM presales.business_policies
                 WHERE code = 'automatic_service_routes'
                   AND jsonb_typeof(policy_value->'routes') IS DISTINCT FROM 'array') THEN
    RAISE EXCEPTION '006 found incompatible policy JSON; inspect it rather than replacing rules';
  END IF;

  UPDATE presales.business_policies
  SET policy_value = policy_value || extraction_patch,
      policy_text = 'Informational extraction schema notes; runtime/engine.js enforces the actual validator.',
      updated_at = now()
  WHERE code = 'extraction_config';

  UPDATE presales.business_policies
  SET policy_value = jsonb_set(policy_value, '{crm,approval}',
        '"conservative_implementation_default"'::jsonb, true)
        || jsonb_build_object(
          'configuration_role', 'informational_runtime_routing_notes',
          'scope_mapping_explicitly_approved', false,
          'policy_notes', 'CRM scope is a conservative implementation default, not an explicit user instruction. Runtime code enforces scope. Existing CRM flags and handoff-reason lists are informational; see automatic_service_routes.runtime_scope_notes for current predicates.'),
      policy_text = 'Informational routing notes; conservative scope defaults are enforced in runtime code.',
      updated_at = now()
  WHERE code = 'routing_config';

  UPDATE presales.business_policies
  SET policy_value = policy_value || jsonb_build_object('runtime_scope_notes', scope_notes),
      policy_text = 'Service ranges drive estimates; packages are informational. Route scope predicates are conservative implementation defaults enforced by runtime code; the existing routes array is preserved.',
      updated_at = now()
  WHERE code = 'automatic_service_routes';

  UPDATE presales.business_policies
  SET policy_value = policy_value || qualification_patch,
      policy_text = 'Approved weights with provisional implementation evidence mappings; runtime qualify enforces the actual predicates.',
      updated_at = now()
  WHERE code = 'qualification_config';

  INSERT INTO presales.schema_migrations (version, description)
  VALUES ('006', 'Align informational policy metadata with runtime schema, scope and qualification predicates')
  ON CONFLICT (version) DO NOTHING;
END;
$alignment$;

COMMIT;
