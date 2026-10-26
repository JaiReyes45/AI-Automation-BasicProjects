import unittest
from crm.classifier import classify_live
class ProviderTests(unittest.TestCase):
 def test_submission_footer_does_not_negate_confirmation(self):
  m=dict(account='demo@example.test',id='one',thread_id='one',received_at='2026-10-24T00:00:00Z',sender='notice@jobstreet.com',body='Your application for Programmer / QA Intern was successfully\nsubmitted to Example Labs. You might not always hear from employers.')
  r=classify_live(m);self.assertEqual((r['stage'],r['company'],r['normalized_role']),('submitted','Example Labs','QA Engineer Intern'))
  m['sender']='someone@example.test';self.assertNotEqual(classify_live(m)['stage'],'submitted')
 def test_alert_not_application(self):
  r=classify_live(dict(account='demo@example.test',id='one',received_at='2026-10-24T00:00:00Z',body='Your job alert for Software Intern. Similar jobs you might like.'))
  self.assertEqual(r['reason'],'opportunity_only')

class ExpandedProviderTests(unittest.TestCase):
 def message(self, body, sender='notice@jobstreet.com', subject=''):
  return dict(account='demo@example.test',id='one',thread_id='thread',received_at='2026-10-24T00:00:00Z',sender=sender,subject=subject,body=body)
 def test_extended_roles_and_company_punctuation(self):
  r=classify_live(self.message('Your application for R001 Business Application Intern was successfully submitted to Example, Inc. Philippines. %%tracking%% Your application for R001 Business Application Intern was successfully submitted to Example, Inc. Philippines.'))
  self.assertEqual(r['company'],'Example, Inc. Philippines')
  self.assertEqual(r['normalized_role'],'Business Application Intern')
 def test_unknown_internship_preserves_title(self):
  from crm.classifier import role_label
  r=classify_live(self.message('Your application for Product Innovation Intern was successfully submitted to Example Labs.'))
  self.assertEqual(r['normalized_role'],'Product Innovation Intern')
  self.assertEqual(role_label(r['normalized_role']),'Other Internship')
 def test_sender_lookalike_not_provider(self):
  r=classify_live(self.message('Your application for IT Intern was successfully submitted to Example Labs.',sender='notice@jobstreet.com.evil.test'))
  self.assertIsNone(r['company'])
 def test_conditional_submission_stays_review(self):
  r=classify_live(self.message('If your application for IT Intern was successfully submitted to Example Labs.'))
  self.assertIsNone(r['stage'])
 def test_listing_closed_not_rejection(self):
  r=classify_live(self.message('The IT Intern job you applied for at Example Labs has now expired and is no longer taking applications. Similar jobs you might like.'))
  self.assertEqual(r['reason'],'listing_expired_not_application_closed')
  self.assertIsNone(r['stage'])
 def test_indeed_missing_employer_does_not_create(self):
  from workflow.engine import decide
  m=self.message('Your application has been submitted. Good luck! If you notice an error please contact Indeed.',sender='notice@indeed.com',subject='Indeed Application: AI Engineering Intern')
  r=classify_live(m)
  self.assertEqual(r['stage'],'submitted')
  self.assertEqual(decide(m,r,[])[1],'unmatched_application')
 def test_workday_missing_reference_does_not_duplicate(self):
  from workflow.engine import decide
  m=self.message('Please do not reply. Thank you for applying for the role of Business Application Intern . Please note we retain your details.',sender='noreply@myworkday.com',subject='[Example Labs] Application Received for Business Application Intern')
  r=classify_live(m)
  self.assertEqual(r['company'],'Example Labs')
  self.assertEqual(decide(m,r,[])[1],'unmatched_application')
 def test_shortlist_is_review_not_scheduled_interview(self):
  r=classify_live(self.message('You have been shortlisted for the Business Systems Intern role. We will be in touch to schedule a phone screening.',sender='recruiter@example.test'))
  self.assertEqual(r['stage'],'reviewing')
 def test_wrapped_rejection(self):
  r=classify_live(self.message('We regret to\ninform you that we have chosen not to move forward with your application.',sender='recruiter@example.test'))
  self.assertEqual(r['stage'],'rejected')
 def test_quoted_shortlist_not_current_evidence(self):
  r=classify_live(self.message('A general update.\nOn Monday wrote:\nYou have been shortlisted for the IT Intern role.'))
  self.assertIsNone(r['stage'])
 def test_shared_provider_thread_separates_explicit_applications(self):
  from crm.classifier import decide_live
  app=dict(id='app-one',account='demo@example.test',company='Example One',original_role='IT Intern',role='IT Intern',reference='gmail-thread:thread',threads=['thread'],stage='submitted',last_event='2026-10-23T00:00:00Z')
  m=self.message('Your application for Business Application Intern was successfully submitted to Example Two.')
  self.assertEqual(decide_live(m,classify_live(m),[app])[1],'create')
  m=self.message('Your application for IT Intern was successfully submitted to Example One.')
  self.assertEqual(decide_live(m,classify_live(m),[app])[1],'update')
 def test_ambiguous_shared_thread_followup_never_guessed(self):
  from crm.classifier import decide_live
  apps=[dict(id=str(i),account='demo@example.test',company='Example '+str(i),original_role='IT Intern',role='IT Intern',reference=str(i),threads=['thread'],stage='submitted',last_event='2026-10-23T00:00:00Z') for i in range(2)]
  m=self.message('We invite you to an interview.',sender='recruiter@example.test')
  self.assertEqual(decide_live(m,classify_live(m),apps)[1],'ambiguous_match')
 def test_recommendation_footer_does_not_hide_status_notice(self):
  r=classify_live(self.message('It appears your application is unlikely to progress further. Similar jobs you might like.',subject='Application update'))
  self.assertNotEqual(r['reason'],'opportunity_only')


class IndeedMultipartTests(unittest.TestCase):
 message = ExpandedProviderTests.message
 def confirmed(self):
  m=self.message('Your application has been submitted. Good luck!',sender='indeedapply@indeed.com',subject='Indeed Application: Software Developer Intern')
  m['html_text']='Application submitted Software Developer Intern Example Labs Inc. - City The following items were sent to Example Labs Inc.. Good luck!'
  return m
 def test_html_company_enables_confirmation(self):
  from crm.classifier import decide_live
  m=self.confirmed();r=classify_live(m)
  self.assertEqual(r['company'],'Example Labs Inc.')
  self.assertEqual(r['normalized_role'],'Software Engineer Intern')
  self.assertEqual(decide_live(m,r,[])[1],'create')
 def test_html_requires_matching_title_and_trusted_sender(self):
  for field,value in [('sender','indeed@evil.test'),('html_text','Application submitted IT Intern The following items were sent to Example Labs Inc.. Good luck!')]:
   m=self.confirmed();m[field]=value
   self.assertIsNone(classify_live(m)['company'])
 def test_repeat_matches_but_other_employer_in_shared_thread_splits(self):
  from crm.classifier import decide_live
  m=self.confirmed();r=classify_live(m)
  app=dict(id='existing',account=m['account'],threads=[m['thread_id']],company=r['company'],original_role=r['original_role'],reference=r['reference'],stage='submitted',last_event=m['received_at'])
  self.assertEqual(decide_live(m,r,[app])[1],'update')
  m['html_text']=m['html_text'].replace('Example Labs Inc.','Example Two')
  self.assertEqual(decide_live(m,classify_live(m),[app])[1],'create')
