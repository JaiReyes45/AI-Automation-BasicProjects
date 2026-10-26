import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';
import 'action_editor.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'workspace_format.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime month;
  DateTime? selected;
  @override
  void initState() {
    super.initState();
    final today = DateTime.parse('${manilaToday()}T00:00:00Z');
    month = DateTime.utc(today.year, today.month);
  }

  DateTime local(String s) =>
      DateTime.parse(s).toUtc().add(const Duration(hours: 8));
  bool dayMatches(Map event, DateTime day) {
    final a = local(event['start']);
    final b = local(event['end']);
    return a.isBefore(day.add(const Duration(days: 1))) && b.isAfter(day);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.repository.calendarData;
    final connection = data['connection'] as Map? ?? {};
    final all =
        (data['items'] as List? ?? [])
            .cast<Map>()
            .where((e) => !['cancelled', 'not_in_window'].contains(e['status']))
            .toList()
          ..sort((a, b) => a['start'].compareTo(b['start']));
    final visible = all
        .where(
          (e) => selected == null
              ? local(e['end'])
                    .isAfter(DateTime.parse('${manilaToday()}T00:00:00Z'))
              : dayMatches(e, selected!),
        )
        .toList();
    final first = month.subtract(Duration(days: month.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Make room for what’s next.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            FilledButton.icon(
              onPressed: widget.repository.applications.isEmpty
                  ? null
                  : () async {
                      await openAction(context, widget.repository, {
                        'kind': 'meeting',
                        'title': 'Interview',
                      });
                      widget.onChanged();
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan an interview'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          connection['connected'] == true
              ? 'Google Calendar connected · Last checked ${manilaTime(connection['last_sync'])}'
              : 'Google Calendar is not connected yet. Complete the credential setup in n8n.',
        ),
        const Text(
          'All times are shown in Manila. Confirmed guests receive a calendar invitation.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 500 ? 4 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => month = DateTime.utc(month.year, month.month - 1),
                    ),
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][month.month - 1]} ${month.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => month = DateTime.utc(month.year, month.month + 1),
                    ),
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent:
                        40 + MediaQuery.textScalerOf(context).scale(18),
                  ),
                  itemBuilder: (context, i) {
                    final day = first.add(Duration(days: i));
                    final count = all.where((e) => dayMatches(e, day)).length;
                    final active = selected == day;
                    return Semantics(
                      label:
                          '${calendarDate(day.toIso8601String().substring(0, 10))}, $count events',
                      selected: active,
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Material(
                          color: active
                              ? teal
                              : day.month == month.month
                              ? const Color(0xFFF1F5EE)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => selected = day),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: active
                                        ? Colors.white
                                        : day.month == month.month
                                        ? ink
                                        : muted,
                                  ),
                                ),
                                if (count > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : teal,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              selected == null
                  ? 'Coming up'
                  : calendarDate(selected!.toIso8601String().substring(0, 10)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (selected != null)
              TextButton(
                onPressed: () => setState(() => selected = null),
                child: const Text('Show all upcoming'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Surface(
            child: Text(
              'Nothing scheduled here yet. Your next interview will have a home here.',
            ),
          ),
        for (final event in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${manilaTime(event['start'])} → ${manilaTime(event['end'])}',
                  ),
                  if (event['all_day'] == true) const Text('All-day event'),
                  if ((event['location'] ?? '').isNotEmpty)
                    Text(event['location']),
                  Text(
                    'Calendar status: ${event['sync_state'] ?? 'synced'}',
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event['error'] != null)
                    Text(
                      event['error'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if ((event['description'] ?? '').isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Meeting notes'),
                      children: [SelectableText(event['description'])],
                    ),
                  if (event['html_link'] != null)
                    TextButton.icon(
                      onPressed: () => openDocument(event['html_link']),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open in Google Calendar'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
