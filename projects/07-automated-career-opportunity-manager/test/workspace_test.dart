import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careerflow/main.dart';
import 'package:careerflow/data/application_repository.dart';
import 'package:careerflow/data/workspace_repository.dart';
import 'package:careerflow/domain/application.dart';
import 'package:careerflow/ui/workspace_format.dart';

class TestWorkspace extends WorkspaceRepository {
  final demo = DemoApplicationRepository();
  @override
  bool get isDemo => false;
  @override
  List<JobApplication> get applications => demo.applications;
  @override
  Map<String, int> versions = {'demo-1': 1};
  @override
  Map<String, dynamic> connection = {
    'review_count': 1,
    'sync_state': 'healthy',
    'polling_enabled': true,
    'account': 'demo@example.test',
    'last_sync_completed': '2026-10-24T16:30:00Z',
    'label_jobs': {'delivered': 2},
  };
  @override
  List<Map<String, dynamic>> reviewItems = [
    {
      'account': 'demo@example.test',
      'id': 'mail-1',
      'revision': 1,
      'subject': 'Synthetic interview invitation',
      'sender': 'recruiter@example.test',
      'received_at': '2026-10-24T16:30:00Z',
      'body': 'Please confirm your interview availability.',
      'result': {
        'action': 'unmatched_application',
        'classification': {
          'stage': 'interview',
          'evidence': ['interview invitation'],
        },
      },
    },
  ];
  @override
  List<Map<String, dynamic>> tasks = [];
  @override
  List<Map<String, dynamic>> deliveries = [];
  Map<String, dynamic>? decision;
  bool fail = false;
  @override
  Future<void> load({bool Function()? acceptResult}) async {
    loads++;
    if (pendingLoad != null) await pendingLoad!.future;
    if (fail) throw Exception('Unavailable');
    if (acceptResult != null && !acceptResult()) return;
    connection = {...connection, 'review_count': loads + 1};
  }

  int loads = 0;
  Completer<void>? pendingLoad;
  @override
  Future<void> save(JobApplication a) => demo.save(a);
  @override
  Future<void> logout() async {}
  @override
  Future<void> resolveReview(Map<String, dynamic> body) async {
    if (fail) throw Exception('Storage unavailable.');
    decision = body;
    reviewItems = [
      {
        ...reviewItems.first,
        'result': {
          ...reviewItems.first['result'],
          'resolution': {
            'action': body['action'],
            'at': '2026-10-25T00:00:00Z',
          },
        },
      },
    ];
  }

  @override
  Future<void> saveTask(Map<String, dynamic> body) async {
    if (fail) throw Exception('Storage unavailable.');
    tasks = [
      ...tasks.where((t) => t['id'] != body['id']),
      {...body, 'version': (body['version'] as int) + 1},
    ];
  }

  @override
  Future<void> retryDelivery(Map<String, dynamic> body) async {}
}

Future<void> launch(
  WidgetTester tester,
  TestWorkspace repo, {
  Size size = const Size(1440, 1000),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: true,
        textScaler: TextScaler.linear(scale),
      ),
      child: CareerFlowApp(repository: repo),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
}

Future<void> nav(WidgetTester tester, int index) async {
  if (tester.view.physicalSize.width < 1000) {
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
  }
  final target = find.byKey(ValueKey('nav-$index'));
  if (target.evaluate().isEmpty) {
    final scrollable = tester.view.physicalSize.width < 1000
        ? find
              .descendant(
                of: find.byType(Drawer),
                matching: find.byType(Scrollable),
              )
              .first
        : find.byType(Scrollable).first;
    await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.tap(find.byKey(ValueKey('nav-$index')));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Live view refreshes without clicks and pauses for editing', (
    tester,
  ) async {
    final repo = TestWorkspace();
    await launch(tester, repo);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(repo.loads, 1);
    expect(find.text('Review 2 messages'), findsOneWidget);
    await nav(tester, 6);
    await tester.tap(find.text('Add action'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Action title'),
      'Keep my draft',
    );
    await tester.pump(const Duration(seconds: 30));
    expect(repo.loads, 1);
    expect(find.text('Keep my draft'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    repo.fail = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.textContaining('Updates paused.'), findsOneWidget);
    repo.fail = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.textContaining('Updates paused.'), findsNothing);
  });

  testWidgets(
    'Live refresh does not overlap or apply a response over an open editor',
    (tester) async {
      final repo = TestWorkspace()..pendingLoad = Completer<void>();
      await launch(tester, repo);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(repo.loads, 1);
      await nav(tester, 6);
      await tester.tap(find.text('Add action'));
      await tester.pumpAndSettle();
      repo.pendingLoad!.complete();
      await tester.pumpAndSettle();
      expect(repo.connection['review_count'], 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
      expect(repo.loads, 1);
    },
  );

  test('timestamps explicitly convert UTC to Manila', () {
    expect(manilaTime('2026-10-24T16:30:00Z'), '2026-10-25 00:30 Manila');
    expect(manilaTime(null), 'Never');
  });
  testWidgets(
    'Review requires an application, preserves fields on failure and saves link without changing stage',
    (tester) async {
      final repo = TestWorkspace();
      await launch(tester, repo);
      await nav(tester, 5);
      await tap(tester, 'Synthetic interview invitation');
      await tap(tester, 'Save decision');
      expect(find.text('Choose an application.'), findsOneWidget);
      final dropdown = find.byType(DropdownButtonFormField<String>).at(1);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tap(tester, 'Northstar Labs · Software Engineer Intern');
      repo.fail = true;
      await tap(tester, 'Save decision');
      expect(find.textContaining('Storage unavailable'), findsOneWidget);
      expect(repo.decision, isNull);
      repo.fail = false;
      await tap(tester, 'Save decision');
      expect(repo.decision?['application_id'], 'demo-1');
      expect(repo.decision?['stage'], isNull);
      expect(repo.applications.first.stage, HiringStage.interview);
      await tap(tester, 'Resolved');
      expect(find.text('Synthetic interview invitation'), findsOneWidget);
    },
  );
  testWidgets(
    'Action date validation, unknown due date and completion keep stage unchanged',
    (tester) async {
      final repo = TestWorkspace();
      await launch(tester, repo);
      await nav(tester, 6);
      await tap(tester, 'Add action');
      await tap(tester, 'Save action');
      expect(find.text('Enter what needs to be done.'), findsOneWidget);
      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tap(tester, 'Northstar Labs · Software Engineer Intern');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Action title'),
        'Confirm availability',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Due date (optional)'),
        '2026-02-31',
      );
      await tap(tester, 'Save action');
      expect(find.textContaining('Use a valid date'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Due date (optional)'),
        '',
      );
      await tap(tester, 'Save action');
      expect(repo.tasks.single['due_on'], isNull);
      await tap(tester, 'Mark complete');
      expect(repo.tasks.single['status'], 'done');
      expect(repo.applications.first.stage, HiringStage.interview);
      await tap(tester, 'Completed');
      expect(find.text('Confirm availability'), findsOneWidget);
      await tap(tester, 'Reopen action');
      expect(repo.tasks.single['status'], 'open');
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(768, 1024),
    const Size(1440, 1000),
  ]) {
    testWidgets('Review, actions and connections fit $size', (tester) async {
      await launch(tester, TestWorkspace(), size: size);
      for (final index in [5, 6, 3]) {
        await nav(tester, index);
        expect(tester.takeException(), isNull);
      }
      expect(find.textContaining('2026-10-25 00:30 Manila'), findsOneWidget);
      expect(find.text('Gmail sync is up to date'), findsOneWidget);
    });
  }
  testWidgets(
    'Large text and reduced motion preserve navigation and controls',
    (tester) async {
      await launch(
        tester,
        TestWorkspace(),
        size: const Size(375, 812),
        scale: 2,
      );
      for (final index in [5, 6, 3]) {
        await nav(tester, index);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
