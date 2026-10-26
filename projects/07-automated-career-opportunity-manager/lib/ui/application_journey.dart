import 'package:flutter/material.dart';

import '../domain/application.dart';
import 'app_theme.dart';

/// Stage counts are current records, not a prediction or completed checklist.
class ApplicationJourney extends StatelessWidget {
  const ApplicationJourney({
    super.key,
    required this.applications,
    required this.onStage,
  });
  final List<JobApplication> applications;
  final ValueChanged<HiringStage> onStage;
  static const steps = [
    (HiringStage.submitted, Icons.send_rounded, 'Submitted'),
    (HiringStage.reviewing, Icons.visibility_rounded, 'In review'),
    (HiringStage.information, Icons.description_rounded, 'More details'),
    (HiringStage.interview, Icons.forum_rounded, 'Interview'),
    (HiringStage.hired, Icons.flag_rounded, 'Hired'),
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Every application has a journey.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      const Text(
        'Pick a stage to see who’s there. Each opportunity moves at its own pace.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 760
              ? 5
              : constraints.maxWidth >= 450
              ? 3
              : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final step in steps)
                SizedBox(
                  width: width,
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: border, width: 2),
                    ),
                    child: InkWell(
                      key: ValueKey('journey-${step.$1.name}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onStage(step.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 20,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE4EFE3),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFB6CEB5),
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(step.$2, color: teal, size: 27),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              step.$3,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${applications.where((a) => a.stage == step.$1).length} applications',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
