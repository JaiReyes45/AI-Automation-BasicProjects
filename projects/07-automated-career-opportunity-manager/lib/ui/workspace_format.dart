String manilaTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return 'Never';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return 'Unknown';
  final d = parsed.toUtc().add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)} Manila';
}

String manilaToday() => DateTime.now()
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);

String actionError(Object error) {
  final message = error.toString().replaceFirst(
    RegExp(r'^(Exception|Error):\s*'),
    '',
  );
  return message.contains('XMLHttpRequest') ||
          message.contains('Failed to fetch')
      ? 'Cannot reach local storage. Check Docker, then try again. Your entries are still here.'
      : '$message Refresh if this item changed; your entries are still here.';
}

String calendarDate(String value) {
  final d = DateTime.tryParse(value);
  if (d == null) return 'Date unknown';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
