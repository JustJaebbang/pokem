class PushTarget {
  const PushTarget({
    required this.ownerId,
    required this.requestNumber,
    required this.eventId,
  });
  final String ownerId, requestNumber, eventId;
  static PushTarget? parse(Map<String, dynamic> data) {
    if (data['target_type'] != 'inspection_results' ||
        data['owner_id'] is! String ||
        data['target_code'] is! String ||
        data['event_id'] is! String) {
      return null;
    }
    final code = data['target_code'] as String;
    final owner = data['owner_id'] as String;
    final event = data['event_id'] as String;
    if (owner.isEmpty ||
        owner.length > 100 ||
        !RegExp(r'^[0-9]{14}$').hasMatch(code) ||
        !event.startsWith('inspection_complete:') ||
        event.length > 150) {
      return null;
    }
    return PushTarget(ownerId: owner, requestNumber: code, eventId: event);
  }
}

class PushState {
  const PushState({
    this.enabled = false,
    this.busy = false,
    this.error,
    this.foreground,
    this.opened,
  });
  final bool enabled, busy;
  final String? error;
  final PushTarget? foreground, opened;
}
