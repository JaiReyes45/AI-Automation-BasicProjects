enum HiringStage {
  submitted('Submitted'),
  reviewing('Under review'),
  information('Information requested'),
  assessment('Assessment'),
  interview('Interview'),
  offer('Offer received'),
  accepted('Offer accepted'),
  hired('Hired'),
  rejected('Rejected'),
  withdrawn('Withdrawn'),
  closed('Position closed');

  const HiringStage(this.label);
  final String label;
}

class ApplicationEvent {
  const ApplicationEvent(this.description, this.date);
  final String description;
  final DateTime date;
}

class JobApplication {
  JobApplication({
    required this.id,
    required this.company,
    required this.role,
    required this.source,
    required this.stage,
    required List<ApplicationEvent> events,
    this.nextAction,
  }) : events = List.unmodifiable(events);
  final String id;
  final String company;
  final String role;
  final String source;
  final HiringStage stage;
  final String? nextAction;
  final List<ApplicationEvent> events;
}
