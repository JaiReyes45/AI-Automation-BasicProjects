import unittest
from crm.matching import match_application, is_career_message


class MatchingTests(unittest.TestCase):
    def setUp(self):
        self.app = dict(id='a', account='me@example.test', company='Example Labs', role='QA Engineer Intern',
                        original_role='QA Engineer Intern', reference='R42', threads=['old'],
                        verified_contacts=['hr@example.test'], stage='submitted')
        self.mail = dict(account='me@example.test', id='m', thread_id='new', sender='HR <hr@example.test>',
                         subject='Your availability', body='For the QA Engineer Intern role, are you available for an interview?')

    def test_new_thread_verified_contact_and_role(self):
        result = match_application(self.mail, {}, [self.app])
        self.assertEqual(result['application_id'], 'a')
        self.assertIn('verified_contact_and_role', result['reasons'])

    def test_company_alone_is_not_match(self):
        mail = dict(self.mail, sender='unknown@example.test', body='Example Labs requests your availability.')
        self.assertIsNone(match_application(mail, {}, [self.app])['application_id'])

    def test_two_reapplications_not_merged(self):
        self.assertIsNone(match_application(self.mail, {}, [self.app, dict(self.app,id='b')])['application_id'])

    def test_stage_uncertainty_does_not_hide_identity(self):
        result = match_application(dict(self.mail,thread_id='old'), {'reason':'conflicting_signals'}, [self.app])
        self.assertEqual(result['application_id'], 'a')

    def test_account_isolation_and_conflicting_reference(self):
        self.assertIsNone(match_application(self.mail, {}, [dict(self.app,account='other@example.test')])['application_id'])
        result = match_application(dict(self.mail,thread_id='old'), {'reference':'OTHER'}, [self.app])
        self.assertIsNone(result['application_id'])

    def test_unknown_interview_outreach_remains_relevant(self):
        self.assertTrue(is_career_message(self.mail, {'reason':'unrecognized_message'}))
        self.assertFalse(is_career_message(dict(self.mail,subject='Receipt',body='Your grocery delivery is complete.'), {}))
        self.assertFalse(is_career_message(dict(self.mail,subject='Your job alert',body='New jobs you may like'), {'reason':'opportunity_only'}))


if __name__ == '__main__': unittest.main()
