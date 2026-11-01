import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/service/push/push_device_service.dart';
import 'package:pokem_app/service/push/push_messaging_service.dart';

class PushRepository {
  PushRepository(this.messaging, this.devices);
  final PushMessagingService messaging;
  final PushDeviceService devices;
  Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool get available => PushMessagingService.available;
  Future<bool> attach(AuthSession session, {bool ask = false}) =>
      _serial(() => _attach(session, ask: ask));
  Future<bool> _attach(AuthSession session, {bool ask = false}) async {
    if (!available) return false;
    await messaging.initialize();
    if (!ask && !await devices.wanted(session.account.id)) return false;
    final granted = await messaging.permission(ask: ask);
    if (!granted) {
      await _detach(session);
      return false;
    }
    if (ask) await devices.preference(session.account.id, true);
    final token = await messaging.token();
    if (token == null || token.isEmpty) throw const PushException();
    await devices.update(session.token, await devices.installation(), token);
    return true;
  }

  Future<void> detach(AuthSession? session, {bool optOut = false}) =>
      _serial(() => _detach(session, optOut: optOut));
  Future<void> _detach(AuthSession? session, {bool optOut = false}) async {
    if (!available ||
        session == null ||
        session.account.role != AccountRole.user) {
      return;
    }
    if (optOut) await devices.preference(session.account.id, false);
    try {
      await devices.update(session.token, await devices.installation(), null);
    } finally {
      try {
        await messaging.revoke();
      } catch (_) {
        /* Retry on the next session. */
      }
    }
  }
}
