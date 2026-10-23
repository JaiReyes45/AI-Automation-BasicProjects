import json
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from workflow.engine import classify, decide
from workflow.service import Store

ROOT = Path(__file__).resolve().parents[1]

def message(**changes):
    result = json.loads((ROOT / 'fixtures/application-submitted.json').read_text())
    result.update(changes)
    return result


class ClassificationTests(unittest.TestCase):
    def test_fixture_matrix(self):
        for case in json.loads((ROOT / 'fixtures/classification-cases.json').read_text()):
            with self.subTest(case=case['name']):
                result = classify(message(body=case['body']))
                self.assertEqual((result['stage'], result['reason']), (case['stage'], case['reason']))

    def test_role_aliases(self):
        for original, expected in [('Quality Assurance Internship', 'QA Engineer Intern'), ('Software Engineering Intern', 'Software Engineer Intern'), ('IT Support Internship', 'IT Intern')]:
            with self.subTest(role=original):
                r = classify(message(body=f'Role: {original}\nWe received your application.'))
                self.assertEqual(r['original_role'], original)
                self.assertEqual(r['normalized_role'], expected)

    def test_missing_and_blank_fields(self):
        r = classify(message(body='Company:\nRole:\nWe received your application.'))
        self.assertIsNone(r['company']); self.assertIsNone(r['normalized_role'])
        self.assertIsNone(r['deadline'])
        self.assertEqual(decide(message(), r, [])[1], 'unmatched_application')

    def test_old_subject_is_not_evidence(self):
        r = classify(message(subject='Application received', body='We invite you to an interview.'))
        self.assertEqual(r['stage'], 'interview')

    def test_invalid_envelopes(self):
        for change in ({'received_at':'2026-10-23'}, {'received_at':'bad'}, {'body':None}, {'id':''}, {'thread_id':[]}):
            with self.subTest(change=change), self.assertRaises(ValueError): classify(message(**change))


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.store = Store(Path(self.temp.name) / 'db.sqlite3')

    def apps(self):
        with self.store.connect() as db:
            return [json.loads(row[0]) for row in db.execute('SELECT data FROM applications')]

    def update(self, **changes):
        defaults = dict(id='next', received_at='2026-10-24T10:00:00+08:00', body='We invite you to an interview.')
        defaults.update(changes)
        return message(**defaults)

    def test_duplicate_across_restarts(self):
        first = self.store.ingest(message())
        second = Store(self.store.path).ingest(message())
        self.assertTrue(second['duplicate'])
        self.assertEqual(first['application_id'], second['application_id'])
        with self.store.connect() as db:
            for table in ('applications','events','messages','outbox'):
                self.assertEqual(db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0], 1)

    def test_concurrent_duplicates(self):
        with ThreadPoolExecutor(max_workers=4) as pool:
            outcomes = list(pool.map(lambda _: self.store.ingest(message()), range(8)))
        self.assertEqual(sum(not r['duplicate'] for r in outcomes), 1)

    def test_new_thread_reference_match(self):
        first = self.store.ingest(message())
        later = self.store.ingest(self.update(thread_id='new-thread', body='Reference: APP-007\nWe invite you to an interview.'))
        self.assertEqual(later['application_id'], first['application_id'])
        self.assertEqual(self.apps()[0]['stage'], 'interview')

    def test_same_company_different_roles(self):
        self.store.ingest(message())
        other = message(id='other', thread_id='other-thread', body=message()['body'].replace('APP-007','APP-008').replace('QA Engineer Intern','IT Intern'))
        self.store.ingest(other)
        self.assertEqual(len(self.apps()), 2)

    def test_reference_thread_conflict(self):
        self.test_same_company_different_roles()
        result = self.store.ingest(self.update(body='Reference: APP-008\nWe invite you to an interview.'))
        self.assertEqual(result['action'], 'identity_conflict')
        self.assertTrue(all(a['stage'] == 'submitted' for a in self.apps()))

    def test_stale_and_regression(self):
        self.store.ingest(message())
        self.store.ingest(self.update())
        old = self.store.ingest(message(id='old'))
        self.assertEqual(old['action'], 'stale_event')
        regressed = self.store.ingest(message(id='regressed', received_at='2026-10-25T10:00:00+08:00'))
        self.assertEqual(regressed['action'], 'stage_regression')
        self.assertEqual(self.apps()[0]['stage'], 'interview')

    def test_closed_application(self):
        self.store.ingest(message())
        self.store.ingest(self.update(body='You have not been selected.'))
        result = self.store.ingest(message(id='late', received_at='2026-10-25T10:00:00+08:00', body='We invite you to an interview.'))
        self.assertEqual(result['action'], 'closed_application')

    def test_company_alone_is_not_match(self):
        self.store.ingest(message())
        result = self.store.ingest(self.update(thread_id='unknown', body='Company: Example Labs\nWe invite you to an interview.'))
        self.assertEqual(result['action'], 'unmatched_application')

    def test_account_isolation(self):
        self.store.ingest(message())
        result = self.store.ingest(self.update(account='other@example.test'))
        self.assertEqual(result['action'], 'unmatched_application')

    def test_ambiguity_does_not_mutate(self):
        self.store.ingest(message())
        self.store.ingest(self.update(body='If successful, we will invite you to an interview.'))
        self.assertEqual(self.apps()[0]['stage'], 'submitted')

    def test_label_failure_is_durable_and_retryable(self):
        self.store.ingest(message())
        first = self.store.deliver_mock(inject_failure=True)
        self.assertEqual(first['outbox'], {'failed': 1})
        result = Store(self.store.path).deliver_mock()
        self.assertEqual(result['outbox'], {'delivered': 1})
        self.assertEqual(result['events'], 1)
        with self.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM delivery_attempts').fetchone()[0], 2)

    def test_label_delivery_preserves_unrelated_labels(self):
        self.store.ingest(message())
        with self.store.connect() as db:
            db.execute('INSERT INTO mock_labels VALUES (?,?,?)', (message()['account'], message()['id'], json.dumps(['INBOX','STARRED','Personal'])))
        self.store.deliver_mock()
        with self.store.connect() as db:
            labels = json.loads(db.execute('SELECT labels FROM mock_labels').fetchone()[0])
        self.assertTrue(set(['INBOX','STARRED','Personal','Career/Stage/Application Submitted']).issubset(labels))

    def test_label_retries_cannot_regress_current_stage(self):
        self.store.ingest(message())
        self.store.deliver_mock(inject_failure=True)
        self.store.ingest(self.update())
        self.store.deliver_mock()
        with self.store.connect() as db:
            for row in db.execute('SELECT labels FROM mock_labels'):
                labels = json.loads(row[0])
                self.assertIn('Career/Stage/Interview', labels)
                self.assertNotIn('Career/Stage/Application Submitted', labels)

    def test_label_delivery_is_repeatable(self):
        self.store.ingest(message())
        self.store.deliver_mock()
        self.assertEqual(self.store.deliver_mock()['delivered'], 0)

    def test_repeated_failure_stops_after_three_attempts(self):
        self.store.ingest(message())
        for _ in range(3): self.store.deliver_mock(inject_failure=True)
        self.assertEqual(self.store.status()['outbox'], {'dead': 1})
        self.assertEqual(self.store.deliver_mock()['delivered'], 0)


if __name__ == '__main__': unittest.main()
