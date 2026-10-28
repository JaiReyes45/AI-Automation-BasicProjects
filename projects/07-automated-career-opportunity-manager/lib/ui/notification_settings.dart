import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/workspace_repository.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'today_screen.dart';
import 'workspace_format.dart';
import 'workspace_screens.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key, required this.repository});
  final WorkspaceRepository repository;
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  late Future<Map<String, dynamic>> state;
  Map<String, dynamic>? pairing;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    state = widget.repository.call('notifications');
  }

  Future<void> command(String action, [String? id]) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repository.call(
        action == 'pair' ? 'notifications/pairing' : 'notifications/command',
        body: action == 'pair'
            ? {}
            : {
                'id': id,
                'action': action,
                if (action == 'snooze') 'minutes': 60,
              },
      );
      if (!mounted) return;
      setState(() {
        if (action == 'pair') {
          pairing = result;
        } else {
          state = widget.repository.call('notifications');
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String setupCommand(String code) =>
      'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\desktop_notifications.ps1 -PairCode "$code" -Install';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Desktop notifications',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'The paired Windows helper can show alerts while this browser tab is closed. Keep this computer awake, Docker running and the helper active.',
      ),
      const SizedBox(height: 16),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: state,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loading alert delivery status…'),
                      SizedBox(height: 12),
                      LinearProgressIndicator(),
                    ],
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alert delivery status could not be loaded.'),
                      TextButton(
                        onPressed: () => setState(
                          () => state = widget.repository.call('notifications'),
                        ),
                        child: const Text('Retry notification status'),
                      ),
                    ],
                  );
                }
                final data = snapshot.data ?? {};
                final items = workspaceItems(data['items']);
                final devices = workspaceItems(data['devices']);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (devices.isEmpty)
                      const Text(
                        'No Windows helper paired.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    for (final device in devices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${device['name'] ?? 'Windows helper'} · last seen ${manilaTime(device['last_seen'])}',
                        ),
                      ),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('No alert deliveries recorded yet.'),
                      ),
                    for (final item in items.take(12)) ...[
                      const Divider(height: 28),
                      Text(
                        item['title']?.toString() ?? 'Employer request',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (item['body'] != null) Text(item['body'].toString()),
                      Text(
                        'Delivery: ${item['state'] ?? 'unknown'} · ${item['attempts'] ?? 0} attempts',
                      ),
                      if (item['error'] != null)
                        Text(
                          item['error'].toString(),
                          style: const TextStyle(color: Color(0xFF9B302E)),
                        ),
                      if (item['snoozed_until'] != null)
                        Text(
                          'Snoozed until ${manilaTime(item['snoozed_until'])}',
                        ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (item['read_at'] == null)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        command('read', item['id'].toString()),
                              child: const Text('Mark read'),
                            ),
                          if (item['state'] != 'suppressed')
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => command(
                                      'snooze',
                                      item['id'].toString(),
                                    ),
                              child: const Text('Snooze 1 hour'),
                            ),
                          if (['failed', 'uncertain'].contains(item['state']))
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                        command('retry', item['id'].toString()),
                              child: const Text('Retry alert'),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : () => command('pair'),
              icon: const Icon(Icons.desktop_windows_outlined),
              label: Text(busy ? 'Updating…' : 'Set up Windows alerts'),
            ),
            if (error != null) errorNotice(error!),
            if (pairing != null) ...[
              const Divider(height: 28),
              Text(
                'Pair this Windows computer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open PowerShell in the CareerFlow project folder. Copy and run the setup command below. It installs the helper to start when you sign in to Windows.',
              ),
              const SizedBox(height: 12),
              const Text('One-time pairing code'),
              SelectableText(
                pairing!['code']?.toString() ?? 'No code returned',
              ),
              Text('Expires ${manilaTime(pairing!['expires_at'])}'),
              const SizedBox(height: 12),
              SelectableText(setupCommand('CODE_FROM_APP')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: pairing!['code'] == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: setupCommand(pairing!['code'].toString()),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Setup command copied. Run it in the project folder.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy),
                label: const Text('Copy setup command'),
              ),
              const SizedBox(height: 8),
              const Text(
                'The helper stores a scoped delivery token encrypted for your Windows account. It does not need your workspace password.',
                style: TextStyle(color: muted),
              ),
              TextButton(
                onPressed: () => setState(() {
                  pairing = null;
                  state = widget.repository.call('notifications');
                }),
                child: const Text('Done · check helper status'),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class MailCaptureSettings extends StatefulWidget {
  const MailCaptureSettings({super.key, required this.repository});
  final WorkspaceRepository repository;
  @override
  State<MailCaptureSettings> createState() => _MailCaptureSettingsState();
}

class _MailCaptureSettingsState extends State<MailCaptureSettings> {
  late Future<Map<String, dynamic>> coverage;
  bool busy = false;
  String? error, confirmation;
  @override
  void initState() {
    super.initState();
    coverage = widget.repository.call('mail/coverage');
  }

  Future<void> backfill() async {
    final today = DateTime.parse(manilaToday());
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 30)),
        end: today,
      ),
      helpText: 'Import up to 90 days of older messages',
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays >= 90) {
      setState(() => error = 'Choose a range of 90 days or less.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      confirmation = null;
    });
    try {
      DateTime startOfManilaDay(DateTime d) => DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).subtract(const Duration(hours: 8));
      final requestedEnd = startOfManilaDay(
        range.end.add(const Duration(days: 1)),
      );
      final now = DateTime.now().toUtc();
      await widget.repository.call(
        'mail/backfill',
        body: {
          'after': startOfManilaDay(range.start).toIso8601String(),
          'before': (requestedEnd.isAfter(now) ? now : requestedEnd)
              .toIso8601String(),
          if (widget.repository.connection['account'] != null)
            'account': widget.repository.connection['account'],
        },
      );
      if (mounted) {
        setState(() {
          confirmation = 'Historical capture queued. Check coverage here as pages finish importing.';
          coverage = widget.repository.call('mail/coverage');
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = actionError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Capture coverage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      FutureBuilder<Map<String, dynamic>>(
        future: coverage,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Capture coverage could not be loaded.'),
                TextButton(
                  onPressed: () => setState(
                    () => coverage = widget.repository.call('mail/coverage'),
                  ),
                  child: const Text('Retry coverage'),
                ),
              ],
            );
          }
          return CoverageSummary(coverage: snapshot.data ?? {});
        },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy ? null : backfill,
        icon: const Icon(Icons.history),
        label: Text(busy ? 'Queuing capture…' : 'Import older messages'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose a bounded date range, up to 90 days. Historical capture does not authorize changes to older Gmail labels.',
        style: TextStyle(color: muted),
      ),
      if (confirmation != null) Text(confirmation!),
      if (error != null) errorNotice(error!),
    ],
  );
}
