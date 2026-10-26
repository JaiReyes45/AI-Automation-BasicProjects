import 'dart:async';

import 'package:flutter/material.dart';

import '../data/application_repository.dart';
import '../domain/application.dart';
import 'app_theme.dart';
import 'application_workspace.dart';
import 'profile_screen.dart';
import '../data/workspace_repository.dart';
import 'workspace_screens.dart';
import 'workspace_format.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository, this.onLogout});
  final VoidCallback? onLogout;
  final ApplicationRepository repository;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int selected = 0;
  bool refreshing = false;
  Timer? refreshTimer;
  bool foreground = true;
  String? refreshError;

  bool get canAutoRefresh =>
      mounted &&
      foreground &&
      selected != 4 &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository is WorkspaceRepository) {
      refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (canAutoRefresh) refreshWorkspace();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (canAutoRefresh) refreshWorkspace();
  }

  Future<void> refreshWorkspace() async {
    if (refreshing || widget.repository is! WorkspaceRepository) return;
    setState(() => refreshing = true);
    try {
      await (widget.repository as WorkspaceRepository).load(
        acceptResult: () => canAutoRefresh,
      );
      if (mounted) setState(() => refreshError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => refreshError =
              'Updates paused. Check Docker or reload to sign in again.',
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static const titles = [
    'Overview',
    'Applications',
    'Activity',
    'Connections',
    'Profile',
    'Review inbox',
    'Actions',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.work_outline_rounded,
    Icons.history_rounded,
    Icons.hub_outlined,
    Icons.person_outline,
    Icons.mark_email_unread_outlined,
    Icons.checklist_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text('CareerFlow'),
              backgroundColor: Colors.white,
            ),
      drawer: wide ? null : Drawer(child: navigation(isDrawer: true)),
      body: Row(
        children: [
          if (wide) SizedBox(width: 238, child: navigation()),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 36 : 20,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Workspace / ${titles[selected]}',
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                      if (wide)
                        const BadgePill(
                          'Personal workspace',
                          Color(0xFFEBF1EC),
                          ink,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(selected),
                    padding: EdgeInsets.all(wide ? 36 : 20),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1250),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.repository.isDemo && selected != 4)
                              const DemoNotice(),
                            const SizedBox(height: 28),
                            if (widget.repository is WorkspaceRepository)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: refreshing
                                      ? null
                                      : refreshWorkspace,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                    refreshing
                                        ? 'Refreshing…'
                                        : 'Refresh workspace',
                                  ),
                                ),
                              ),
                            if (widget.repository is WorkspaceRepository)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  refreshError ?? 'Live view · refreshes every 30 seconds. Gmail checks every 5 minutes while Docker is running.',
                                  style: TextStyle(
                                    color: refreshError == null
                                        ? muted
                                        : Colors.red.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ...page(context),
                            const SizedBox(height: 32),
                            Text(
                              widget.repository.isDemo
                                  ? 'Application preview · Changes reset on refresh'
                                  : 'Applications saved locally in PostgreSQL',
                              style: TextStyle(color: muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget navigation({bool isDrawer = false}) => Material(
    color: Colors.white,
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: ink,
                foregroundColor: Colors.white,
                child: Icon(Icons.alt_route_rounded),
              ),
              SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CareerFlow',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          for (int i = 0; i < titles.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: ValueKey('nav-$i'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                selected: selected == i,
                selectedTileColor: const Color(0xFFE7EEEB),
                selectedColor: teal,
                leading: Icon(icons[i], size: 21),
                title: Text(
                  titles[i],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  setState(() => selected = i);
                  if (isDrawer) Navigator.pop(context);
                },
              ),
            ),
          const SizedBox(height: 48),
          TextButton.icon(
            onPressed: () {
              setState(() => selected = 3);
              if (isDrawer) Navigator.pop(context);
            },
            icon: const Icon(Icons.mail_outline, size: 18),
            label: Text(
              widget.repository is WorkspaceRepository &&
                      (widget.repository as WorkspaceRepository)
                              .connection['gmail_connected'] ==
                          true
                  ? 'Gmail authorized'
                  : 'Gmail not connected',
            ),
          ),
          if (widget.onLogout != null)
            TextButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          const SizedBox(height: 20),
          const Text(
            'Local workspace',
            style: TextStyle(fontSize: 10, color: muted, letterSpacing: 1.3),
          ),
        ],
      ),
    ),
  );

  List<Widget> page(BuildContext context) {
    final apps = widget.repository.applications;
    switch (selected) {
      case 5:
        return [
          widget.repository is WorkspaceRepository
              ? ReviewScreen(
                  repository: widget.repository as WorkspaceRepository,
                  onChanged: () => setState(() {}),
                )
              : const Text(
                  'Sign in to your saved workspace to review imported emails.',
                ),
        ];
      case 6:
        return [
          widget.repository is WorkspaceRepository
              ? ActionsScreen(
                  repository: widget.repository as WorkspaceRepository,
                  onChanged: () => setState(() {}),
                )
              : const Text(
                  'Sign in to your saved workspace to manage dated actions.',
                ),
        ];
      case 4:
        return [const ProfileScreen()];
      case 1:
        return [
          ApplicationWorkspace(
            repository: widget.repository,
            onChanged: () => setState(() {}),
          ),
        ];
      case 2:
        final items =
            apps.expand((a) => a.events.map((e) => (app: a, event: e))).toList()
              ..sort((a, b) => b.event.date.compareTo(a.event.date));
        return [
          heading(
            context,
            'Activity',
            'Application history, most recent first.',
          ),
          const SizedBox(height: 24),
          Surface(
            child: Column(
              children: [
                if (items.isEmpty) const Text('No activity yet.'),
                for (final item in items)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE7EEEB),
                      child: Icon(Icons.history, color: teal),
                    ),
                    title: Text(item.event.description),
                    subtitle: Text(
                      '${item.app.company} · ${item.app.role}\n${manilaTime(item.event.date.toIso8601String())}${widget.repository.isDemo ? ' · Sample event' : ''}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ),
        ];
      case 3:
        return [
          widget.repository is WorkspaceRepository
              ? ConnectionScreen(
                  repository: widget.repository as WorkspaceRepository,
                  onChanged: () => setState(() {}),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading(
                      context,
                      'Connections',
                      'Email access and local application storage.',
                    ),
                    const SizedBox(height: 24),
                    const Text('Gmail not connected'),
                    const Text('No emails have been read or labeled.'),
                    const Text('Last synchronization: Never'),
                  ],
                ),
        ];
      default:
        final actions = apps.where((a) => a.nextAction != null).toList();
        return [
          heading(
            context,
            'Application overview',
            'Track employer updates and what you need to do next.',
          ),
          const SizedBox(height: 26),
          Text(
            '${apps.length} applications · ${actions.length} have next-action notes',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          if (widget.repository is WorkspaceRepository)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => selected = 5),
                  child: Text(
                    'Review ${(widget.repository as WorkspaceRepository).connection['review_count'] ?? 0} messages',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => selected = 6),
                  child: const Text('View actions'),
                ),
              ],
            ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final main = applicationPanel(apps);
              final side = Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next-action notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage due dates and completed tasks in Actions.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 18),
                    if (actions.isEmpty)
                      const Text('Nothing needs your attention yet.'),
                    for (final a in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.arrow_circle_right_outlined,
                                size: 20,
                                color: teal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.nextAction!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    a.company,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'About these stages',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Stages reflect employer updates. They do not represent a probability of being hired.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              );
              if (constraints.maxWidth < 850) {
                return Column(
                  children: [main, const SizedBox(height: 20), side],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: main),
                  const SizedBox(width: 20),
                  Expanded(flex: 3, child: side),
                ],
              );
            },
          ),
        ];
    }
  }

  Widget heading(BuildContext context, String title, String description) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: muted)),
        ],
      );

  Widget applicationPanel(List<JobApplication> apps) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Application pipeline',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Company, role, and current stage',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 18),
        if (apps.isEmpty) const Text('No applications yet.'),
        for (int i = 0; i < apps.length; i++) ...[
          if (i > 0) const Divider(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final a = apps[i];
              final info = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF1E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a.company.isEmpty ? '?' : a.company[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.company,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          a.role,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.source,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final badge = BadgePill(
                a.stage.label,
                a.stage == HiringStage.interview
                    ? const Color(0xFFE1F0E7)
                    : const Color(0xFFF0F1F6),
                a.stage == HiringStage.interview
                    ? teal
                    : const Color(0xFF626580),
              );
              if (constraints.maxWidth < 470) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [info, const SizedBox(height: 10), badge],
                );
              }
              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class BadgePill extends StatelessWidget {
  const BadgePill(this.label, this.background, this.foreground, {super.key});
  final String label;
  final Color background;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F0EC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 19, color: teal),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Sample workspace · Fictional applications only. Refreshing resets changes. Gmail is not connected.',
            style: TextStyle(fontSize: 12, color: ink),
          ),
        ),
      ],
    ),
  );
}
