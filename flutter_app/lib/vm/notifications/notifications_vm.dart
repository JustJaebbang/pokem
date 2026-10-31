import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/notifications/app_notification.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class NotificationsVm extends AsyncNotifier<NotificationsState> {
  int _generation = 0;
  @override
  Future<NotificationsState> build() async {
    _generation++;
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return const NotificationsState(items: []);
    try {
      return await ref
          .read(notificationsRepositoryProvider)
          .get(session.account.id, session.token);
    } on NotificationsException catch (e) {
      if (e.status == 401 &&
          ref.mounted &&
          ref.read(authRepositoryProvider).session?.token == session.token) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      rethrow;
    }
  }

  void refresh() {
    if (state.asData?.value.saving != true) ref.invalidateSelf();
  }

  Future<void> markRead({String? id}) async {
    final previous = state.asData?.value;
    final session = ref.read(authRepositoryProvider).session;
    if (previous == null || previous.saving || session == null) return;
    final generation = _generation;
    final ids = {
      ...previous.readIds,
      if (id == null)
        ...previous.items.map((i) => i.id)
      else if (previous.items.any((i) => i.id == id))
        id,
    };
    state = AsyncData(
      NotificationsState(items: previous.items, readIds: ids, saving: true),
    );
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .saveRead(session.account.id, ids);
      if (ref.mounted &&
          generation == _generation &&
          ref.read(authRepositoryProvider).session?.token == session.token) {
        state = AsyncData(
          NotificationsState(items: previous.items, readIds: ids),
        );
      }
    } catch (_) {
      if (ref.mounted &&
          generation == _generation &&
          ref.read(authRepositoryProvider).session?.token == session.token) {
        state = AsyncData(
          NotificationsState(
            items: previous.items,
            readIds: previous.readIds,
            error: '읽음 상태를 저장하지 못했습니다. 다시 시도해주세요.',
          ),
        );
      }
    }
  }
}

final notificationsVmProvider =
    AsyncNotifierProvider.autoDispose<NotificationsVm, NotificationsState>(
      NotificationsVm.new,
      retry: (_, _) => null,
    );
