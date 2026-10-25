import 'package:flutter/material.dart';

import 'data/application_repository.dart';
import 'ui/app_shell.dart';
import 'ui/app_theme.dart';
import 'ui/workspace_gate.dart';

void main() => runApp(
  MaterialApp(
    title: 'CareerFlow',
    debugShowCheckedModeBanner: false,
    theme: careerTheme(),
    home: const WorkspaceGate(),
  ),
);

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
