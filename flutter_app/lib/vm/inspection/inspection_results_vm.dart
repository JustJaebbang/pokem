import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/model/inspection/inspection_result.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class InspectionResultsVm extends AsyncNotifier<List<InspectionResult>> {
  InspectionResultsVm(this.number);
  final String number;
  @override
  Future<List<InspectionResult>> build() async {
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) return [];
    try {
      return await ref
          .read(inspectionRepositoryProvider)
          .results(number, token);
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

final inspectionResultsVmProvider = AsyncNotifierProvider.autoDispose
    .family<InspectionResultsVm, List<InspectionResult>, String>(
      InspectionResultsVm.new,
      retry: (_, _) => null,
    );
