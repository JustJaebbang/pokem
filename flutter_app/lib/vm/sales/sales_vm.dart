import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/sales/sale_record.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class SalesVm extends AsyncNotifier<List<SaleRecord>> {
  @override
  Future<List<SaleRecord>> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) return [];
    try {
      return await ref.read(salesRepositoryProvider).history(token);
    } on SalesException catch (e) {
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

final salesVmProvider =
    AsyncNotifierProvider.autoDispose<SalesVm, List<SaleRecord>>(
      SalesVm.new,
      retry: (_, _) => null,
    );
