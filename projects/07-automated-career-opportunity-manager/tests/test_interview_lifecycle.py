import unittest
from crm.interviews import parse_interview, event_key, free_slots


class InterviewTests(unittest.TestCase):
    def message(self, body):
        return dict(account='me@example.test',id='one',thread_id='thread',sender='HR <hr@example.test>',
                    subject='Interview',body=body,received_at='2026-10-27T08:00:00Z')

    def test_availability_is_not_an_appointment(self):
        p=parse_interview(self.message('Please share your availability for an interview.'))
        self.assertIsNone(p['start']);self.assertEqual(p['state'],'availability_requested')

    def test_explicit_iso_range_is_private_tentative(self):
        p=parse_interview(self.message('Can you attend an interview from 2026-11-02T10:00:00+08:00 to 2026-11-02T10:30:00+08:00?'))
        self.assertEqual(p['state'],'tentative');self.assertEqual(p['start'],'2026-11-02T10:00:00+08:00')

    def test_named_month_and_philippine_timezone(self):
        p=parse_interview(self.message('Your interview is confirmed for November 2, 2026 from 10:00 AM to 10:30 AM PHT.'))
        self.assertEqual(p['state'],'confirmed');self.assertEqual(p['end'],'2026-11-02T10:30:00+08:00')

    def test_fractional_seconds_and_invalid_dates(self):
        p=parse_interview(self.message('Interview 2026-11-02T10:00:00.123456+08:00 to 2026-11-02T10:30:00.123456+08:00'))
        self.assertIsNotNone(p['start'])
        self.assertIsNone(parse_interview(self.message('Interview 2026-19-02T10:00:00Z to 2026-19-02T11:00:00Z'))['start'])

    def test_utc_offset_is_preserved(self):
        p=parse_interview(self.message('Your interview is confirmed for November 2, 2026 from 10:00 AM to 10:30 AM UTC+08:00.'))
        self.assertEqual(p['start'],'2026-11-02T10:00:00+08:00')

    def test_ambiguous_time_or_multiple_options_needs_review(self):
        for body in ['Interview November 2, 2026 at 10:00 AM.',
                     'Interview November 2, 2026 from 10:00 AM to 10:30 AM.',
                     'Interview 2026-11-02T10:00:00+08:00 to 2026-11-02T10:30:00+08:00 or 2026-11-03T10:00:00+08:00 to 2026-11-03T10:30:00+08:00']:
            self.assertIsNone(parse_interview(self.message(body))['start'])

    def test_cancellation_not_negation_or_quoted(self):
        self.assertEqual(parse_interview(self.message('Your interview has been cancelled.'))['state'],'cancelled')
        self.assertNotEqual(parse_interview(self.message('Your interview is not cancelled.'))['state'],'cancelled')
        self.assertNotEqual(parse_interview(self.message('Thank you.\nOn Monday wrote:\nYour interview has been cancelled.'))['state'],'cancelled')

    def test_stable_event_identity_across_messages(self):
        self.assertEqual(event_key(self.message('one'),'app'),event_key(dict(self.message('two'),id='two'),'app'))
        self.assertNotEqual(event_key(self.message('one'),'app'),event_key(self.message('one'),'other-app'))

    def test_free_slots_exclude_overlaps_and_outside_working_hours(self):
        events=[dict(start='2026-11-02T09:00:00+08:00',end='2026-11-02T10:00:00+08:00',status='confirmed')]
        slots=free_slots(events,'2026-11-02',30)
        self.assertTrue(slots);self.assertEqual(slots[0]['start'],'2026-11-02T10:00:00+08:00')
        self.assertLessEqual(len(slots),6)


if __name__ == '__main__': unittest.main()
