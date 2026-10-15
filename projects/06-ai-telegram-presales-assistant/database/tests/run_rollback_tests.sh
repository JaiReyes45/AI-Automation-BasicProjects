#!/usr/bin/env bash
# Runs against the already-running local Postgres service. No .env is read.
# All test DDL/data live in a unique schema in ONE transaction ending ROLLBACK.
set -euo pipefail
base_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
original_dir="${1:-$base_dir}"
container_name="${2:-project06-presales-postgres-1}"
test_schema="presales_test_${$}_${RANDOM}"
emit_sql() {
  printf 'BEGIN;\nCREATE SCHEMA %s;\n' "$test_schema"
  for source in "$original_dir/001_core_presales_schema.sql" "$original_dir/002_catalog_and_rules.sql" \
    "$base_dir/tests/002_legacy_fixture.sql" "$base_dir/003_runtime.sql" "$base_dir/003_runtime.sql" \
    "$base_dir/tests/003_runtime_assertions.sql"; do
    sed -e '/^BEGIN;$/d' -e '/^COMMIT;$/d' -e '/^ROLLBACK;$/d' \
      -e "s/presales/$test_schema/g" "$source"
  done
  printf '\nROLLBACK;\n'
}
emit_sql | docker exec -i "$container_name" sh -c \
  'exec psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
printf 'Phase06 rollback assertions passed; isolated schema rolled back.\n'
