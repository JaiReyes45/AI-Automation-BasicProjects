import 'package:flutter/material.dart';

import '../data/application_repository.dart';
import '../domain/application.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class ApplicationWorkspace extends StatefulWidget {
  const ApplicationWorkspace({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final ApplicationRepository repository;
  final VoidCallback onChanged;
  @override
  State<ApplicationWorkspace> createState() => _ApplicationWorkspaceState();
}

class _ApplicationWorkspaceState extends State<ApplicationWorkspace> {
  final search = TextEditingController();
  String? role;
  HiringStage? stage;
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
    final apps = all
        .where(
          (a) =>
              '${a.company} ${a.role} ${a.source}'.toLowerCase().contains(
                query,
              ) &&
              (role == null || a.role == role) &&
              (stage == null || a.stage == stage),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Your applications',
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
            labelText: 'Search company, role or source',
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
            if (query.isNotEmpty || role != null || stage != null)
              TextButton(
                onPressed: () => setState(() {
                  search.clear();
                  role = null;
                  stage = null;
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
  late final TextEditingController company, role, source, action;
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
  }

  @override
  void dispose() {
    for (final c in [company, role, source, action]) {
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
    setState(() => editing = false);
  }

  void save() {
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
      events: [...changes, ...?old?.events],
    );
    widget.repository.save(updated);
    setState(() {
      record = updated;
      editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Saved for this session. Refreshing resets the workspace.',
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
              const DemoNotice(),
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
              const Text(
                'Session preview · Refreshing resets all changes.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
