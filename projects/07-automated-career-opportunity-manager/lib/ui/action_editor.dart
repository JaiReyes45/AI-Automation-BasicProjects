import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../domain/application.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'workspace_format.dart';

Future<void> openAction(
  BuildContext context,
  WorkspaceRepository repo,
  Map<String, dynamic> initial,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ActionEditor(repository: repo, initial: initial),
  ),
);

class ActionEditor extends StatefulWidget {
  const ActionEditor({
    super.key,
    required this.repository,
    required this.initial,
  });
  final WorkspaceRepository repository;
  final Map<String, dynamic> initial;
  @override
  State<ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<ActionEditor> {
  final fields = <String, TextEditingController>{};
  String? appId;
  String stage = 'submitted';
  bool busy = false, confirmed = false;
  String? error, outcome;
  Map<String, dynamic>? preview;
  String get kind => widget.initial['kind'] as String;
  @override
  void initState() {
    super.initState();
    appId = widget.initial['application_id'];
    final matches = widget.repository.applications.where((a) => a.id == appId);
    final app = matches.isEmpty ? null : matches.first;
    stage = widget.initial['stage'] ?? app?.stage.name ?? 'submitted';
    for (final key in [
      'nextAction',
      'to',
      'subject',
      'body',
      'title',
      'start',
      'end',
      'location',
      'description',
      'attendees',
    ]) {
      var value = widget.initial[key];
      if (key == 'nextAction' && !widget.initial.containsKey(key)) {
        value = app?.nextAction;
      }
      if (value is List) value = value.join(', ');
      if ((key == 'start' || key == 'end') &&
          value is String &&
          value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          value = parsed
              .toUtc()
              .add(const Duration(hours: 8))
              .toIso8601String()
              .substring(0, 16);
        }
      }
      fields[key] = TextEditingController(text: value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit({bool commit = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (commit) {
        final result = await widget.repository.call(
          'actions/confirm',
          body: {'id': preview!['id']},
        );
        if (mounted) {
          setState(() {
            confirmed = true;
            outcome = result['state'] == 'completed'
                ? 'Application updated.'
                : kind == 'reply'
                ? 'Reply queued. Check delivery below before sending another.'
                : 'Meeting saved and queued for Google Calendar.';
          });
        }
        // The action is already confirmed even if the following refresh fails.
        // Never offer a second send because a read failed afterward.
        try {
          await widget.repository.load();
        } catch (_) {
          if (mounted) {
            setState(
              () => error = 'Action confirmed. Refresh the workspace to check its delivery status.',
            );
          }
        }
      } else {
        final payload = <String, dynamic>{
          ...widget.initial,
          'kind': kind,
          'application_id': appId,
          'stage': stage,
          for (final entry in fields.entries)
            entry.key: entry.value.text.trim(),
        };
        if (kind == 'meeting') {
          for (final key in ['start', 'end']) {
            final value = fields[key]!.text.trim();
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(value)) {
              throw Exception(
                'Enter start/end as YYYY-MM-DDTHH:MM in Manila time.',
              );
            }
            payload[key] = '$value:00+08:00';
          }
          payload['attendees'] = fields['attendees']!.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        final result = await widget.repository.call(
          'actions/preview',
          body: payload,
        );
        if (mounted) setState(() => preview = result);
      }
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(String key, String label, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: fields[key],
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = preview?['data'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          kind == 'reply'
              ? 'Compose a reply'
              : kind == 'meeting'
              ? 'Plan an interview'
              : 'Review application changes',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (confirmed) ...[
                  const Icon(Icons.check_circle_rounded, color: teal, size: 48),
                  const SizedBox(height: 16),
                  Text(outcome!, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ] else if (data != null) ...[
                  Text(
                    'Check before confirming',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['company']} · ${data['role']}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(height: 32),
                        if (kind == 'edit') ...[
                          Text(
                            'Stage: ${data['previous_stage']} → ${data['stage']}',
                          ),
                          Text('Next action: ${data['nextAction'] ?? 'None'}'),
                        ],
                        if (kind == 'reply') ...[
                          Text('To: ${data['to']}'),
                          Text('Subject: ${data['subject']}'),
                          const SizedBox(height: 16),
                          SelectableText(data['body']),
                        ],
                        if (kind == 'meeting') ...[
                          Text(data['title']),
                          Text('Start: ${manilaTime(data['start'])}'),
                          Text('End: ${manilaTime(data['end'])}'),
                          Text('Location: ${data['location']}'),
                          Text(
                            'Invite: ${(data['attendees'] as List).isEmpty ? 'No guests (personal calendar only)' : (data['attendees'] as List).join(', ')}',
                          ),
                          const SizedBox(height: 12),
                          Text(data['description']),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    kind == 'reply'
                        ? 'Confirming sends this email through your connected Gmail account.'
                        : kind == 'meeting'
                        ? 'Confirming creates a Google Calendar event and emails invitations to the guests listed above.'
                        : 'Confirming saves these application changes.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : () => submit(commit: true),
                        child: Text(
                          busy
                              ? 'Working…'
                              : kind == 'reply'
                              ? 'Confirm and send reply'
                              : kind == 'meeting'
                              ? 'Confirm meeting'
                              : 'Confirm changes',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => preview = null),
                        child: const Text('Back to editing'),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Nothing is sent or changed until you review the preview and confirm.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: appId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Application'),
                    items: [
                      for (final app in widget.repository.applications)
                        DropdownMenuItem(
                          value: app.id,
                          child: Text(
                            '${app.company} · ${app.role}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => appId = v),
                  ),
                  const SizedBox(height: 20),
                  if (kind == 'edit') ...[
                    DropdownButtonFormField<String>(
                      initialValue: stage,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hiring stage',
                      ),
                      items: [
                        for (final s in HiringStage.values)
                          DropdownMenuItem(value: s.name, child: Text(s.label)),
                      ],
                      onChanged: (v) => setState(() => stage = v!),
                    ),
                    const SizedBox(height: 16),
                    input('nextAction', 'Next action'),
                  ],
                  if (kind == 'reply') ...[
                    input('to', 'Recipient email'),
                    input('subject', 'Subject'),
                    input('body', 'Your reply', lines: 10),
                  ],
                  if (kind == 'meeting') ...[
                    input('title', 'Meeting title'),
                    input('start', 'Start in Manila (YYYY-MM-DDTHH:MM)'),
                    input('end', 'End in Manila (YYYY-MM-DDTHH:MM)'),
                    input('location', 'Location or meeting URL'),
                    input(
                      'attendees',
                      'Guest emails, separated by commas (optional)',
                    ),
                    input('description', 'Notes', lines: 4),
                  ],
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : () => submit(),
                        child: Text(busy ? 'Checking…' : 'Review preview'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
