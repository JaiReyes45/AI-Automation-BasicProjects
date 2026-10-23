import 'package:flutter/material.dart';

import 'data/application_repository.dart';
import 'ui/app_shell.dart';
import 'ui/app_theme.dart';

void main() => runApp(CareerFlowApp(repository: DemoApplicationRepository()));

class CareerFlowApp extends StatelessWidget {
  const CareerFlowApp({super.key, required this.repository});
  final ApplicationRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CareerFlow',
    debugShowCheckedModeBanner: false,
    theme: careerTheme(),
    home: AppShell(repository: repository),
  );
}
