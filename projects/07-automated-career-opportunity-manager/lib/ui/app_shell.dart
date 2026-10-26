import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/application_repository.dart';
import 'app_theme.dart';
import 'application_workspace.dart';
import 'profile_screen.dart';
import '../data/workspace_repository.dart';
import 'workspace_screens.dart';
import 'workspace_format.dart';
import 'calendar_screen.dart';
import 'assistant_screen.dart';
import 'application_journey.dart';
import '../domain/application.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';

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
  String? refreshError, avatarUrl;
  String profileName = '';
  bool profileEditing = false;
  HiringStage? journeyStage;

  Future<void> loadProfileHeader() async {
    try {
      final data = jsonDecode(await profileRequest('GET', '/api/profile', ''));
      if (mounted) {
        setState(() {
          profileName = data['profile']['name'] ?? '';
          avatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {
      /* A profile outage must not hide the CRM. */
    }
  }

  Widget profileMenu() => PopupMenuButton<String>(
    tooltip: 'Profile menu',
    onSelected: (value) {
      if (value == 'logout') {
        widget.onLogout?.call();
        return;
      }
      setState(() {
        selected = 4;
        profileEditing = value == 'edit';
      });
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'view', child: Text('View profile')),
      const PopupMenuItem(
        value: 'edit',
        child: Text('Edit personal information'),
      ),
      if (widget.onLogout != null)
        const PopupMenuItem(value: 'logout', child: Text('Sign out')),
    ],
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE0EDE4),
            backgroundImage: avatarUrl == null
                ? null
                : NetworkImage(avatarUrl!),
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, color: teal)
                : null,
          ),
          if (MediaQuery.sizeOf(context).width >= 1000) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                profileName.isEmpty ? 'Your profile' : profileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const Icon(Icons.expand_more_rounded, size: 20),
        ],
      ),
    ),
  );

  bool get canAutoRefresh =>
      mounted &&
      foreground &&
      selected != 4 &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadProfileHeader();
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
    'Calendar',
    'Assistant',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.work_outline_rounded,
    Icons.history_rounded,
    Icons.hub_outlined,
    Icons.person_outline,
    Icons.mark_email_unread_outlined,
    Icons.checklist_outlined,
    Icons.calendar_month_rounded,
    Icons.chat_bubble_outline_rounded,
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
              actions: [profileMenu()],
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
                      if (wide) profileMenu(),
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
                            const SizedBox(height: 8),
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
          for (final i in [0, 1, 5, 6, 7, 8, 2, 3])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: ValueKey('nav-$i'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: selected == i
                        ? const Color(0xFFB2CFBE)
                        : Colors.transparent,
                    width: 2,
                  ),
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
                  setState(() {
                    selected = i;
                    journeyStage = null;
                  });
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
      case 7:
        return [
          widget.repository is WorkspaceRepository
              ? CalendarScreen(
                  repository: widget.repository as WorkspaceRepository,
                  onChanged: () => setState(() {}),
                )
              : const Text('Sign in to use the calendar.'),
        ];
      case 8:
        return [
          widget.repository is WorkspaceRepository
              ? AssistantScreen(
                  repository: widget.repository as WorkspaceRepository,
                  onChanged: () => setState(() {}),
                )
              : const Text('Sign in to use your local assistant.'),
        ];
      case 4:
        return [
          ProfileScreen(
            key: ValueKey(profileEditing),
            initialEdit: profileEditing,
            onSaved: loadProfileHeader,
          ),
        ];
      case 1:
        return [
          ApplicationWorkspace(
            key: ValueKey(journeyStage),
            initialStage: journeyStage,
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
        return [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE4EFE3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFB6CEB5), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your next chapter starts here.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${apps.length} applications. One place to keep moving forward.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.repository is WorkspaceRepository)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => selected = 5),
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: Text(
                          'Review ${(widget.repository as WorkspaceRepository).connection['review_count'] ?? 0} messages',
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => selected = 7),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Interview calendar'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => selected = 6),
                      child: const Text('View actions'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ApplicationJourney(
            applications: apps,
            onStage: (stage) => setState(() {
              journeyStage = stage;
              selected = 1;
            }),
          ),
          const SizedBox(height: 28),
          ApplicationWorkspace(
            repository: widget.repository,
            onChanged: () => setState(() {}),
            title: 'Application pipeline',
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
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border, width: 2),
      boxShadow: const [BoxShadow(color: border, offset: Offset(0, 4))],
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
