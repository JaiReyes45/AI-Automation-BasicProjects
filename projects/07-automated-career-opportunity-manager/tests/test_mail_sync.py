"""Durable mail checkpoint contracts, exercised against a real temporary SQL store."""
import importlib.util
import json
import sqlite3
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

if importlib.util.find_spec('crm.mail_sync'):
    from crm import mail_sync
else:
    mail_sync = None


class SqliteStore:
    """Only PostgreSQL syntax/JSON adaptation is replaced; persistence is real SQL."""
    def __init__(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute("ATTACH DATABASE ':memory:' AS career")
        self.db.execute('CREATE TABLE career.mail_sync_accounts(account TEXT PRIMARY KEY, state TEXT NOT NULL)')
        self.db.execute('CREATE TABLE career.messages(account TEXT, id TEXT, PRIMARY KEY(account,id))')

    def execute(self, query, params=()):
        query = query.replace(' FOR UPDATE', '').replace('::jsonb', '').replace('%s', '?')
        params = tuple(json.dumps(p.obj) if hasattr(p, 'obj') else p for p in params)
        cursor = self.db.execute(query, params)
        if query.startswith('SELECT state'):
            rows = [(json.loads(r[0]),) for r in cursor.fetchall()]
            class Rows:
                def fetchone(self): return rows[0] if rows else None
                def fetchall(self): return rows
                def __iter__(self): return iter(rows)
            return Rows()
        return cursor

    def stored(self, account, *ids):
        for key in ids:
            self.db.execute('INSERT OR IGNORE INTO career.messages VALUES (?,?)', (account, key))


class MailSyncTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(mail_sync, 'Durable mailbox capture is not implemented')
        self.db = SqliteStore()
        self.addCleanup(self.db.db.close)
        self.clock = patch('crm.mail_sync.time.time', return_value=1793092800.0)
        self.now = self.clock.start()
        self.addCleanup(self.clock.stop)

    def start(self, **body):
        return mail_sync.start_run(self.db, {'account':'demo@example.test', **body})

    def ack(self, run, ids=(), token=None, **changes):
        body = {k:run[k] for k in ('account','run_id','lease_token','page_index','page_token')}
        return mail_sync.record_page(self.db, {**body, 'message_ids':list(ids), 'next_page_token':token, **changes})

    def finish(self, run, success=True, **changes):
        body = {k:run[k] for k in ('account','run_id','lease_token')}
        return mail_sync.finish_run(self.db, {**body,'success':success, **changes})

    def test_initial_capture_is_seven_days_without_subject_or_sent_exclusion(self):
        run = self.start()
        self.assertTrue(run['should_run'])
        self.assertEqual(run['before'], '2026-10-27T09:20:00+00:00')
        self.assertEqual(run['after'], '2026-10-20T09:20:00+00:00')
        self.assertNotIn('subject:', run['query'])
        self.assertNotIn('-in:sent', run['query'])
        self.assertIn('-in:drafts', run['query'])

    def test_uncommitted_page_cannot_advance_coverage(self):
        run = self.start()
        with self.assertRaisesRegex(ValueError, 'stored'):
            self.ack(run, ['missing'])
        with self.assertRaisesRegex(ValueError, 'page'):
            self.finish(run)
        self.assertIsNone(mail_sync.coverage(self.db, run['account'])['complete_through'])

    def test_account_must_own_each_acknowledged_message(self):
        run = self.start()
        self.db.stored('other@example.test', 'private-id')
        with self.assertRaisesRegex(ValueError, 'stored'):
            self.ack(run, ['private-id'])

    def test_failure_and_resume_keep_checkpoint_and_fixed_bounds(self):
        run = self.start()
        self.db.stored(run['account'], 'one')
        page = self.ack(run, ['one'], 'provider-page-2')
        partial = self.finish(run)
        self.assertFalse(partial['complete'])
        self.assertIsNone(partial['coverage']['complete_through'])
        self.now.return_value += 300
        resumed = self.start()
        self.assertEqual(resumed['run_id'], run['run_id'])
        self.assertEqual(resumed['before'], run['before'])
        self.assertEqual(resumed['page_token'], 'provider-page-2')
        self.assertEqual(resumed['page_index'], 1)
        failed = self.finish(resumed, False, error='provider_error')
        self.assertEqual(failed['coverage']['last_error'], 'provider_error')
        self.assertEqual(self.start()['page_token'], 'provider-page-2')

    def test_last_page_then_finish_advances_cursor_and_replay_is_idempotent(self):
        run = self.start()
        self.db.stored(run['account'], 'one')
        self.ack(run, ['one'])
        self.ack(run, ['one'])
        done = self.finish(run)
        self.assertTrue(done['complete'])
        self.assertEqual(done['coverage']['complete_through'], run['before'])
        self.assertEqual(done['processed'], 1)
        self.assertEqual(self.finish(run), done)
        self.now.return_value += 300
        later = self.start()
        self.assertEqual(later['after'], '2026-10-26T09:20:00+00:00')

    def test_conflicting_page_replay_and_cycle_are_rejected(self):
        run = self.start()
        self.ack(run, (), 'p2')
        with self.assertRaisesRegex(ValueError, 'replay'):
            self.ack(run, (), 'different')
        self.finish(run)
        resumed = self.start()
        with self.assertRaisesRegex(ValueError, 'token'):
            self.ack(resumed, (), 'p2')

    def test_other_worker_is_busy_then_expired_lease_cannot_ack(self):
        run = self.start()
        self.assertEqual(self.start()['reason'], 'busy')
        self.now.return_value += 901
        resumed = self.start()
        self.assertEqual(resumed['run_id'], run['run_id'])
        self.assertNotEqual(resumed['lease_token'], run['lease_token'])
        with self.assertRaisesRegex(ValueError, 'lease'):
            self.ack(run)
        self.ack(resumed)
        self.assertTrue(self.finish(resumed)['complete'])

    def test_timeout_is_visible_before_another_worker_starts(self):
        run = self.start()
        self.now.return_value += 901
        state = mail_sync.coverage(self.db, run['account'])
        self.assertEqual(state['status'], 'interrupted')
        self.assertIsNone(state['complete_through'])

    def test_crash_after_final_ack_recovers_completion_without_rereading_page(self):
        run = self.start()
        self.ack(run)
        self.now.return_value += 901
        recovered = self.start()
        self.assertFalse(recovered['should_run'])
        self.assertEqual(recovered['reason'], 'recovered_completed_run')
        self.assertEqual(recovered['coverage']['complete_through'], run['before'])

    def test_worker_page_cap_preserves_resume_and_reports_incomplete(self):
        run = self.start()
        self.ack(run, (), 'p2')
        with self.assertRaisesRegex(ValueError, 'limit'):
            self.ack({**run,'page_index':1,'page_token':'p2'}, (), 'p3')
        partial = self.finish(run)
        self.assertEqual(partial['reason'], 'page_limit')
        self.assertEqual(partial['coverage']['status'], 'catching_up')
        self.assertEqual(self.start()['page_token'], 'p2')

    def test_invalid_provider_token_restarts_same_window_without_losing_cursor(self):
        run = self.start()
        self.ack(run, (), 'expired-provider-token')
        self.finish(run)
        resumed = self.start()
        self.finish(resumed, False, error='invalid_page_token')
        restarted = self.start()
        self.assertEqual(restarted['run_id'], run['run_id'])
        self.assertEqual(restarted['after'], run['after'])
        self.assertIsNone(restarted['page_token'])
        self.assertIsNone(mail_sync.coverage(self.db, run['account'])['complete_through'])

    def test_backfill_requires_request_and_rejects_unbounded_dates(self):
        with self.assertRaisesRegex(ValueError, 'request'):
            self.start(mode='backfill')
        for days in (0, 91, -1):
            with self.assertRaises(ValueError):
                mail_sync.request_backfill(self.db, {'account':'demo@example.test','days':days})
        with self.assertRaises(ValueError):
            mail_sync.request_backfill(self.db, {'account':'demo@example.test','after':'2026-06-01T00:00:00Z','before':'2026-10-27T00:00:00Z'})

    def test_queued_backfill_uses_bounded_windows_and_does_not_advance_incremental(self):
        run = self.start()
        self.ack(run)
        self.finish(run)
        requested = mail_sync.request_backfill(self.db, {'account':run['account'],'days':90})
        self.assertEqual(requested['coverage']['status'], 'catching_up')
        backfill = self.start()
        self.assertEqual(backfill['mode'], 'backfill')
        self.assertEqual(backfill['before'], '2026-10-27T09:20:00+00:00')
        self.assertEqual(backfill['after'], '2026-09-27T09:20:00+00:00')
        self.ack(backfill)
        done = self.finish(backfill)
        self.assertEqual(done['coverage']['complete_through'], run['before'])
        self.assertEqual(done['coverage']['backfill']['status'], 'pending')
        self.assertEqual(done['coverage']['backfill']['next_before'], backfill['after'])

    def test_historical_ingest_requires_current_account_lease_and_time_range(self):
        mail_sync.request_backfill(self.db, {'account':'demo@example.test','days':90})
        run = self.start(mode='backfill')
        message = dict(account=run['account'],id='history',received_at='2026-10-01T12:00:00Z',
                       mail_sync_run_id=run['run_id'],mail_sync_lease_token=run['lease_token'])
        self.assertTrue(mail_sync.validate_message(self.db, message))
        for change in ({'account':'other@example.test'}, {'received_at':'2025-01-01T00:00:00Z'},
                       {'mail_sync_lease_token':'wrong'}, {'received_at':'2026-10-01'}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                mail_sync.validate_message(self.db, {**message, **change})
        self.assertFalse(mail_sync.validate_message(self.db, {'account':run['account']}))

    def test_coverage_aggregates_without_exposing_worker_lease(self):
        self.start()
        all_accounts = mail_sync.coverage(self.db)
        self.assertEqual(len(all_accounts['accounts']), 1)
        self.assertNotIn('lease_token', json.dumps(all_accounts))


if __name__ == '__main__':
    unittest.main()
