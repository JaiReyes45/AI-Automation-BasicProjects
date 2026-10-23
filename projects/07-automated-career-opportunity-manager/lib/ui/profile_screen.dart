import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/profile_stub.dart'
    if (dart.library.js_interop) '../data/profile_web.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const fields = {
    'name': 'Full name',
    'email': 'Email address',
    'phone': 'Phone number',
    'location': 'City / location',
    'school': 'School / university',
    'course': 'Degree / course',
    'year': 'Year level',
    'hours': 'Required internship hours',
    'availability': 'Availability / target dates',
    'linkedin': 'LinkedIn URL',
    'github': 'GitHub URL',
    'portfolio': 'Portfolio URL',
    'drive': 'School Drive folder URL',
    'notes': 'Internship requirements / notes',
  };
  final controllers = {
    for (final key in fields.keys) key: TextEditingController(),
  };
  final requirement = TextEditingController(text: 'Resume');
  final link = TextEditingController();
  final form = GlobalKey<FormState>();
  List<dynamic> docs = [];
  bool loading = true, busy = false, loaded = false;
  String? error, notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [...controllers.values, requirement, link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = jsonDecode(
        await profileRequest('GET', '/api/profile', ''),
      ) as Map<String, dynamic>;
      if (!mounted) return;
      for (final key in fields.keys) {
        controllers[key]!.text = data['profile'][key] ?? '';
      }
      setState(() {
        loaded = true;
        docs = data['documents'];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load local storage. Check the Docker containers and retry.';
        });
      }
    }
  }

  Future<void> run(Future<void> Function() task) async {
    if (!loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reload the saved profile before making changes.'),
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Could not save. Check HTTPS links, file type and size, or Docker storage. Your entries are still here.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        final message = error ?? notice;
        if (message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  Future<void> refreshDocs() async {
    final data = jsonDecode(await profileRequest('GET', '/api/profile', ''));
    if (mounted) setState(() => docs = data['documents']);
  }

  Widget section(String title, String description, List<String> keys) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: muted)),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final k in keys)
                      SizedBox(
                        width: c.maxWidth < 620
                            ? c.maxWidth
                            : (c.maxWidth - 20) / 2,
                        child: TextFormField(
                          controller: controllers[k],
                          maxLength: k == 'notes' ? 3000 : 300,
                          maxLines: k == 'notes' ? 3 : 1,
                          decoration: InputDecoration(
                            labelText: fields[k],
                            counterText: '',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if ([
                              'linkedin',
                              'github',
                              'portfolio',
                              'drive',
                            ].contains(k)) {
                              final u = Uri.tryParse(v.trim());
                              if (u == null ||
                                  u.scheme != 'https' ||
                                  u.host.isEmpty) {
                                return 'Use a full https:// link.';
                              }
                            }
                            if (k == 'email' &&
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(v)) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your internship profile',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your details, professional links and documents. Ready when an employer asks.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Icon(Icons.folder_outlined, size: 18, color: teal),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saved on this device in your Project 07 Docker folder.',
                style: TextStyle(color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text('Reload saved profile'),
                ),
              ],
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(notice!, style: const TextStyle(color: teal)),
          ),
        Form(
          key: form,
          child: Column(
            children: [
              section(
                'Personal details',
                'Only fill in what you want to keep here.',
                ['name', 'email', 'phone', 'location'],
              ),
              section(
                'Internship',
                'Keep your school requirements close to your applications.',
                ['school', 'course', 'year', 'hours', 'availability', 'notes'],
              ),
              section(
                'Professional links',
                'Links are saved as references. No account connection is required.',
                ['linkedin', 'github', 'portfolio', 'drive'],
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  if (!form.currentState!.validate()) return;
                  await profileRequest(
                    'POST',
                    '/api/profile',
                    jsonEncode({
                      for (final k in fields.keys)
                        k: controllers[k]!.text.trim(),
                    }),
                  );
                  if (mounted) {
                    setState(() => notice = 'Profile saved locally.');
                  }
                }),
          icon: const Icon(Icons.check, size: 18),
          label: Text(busy ? 'Working…' : 'Save profile'),
        ),
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 24),
        Text(
          'Documents & requirements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Resume, student consent form, endorsement letter, or any requirement from your school. Uploads stay local; Drive links keep the original sharing permissions.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: requirement,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Requirement name',
                  helperText: 'For example: Student consent form',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        if (requirement.text.trim().isEmpty) {
                          setState(
                            () => error = 'Enter a requirement name first.',
                          );
                          return;
                        }
                        final result = await uploadDocument(
                          requirement.text.trim(),
                        );
                        if (result == 'uploaded') {
                          await refreshDocs();
                          if (mounted) {
                            setState(() => notice = 'Document stored locally.');
                          }
                        }
                      }),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload local file'),
              ),
              const SizedBox(height: 8),
              const Text(
                'PDF, DOCX, PNG or JPG · Up to 8 MB',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: link,
                decoration: const InputDecoration(
                  labelText: 'Or paste an HTTPS document link',
                  hintText: 'https://drive.google.com/...',
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final u = Uri.tryParse(link.text.trim());
                        if (requirement.text.trim().isEmpty ||
                            u == null ||
                            u.scheme != 'https' ||
                            u.host.isEmpty) {
                          setState(
                            () => error = 'Enter a requirement name and a valid HTTPS link.',
                          );
                          return;
                        }
                        await profileRequest(
                          'POST',
                          '/api/documents',
                          jsonEncode({
                            'category': requirement.text.trim(),
                            'url': link.text.trim(),
                          }),
                        );
                        await refreshDocs();
                        link.clear();
                        if (mounted) {
                          setState(() => notice = 'Document link saved.');
                        }
                      }),
                icon: const Icon(Icons.add_link),
                label: const Text('Save document link'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No documents yet. Add your resume or first school requirement above.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final d in docs)
          Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  d['size'] == 0 ? Icons.link : Icons.description_outlined,
                  color: teal,
                ),
                title: Text(d['category']),
                subtitle: Text(
                  '${d['name']} · ${d['size'] == 0 ? 'External link' : 'Local file'}',
                ),
                trailing: IconButton(
                  tooltip: d['size'] == 0
                      ? 'Open document link'
                      : 'Download document',
                  onPressed: () => openDocument(d['url']),
                  icon: Icon(
                    d['size'] == 0
                        ? Icons.open_in_new
                        : Icons.download_outlined,
                  ),
                ),
              ),
              const Divider(),
            ],
          ),
      ],
    );
  }
}
