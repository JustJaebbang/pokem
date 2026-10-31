import 'package:pokem_app/model/notifications/app_notification.dart';
import 'package:pokem_app/service/notifications/notifications_api_service.dart';
import 'package:pokem_app/service/notifications/notification_read_storage.dart';

class NotificationsRepository {
  NotificationsRepository(this._api, this._storage, {required this.namespace});
  final NotificationsApiService _api;
  final NotificationReadStorage _storage;
  final String namespace;
  String key(String owner) => '$namespace|$owner';
  Future<NotificationsState> get(String owner, String token) async {
    final items = await _api.get(token);
    if (items.any((item) => item.ownerId != owner)) {
      throw const NotificationsException('알림의 사용자가 일치하지 않습니다.');
    }
    try {
      return NotificationsState(
        items: items,
        readIds: await _storage.read(key(owner)),
      );
    } catch (_) {
      return NotificationsState(items: items, error: '저장된 읽음 상태를 불러오지 못했습니다.');
    }
  }

  Future<void> saveRead(String owner, Set<String> ids) =>
      _storage.write(key(owner), ids);
}
