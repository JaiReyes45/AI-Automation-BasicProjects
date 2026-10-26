import 'package:flutter/material.dart';

import '../data/application_repository.dart';
import '../domain/application.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import '../data/workspace_repository.dart';
import 'email_panel.dart';
import 'workspace_format.dart';

class ApplicationWorkspace extends StatefulWidget {
  const ApplicationWorkspace({
    super.key,
    required this.repository,
    required this.onChanged,
    this.title = 'Your applications',
    this.initialStage,
  });
  final ApplicationRepository repository;
  final VoidCallback onChanged;
  final String title;
  final HiringStage? initialStage;
  @override
  State<ApplicationWorkspace> createState() => _ApplicationWorkspaceState();
}

class _ApplicationWorkspaceState extends State<ApplicationWorkspace> {
  final search = TextEditingController();
  String? role;
  HiringStage? stage;
  DateTimeRange? dates;
  bool newestFirst = true;
  @override
  void initState() {
    super.initState();
    stage = widget.initialStage;
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> open(JobApplication? app) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationRecord(
          repository: widget.repository,
          applicationId: app?.id,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (!widget.repository.applications.any((a) => a.role == role)) {
        role = null;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.repository.applications;
    final roles = all.map((a) => a.role).toSet().toList()..sort();
    final query = search.text.trim().toLowerCase();
    final apps =
        all
            .where(
              (a) =>
                  '${a.company} ${a.role} ${a.source} ${a.jobDescription}'
                      .toLowerCase()
                      .contains(query) &&
                  (role == null || a.role == role) &&
                  (stage == null || a.stage == stage) &&
                  (dates == null ||
                      (a.submittedOn != null &&
                          !DateTime.parse(a.submittedOn!)
                              .isBefore(dates!.start) &&
                          !DateTime.parse(a.submittedOn!).isAfter(dates!.end))),
            )
            .toList()
          ..sort((a, b) {
            if (a.submittedOn == null) {
              return b.submittedOn == null ? a.company.compareTo(b.company) : 1;
            }
            if (b.submittedOn == null) return -1;
            final order = a.submittedOn!.compareTo(b.submittedOn!);
            return order == 0
                ? a.company.compareTo(b.company)
                : newestFirst
                ? -order
                : order;
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            FilledButton.icon(
              onPressed: () => open(null),
              icon: const Icon(Icons.add),
              label: const Text('Add application'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search company, role or job description',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(search.clear),
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                dates == null
                    ? 'Submission dates'
                    : '${calendarDate(dates!.start.toIso8601String().substring(0, 10))} – ${calendarDate(dates!.end.toIso8601String().substring(0, 10))}',
              ),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: dates,
                  helpText: 'Filter by submission date',
                );
                if (picked != null && mounted) setState(() => dates = picked);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_vert_rounded),
              label: Text(
                newestFirst
                    ? 'Newest submitted first'
                    : 'Oldest submitted first',
              ),
              onPressed: () => setState(() => newestFirst = !newestFirst),
            ),
            if (dates != null)
              TextButton(
                onPressed: () => setState(() => dates = null),
                child: const Text('Clear dates'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: constraints.maxWidth < 600 ? constraints.maxWidth : 280,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('role-$role'),
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All roles'),
                    ),
                    ...roles.map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => role = value),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth < 600 ? constraints.maxWidth : 250,
                child: DropdownButtonFormField<HiringStage>(
                  key: ValueKey('stage-$stage'),
                  initialValue: stage,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Stage',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All stages'),
                    ),
                    ...HiringStage.values.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    ),
                  ],
                  onChanged: (value) => setState(() => stage = value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${apps.length} of ${all.length} applications',
                style: const TextStyle(color: muted),
              ),
            ),
            if (query.isNotEmpty ||
                role != null ||
                stage != null ||
                dates != null)
              TextButton(
                onPressed: () => setState(() {
                  search.clear();
                  role = null;
                  stage = null;
                  dates = null;
                }),
                child: const Text('Clear filters'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Surface(
          child: Column(
            children: [
              if (apps.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    all.isEmpty
                        ? 'No applications yet. Add your first application above.'
                        : 'No applications match. Try another search or clear the filters.',
                  ),
                ),
              for (final a in apps) ...[
                if (a != apps.first) const Divider(height: 28),
                ListTile(
                  key: ValueKey('application-${a.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    a.company,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.role),
                        Text(
                          a.submittedOn == null
                              ? 'Submission date unknown'
                              : 'Submitted ${calendarDate(a.submittedOn!)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: teal,
                          ),
                        ),
                        Text(a.source, style: const TextStyle(color: muted)),
                        const SizedBox(height: 10),
                        BadgePill(a.stage.label, const Color(0xFFEAF3ED), teal),
                        if (a.nextAction != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Next: ${a.nextAction}'),
                          ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(a),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ApplicationRecord extends StatefulWidget {
  const ApplicationRecord({
    super.key,
    required this.repository,
    this.applicationId,
  });
  final ApplicationRepository repository;
  final String? applicationId;
  @override
  State<ApplicationRecord> createState() => _ApplicationRecordState();
}

class _ApplicationRecordState extends State<ApplicationRecord> {
  final form = GlobalKey<FormState>();
  late final TextEditingController company,
      role,
      source,
      action,
      submitted,
      description;
  late HiringStage stage;
  JobApplication? record;
  late bool editing;
  @override
  void initState() {
    super.initState();
    record = widget.applicationId == null
        ? null
        : widget.repository.applications.firstWhere(
            (a) => a.id == widget.applicationId,
          );
    editing = record == null;
    company = TextEditingController(text: record?.company);
    role = TextEditingController(text: record?.role);
    source = TextEditingController(text: record?.source ?? 'Manual entry');
    action = TextEditingController(text: record?.nextAction);
    stage = record?.stage ?? HiringStage.submitted;
    submitted = TextEditingController(text: record?.submittedOn ?? '');
    description = TextEditingController(text: record?.jobDescription ?? '');
  }

  @override
  void dispose() {
    for (final c in [company, role, source, action, submitted, description]) {
      c.dispose();
    }
    super.dispose();
  }

  void reset() {
    company.text = record!.company;
    role.text = record!.role;
    source.text = record!.source;
    action.text = record!.nextAction ?? '';
    stage = record!.stage;
    submitted.text = record!.submittedOn ?? '';
    description.text = record!.jobDescription;
    setState(() => editing = false);
  }

  bool saving = false;
  Future<void> save() async {
    if (saving) return;
    if (!form.currentState!.validate()) return;
    final old = record;
    final next = action.text.trim().isEmpty ? null : action.text.trim();
    final now = DateTime.now();
    final changes = <ApplicationEvent>[];
    if (old == null) {
      changes.add(
        ApplicationEvent('Manually added application · ${stage.label}', now),
      );
    } else {
      if (old.stage != stage) {
        changes.add(
          ApplicationEvent(
            'Manual stage change: ${old.stage.label} → ${stage.label}',
            now,
          ),
        );
      }
      if (old.company != company.text.trim() ||
          old.role != role.text.trim() ||
          old.source != source.text.trim()) {
        changes.add(
          ApplicationEvent('Application details edited manually', now),
        );
      }
      if (old.nextAction != next) {
        changes.add(
          ApplicationEvent(
            next == null
                ? 'Next action cleared manually'
                : 'Next action updated: $next',
            now,
          ),
        );
      }
    }
    final updated = JobApplication(
      id: old?.id ?? 'manual-${now.microsecondsSinceEpoch}',
      company: company.text.trim(),
      role: role.text.trim(),
      source: source.text.trim(),
      stage: stage,
      nextAction: next,
      submittedOn: submitted.text.trim().isEmpty ? null : submitted.text.trim(),
      jobDescription: description.text.trim(),
      events: [...changes, ...?old?.events],
    );
    setState(() => saving = true);
    try {
      await widget.repository.save(updated);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Save failed or this record changed. Your edits are still here. Return to Applications and refresh before retrying a conflict.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    saving = false;
    setState(() {
      record = widget.repository.applications.firstWhere(
        (a) => a.id == updated.id,
      );
      editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.repository.isDemo
              ? 'Saved for this session. Refreshing resets the workspace.'
              : 'Application saved locally.',
        ),
      ),
    );
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool required = true,
    int max = 120,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      controller: controller,
      maxLength: max,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      validator: (value) => required && (value == null || value.trim().isEmpty)
          ? 'Enter ${label.toLowerCase()}.'
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        record == null
            ? 'Add application'
            : editing
            ? 'Edit application'
            : 'Application details',
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.repository.isDemo) const DemoNotice(),
              const SizedBox(height: 24),
              if (editing)
                Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      field('Company', company),
                      field('Role title', role),
                      field('Source', source),
                      TextFormField(
                        controller: submitted,
                        decoration: const InputDecoration(
                          labelText: 'Submission date (YYYY-MM-DD, optional)',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final parsed = DateTime.tryParse(value.trim());
                          return parsed == null ||
                                  parsed.toIso8601String().substring(0, 10) !=
                                      value.trim()
                              ? 'Enter a real date as YYYY-MM-DD.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: description,
                        maxLines: 5,
                        maxLength: 10000,
                        decoration: const InputDecoration(
                          labelText:
                              'Job description / requirements (optional)',
                          hintText: 'Paste the role description to make it searchable.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<HiringStage>(
                        initialValue: stage,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Hiring stage',
                          border: OutlineInputBorder(),
                        ),
                        items: HiringStage.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => stage = value!),
                      ),
                      const SizedBox(height: 20),
                      field(
                        'Next action (optional)',
                        action,
                        required: false,
                        max: 300,
                      ),
                      const Text(
                        'Stage changes are manual updates. Next actions are tracked separately.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        children: [
                          FilledButton(
                            onPressed: save,
                            child: const Text('Save application'),
                          ),
                          TextButton(
                            onPressed: record == null
                                ? () => Navigator.pop(context)
                                : reset,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  record!.company,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  record!.role,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Source: ${record!.source}'),
                Text(
                  record!.submittedOn == null
                      ? 'Submission date unknown'
                      : 'Submitted ${calendarDate(record!.submittedOn!)}',
                ),
                if (record!.jobDescription.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Job description',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SelectableText(record!.jobDescription),
                ],
                const SizedBox(height: 20),
                BadgePill(record!.stage.label, const Color(0xFFEAF3ED), teal),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => setState(() => editing = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit application'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Next action',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(record!.nextAction ?? 'No next action set.'),
                const SizedBox(height: 28),
                if (widget.repository is WorkspaceRepository) ...[
                  EmailPanel(
                    repository: widget.repository as WorkspaceRepository,
                    applicationId: record!.id,
                  ),
                  const SizedBox(height: 28),
                ],
                Text('History', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (record!.events.isEmpty)
                  const Text('No events recorded yet.'),
                for (final event in record!.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.description),
                        const SizedBox(height: 4),
                        Text(
                          '${event.date.toUtc().add(const Duration(hours: 8)).toString().substring(0, 16)} · Manila',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 32),
              Text(
                widget.repository.isDemo
                    ? 'Session preview · Refreshing resets all changes.'
                    : 'Application saved locally in PostgreSQL.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
