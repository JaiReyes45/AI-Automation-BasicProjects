import '../domain/application.dart';

/// Shared application interface; DemoApplicationRepository is for previews only.
abstract class ApplicationRepository {
  List<JobApplication> get applications;
  bool get isDemo;
  Future<void> save(JobApplication application);
}

class DemoApplicationRepository implements ApplicationRepository {
  @override
  bool get isDemo => true;
  @override
  List<JobApplication> get applications => List.unmodifiable(_applications);

  @override
  Future<void> save(JobApplication application) async {
    final index = _applications.indexWhere((a) => a.id == application.id);
    if (index < 0) {
      _applications.insert(0, application);
    } else {
      _applications[index] = application;
    }
  }

  final List<JobApplication> _applications = [
    JobApplication(
      id: 'demo-1',
      company: 'Northstar Labs',
      role: 'Software Engineer Intern',
      source: 'Indeed',
      stage: HiringStage.interview,
      nextAction: 'Confirm interview availability',
      events: [
        ApplicationEvent(
          'Interview invitation received',
          DateTime(2026, 10, 22),
        ),
      ],
    ),
    JobApplication(
      id: 'demo-2',
      company: 'Orbit Systems',
      role: 'QA Engineer Intern',
      source: 'JobStreet',
      stage: HiringStage.assessment,
      nextAction: 'Complete technical assessment',
      events: [
        ApplicationEvent('Assessment requested', DateTime(2026, 10, 21)),
      ],
    ),
    JobApplication(
      id: 'demo-3',
      company: 'Cedar Digital',
      role: 'IT Intern',
      source: 'LinkedIn',
      stage: HiringStage.reviewing,
      events: [
        ApplicationEvent('Application is under review', DateTime(2026, 10, 21)),
      ],
    ),
    JobApplication(
      id: 'demo-4',
      company: 'Northstar Labs',
      role: 'QA Engineer Intern',
      source: 'Indeed',
      stage: HiringStage.submitted,
      events: [
        ApplicationEvent('Application received', DateTime(2026, 10, 20)),
      ],
    ),
    JobApplication(
      id: 'demo-5',
      company: 'Forma Studio',
      role: 'Software Engineer Intern',
      source: 'Direct employer',
      stage: HiringStage.information,
      nextAction: 'Share portfolio link',
      events: [ApplicationEvent('Portfolio requested', DateTime(2026, 10, 20))],
    ),
  ];
}
