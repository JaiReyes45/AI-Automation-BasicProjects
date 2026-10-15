#!/usr/bin/env python3
"""Real concurrent PostgreSQL sessions; ONLY the named disposable database.

Run from WSL with Python 3. No Python dependencies, .env reads, network sends,
container lifecycle changes, schema drops, or truncation. --apply-migration
explicitly reapplies the staging 003 to the disposable database before testing.
Only this run's marked synthetic rows are removed on exit; sequences advance.
"""
import argparse
import concurrent.futures
import json
from pathlib import Path
import secrets
import subprocess
import threading
import time


DATABASE = "p06_verify_20261014"
CONTAINER = "project06-presales-postgres-1"
TABLES = (
    "customers", "conversations", "conversation_state", "messages",
    "processed_updates", "services", "service_packages", "pricing_adjustments",
    "faqs", "business_policies", "estimates", "leads", "handoff_tickets",
    "audit_events", "outbox_jobs", "dead_letter_events", "schema_migrations",
    "chat_sessions", "chat_message_receipts", "consent_events", "runtime_settings",
    "inbox_jobs",
)


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def json_sql(value):
    return literal(json.dumps(value, separators=(",", ":"))) + "::jsonb"


def sql(source):
    # The database name is hard-coded both in the connection and SQL guard.
    guard = """DO $$ BEGIN
      IF current_database() <> 'p06_verify_20261014' THEN
        RAISE EXCEPTION 'refusing non-disposable database';
      END IF;
    END $$;
    SET lock_timeout='15s'; SET statement_timeout='30s';
    SET client_min_messages=warning;
    """
    command = ["docker", "exec", "-i", CONTAINER, "sh", "-c",
               'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1"',
               "phase06-test", DATABASE]
    proc = subprocess.run(command, input=guard + source, text=True,
                          capture_output=True, timeout=45)
    if proc.returncode:
        raise RuntimeError(proc.stderr.strip())
    return [line for line in proc.stdout.splitlines() if line.strip()]


def one(source):
    rows = sql(source)
    assert len(rows) == 1, f"Expected one result, received {len(rows)}"
    return json.loads(rows[0])


def assert_sql(expression, label):
    assert one(f"SELECT coalesce(({expression}),false)::text;") is True, label


def snapshot():
    # Hash rows inside PostgreSQL; existing customer data is never returned.
    parts = [f"SELECT '{table}' AS name, count(*) AS rows, "
             f"md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' "
             f"ORDER BY md5(to_jsonb(t)::text)),'')) AS digest "
             f"FROM presales.{table} t" for table in TABLES]
    return one("SELECT jsonb_agg(to_jsonb(s) ORDER BY name) FROM (" +
               " UNION ALL ".join(parts) + ") s;")


def race(statements):
    # Thread barrier plus a common server-clock release time. Each statement
    # uses its own docker-exec/psql/backend and commits independently.
    barrier = threading.Barrier(len(statements))
    release = time.time() + 2.0

    def run(statement):
        barrier.wait(timeout=10)
        rows = sql(f"BEGIN; SELECT pg_sleep(greatest(0,"
                   f"{release}-extract(epoch FROM clock_timestamp())));\n"
                   + statement + "\nSELECT pg_sleep(0.05); COMMIT;")
        assert len(rows) == 1, "Concurrent session returned an unexpected result"
        return json.loads(rows[0])

    with concurrent.futures.ThreadPoolExecutor(max_workers=len(statements)) as pool:
        # Materialize every future, including failures, before cleanup can run.
        futures = [pool.submit(run, statement) for statement in statements]
        results, errors = [], []
        for future in futures:
            try:
                results.append(future.result())
            except Exception as error:
                errors.append(error)
        if errors:
            raise RuntimeError(f"{len(errors)} concurrent sessions failed: {errors[0]}")
        return results


def claim_sql(kind, owned_updates):
    # A foreign claim is rolled back in SQL, before it can affect another test.
    allowed = ",".join(map(str, owned_updates))
    return f"""DO $$ DECLARE j jsonb; BEGIN
      j := presales.claim_{kind}();
      IF j IS NOT NULL AND (j->>'update_id')::bigint NOT IN ({allowed}) THEN
        RAISE EXCEPTION 'foreign job encountered; claim rolled back';
      END IF;
      PERFORM set_config('phase06_test.claim',coalesce(j::text,'null'),true);
    END $$;
    SELECT current_setting('phase06_test.claim');"""


def claim_wave(kind, owned_updates):
    claimed = []
    # SKIP LOCKED may temporarily return NULL while a cursor holds candidate
    # row locks in another transaction. Retry waves, without expiring leases.
    for _ in range(5):
        claimed += [r for r in race([claim_sql(kind, owned_updates)] * 16) if r is not None]
        if len(claimed) >= 3:
            break
    return claimed


def cleanup(chats, marker):
    ids = ",".join(map(str, chats))
    # Resolve exact rows by BOTH random IDs and this run's unique marker.
    sql(f"""BEGIN;
    CREATE TEMP TABLE test_customers ON COMMIT DROP AS
      SELECT id FROM presales.customers WHERE telegram_user_id IN ({ids})
      AND display_name={literal(marker)};
    CREATE TEMP TABLE test_conversations ON COMMIT DROP AS
      SELECT id FROM presales.conversations WHERE customer_id IN (SELECT id FROM test_customers);
    CREATE TEMP TABLE test_messages ON COMMIT DROP AS
      SELECT id FROM presales.messages WHERE conversation_id IN (SELECT id FROM test_conversations);
    CREATE TEMP TABLE test_updates ON COMMIT DROP AS
      SELECT update_id FROM presales.inbox_jobs WHERE customer_id IN (SELECT id FROM test_customers);
    DELETE FROM presales.dead_letter_events WHERE inbox_update_id IN (SELECT update_id FROM test_updates)
      OR source_id IN (SELECT id FROM test_messages)
      OR source_id IN (SELECT id FROM presales.outbox_jobs WHERE update_id IN (SELECT update_id FROM test_updates));
    DELETE FROM presales.audit_events WHERE conversation_id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.outbox_jobs WHERE update_id IN (SELECT update_id FROM test_updates);
    DELETE FROM presales.estimates WHERE conversation_id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.leads WHERE conversation_id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.handoff_tickets WHERE conversation_id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.consent_events WHERE customer_id IN (SELECT id FROM test_customers);
    DELETE FROM presales.processed_updates WHERE message_id IN (SELECT id FROM test_messages);
    DELETE FROM presales.inbox_jobs WHERE update_id IN (SELECT update_id FROM test_updates);
    DELETE FROM presales.chat_message_receipts WHERE message_id IN (SELECT id FROM test_messages);
    DELETE FROM presales.messages WHERE id IN (SELECT id FROM test_messages);
    DELETE FROM presales.conversation_state WHERE conversation_id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.chat_sessions WHERE customer_id IN (SELECT id FROM test_customers);
    DELETE FROM presales.conversations WHERE id IN (SELECT id FROM test_conversations);
    DELETE FROM presales.customers WHERE id IN (SELECT id FROM test_customers);
    COMMIT;""")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply-migration", action="store_true")
    args = parser.parse_args()
    assert one("SELECT to_jsonb(current_database());") == DATABASE
    if args.apply_migration:
        source = Path(__file__).resolve().parents[1] / "003_runtime.sql"
        sql(source.read_text(encoding="utf-8"))
        print("Applied staging 003 only to " + DATABASE, flush=True)
    assert_sql("NOT EXISTS(SELECT 1 FROM presales.inbox_jobs WHERE status<>'completed')",
               "Disposable database has unfinished inbox work; refusing to interfere")
    assert_sql("NOT EXISTS(SELECT 1 FROM presales.outbox_jobs WHERE update_id IS NOT NULL AND status<>'sent')",
               "Disposable database has unfinished delivery work; refusing to interfere")
    before = snapshot()
    marker = "phase06 concurrent " + "".join(secrets.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(24))
    base = 7_000_000_000_000 + secrets.randbelow(1_000_000_000) * 1000
    chats = [base + 1, base + 2, base + 3]
    updates = [base + 100 + chat * 10 + step for chat in range(3) for step in range(3)]
    retry_updates = [base + 300 + step for step in range(7)]
    owned = updates + retry_updates
    alias_updates = [base + 500 + index for index in range(16)]
    assert_sql(f"NOT EXISTS(SELECT 1 FROM presales.customers WHERE telegram_user_id IN ({','.join(map(str,chats))}))",
               "Synthetic customer collision")
    assert_sql(f"NOT EXISTS(SELECT 1 FROM presales.processed_updates WHERE update_id IN ({','.join(map(str,owned+alias_updates))}))",
               "Synthetic update collision")

    def accept(update, chat, message):
        return "SELECT presales.accept_update(" + json_sql({
            "update_id": update, "message_id": message, "chat_id": chat,
            "user_id": chat, "display_name": marker, "message_type": "text",
            "text": f"Synthetic concurrency step {message}",
        }) + ");"

    try:
        duplicates = race([accept(updates[0], chats[0], 1)] * 16)
        assert sum(r["status"] == "accepted" for r in duplicates) == 1
        assert sum(r["status"] == "duplicate" for r in duplicates) == 15
        aliases = race([accept(update, chats[0], 1) for update in alias_updates])
        assert all(r["status"] == "duplicate" for r in aliases)
        assert len({r["message_id"] for r in duplicates + aliases}) == 1
        assert_sql(f"(SELECT count(*)=1 FROM presales.messages WHERE telegram_chat_id={chats[0]} AND direction='incoming')",
                   "Duplicate storm created extra messages")
        assert_sql(f"(SELECT count(*)=1 FROM presales.inbox_jobs WHERE update_id={updates[0]})",
                   "Duplicate storm created extra inbox entries")
        print("PASS: 16 same-update and 16 alternate-update concurrent ingests -> one message/inbox", flush=True)

        for chat_index, chat in enumerate(chats):
            for step in range(3):
                if chat_index == 0 and step == 0:
                    continue
                assert one(accept(updates[chat_index * 3 + step], chat, step + 1))["status"] == "accepted"
        for step in range(3):
            claims = claim_wave("inbox", owned)
            assert len(claims) == 3, f"Expected one claim per conversation, got {len(claims)}"
            assert len({r["conversation_id"] for r in claims}) == 3
            expected = {updates[chat * 3 + step] for chat in range(3)}
            assert {r["update_id"] for r in claims} == expected, "Inbox order changed"
            assert all(r["state"].get("step", 0) == step for r in claims), "State was stale"
            assert all(r is None for r in race([claim_sql("inbox", owned)] * 8)), "Concurrent second lease"
            commits = []
            for claim in claims:
                statement = ("SELECT presales.commit_decision(" + str(claim["update_id"]) + "," +
                             literal(claim["lease_token"]) + "::uuid," + json_sql({
                                 "state": {"step": step + 1}, "response": f"Synthetic reply {step + 1}",
                                 "event_type": "concurrency_test",
                             }) + ");")
                commits += [statement] * 4
            committed = race(commits)
            assert sum(r["status"] == "completed" for r in committed) == 3
            assert sum(r["status"] == "duplicate" for r in committed) == 9
        assert_sql(f"(SELECT count(*)=9 AND count(DISTINCT update_id)=9 FROM presales.outbox_jobs WHERE update_id IN ({','.join(map(str,updates))}))",
                   "Concurrent commit replay created duplicate replies")
        print("PASS: 3 chats x 3 ordered decisions; 16 claim racers; 4 commit racers per update", flush=True)

        for step in range(3):
            jobs = claim_wave("outbox", owned)
            assert len(jobs) == 3
            assert len({r["payload"]["chat_id"] for r in jobs}) == 3
            assert {r["update_id"] for r in jobs} == {updates[chat * 3 + step] for chat in range(3)}
            assert all(r["payload"]["text"] == f"Synthetic reply {step + 1}" for r in jobs)
            assert all(r is None for r in race([claim_sql("outbox", owned)] * 8))
            finishes = []
            for job in jobs:
                statement = ("SELECT presales.finish_outbox(" + literal(job["id"]) + "::uuid," +
                             literal(job["lease_token"]) + "::uuid," + json_sql({
                                 "ok": True, "status": 200, "message_id": 100001 + step,
                             }) + ");")
                finishes += [statement] * 4
            finished = race(finishes)
            assert sum(r["status"] == "sent" for r in finished) == 3
            assert sum(r["status"] == "duplicate" for r in finished) == 9
        assert_sql(f"(SELECT count(*)=9 FROM presales.messages WHERE telegram_chat_id IN ({','.join(map(str,chats))}) AND direction='outgoing')",
                   "Acknowledgement replay duplicated outgoing messages")
        assert_sql(f"(SELECT count(*)=9 FROM presales.audit_events WHERE event_type='concurrency_test' AND correlation_id IN ({','.join(literal(u) for u in updates)}))",
                   "Commit replay duplicated audit events")
        print("PASS: 9 ordered replies; 16 delivery claim racers; 4 acknowledgement racers per reply", flush=True)

        # Each rate-limit scenario is rolled back, retaining no extra fixture.
        # Large numeric JSON values and fractional delays are included.
        delays = [30, 30.25, 86400, 86400.25, 172800, 10**40, -1]
        for index, delay in enumerate(delays):
            update = retry_updates[index]
            result = json_sql({"ok": False, "status": 429, "retry_after": delay})
            expect_quarantine = delay > 86400 or delay < 0
            assertion = ("IF r->>'status'<>'dead_letter' OR NOT EXISTS(SELECT 1 FROM presales.dead_letter_events WHERE source_id=(j->>'id')::uuid) THEN RAISE EXCEPTION 'expected quarantine'; END IF;"
                         if expect_quarantine else
                         f"IF r->>'status'<>'retry_wait' OR due < started + interval '{delay} seconds' THEN RAISE EXCEPTION 'retry scheduled too early'; END IF;")
            sql("BEGIN; " + accept(update, chats[0], 200 + index) + f"""
              DO $$ DECLARE c jsonb; j jsonb; r jsonb; started timestamptz; due timestamptz; BEGIN
                c := presales.claim_inbox();
                IF c IS NULL OR (c->>'update_id')::bigint<>{update} THEN RAISE EXCEPTION 'foreign inbox'; END IF;
                PERFORM presales.commit_decision({update},(c->>'lease_token')::uuid,'{{"state":{{}},"response":"Rate-limit fixture"}}'::jsonb);
                j := presales.claim_outbox();
                IF j IS NULL OR (j->>'update_id')::bigint<>{update} THEN RAISE EXCEPTION 'foreign outbox'; END IF;
                started := clock_timestamp();
                r := presales.finish_outbox((j->>'id')::uuid,(j->>'lease_token')::uuid,{result});
                SELECT available_at INTO due FROM presales.outbox_jobs WHERE id=(j->>'id')::uuid;
                {assertion}
                IF presales.claim_outbox() IS NOT NULL THEN RAISE EXCEPTION 'rate-limit bypass'; END IF;
              END $$; ROLLBACK;""")
        print("PASS: retry_after 30, 30.25, 86400 honored; 86400.25, 172800, 10^40 and negative quarantined", flush=True)
    finally:
        cleanup(chats, marker)
        after = snapshot()
        changed = [old['name'] for old, new in zip(before, after) if old != new]
        assert not changed, f"Pre-existing table snapshots changed: {changed}; inspect disposable database"
        print(f"PASS: synthetic rows removed; all {len(TABLES)} pre-existing table snapshots unchanged", flush=True)
    print("PASS: concurrent integration complete; no live writes or Telegram sends", flush=True)


if __name__ == "__main__":
    main()
