class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
    required this.ownerId,
    this.code,
    this.date,
  });
  final String id, title, body, target, ownerId;
  final String? code, date;
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    target: j['target_type'] as String,
    ownerId: j['user_user_id'] as String,
    code: j['target_code'] as String?,
    date: j['occurred_at'] as String?,
  );
}

class NotificationsState {
  const NotificationsState({
    required this.items,
    this.readIds = const {},
    this.saving = false,
    this.error,
  });
  final List<AppNotification> items;
  final Set<String> readIds;
  final bool saving;
  final String? error;
  int get unread => items.where((item) => !readIds.contains(item.id)).length;
}

class NotificationsException implements Exception {
  const NotificationsException(this.message, {this.status});
  final String message;
  final int? status;
}
