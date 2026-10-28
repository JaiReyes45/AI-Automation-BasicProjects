import 'dart:convert';

import '../domain/application.dart';
import 'workspace_repository.dart';
import 'profile_stub.dart' if (dart.library.js_interop) 'profile_web.dart';

class PersistentApplicationRepository extends WorkspaceRepository {
  List<JobApplication> _apps = [];
  @override
  final versions = <String, int>{};
  @override
  Map<String, dynamic> connection = {};
  @override
  List<Map<String, dynamic>> reviewItems = [], tasks = [], deliveries = [];
  @override
  bool get isDemo => false;
  @override
  Map<String, dynamic> calendarData = {
    'items': <dynamic>[],
    'connection': <String, dynamic>{},
  };
  @override
  List<Map<String, dynamic>> actionLog = [];
  @override
  Map<String, dynamic> todayData = {};

  @override
  List<JobApplication> get applications => List.unmodifiable(_apps);
  void accept(String raw) {
    final rows = jsonDecode(raw)['applications'] as List;
    _apps = rows.map((a) {
      versions[a['id']] = a['version'];
      return JobApplication(
        id: a['id'],
        company: a['company'],
        role: a['role'],
        source: a['source'] ?? 'Gmail',
        stage: HiringStage.values.firstWhere((s) => s.name == a['stage']),
        nextAction: a['nextAction'],
        submittedOn: a['submitted_on'],
        jobDescription: a['job_description'] ?? '',
        captureState: a['capture_state'] ?? 'applied',
        sourceUrl: a['source_url'] ?? '',
        events: (a['events'] as List)
            .map(
              (e) =>
                  ApplicationEvent(e['description'], DateTime.parse(e['date'])),
            )
            .toList(),
      );
    }).toList();
  }

  @override
  Future<void> load({bool Function()? acceptResult}) async {
    final results = await Future.wait([
      for (final path in [
        'applications',
        'status',
        'review',
        'tasks',
        'deliveries',
        'calendar',
        'actions',
        'today',
      ])
        profileRequest('GET', '/api/crm/$path', ''),
    ]);
    if (acceptResult != null && !acceptResult()) return;
    accept(results[0]);
    connection = jsonDecode(results[1]);
    List<Map<String, dynamic>> items(String raw) =>
        (jsonDecode(raw)['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    reviewItems = items(results[2]);
    tasks = items(results[3]);
    deliveries = items(results[4]);
    calendarData = Map<String, dynamic>.from(jsonDecode(results[5]));
    actionLog = items(results[6]);
    todayData = Map<String, dynamic>.from(jsonDecode(results[7]));
  }

  @override
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
  }) async => Map<String, dynamic>.from(
    jsonDecode(
      await profileRequest(
        body == null ? 'GET' : 'POST',
        '/api/crm/$path',
        body == null ? '' : jsonEncode(body),
      ),
    ),
  );

  Future<void> mutate(String path, Map<String, dynamic> body) async {
    await profileRequest('POST', '/api/crm/$path', jsonEncode(body));
    await load();
  }

  @override
  Future<void> resolveReview(Map<String, dynamic> body) =>
      mutate('review/resolve', body);
  @override
  Future<void> saveTask(Map<String, dynamic> body) => mutate('tasks', body);
  @override
  Future<void> retryDelivery(Map<String, dynamic> body) =>
      mutate('deliveries/retry', body);
  @override
  Future<void> logout() async {
    await profileRequest('POST', '/api/crm/logout', '{}');
    _apps = [];
    versions.clear();
    reviewItems = [];
    tasks = [];
    deliveries = [];
    connection = {};
    todayData = {};
    calendarData = {'items': <dynamic>[], 'connection': <String, dynamic>{}};
    actionLog = [];
  }

  Future<void> login(String password) async {
    await profileRequest(
      'POST',
      '/api/crm/login',
      jsonEncode({'password': password}),
    );
    await load();
  }

  @override
  Future<void> save(JobApplication a) async => accept(
    await profileRequest(
      'POST',
      '/api/crm/applications',
      jsonEncode({
        'id': a.id,
        'company': a.company,
        'role': a.role,
        'source': a.source,
        'stage': a.stage.name,
        'nextAction': a.nextAction,
        'submitted_on': a.submittedOn,
        'job_description': a.jobDescription,
        'capture_state': a.captureState,
        'source_url': a.sourceUrl,
        'version': versions[a.id] ?? 0,
      }),
    ),
  );
}
