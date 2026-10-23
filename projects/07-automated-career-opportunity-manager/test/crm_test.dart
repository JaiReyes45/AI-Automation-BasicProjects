import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careerflow/main.dart';
import 'package:careerflow/data/application_repository.dart';
import 'package:careerflow/domain/application.dart';

void main() {
  Future<void> start(
    WidgetTester tester,
    DemoApplicationRepository repo, {
    Size size = const Size(1440, 1100),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(CareerFlowApp(repository: repo));
    if (size.width < 1000) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets(
    'Create, validate, filter, edit stage and preserve another role',
    (tester) async {
      final repo = DemoApplicationRepository();
      await start(tester, repo);
      await tapText(tester, 'Add application');
      await tapText(tester, 'Save application');
      expect(find.text('Enter company.'), findsOneWidget);
      expect(repo.applications.length, 5);
      await tester.enterText(field('Company'), 'Northstar Labs');
      await tester.enterText(field('Role title'), 'Design Intern');
      await tester.enterText(field('Next action (optional)'), 'Send portfolio');
      await tapText(tester, 'Save application');
      expect(repo.applications.length, 6);
      final id = repo.applications.first.id;
      expect(find.text('History'), findsOneWidget);
      await tapText(tester, 'Edit application');
      await tester.tap(find.byType(DropdownButtonFormField<HiringStage>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Interview');
      await tapText(tester, 'Save application');
      expect(repo.applications.first.id, id);
      expect(repo.applications.first.stage, HiringStage.interview);
      expect(repo.applications.first.nextAction, 'Send portfolio');
      expect(repo.applications.first.events.length, 2);
      expect(
        repo.applications.firstWhere((a) => a.id == 'demo-4').stage,
        HiringStage.submitted,
      );
      await tapText(tester, 'Edit application');
      await tester.enterText(field('Next action (optional)'), '');
      await tapText(tester, 'Save application');
      expect(repo.applications.first.stage, HiringStage.interview);
      expect(repo.applications.first.nextAction, isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'design');
      await tester.pumpAndSettle();
      expect(find.text('1 of 6 applications'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no matching company');
      await tester.pumpAndSettle();
      expect(find.textContaining('No applications match'), findsOneWidget);
      await tapText(tester, 'Clear filters');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'QA Engineer Intern');
      expect(find.text('2 of 6 applications'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<HiringStage>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Submitted');
      expect(find.text('1 of 6 applications'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(DemoApplicationRepository().applications.length, 5);
    },
  );

  for (final size in [const Size(390, 844), const Size(1000, 500)]) {
    testWidgets('Edit cancellation and forms fit $size', (tester) async {
      final repo = DemoApplicationRepository();
      await start(tester, repo, size: size);
      final target = find.byKey(const ValueKey('application-demo-1'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tapText(tester, 'Edit application');
      await tester.enterText(field('Company'), 'Unsaved company');
      await tapText(tester, 'Cancel');
      expect(repo.applications.first.company, 'Northstar Labs');
      expect(find.text('Northstar Labs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
