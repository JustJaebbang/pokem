import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class PurchaseHistoryVm extends AsyncNotifier<List<Purchase>> {
  @override
  Future<List<Purchase>> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) return [];
    try {
      return await ref.read(purchaseRepositoryProvider).history(token);
    } on PurchaseException catch (e) {
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

final purchaseHistoryVmProvider =
    AsyncNotifierProvider.autoDispose<PurchaseHistoryVm, List<Purchase>>(
      PurchaseHistoryVm.new,
      retry: (_, _) => null,
    );
