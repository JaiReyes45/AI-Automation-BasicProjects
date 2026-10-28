"""Queue transition and helper preflight checks without desktop sends."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import unittest

HAS_MODULE = importlib.util.find_spec('crm.notifications') is not None
if HAS_MODULE:
    from crm import notifications


class NotificationTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HAS_MODULE, 'The durable notification module must exist')

    def test_completed_and_read_tasks_suppress_pending_delivery(self):
        self.assertEqual(notifications.delivery_state({'state': 'pending'}, {'status': 'done'}, 100), 'suppressed')
        self.assertEqual(notifications.delivery_state({'state': 'pending', 'read_at': 90}, {'status': 'open'}, 100), 'suppressed')

    def test_snooze_and_retry_time_prevent_early_delivery(self):
        for item in [{'state': 'pending', 'snoozed_until': 150}, {'state': 'failed', 'next_attempt': 150, 'attempts': 1}]:
            self.assertIsNone(notifications.delivery_state(item, {'status': 'open'}, 100))
            self.assertEqual(notifications.delivery_state(item, {'status': 'open'}, 151), 'claimable')

    def test_lost_delivery_ack_is_visible_as_uncertain_without_automatic_duplicate(self):
        self.assertIsNone(notifications.delivery_state({'state': 'processing', 'lease_until': 150}, {'status': 'open'}, 100))
        self.assertEqual(notifications.delivery_state({'state': 'processing', 'lease_until': 90}, {'status': 'open'}, 100), 'uncertain')
        self.assertIsNone(notifications.delivery_state({'state': 'uncertain'}, {'status': 'open'}, 200))

    def test_retries_are_bounded_and_back_off(self):
        self.assertLess(notifications.retry_delay(1), notifications.retry_delay(2))
        self.assertIsNone(notifications.delivery_state({'state': 'failed', 'attempts': 5, 'next_attempt': 0}, {'status': 'open'}, 100))

    def test_scoped_notification_payload_does_not_expose_mail_or_token(self):
        value = notifications.delivery_payload(dict(id='n-1', task_id='t-1', title='Reply requested', body='Review this request in CareerFlow.',
            href='/', lease_token='lease', state='processing', account='private@example.test', envelope={'body':'private'}, token_hash='secret', attempts=1))
        self.assertEqual(set(value), {'id', 'task_id', 'title', 'body', 'href', 'lease', 'attempt'})
        self.assertEqual(value['lease'], 'lease')

    def test_pairing_code_validation_rejects_malformed_input(self):
        for code in [None, 'short', 'A'*200, '../malformed']:
            with self.assertRaises(ValueError):
                notifications.normalize_pairing_code(code)


@unittest.skipUnless(os.name == 'nt' and shutil.which('powershell.exe'), 'Windows-only helper preflight')
class HelperPreflightTests(unittest.TestCase):
    script = Path(__file__).resolve().parents[1] / 'scripts' / 'desktop_notifications.ps1'

    def run_check(self, url):
        self.assertTrue(self.script.exists(), 'The scoped Windows helper must exist')
        return subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(self.script), '-Check', '-BaseUrl', url],
            capture_output=True, text=True, timeout=20)

    def test_check_has_no_pairing_or_notification_side_effect(self):
        result = self.run_check('http://localhost:8087')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Ready', result.stdout)

    def test_helper_refuses_remote_and_embedded_credential_urls(self):
        for url in ['https://example.test', 'http://user:password@localhost:8087', 'http://localhost:8087/redirect']:
            with self.subTest(url=url):
                self.assertNotEqual(self.run_check(url).returncode, 0)


if __name__ == '__main__':
    unittest.main()
