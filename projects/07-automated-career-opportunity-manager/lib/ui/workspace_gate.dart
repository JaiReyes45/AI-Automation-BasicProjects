import 'package:flutter/material.dart';

import '../data/persistent_repository.dart';
import 'app_shell.dart';

class WorkspaceGate extends StatefulWidget {
  const WorkspaceGate({super.key});
  @override
  State<WorkspaceGate> createState() => _WorkspaceGateState();
}

class _WorkspaceGateState extends State<WorkspaceGate> {
  final repo = PersistentApplicationRepository();
  final password = TextEditingController();
  bool busy = true, ready = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> load({bool login = false}) async {
    setState(() => busy = true);
    try {
      if (login) {
        await repo.login(password.text);
      } else {
        await repo.load();
      }
      if (mounted) setState(() => ready = true);
      password.clear();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = login
              ? 'Unable to sign in. Check the password and Docker services.'
              : 'Sign in to open your saved applications.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) {
      return AppShell(
        repository: repo,
        onLogout: () async {
          try {
            await repo.logout();
            if (mounted) {
              setState(() {
                ready = false;
                error = 'Signed out.';
              });
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not sign out. Check Docker and retry.'),
                ),
              );
            }
          }
        },
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Open your workspace',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in to your personal internship workspace with your CareerFlow password.',
                ),
                const SizedBox(height: 24),
                if (busy)
                  const LinearProgressIndicator()
                else ...[
                  TextField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Workspace password',
                    ),
                    onSubmitted: (_) => load(login: true),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => load(login: true),
                    child: const Text('Sign in'),
                  ),
                  TextButton(
                    onPressed: () => load(),
                    child: const Text('Retry connection'),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(error!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
