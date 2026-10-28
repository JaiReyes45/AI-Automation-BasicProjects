import unittest
from crm.retrieval import retrieve, operational_answer


class RetrievalTests(unittest.TestCase):
    def test_search_reaches_record_beyond_context_window(self):
        apps=[dict(id=str(i), company='Ordinary', role='Intern') for i in range(100)]
        apps.append(dict(id='psb',company='PSB',role='QA Intern'))
        data=retrieve('Find PSB',apps,[],[],[])
        self.assertEqual(data['applications'][0]['id'],'psb')
        self.assertEqual(data['completeness']['total'],101)
        self.assertTrue(data['completeness']['limited'])

    def test_tasks_have_citable_evidence_even_without_application(self):
        task=dict(id='t',application_id=None,title='Share availability',status='open',actor='user',evidence=['Please share availability'],source_message_id='m',source_account='me@example.test')
        data=retrieve('What needs my response?',[],[task],[],[])
        answer=operational_answer('What needs my response?',data)
        self.assertIn('Share availability',answer['answer'])
        self.assertEqual(answer['sources'][0]['message_id'],'m')

    def test_saved_opportunities_are_not_submitted_applications(self):
        apps=[dict(id='a',company='A',role='IT',capture_state='saved'),dict(id='b',company='B',role='IT',capture_state='applied')]
        answer=operational_answer('How many applications?',retrieve('How many applications?',apps,[],[],[]))
        self.assertIn('1 application',answer['answer'])
        self.assertIn('1 saved',answer['answer'])

    def test_selected_email_rank_and_bounded_evidence(self):
        mail=[dict(id='m',account='me',application_id='a',body='Interview '*1000,subject='Interview')]
        data=retrieve('Draft a reply', [dict(id='a',company='A',role='IT')],[],mail,[],selected='a')
        self.assertLessEqual(len(data['emails'][0]['body']),2000)
        self.assertIsNone(operational_answer('Draft a reply',data))


if __name__=='__main__': unittest.main()
