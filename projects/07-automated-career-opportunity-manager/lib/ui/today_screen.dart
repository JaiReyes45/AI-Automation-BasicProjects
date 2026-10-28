import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'application_workspace.dart';
import 'workspace_format.dart';
import 'workspace_screens.dart';

List<Map<String, dynamic>> workspaceItems(dynamic value) =>
    (value is List ? value : const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

String taskDeadline(Map task) {
  if (task['due_at'] != null) return 'Due ${manilaTime(task['due_at'])}';
  if (task['due_on'] != null) {
    return 'Due ${calendarDate(task['due_on'].toString())} · Manila';
  }
  return 'No deadline stated';
}

String schedulingLabel(Map event) {
  final state = event['scheduling_state'] ?? event['status'];
  return switch (state) {
    'tentative' => 'Tentative · awaiting confirmation',
    'confirmed' => 'Confirmed',
    'cancelled' => 'Cancelled',
    'proposal' || 'proposed' => 'Proposed time · needs review',
    'request' || 'requested' => 'Availability requested',
    _ => 'Confirmation not recorded',
  };
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.repository,
    required this.onChanged,
    required this.onNavigate,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final data = repository.todayData;
    final needs = workspaceItems(data['needs_response']);
    final waiting = workspaceItems(data['waiting']);
    final upcoming = workspaceItems(data['upcoming'])
        .where(
          (e) =>
              e['scheduling_state'] != 'cancelled' &&
              e['status'] != 'cancelled',
        )
        .toList();
    final handled = workspaceItems(data['handled']);
    final coverage = Map<String, dynamic>.from(data['coverage'] as Map? ?? {});
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
    Widget taskList(
      List<Map<String, dynamic>> tasks,
      String empty, {
      bool completed = false,
    }) => Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tasks.isEmpty) Text(empty),
          for (final task in tasks) ...[
            if (task != tasks.first) const Divider(height: 32),
            WorkspaceTask(
              repository: repository,
              task: task,
              onChanged: onChanged,
              completed: completed,
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Today', style: Theme.of(context).textTheme.headlineLarge),
            Text(
              '${calendarDate(manilaToday())} · Manila',
              style: const TextStyle(color: muted),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ApplicationRecord(repository: repository),
                  ),
                );
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Quick capture'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Employer requests, interview times and your next response.',
        ),
        title('Needs your response'),
        taskList(needs, 'No open requests in the captured messages.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => onNavigate(5),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text(
                'Review ${repository.connection['review_count'] ?? workspaceItems(data['review']).length} messages',
              ),
            ),
            TextButton(
              onPressed: () => onNavigate(6),
              child: const Text('View all actions'),
            ),
          ],
        ),
        title('Upcoming interviews'),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (upcoming.isEmpty)
                const Text(
                  'No upcoming times captured. Availability requests stay in your response list until a time is agreed.',
                ),
              for (final event in upcoming.take(8)) ...[
                if (event != upcoming.first) const Divider(height: 28),
                Text(
                  event['title']?.toString() ?? 'Interview',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (event['start'] != null) Text(manilaTime(event['start'])),
                Text(schedulingLabel(event)),
                Text(
                  'Calendar sync: ${event['sync_state'] ?? 'unknown'}',
                  style: const TextStyle(color: muted),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => onNavigate(7),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Open interview calendar'),
              ),
            ],
          ),
        ),
        title('Waiting on employer'),
        taskList(
          waiting,
          'No requests currently marked as waiting on an employer.',
        ),
        title('Recently handled'),
        taskList(
          handled.take(8).toList(),
          'Completed requests and recent actions will appear here.',
          completed: true,
        ),
        title('Capture coverage'),
        CoverageSummary(coverage: coverage),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => onNavigate(3),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Manage capture and desktop alerts'),
        ),
      ],
    );
  }
}

class WorkspaceTask extends StatefulWidget {
  const WorkspaceTask({
    super.key,
    required this.repository,
    required this.task,
    required this.onChanged,
    this.completed = false,
  });
  final WorkspaceRepository repository;
  final Map<String, dynamic> task;
  final VoidCallback onChanged;
  final bool completed;
  @override
  State<WorkspaceTask> createState() => _WorkspaceTaskState();
}

class _WorkspaceTaskState extends State<WorkspaceTask> {
  bool busy = false;
  String? error;
  Future<void> complete() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.saveTask({...widget.task, 'status': 'done'});
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final app = widget.repository.applications
        .where((a) => a.id == t['application_id'])
        .firstOrNull;
    final source = widget.repository.reviewItems
        .where(
          (r) =>
              r['id'] == t['source_message_id'] &&
              r['account'] == t['source_account'],
        )
        .firstOrNull;
    final evidence = t['evidence'] is List
        ? (t['evidence'] as List).map((e) => e.toString()).join('\n')
        : t['evidence']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t['title']?.toString() ?? t['kind']?.toString() ?? 'Recorded action',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          app == null
              ? 'Application not matched'
              : '${app.company} · ${app.role}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          widget.completed
              ? 'Handled · ${t['status'] ?? t['state'] ?? 'recorded'}'
              : '${t['actor'] == 'employer' ? 'Employer to respond' : 'Your response needed'} · ${categories[t['category']] ?? t['request_kind'] ?? 'Action'}',
          style: const TextStyle(color: muted),
        ),
        if (!widget.completed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(taskDeadline(t)),
          ),
        if (evidence.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(evidence),
          ),
        if (error != null) errorNotice(error!),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (!widget.completed && t['id'] != null)
              OutlinedButton.icon(
                onPressed: busy ? null : complete,
                icon: const Icon(Icons.check_rounded),
                label: Text(busy ? 'Saving…' : 'Mark complete'),
              ),
            if (app != null)
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ApplicationRecord(
                        repository: widget.repository,
                        applicationId: app.id,
                      ),
                    ),
                  );
                  widget.onChanged();
                },
                child: const Text('Open application'),
              ),
            if (source != null)
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewRecord(
                        repository: widget.repository,
                        item: source,
                      ),
                    ),
                  );
                  widget.onChanged();
                },
                child: const Text('Review matching email'),
              ),
            if (t['source_message_id'] != null && t['source_account'] != null)
              TextButton.icon(
                onPressed: () => openDocument(
                  'https://mail.google.com/mail/u/?authuser=${Uri.encodeComponent(t['source_account'].toString())}#all/${Uri.encodeComponent(t['source_message_id'].toString())}',
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open source email'),
              ),
          ],
        ),
      ],
    );
  }
}

class CoverageSummary extends StatelessWidget {
  const CoverageSummary({super.key, required this.coverage});
  final Map<String, dynamic> coverage;
  @override
  Widget build(BuildContext context) {
    final from = coverage['complete_from'];
    final through = coverage['complete_through'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          from != null && through != null
              ? 'Captured interval: ${manilaTime(from)} to ${manilaTime(through)}'
              : 'Complete capture interval has not been verified.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (coverage['account'] != null) Text(coverage['account'].toString()),
        if (coverage['status'] != null)
          Text('Capture status: ${coverage['status']}'),
        if (coverage['last_completed_at'] != null)
          Text(
            'Last completed capture: ${manilaTime(coverage['last_completed_at'])}',
          ),
        if (coverage['last_error'] != null)
          Text(
            coverage['last_error'].toString(),
            style: const TextStyle(color: Color(0xFF9B302E)),
          ),
        const SizedBox(height: 8),
        const Text(
          'This workspace can only report captured records. Applications without an email need quick capture. Your computer, Docker and the Windows helper must stay running for desktop alerts.',
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}

class ApplicationFollowThrough extends StatelessWidget {
  const ApplicationFollowThrough({
    super.key,
    required this.repository,
    required this.applicationId,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final String applicationId;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final tasks = repository.tasks
        .where((t) => t['application_id'] == applicationId)
        .toList();
    final events = workspaceItems(repository.calendarData['items'])
        .where((e) => e['application_id'] == applicationId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requests and follow-through',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Text('No requests linked to this application.'),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: WorkspaceTask(
              repository: repository,
              task: task,
              onChanged: onChanged,
              completed: task['status'] == 'done',
            ),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TaskRecord(
                  repository: repository,
                  applicationId: applicationId,
                ),
              ),
            );
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add linked action'),
        ),
        const SizedBox(height: 24),
        Text(
          'Interview scheduling',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text(
            'No interview times linked yet. A request for availability does not confirm an appointment.',
          ),
        for (final event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title']?.toString() ?? 'Interview',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (event['start'] != null) Text(manilaTime(event['start'])),
                Text(schedulingLabel(event)),
                Text('Calendar sync: ${event['sync_state'] ?? 'unknown'}'),
                if (event['error'] != null) Text(event['error'].toString()),
                if (event['html_link'] != null)
                  TextButton(
                    onPressed: () =>
                        openDocument(event['html_link'].toString()),
                    child: const Text('Open in Google Calendar'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
