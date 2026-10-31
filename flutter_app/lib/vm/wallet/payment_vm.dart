import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/product_payment.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class PaymentHistoryVm extends AsyncNotifier<List<ProductPayment>> {
  @override
  Future<List<ProductPayment>> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return [];
    try {
      return await ref
          .read(paymentRepositoryProvider)
          .history(session.account.id, session.token);
    } on PaymentException catch (e) {
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

class PaymentDetailVm extends AsyncNotifier<ProductPayment?> {
  PaymentDetailVm(this.code);
  final String code;
  @override
  Future<ProductPayment?> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return null;
    try {
      return await ref
          .read(paymentRepositoryProvider)
          .detail(code, session.account.id, session.token);
    } on PaymentException catch (e) {
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

final paymentHistoryVmProvider =
    AsyncNotifierProvider.autoDispose<PaymentHistoryVm, List<ProductPayment>>(
      PaymentHistoryVm.new,
      retry: (_, _) => null,
    );
final paymentDetailVmProvider = AsyncNotifierProvider.autoDispose
    .family<PaymentDetailVm, ProductPayment?, String>(
      PaymentDetailVm.new,
      retry: (_, _) => null,
    );
