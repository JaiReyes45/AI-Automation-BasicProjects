"""Synthetic request and reply evidence checks; no mailbox or network access."""
import importlib.util
import unittest

HAS_MODULE = importlib.util.find_spec('crm.engagement') is not None
if HAS_MODULE:
    from crm import engagement


def message(body, **extra):
    return dict(account='candidate@example.test', id='incoming-1', thread_id='thread-1',
                received_at='2026-10-27T08:00:00+00:00', sender='Recruiter <hr@example.test>',
                subject='Next steps', body=body, direction='received', rfc_message_id='<one@example.test>', **extra)


class EngagementTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HAS_MODULE, 'The evidence-backed engagement module must exist')

    def test_unmatched_availability_has_literal_evidence_and_no_invented_deadline(self):
        tasks = engagement.extract_requests(message('Could you share your availability for a short call?'), {})
        self.assertEqual(len(tasks), 1)
        task = tasks[0]
        self.assertEqual((task['request_kind'], task['category'], task['actor']), ('availability', 'reply', 'user'))
        self.assertIsNone(task['application_id'])
        self.assertEqual(task['evidence'], ['Could you share your availability for a short call?'])
        self.assertEqual((task['due_on'], task['due_at'], task['deadline_origin']), (None, None, 'none'))

    def test_request_does_not_depend_on_uncertain_stage_classifier(self):
        result = engagement.extract_requests(message('Please send your updated resume.'),
            {'classification': {'reason': 'uncertain_language'}, 'application_id': 'app-1'})
        self.assertEqual(result[0]['request_kind'], 'documents')
        self.assertEqual(result[0]['application_id'], 'app-1')

    def test_distinct_requests_and_explicit_deadline(self):
        result = engagement.extract_requests(message('Please share your availability. Please complete the coding assessment by 2026-10-30T17:00:00+08:00.'), {})
        self.assertEqual([r['request_kind'] for r in result], ['availability', 'assessment'])
        self.assertIsNone(result[0]['due_at'])
        self.assertEqual(result[1]['due_at'], '2026-10-30T17:00:00+08:00')
        self.assertEqual(result[1]['due_on'], '2026-10-30')

    def test_explicit_date_without_timezone_does_not_invent_time(self):
        task = engagement.extract_requests(message('Please send your portfolio by 2026-10-29.'), {})[0]
        self.assertEqual(task['due_on'], '2026-10-29')
        self.assertIsNone(task['due_at'])
        self.assertEqual(task['deadline_origin'], 'explicit')

    def test_negated_quoted_and_job_alert_requests_are_ignored(self):
        bodies = ['Please do not send your resume.', 'No need to share your availability.',
                  'We are not inviting you to an interview.', 'If selected, please complete the assessment.',
                  'Thanks for the update.\nOn Monday Recruiter wrote:\nPlease share your availability.',
                  'Your job alert: recommended vacancies. Please send your resume.']
        for body in bodies:
            with self.subTest(body=body):
                self.assertEqual(engagement.extract_requests(message(body), {}), [])

    def test_negation_in_different_sentence_does_not_hide_request(self):
        result = engagement.extract_requests(message('Do not send any documents. Please share your availability.'), {})
        self.assertEqual([r['request_kind'] for r in result], ['availability'])

    def test_plain_quote_boundary_wins_over_legacy_flattened_html(self):
        email=message('Thank you.\nOn Monday Recruiter wrote:\nPlease share your availability.',html_text='Thank you. On Monday Recruiter wrote: Please share your availability.')
        self.assertEqual(engagement.extract_requests(email,{}),[])

    def test_interview_invitation_and_offer_generate_review_tasks(self):
        for body, kind in [('We would like to invite you to an interview.', 'interview'),
                           ('We are pleased to offer you the position of QA Intern.', 'offer')]:
            with self.subTest(kind=kind):
                self.assertEqual(engagement.extract_requests(message(body), {})[0]['request_kind'], kind)

    def test_event_identity_is_stable_across_reclassification(self):
        first = engagement.extract_requests(message('Please share your availability.'), {})[0]
        second = engagement.extract_requests(message('Please share your availability.'), {'application_id': 'linked'})[0]
        self.assertEqual(first['id'], second['id'])
        different = message('Please share your availability.')
        different['account'] = 'other@example.test'
        self.assertNotEqual(first['id'], engagement.extract_requests(different, {})[0]['id'])

    def test_sent_reply_requires_response_content_and_exact_source(self):
        source = message('Please share your availability. Please complete the assessment.')
        tasks = engagement.extract_requests(source, {'application_id': 'app-1'})
        sent = message('I am available on Friday at 2pm.')
        sent.update(id='sent-1', direction='sent', received_at='2026-10-27T09:00:00+00:00', in_reply_to='<one@example.test>')
        resolved = engagement.reply_completions(sent, [(task, source) for task in tasks], ['app-1'])
        self.assertEqual(resolved, [tasks[0]['id']])
        sent['body'] = 'Thank you for your message.'
        self.assertEqual(engagement.reply_completions(sent, [(task, source) for task in tasks], ['app-1']), [])

    def test_thread_fallback_requires_unique_application_and_latest_request(self):
        source = message('Please share your availability.')
        task = engagement.extract_requests(source, {'application_id': 'app-1'})[0]
        sent = message('I am available on Friday.')
        sent.update(id='sent', direction='sent', received_at='2026-10-27T09:00:00+00:00')
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1', 'app-2']), [])
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1']), [task['id']])
        sent['in_reply_to'] = '<unrelated@example.test>'
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1']), [])

    def test_older_sent_message_and_corrected_task_are_never_completed(self):
        source = message('Please send your resume.')
        task = engagement.extract_requests(source, {'application_id': 'app-1'})[0]
        sent = message('Please find attached my resume.')
        sent.update(direction='sent', received_at='2026-10-27T07:00:00+00:00', in_reply_to='<one@example.test>')
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1']), [])
        sent['received_at'] = '2026-10-27T10:00:00+00:00'
        task['corrected'] = True
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1']), [])

    def test_reply_about_another_action_cannot_complete_assessment_or_interview(self):
        source = message('Please complete the assessment. We invite you to an interview.')
        tasks = engagement.extract_requests(source, {'application_id': 'app-1'})
        for body in ['I completed my resume. I confirm receipt of your message.',
                     'I have not completed the assessment.', 'I cannot attend the interview.']:
            sent = message(body)
            sent.update(direction='sent', received_at='2026-10-27T10:00:00+00:00', in_reply_to='<one@example.test>')
            self.assertEqual(engagement.reply_completions(sent, [(task, source) for task in tasks], ['app-1']), [])

    def test_waiting_task_finishes_only_on_a_newer_employer_reply(self):
        source = message('I am available Friday.')
        source.update(direction='sent', rfc_message_id='<sent@example.test>')
        task = dict(id='waiting-1', status='open', actor='employer', request_kind='employer_reply', application_id='app-1')
        reply = message('Thank you, we will call you on Friday.')
        reply.update(received_at='2026-10-27T10:00:00+00:00', in_reply_to='<sent@example.test>')
        self.assertEqual(engagement.reply_completions(reply, [(task, source)], ['app-1']), ['waiting-1'])

    def test_natural_date_has_explicit_year_and_keeps_date_only_precision(self):
        task = engagement.extract_requests(message('Please submit your resume by October 30, 2026.'), {})[0]
        self.assertEqual((task['due_on'], task['due_at']), ('2026-10-30', None))

    def test_user_ignored_request_does_not_reappear_on_replay(self):
        for action in ('ignore', 'opportunity'):
            self.assertEqual(engagement.extract_requests(message('Please share your availability.'),
                {'resolution': {'action': action}}), [])

    def test_negative_attachment_claim_does_not_complete_documents(self):
        source = message('Please send your resume.')
        task = engagement.extract_requests(source, {'application_id': 'app-1'})[0]
        sent = message('I have not attached my resume yet.')
        sent.update(direction='sent', received_at='2026-10-27T10:00:00+00:00', in_reply_to='<one@example.test>')
        self.assertEqual(engagement.reply_completions(sent, [(task, source)], ['app-1']), [])


if __name__ == '__main__':
    unittest.main()
