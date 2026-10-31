import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/mypage/pending_actions.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class PendingActionsVm extends AsyncNotifier<PendingActions> {
  @override
  Future<PendingActions> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) {
      return const PendingActions(fees: 0, choices: 0, cancellations: 0);
    }
    try {
      return await ref
          .read(pendingActionsRepositoryProvider)
          .get(session.token);
    } on PendingActionsException catch (e) {
      if (e.status == 401 &&
          ref.mounted &&
          ref.read(authRepositoryProvider).session?.token == session.token) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      rethrow;
    }
  }

  void refresh() => ref.invalidateSelf();
}

final pendingActionsVmProvider =
    AsyncNotifierProvider.autoDispose<PendingActionsVm, PendingActions>(
      PendingActionsVm.new,
      retry: (_, _) => null,
    );
