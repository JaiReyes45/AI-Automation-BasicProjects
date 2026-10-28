import 'package:flutter_test/flutter_test.dart';

import 'workspace_test.dart' as support;

class FollowThroughWorkspace extends support.TestWorkspace {
  final commands = <Map<String, dynamic>>[];
  FollowThroughWorkspace() {
    tasks = [
      {
        'id': 'unmatched-request',
        'version': 1,
        'application_id': null,
        'title': 'Send interview availability',
        'category': 'interview',
        'status': 'open',
        'actor': 'user',
        'request_kind': 'availability',
        'source_account': 'demo@example.test',
        'source_message_id': 'mail-1',
        'evidence': ['Could you share your availability next week?'],
        'due_on': null,
        'deadline_origin': 'none',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) commands.add({'path': path, ...body});
    if (path == 'notifications') {
      return {
        'items': [
          {
            'id': 'notice-1',
            'title': 'Availability requested',
            'body': 'Employer awaits a response',
            'state': 'failed',
            'attempts': 2,
            'error': 'Windows helper offline',
          },
        ],
        'devices': [],
        'local_uptime_required': true,
      };
    }
    if (path == 'notifications/pairing') {
      return {'code': 'TEST-PAIR', 'expires_at': '2026-10-28T00:00:00Z'};
    }
    return super.call(path, body: body);
  }
}

void main() {
  testWidgets(
    'Today keeps unmatched requests actionable without invented deadlines',
    (tester) async {
      final repo = FollowThroughWorkspace();
      await support.launch(tester, repo);
      expect(find.text('Needs your response'), findsOneWidget);
      expect(find.text('Send interview availability'), findsOneWidget);
      expect(find.text('Application not matched'), findsOneWidget);
      expect(
        find.text('Could you share your availability next week?'),
        findsOneWidget,
      );
      expect(find.text('No deadline stated'), findsOneWidget);
      await support.tap(tester, 'Review matching email');
      expect(find.text('Review message'), findsOneWidget);
      expect(find.text('Synthetic interview invitation'), findsOneWidget);
    },
  );

  testWidgets(
    'Completing an unmatched request preserves source and removes it from Today response queue',
    (tester) async {
      final repo = FollowThroughWorkspace();
      await support.launch(tester, repo);
      await support.tap(tester, 'Mark complete');
      expect(repo.tasks.single['status'], 'done');
      expect(repo.tasks.single['source_message_id'], 'mail-1');
      expect(
        find.text('No open requests in the captured messages.'),
        findsOneWidget,
      );
      expect(repo.applications.first.stage.name, 'interview');
    },
  );

  testWidgets('Notification failures remain visible and retry is explicit', (
    tester,
  ) async {
    final repo = FollowThroughWorkspace();
    await support.launch(tester, repo);
    await support.nav(tester, 3);
    expect(find.text('Desktop notifications'), findsOneWidget);
    expect(find.textContaining('Windows helper offline'), findsOneWidget);
    await support.tap(tester, 'Retry alert');
    expect(repo.commands, contains(containsPair('action', 'retry')));
    await support.tap(tester, 'Set up Windows alerts');
    expect(find.text('TEST-PAIR'), findsOneWidget);
    expect(find.textContaining('Docker'), findsWidgets);
  });
}
