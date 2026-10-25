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
  Future<void> load() async {
    final results = await Future.wait([
      for (final path in [
        'applications',
        'status',
        'review',
        'tasks',
        'deliveries',
      ])
        profileRequest('GET', '/api/crm/$path', ''),
    ]);
    accept(results[0]);
    connection = jsonDecode(results[1]);
    List<Map<String, dynamic>> items(String raw) =>
        (jsonDecode(raw)['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    reviewItems = items(results[2]);
    tasks = items(results[3]);
    deliveries = items(results[4]);
  }

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
        'version': versions[a.id] ?? 0,
      }),
    ),
  );
}
