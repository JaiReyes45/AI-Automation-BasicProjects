import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';
import '../domain/application.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'workspace_format.dart';

const categories = {
  'reply': 'Reply needed',
  'assessment': 'Assessment',
  'interview': 'Interview scheduling',
  'followup': 'Follow-up',
  'other': 'Other',
};
const reasons = {
  'unmatched_application': 'The application could not be identified.',
  'ambiguous_match': 'More than one application could match.',
  'identity_conflict':
      'The company or role differs from the existing application.',
  'unrecognized_message': 'No supported application update was found.',
  'uncertain_language': 'The wording does not confirm a stage change.',
  'conflicting_signals': 'The email contains conflicting stage signals.',
  'stale_event': 'This email predates the current application stage.',
  'stage_regression':
      'This would move the application back to an earlier stage.',
  'closed_application': 'This application is already closed.',
  'listing_expired_not_application_closed':
      'The listing expired. That does not mean your application was rejected.',
  'opportunity_only': 'This is a job opportunity, not a confirmed application.',
};
Widget errorNotice(String message) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Semantics(
    liveRegion: true,
    child: Text(message, style: const TextStyle(color: Color(0xFF9B302E))),
  ),
);

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String filter = 'pending';
  Future<void> open(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewRecord(repository: widget.repository, item: item),
      ),
    );
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.repository.reviewItems.where((m) {
      final r = m['result'] as Map;
      if (filter == 'resolved') return r['resolution'] != null;
      return r['resolution'] == null &&
          (filter == 'opportunities'
              ? r['action'] == 'opportunity_only'
              : r['action'] != 'opportunity_only');
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review inbox', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Check the evidence before linking an email or changing an application.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in {
              'pending': 'Needs review',
              'opportunities': 'Opportunities',
              'resolved': 'Resolved',
            }.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: filter == e.key,
                onSelected: (_) => setState(() => filter = e.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('${items.length} messages', style: const TextStyle(color: muted)),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nothing in this view. Imported messages that need a decision will appear here.',
                  ),
                ),
              for (final item in items) ...[
                if (item != items.first) const Divider(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item['subject'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['sender']),
                        const SizedBox(height: 4),
                        Text(
                          manilaTime(item['received_at']),
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['result']['resolution'] != null
                              ? 'Resolved: ${item['result']['resolution']['action']}'
                              : reasons[item['result']['action']] ??
                                    'A decision is needed.',
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(item),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ReviewRecord extends StatefulWidget {
  const ReviewRecord({super.key, required this.repository, required this.item});
  final WorkspaceRepository repository;
  final Map<String, dynamic> item;
  @override
  State<ReviewRecord> createState() => _ReviewRecordState();
}

class _ReviewRecordState extends State<ReviewRecord> {
  final form = GlobalKey<FormState>();
  late final TextEditingController company, role;
  final note = TextEditingController();
  String action = 'link', stage = '';
  String? applicationId, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final c = widget.item['result']['classification'] as Map? ?? {};
    company = TextEditingController(text: c['company'] ?? '');
    role = TextEditingController(
      text: c['original_role'] ?? c['normalized_role'] ?? '',
    );
    if (widget.repository.applications.isEmpty) action = 'create';
  }

  @override
  void dispose() {
    company.dispose();
    role.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.resolveReview({
        'account': widget.item['account'],
        'id': widget.item['id'],
        'revision': widget.item['revision'],
        'action': action,
        'application_id': applicationId,
        'application_version': widget.repository.versions[applicationId],
        'company': company.text.trim(),
        'role': role.text.trim(),
        'stage': (action == 'link' || action == 'create') && stage.isNotEmpty
            ? stage
            : null,
        'note': note.text.trim(),
      });
      if (!mounted) return;
      setState(() => busy = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Decision saved. Gmail labels will reconcile automatically.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = actionError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final resolved = item['result']['resolution'];
    final c = item['result']['classification'] as Map? ?? {};
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Review message')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['subject'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(item['sender']),
                  Text(
                    manilaTime(item['received_at']),
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 20),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reasons[item['result']['action']] ??
                              'Review the message and choose a destination.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (c['stage'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Detected signal: ${c['stage']}. Confirm it against the message.',
                          ),
                        ],
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Read email evidence'),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(item['body']),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => openDocument(
                            'https://mail.google.com/mail/u/?authuser=${Uri.encodeComponent(item['account'])}#all/${Uri.encodeComponent(item['id'])}',
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open original in Gmail'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (resolved != null)
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resolved: ${resolved['action']}'),
                          Text(manilaTime(resolved['at'])),
                          if ((resolved['note'] ?? '').isNotEmpty)
                            Text(resolved['note']),
                          const SizedBox(height: 12),
                          const Text(
                            'The decision is kept in audit history. Correct a linked application from Applications.',
                          ),
                        ],
                      ),
                    )
                  else
                    Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: action,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Decision',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'link',
                                child: Text('Link to an existing application'),
                              ),
                              DropdownMenuItem(
                                value: 'create',
                                child: Text('Create a confirmed application'),
                              ),
                              DropdownMenuItem(
                                value: 'opportunity',
                                child: Text('Keep as a job opportunity'),
                              ),
                              DropdownMenuItem(
                                value: 'ignore',
                                child: Text('Dismiss from the review queue'),
                              ),
                            ],
                            onChanged: busy
                                ? null
                                : (v) => setState(() {
                                    action = v!;
                                    stage = '';
                                  }),
                          ),
                          const SizedBox(height: 20),
                          if (action == 'link') ...[
                            DropdownButtonFormField<String>(
                              initialValue: applicationId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Application',
                              ),
                              items: [
                                for (final a in widget.repository.applications)
                                  DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      '${a.company} · ${a.role}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => applicationId = v),
                              validator: (v) =>
                                  v == null ? 'Choose an application.' : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (action == 'create') ...[
                            TextFormField(
                              controller: company,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Company',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter the employer shown in the email.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: role,
                              maxLength: 300,
                              decoration: const InputDecoration(
                                labelText: 'Role title',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter the role shown in the email.'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (action == 'link' || action == 'create') ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey(action),
                              initialValue: stage,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Hiring stage',
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    action == 'link'
                                        ? 'Keep the current stage'
                                        : 'Choose the confirmed stage',
                                  ),
                                ),
                                for (final s in HiringStage.values)
                                  DropdownMenuItem(
                                    value: s.name,
                                    child: Text(s.label),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => stage = v!),
                              validator: (v) =>
                                  action == 'create' && (v == null || v.isEmpty)
                                  ? 'Choose the stage confirmed by the email.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Older emails can be linked without changing the stage. A shared conversation may contain several applications.',
                              style: TextStyle(color: muted),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (action == 'ignore')
                            const Padding(
                              padding: EdgeInsets.only(bottom: 20),
                              child: Text(
                                'This keeps the email and local evidence. CareerFlow labels will be cleared; unrelated Gmail labels stay unchanged.',
                              ),
                            ),
                          TextFormField(
                            controller: note,
                            maxLength: 1000,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Decision note (optional)',
                            ),
                          ),
                          if (error != null) errorNotice(error!),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed: busy ? null : save,
                                child: Text(busy ? 'Saving…' : 'Save decision'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionsScreen extends StatefulWidget {
  const ActionsScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  String filter = 'open', category = 'all';
  String? error, busyId;
  Future<void> edit([Map<String, dynamic>? item, String? applicationId]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskRecord(
          repository: widget.repository,
          item: item,
          applicationId: applicationId,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> toggle(Map<String, dynamic> item) async {
    setState(() {
      busyId = item['id'];
      error = null;
    });
    try {
      await widget.repository.saveTask({
        ...item,
        'status': item['status'] == 'done' ? 'open' : 'done',
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final items =
        repo.tasks
            .where(
              (t) =>
                  t['status'] == filter &&
                  (category == 'all' || t['category'] == category),
            )
            .toList()
          ..sort(
            (a, b) => (a['due_on'] ?? '9999').toString().compareTo(
              (b['due_on'] ?? '9999').toString(),
            ),
          );
    final suggestions = repo.applications.where((a) {
      if ([
            HiringStage.hired,
            HiringStage.rejected,
            HiringStage.withdrawn,
            HiringStage.closed,
          ].contains(a.stage) ||
          a.events.isEmpty) {
        return false;
      }
      final last = a.events
          .map((e) => e.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return DateTime.now().toUtc().difference(last.toUtc()).inDays >= 7 &&
          !repo.tasks.any(
            (t) => t['application_id'] == a.id && t['status'] == 'open',
          );
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Track replies, assessments and follow-ups. Completing a task does not change the hiring stage.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: repo.applications.isEmpty ? null : () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add action'),
            ),
            ChoiceChip(
              label: const Text('Open'),
              selected: filter == 'open',
              onSelected: (_) => setState(() => filter = 'open'),
            ),
            ChoiceChip(
              label: const Text('Completed'),
              selected: filter == 'done',
              onSelected: (_) => setState(() => filter = 'done'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in {'all': 'All types', ...categories}.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: category == e.key,
                onSelected: (_) => setState(() => category = e.key),
              ),
          ],
        ),
        if (error != null) errorNotice(error!),
        const SizedBox(height: 20),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No actions in this view. Add a reply, deadline or follow-up to track.',
                  ),
                ),
              for (final t in items) ...[
                if (t != items.first) const Divider(height: 28),
                Text(
                  t['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  repo.applications
                          .where((a) => a.id == t['application_id'])
                          .map((a) => '${a.company} · ${a.role}')
                          .firstOrNull ??
                      'Application',
                ),
                const SizedBox(height: 8),
                Text(
                  '${categories[t['category']]} · ${t['due_on'] == null ? 'No deadline specified' : 'Due ${t['due_on']} (Manila)'}',
                  style: const TextStyle(color: muted),
                ),
                if (t['status'] == 'open' &&
                    t['due_on'] != null &&
                    t['due_on'].toString().compareTo(manilaToday()) < 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Overdue',
                      style: TextStyle(
                        color: Color(0xFF9B302E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busyId != null ? null : () => toggle(t),
                      icon: Icon(
                        t['status'] == 'done' ? Icons.undo : Icons.check,
                      ),
                      label: Text(
                        busyId == t['id']
                            ? 'Saving…'
                            : t['status'] == 'done'
                            ? 'Reopen action'
                            : 'Mark complete',
                      ),
                    ),
                    TextButton(
                      onPressed: busyId != null ? null : () => edit(t),
                      child: const Text('Edit action'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (filter == 'open' && suggestions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Consider a follow-up',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'No recorded activity for at least seven days. Silence is not a rejection; decide whether a follow-up is appropriate.',
          ),
          const SizedBox(height: 12),
          for (final a in suggestions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a.company),
              subtitle: Text(a.role),
              trailing: TextButton(
                onPressed: () => edit(null, a.id),
                child: const Text('Plan follow-up'),
              ),
            ),
        ],
      ],
    );
  }
}

class TaskRecord extends StatefulWidget {
  const TaskRecord({
    super.key,
    required this.repository,
    this.item,
    this.applicationId,
  });
  final WorkspaceRepository repository;
  final Map<String, dynamic>? item;
  final String? applicationId;
  @override
  State<TaskRecord> createState() => _TaskRecordState();
}

class _TaskRecordState extends State<TaskRecord> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, due;
  late final String taskId;
  String category = 'other';
  String? applicationId, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    taskId =
        widget.item?['id'] ?? 'task-${DateTime.now().microsecondsSinceEpoch}';
    title = TextEditingController(
      text:
          widget.item?['title'] ??
          (widget.applicationId != null ? 'Follow up on application' : ''),
    );
    due = TextEditingController(text: widget.item?['due_on'] ?? '');
    category =
        widget.item?['category'] ??
        (widget.applicationId != null ? 'followup' : 'other');
    applicationId = widget.item?['application_id'] ?? widget.applicationId;
  }

  @override
  void dispose() {
    title.dispose();
    due.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.saveTask({
        'id': taskId,
        'application_id': applicationId,
        'title': title.text.trim(),
        'category': category,
        'status': widget.item?['status'] ?? 'open',
        'due_on': due.text.trim().isEmpty ? null : due.text.trim(),
        'version': widget.item?['version'] ?? 0,
      });
      if (mounted) {
        setState(() => busy = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = actionError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add action' : 'Edit action'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use a date only when you know it or deliberately plan a follow-up. All due dates use Manila time.',
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: applicationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Application'),
                    items: [
                      for (final a in widget.repository.applications)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.company} · ${a.role}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => applicationId = v),
                    validator: (v) =>
                        v == null ? 'Choose an application.' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: title,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Action title',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter what needs to be done.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final e in categories.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => category = v!),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: due,
                    decoration: const InputDecoration(
                      labelText: 'Due date (optional)',
                      hintText: 'YYYY-MM-DD · Manila',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final d = DateTime.tryParse(v.trim());
                      return d != null &&
                              RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                  .hasMatch(v.trim()) &&
                              d.toIso8601String().startsWith(v.trim())
                          ? null
                          : 'Use a valid date in YYYY-MM-DD format.';
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final parsed = DateTime.tryParse(due.text);
                            final initial =
                                parsed != null &&
                                    parsed.year >= 2020 &&
                                    parsed.year < 2100
                                ? parsed
                                : DateTime.parse(manilaToday());
                            final selected = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: initial,
                            );
                            if (selected != null) {
                              due.text = selected.toIso8601String().substring(
                                0,
                                10,
                              );
                            }
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Choose a date'),
                  ),
                  if (error != null) errorNotice(error!),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: busy ? null : save,
                        child: Text(busy ? 'Saving…' : 'Save action'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  bool busy = false;
  String? error;
  Future<void> retry(Map<String, dynamic> job) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.retryDelivery({
        'id': job['id'],
        'generation': job['generation'],
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.repository.connection;
    final labels = status['label_jobs'] as Map? ?? {};
    final active = status['polling_enabled'] == true;
    final healthy = status['sync_state'] == 'healthy';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connections', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'See what has synced and recover failed Gmail label updates.',
        ),
        const SizedBox(height: 24),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !active
                    ? 'Automatic sync paused'
                    : healthy
                    ? 'Gmail sync is up to date'
                    : 'Gmail sync needs attention',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(status['account'] ?? 'No Gmail account connected'),
              const SizedBox(height: 16),
              Text(
                'Last completed import: ${manilaTime(status['last_sync_completed'])}',
              ),
              const SizedBox(height: 8),
              Text(
                'Last label check: ${manilaTime(status['last_label_check'])}',
              ),
              const SizedBox(height: 12),
              Text(
                '${labels['delivered'] ?? 0} delivered · ${labels['pending'] ?? 0} pending · ${labels['failed'] ?? 0} failed · ${labels['expired'] ?? 0} outside the date window',
              ),
              const SizedBox(height: 12),
              Text(
                active
                    ? 'Runs every five minutes while Docker and n8n are running. Reads matching incoming career emails from the last seven days.'
                    : 'Open n8n to configure or publish workflows 06 and 07.',
              ),
              if (!healthy) ...[
                const SizedBox(height: 12),
                const Text(
                  'If updates stop, check Docker and reconnect the Gmail credential in n8n if it has expired. Refresh this workspace afterward.',
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => openDocument('http://localhost:5678/'),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open local n8n'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Label recovery', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'A retry keeps the current stage and preserves unrelated Gmail labels.',
        ),
        if (error != null) errorNotice(error!),
        const SizedBox(height: 16),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.repository.deliveries.isEmpty)
                const Text('No label deliveries need attention.'),
              for (final job in widget.repository.deliveries) ...[
                if (job != widget.repository.deliveries.first)
                  const Divider(height: 24),
                Text(
                  job['subject'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${job['state']} · ${job['attempts']} attempts · ${job['error'] ?? 'Waiting for the next run'}',
                ),
                const SizedBox(height: 8),
                if (job['retry_allowed'] != true)
                  const Text(
                    'Outside the seven-day authorization window. The CRM record is retained; change older email labels directly in Gmail if needed.',
                  ),
                if (job['state'] == 'failed' && job['retry_allowed'] == true)
                  OutlinedButton(
                    onPressed: busy ? null : () => retry(job),
                    child: Text(busy ? 'Queuing…' : 'Queue retry'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Storage stays on this device. Profile manages documents and Drive links. See the hand-off guide for backup and recovery.',
        ),
      ],
    );
  }
}
