import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careerflow/main.dart';
import 'package:careerflow/data/application_repository.dart';

void main() {
  testWidgets('Desktop navigation exposes honest connection state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CareerFlowApp(repository: DemoApplicationRepository()),
    );
    expect(find.text('Application pipeline'), findsOneWidget);
    expect(find.textContaining('Fictional applications only'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Your applications'), findsOneWidget);
    expect(find.text('Northstar Labs'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Interview invitation received'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Last synchronization: Never'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 800),
    const Size(768, 900),
    const Size(1024, 768),
    const Size(1440, 1000),
    const Size(1000, 500),
  ]) {
    testWidgets('Shell fits viewport $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        CareerFlowApp(repository: DemoApplicationRepository()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width < 1000) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(
          find.text('No emails have been read or labeled.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
