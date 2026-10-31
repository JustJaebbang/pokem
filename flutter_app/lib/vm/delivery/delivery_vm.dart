import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/delivery/delivery.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class DeliveryVm extends AsyncNotifier<Delivery?> {
  DeliveryVm(this.source);
  final DeliverySource source;
  @override
  Future<Delivery?> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return null;
    try {
      return await ref
          .read(deliveryRepositoryProvider)
          .find(source, session.account.id, session.token);
    } on DeliveryException catch (e) {
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

final deliveryVmProvider = AsyncNotifierProvider.autoDispose
    .family<DeliveryVm, Delivery?, DeliverySource>(
      DeliveryVm.new,
      retry: (_, _) => null,
    );
