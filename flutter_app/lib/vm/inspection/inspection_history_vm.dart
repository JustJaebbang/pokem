import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class InspectionHistoryVm extends AsyncNotifier<List<InspectionRequest>> {
  @override
  Future<List<InspectionRequest>> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) return [];
    try {
      return await ref.read(inspectionRepositoryProvider).history(token);
    } on InspectionException catch (e) {
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

final inspectionHistoryVmProvider =
    AsyncNotifierProvider.autoDispose<
      InspectionHistoryVm,
      List<InspectionRequest>
    >(InspectionHistoryVm.new, retry: (_, _) => null);
