\set ON_ERROR_STOP on

SELECT to_regclass('presales.customers') IS NOT NULL AS customers_table_exists;
SELECT to_regclass('presales.services') IS NOT NULL AS services_table_exists;
SELECT to_regclass('presales.processed_updates') IS NOT NULL AS idempotency_table_exists;
SELECT count(*) >= 16 AS seeded_services_ok FROM presales.services WHERE active;
SELECT count(*) = 4 AS seeded_packages_ok FROM presales.service_packages WHERE active;
SELECT policy_value->>'threshold' = '0.75' AS confidence_policy_ok
  FROM presales.business_policies WHERE code = 'ai_confidence_threshold';
SELECT policy_value->>'amount' = '85000' AS ceiling_policy_ok
  FROM presales.business_policies WHERE code = 'automatic_estimate_ceiling';
