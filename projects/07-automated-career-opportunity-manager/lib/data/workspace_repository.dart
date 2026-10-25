import 'application_repository.dart';

abstract class WorkspaceRepository extends ApplicationRepository {
  Map<String, dynamic> get connection;
  List<Map<String, dynamic>> get reviewItems;
  List<Map<String, dynamic>> get tasks;
  List<Map<String, dynamic>> get deliveries;
  Map<String, int> get versions;
  Future<void> load();
  Future<void> resolveReview(Map<String, dynamic> body);
  Future<void> saveTask(Map<String, dynamic> body);
  Future<void> retryDelivery(Map<String, dynamic> body);
  Future<void> logout();
}
