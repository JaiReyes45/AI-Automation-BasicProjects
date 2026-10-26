import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careerflow/domain/application.dart';

import 'workspace_test.dart' as support;

class OrganizerWorkspace extends support.TestWorkspace {
  final calls = <String>[];
  @override
  List<JobApplication> get applications => [
    JobApplication(
      id: 'older',
      company: 'Earlier Company',
      role: 'QA Intern',
      source: 'Gmail',
      stage: HiringStage.submitted,
      submittedOn: '2026-10-24',
      jobDescription: 'Automation and regression testing',
      events: [],
    ),
    JobApplication(
      id: 'newer',
      company: 'Later Company',
      role: 'IT Intern',
      source: 'Gmail',
      stage: HiringStage.interview,
      submittedOn: '2026-10-25',
      events: [],
    ),
    JobApplication(
      id: 'unknown',
      company: 'Unknown Date',
      role: 'IT Intern',
      source: 'Manual',
      stage: HiringStage.submitted,
      events: [],
    ),
  ];
  @override
  Map<String, dynamic> get calendarData => {
    'connection': {'connected': true, 'last_sync': '2026-10-26T00:00:00Z'},
    'items': [
      {
        'id': 'event',
        'title': 'Synthetic interview',
        'start': '2026-10-26T01:00:00Z',
        'end': '2026-10-26T02:00:00Z',
        'status': 'confirmed',
        'sync_state': 'synced',
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (path == 'assistant/status') {
      return {'ready': true, 'model': 'test model'};
    }
    if (path == 'assistant/chat') {
      return {
        'answer': 'Here is the matching application.',
        'application_ids': ['older'],
        'proposal': null,
      };
    }
    if (path.startsWith('application-emails/')) {
      return {
        'items': [
          {
            'id': 'email',
            'account': 'synthetic@example.test',
            'subject': 'Application received',
            'sender': 'Recruiting team',
            'reply_to': 'recruiter@example.test',
            'received_at': '2026-10-24T01:00:00Z',
            'body': 'Your application arrived. Original quoted message is also here.',
            'has_more': false,
          },
        ],
      };
    }
    return {'items': <dynamic>[]};
  }
}

void main() {
  testWidgets('Date ordering, description search and inclusive date filter', (
    tester,
  ) async {
    final repo = OrganizerWorkspace();
    await support.launch(tester, repo);
    await support.nav(tester, 1);
    List<String> order() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((w) => w.key.toString())
        .where((k) => k.contains('application-'))
        .toList();
    expect(order().join(','), contains('newer'));
    expect(order()[0], contains('newer'));
    expect(order().last, contains('unknown'));
    await support.tap(tester, 'Newest submitted first');
    expect(order()[0], contains('older'));
    await tester.enterText(find.byType(TextField).first, 'regression');
    await tester.pumpAndSettle();
    expect(order().length, 1);
    expect(order().single, contains('older'));
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await support.tap(tester, 'Submission dates');
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(DateRangePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '10/24/2026');
    await tester.enterText(fields.at(1), '10/24/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(order().length, 1);
    expect(order().single, contains('older'));
  });

  testWidgets('Journey opens the matching stage and actual email content', (
    tester,
  ) async {
    final repo = OrganizerWorkspace();
    await support.launch(tester, repo);
    await tester.ensureVisible(find.byKey(const ValueKey('journey-interview')));
    await tester.tap(find.byKey(const ValueKey('journey-interview')));
    await tester.pumpAndSettle();
    expect(find.text('Later Company'), findsOneWidget);
    expect(find.text('Earlier Company'), findsNothing);
    final row = find.byKey(const ValueKey('application-newer'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await support.tap(tester, 'Read received email');
    expect(
      find.text(
        'Your application arrived. Original quoted message is also here.',
      ),
      findsOneWidget,
    );
    expect(repo.calls, contains('application-emails/newer'));
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'Calendar, assistant and profile menu fit $size at large text',
      (tester) async {
        final repo = OrganizerWorkspace();
        await support.launch(tester, repo, size: size, scale: 2);
        expect(tester.takeException(), isNull);
        await support.nav(tester, 7);
        expect(
          find.textContaining('Google Calendar connected'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await support.nav(tester, 8);
        expect(find.text('Local assistant ready · test model'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Profile menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit personal information'));
        await tester.pumpAndSettle();
        expect(find.text('Documents'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
