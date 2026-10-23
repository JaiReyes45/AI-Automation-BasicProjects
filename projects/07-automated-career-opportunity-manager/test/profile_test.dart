import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careerflow/ui/profile_screen.dart';
import 'package:careerflow/ui/app_theme.dart';

void main() {
  for (final size in [
    const Size(375, 812),
    const Size(844, 390),
    const Size(1440, 1000),
  ]) {
    testWidgets('Profile form fits $size and validates links', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: careerTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your internship profile'), findsOneWidget);
      final field = find.widgetWithText(TextFormField, 'GitHub URL');
      await tester.ensureVisible(field);
      await tester.enterText(field, 'not-a-link');
      final save = find.text('Save profile');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Use a full https:// link.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
