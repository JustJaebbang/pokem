import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/consignment/consignment.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class ConsignmentVm extends AsyncNotifier<ConsignmentDetail?> {
  ConsignmentVm(this.source);
  final ConsignmentSource source;
  @override
  Future<ConsignmentDetail?> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return null;
    try {
      return await ref
          .read(consignmentRepositoryProvider)
          .get(source, session.account.id, session.token);
    } on ConsignmentException catch (e) {
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

final consignmentVmProvider = AsyncNotifierProvider.autoDispose
    .family<ConsignmentVm, ConsignmentDetail?, ConsignmentSource>(
      ConsignmentVm.new,
      retry: (_, _) => null,
    );
