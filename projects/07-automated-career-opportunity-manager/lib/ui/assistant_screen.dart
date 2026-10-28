import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import 'action_editor.dart';
import 'application_workspace.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'workspace_format.dart';
import 'today_screen.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final WorkspaceRepository repository;
  final VoidCallback onChanged;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();
  final conversation = <Map<String, dynamic>>[];
  String? appId, error;
  bool busy = false;
  late Future<Map<String, dynamic>> status;
  @override
  void initState() {
    super.initState();
    status = widget.repository.call('assistant/status');
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final question = input.text.trim();
    if (question.isEmpty || busy) return;
    setState(() => busy = true);
    final history = conversation
        .map((m) => {'role': m['role'], 'content': m['text']})
        .toList();
    setState(() {
      error = null;
      conversation.add({'role': 'user', 'text': question});
    });
    try {
      final result = await widget.repository.call(
        'assistant/chat',
        body: {
          'message': question,
          'history': history,
          'application_id': appId,
        },
      );
      if (mounted) {
        setState(() {
          conversation.add({
            'role': 'assistant',
            'text': result['answer'],
            'ids': result['application_ids'],
            'proposal': result['proposal'],
            'sources': result['sources'],
            'completeness': result['completeness'],
            'coverage': result['coverage'],
          });
          input.clear();
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
      Text(
        'Workspace assistant',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Find applications, draft replies, plan interviews, and review changes before they happen.',
      ),
      const SizedBox(height: 12),
      FutureBuilder<Map<String, dynamic>>(
        future: status,
        builder: (context, s) {
          final ready = s.data?['ready'] == true;
          return Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                ready
                    ? 'Local assistant ready · ${s.data!['model']}'
                    : s.connectionState != ConnectionState.done
                    ? 'Connecting to your local assistant…'
                    : 'Assistant unavailable. Check that Ollama is running in Docker.',
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!ready && s.connectionState == ConnectionState.done)
                TextButton.icon(
                  onPressed: () => setState(
                    () => status = widget.repository.call('assistant/status'),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try connection again'),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: appId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Application context (optional for search)',
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Search the whole workspace'),
          ),
          for (final a in widget.repository.applications)
            DropdownMenuItem(
              value: a.id,
              child: Text(
                '${a.company} · ${a.role}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: busy ? null : (v) => setState(() => appId = v),
      ),
      const SizedBox(height: 20),
      if (conversation.isEmpty)
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final prompt in [
              'Which employers are waiting for my response?',
              'Find unmatched interview requests.',
              'Draft a reply with my availability.',
              'Which applications did I submit this week?',
            ])
              ActionChip(
                label: Text(prompt),
                onPressed: () => setState(() => input.text = prompt),
              ),
          ],
        ),
      for (final message in conversation)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message['role'] == 'user' ? 'You' : 'CareerFlow assistant',
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  message['text']?.toString() ?? 'No answer returned.',
                ),
                if (message['role'] == 'assistant') ...[
                  const SizedBox(height: 12),
                  if (message['completeness'] is Map)
                    Text(
                      'Evidence coverage: ${message['completeness']['records'] ?? '?'} of ${message['completeness']['total'] ?? '?'} relevant records${message['completeness']['limited'] == true ? ' · results limited' : ''}',
                      style: const TextStyle(color: muted),
                    )
                  else
                    const Text(
                      'Retrieval completeness was not reported.',
                      style: TextStyle(color: muted),
                    ),
                  if (workspaceItems(message['sources']).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Sources used',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final source in workspaceItems(message['sources']))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${source['label'] ?? source['id'] ?? 'Source'} · ${source['type'] ?? 'record'}',
                            ),
                            if (source['message_id'] != null &&
                                source['account'] != null)
                              TextButton.icon(
                                onPressed: () => openDocument(
                                  'https://mail.google.com/mail/u/?authuser=${Uri.encodeComponent(source['account'].toString())}#all/${Uri.encodeComponent(source['message_id'].toString())}',
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open source email'),
                              ),
                          ],
                        ),
                      ),
                  ] else
                    const Text(
                      'No source references were returned.',
                      style: TextStyle(color: muted),
                    ),
                  if (message['coverage'] is Map &&
                      (message['coverage'] as Map).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: CoverageSummary(
                        coverage: Map<String, dynamic>.from(
                          message['coverage'],
                        ),
                      ),
                    ),
                ],
                for (final id in message['ids'] ?? []) ...[
                  for (final a in widget.repository.applications.where(
                    (a) => a.id == id,
                  ))
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ApplicationRecord(
                            repository: widget.repository,
                            applicationId: id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: Text('${a.company} · ${a.role}'),
                    ),
                ],
                if (message['proposal'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await openAction(
                          context,
                          widget.repository,
                          Map<String, dynamic>.from(message['proposal']),
                        );
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Review proposed action'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (busy)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(),
        ),
      TextField(
        controller: input,
        minLines: 2,
        maxLines: 6,
        maxLength: 3000,
        decoration: const InputDecoration(
          labelText: 'Ask your assistant',
          hintText: 'Try “Find QA internships submitted last Friday”',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: busy ? null : send,
        icon: const Icon(Icons.arrow_upward_rounded),
        label: Text(busy ? 'Thinking locally…' : 'Ask assistant'),
      ),
      const SizedBox(height: 28),
      Text(
        'Recent confirmed actions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (widget.repository.actionLog.isEmpty)
        const Text('No actions confirmed yet.'),
      for (final action in widget.repository.actionLog.take(15))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${action['kind']} · ${action['company']}'),
          subtitle: Text(
            '${action['state']}${action['error'] == null ? '' : ' · ${action['error']}'}',
          ),
        ),
    ],
  );
}
