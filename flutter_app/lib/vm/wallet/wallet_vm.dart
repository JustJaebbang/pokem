import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class WalletVm extends AsyncNotifier<WalletSnapshot> {
  @override
  Future<WalletSnapshot> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || token == null) return const WalletSnapshot(0, []);
    try {
      return await ref
          .read(walletRepositoryProvider)
          .snapshot(session.account.id, token);
    } on WalletException catch (e) {
      if (e.status == 401 &&
          ref.mounted &&
          ref.read(authRepositoryProvider).session?.token == token) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      rethrow;
    }
  }

  void refresh() => ref.invalidateSelf();
}

final walletVmProvider =
    AsyncNotifierProvider.autoDispose<WalletVm, WalletSnapshot>(
      WalletVm.new,
      retry: (_, _) => null,
    );
