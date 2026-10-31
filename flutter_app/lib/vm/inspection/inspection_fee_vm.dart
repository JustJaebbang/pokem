import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_fee.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class InspectionFeeVm extends AsyncNotifier<InspectionFee?> {
  InspectionFeeVm(this.number);
  final String number;
  @override
  Future<InspectionFee?> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) return null;
    try {
      return await ref
          .read(inspectionFeeRepositoryProvider)
          .getFee(number, token);
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

final inspectionFeeVmProvider = AsyncNotifierProvider.autoDispose
    .family<InspectionFeeVm, InspectionFee?, String>(
      InspectionFeeVm.new,
      retry: (_, _) => null,
    );
