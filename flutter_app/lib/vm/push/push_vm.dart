import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/push/push_target.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/notifications/notifications_vm.dart';
export 'package:pokem_app/model/push/push_target.dart';

class PushVm extends Notifier<PushState> {
  int _generation = 0;
  final _seen = <String>{};
  int _listeningGeneration = -1;
  List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  PushState build() {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    _generation++;
    final subscriptions = <StreamSubscription<dynamic>>[];
    _subscriptions = subscriptions;
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });
    if (session?.account.role == AccountRole.user &&
        ref.read(pushRepositoryProvider).available) {
      Future.microtask(synchronize);
    }
    return const PushState();
  }

  Future<bool> _ensureListeners(int generation, AuthSession session) async {
    final repo = ref.read(pushRepositoryProvider);
    await repo.messaging.initialize();
    if (!_current(generation, session)) return false;
    if (_listeningGeneration != generation) {
      _listeningGeneration = generation;
      _subscriptions.add(
        repo.messaging.foreground.listen(
          (data) => _receive(data, generation, session, false),
        ),
      );
      _subscriptions.add(
        repo.messaging.opened.listen(
          (data) => _receive(data, generation, session, true),
        ),
      );
      _subscriptions.add(
        repo.messaging.refreshed.listen((_) {
          if (_current(generation, session)) {
            synchronize();
          }
        }),
      );
      final initial = await repo.messaging.initial();
      if (initial != null) _receive(initial, generation, session, true);
    }
    return _current(generation, session);
  }

  bool _current(int generation, AuthSession session) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(loginVmProvider).session?.token == session.token &&
      !ref.read(loginVmProvider).submitting;
  void _receive(
    Map<String, dynamic> data,
    int generation,
    AuthSession session,
    bool opened,
  ) {
    if (!_current(generation, session)) return;
    final target = PushTarget.parse(data);
    if (target == null || target.ownerId != session.account.id) return;
    final key = '${opened ? 'tap' : 'message'}:${target.eventId}';
    if (!_seen.add(key)) return;
    if (_seen.length > 100) _seen.remove(_seen.first);
    ref.invalidate(notificationsVmProvider);
    state = PushState(
      enabled: state.enabled,
      busy: state.busy,
      error: state.error,
      foreground: opened ? null : target,
      opened: opened ? target : null,
    );
  }

  Future<void> synchronize({bool ask = false}) async {
    if (!ref.read(pushRepositoryProvider).available) return;
    final session = ref.read(loginVmProvider).session;
    if (session?.account.role != AccountRole.user ||
        state.busy ||
        ref.read(loginVmProvider).submitting) {
      return;
    }
    final generation = _generation;
    state = PushState(enabled: state.enabled, busy: true);
    try {
      if (!await _ensureListeners(generation, session!)) return;
      final enabled = await ref
          .read(pushRepositoryProvider)
          .attach(session, ask: ask);
      if (_current(generation, session)) {
        state = PushState(
          enabled: enabled,
          error: ask && !enabled ? '휴대폰 설정에서 알림을 허용해주세요.' : null,
        );
      }
    } catch (_) {
      if (_current(generation, session!)) {
        state = PushState(
          enabled: state.enabled,
          error: '알림을 연결하지 못했습니다. 다시 시도해주세요.',
        );
      }
    }
  }

  Future<void> disable() async {
    final session = ref.read(loginVmProvider).session;
    if (session == null || state.busy) return;
    final generation = _generation;
    state = PushState(enabled: state.enabled, busy: true);
    try {
      await ref.read(pushRepositoryProvider).detach(session, optOut: true);
      if (_current(generation, session)) state = const PushState();
    } catch (_) {
      if (_current(generation, session)) {
        state = const PushState(error: '알림 해제를 확인하지 못했습니다. 다시 시도해주세요.');
      }
    }
  }
}

final pushVmProvider = NotifierProvider<PushVm, PushState>(PushVm.new);
final pushSupportedProvider = Provider<bool>(
  (ref) => ref.watch(pushRepositoryProvider).available,
);
