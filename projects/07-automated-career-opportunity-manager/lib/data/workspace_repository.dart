import 'application_repository.dart';

abstract class WorkspaceRepository extends ApplicationRepository {
  Map<String, dynamic> get connection;
  List<Map<String, dynamic>> get reviewItems;
  List<Map<String, dynamic>> get tasks;
  List<Map<String, dynamic>> get deliveries;
  Map<String, int> get versions;
  Map<String, dynamic> get calendarData => {
    'items': <dynamic>[],
    'connection': <String, dynamic>{},
  };
  List<Map<String, dynamic>> get actionLog => [];
  Map<String, dynamic> get todayData => {
    'needs_response': tasks
        .where((t) => t['status'] == 'open' && t['actor'] != 'employer')
        .toList(),
    'waiting': tasks
        .where((t) => t['status'] == 'open' && t['actor'] == 'employer')
        .toList(),
    'upcoming': calendarData['items'] ?? [],
    'review': reviewItems,
    'handled': tasks.where((t) => t['status'] == 'done').toList(),
    'notifications': [],
    'coverage': <String, dynamic>{},
  };

  Future<void> load({bool Function()? acceptResult});
  Future<void> resolveReview(Map<String, dynamic> body);
  Future<void> saveTask(Map<String, dynamic> body);
  Future<void> retryDelivery(Map<String, dynamic> body);
  Future<void> logout();
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
  }) async => {'items': <Map<String, dynamic>>[]};
}
