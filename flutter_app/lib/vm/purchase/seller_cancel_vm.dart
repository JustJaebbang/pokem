import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class SellerCancelVm extends AsyncNotifier<List<PurchaseCancellation>> {
  @override
  Future<List<PurchaseCancellation>> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    final session = ref.read(authRepositoryProvider).session;
    if (token == null || session == null) return [];
    try {
      return await ref
          .read(sellerCancelRepositoryProvider)
          .requests(session.account.id, token);
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

final sellerCancelVmProvider =
    AsyncNotifierProvider.autoDispose<
      SellerCancelVm,
      List<PurchaseCancellation>
    >(SellerCancelVm.new, retry: (_, _) => null);
