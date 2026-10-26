import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';
import 'action_editor.dart';
import 'app_shell.dart';
import 'workspace_format.dart';

class EmailPanel extends StatefulWidget {
  const EmailPanel({
    super.key,
    required this.repository,
    required this.applicationId,
  });
  final WorkspaceRepository repository;
  final String applicationId;
  @override
  State<EmailPanel> createState() => _EmailPanelState();
}

class _EmailPanelState extends State<EmailPanel> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.repository.call(
      'application-emails/${Uri.encodeComponent(widget.applicationId)}',
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Email conversation', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'The messages linked to this application. Read the evidence before updating its stage.',
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(
                () => future = widget.repository.call(
                  'application-emails/${widget.applicationId}',
                ),
              ),
              child: const Text('Could not load emails. Retry'),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final items = snapshot.data!['items'] as List;
          if (items.isEmpty) {
            return const Text(
              'No linked email yet. Link a message from Review inbox.',
            );
          }
          return Column(
            children: [
              for (final m in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['subject'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(m['sender']),
                        Text(manilaTime(m['received_at'])),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Read received email'),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(m['body']),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                        if (m['has_more'] == true)
                          const Text(
                            'This long message was capped during import. Open Gmail for the entire original.',
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => openDocument(
                                'https://mail.google.com/mail/u/?authuser=${Uri.encodeComponent(m['account'])}#all/${m['id']}',
                              ),
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open in Gmail'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await openAction(context, widget.repository, {
                                  'kind': 'reply',
                                  'application_id': widget.applicationId,
                                  'message_id': m['id'],
                                  'to': m['reply_to'],
                                  'subject': 'Re: ${m['subject']}',
                                });
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.reply_rounded),
                              label: const Text('Write a reply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
