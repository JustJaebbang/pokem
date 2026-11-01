import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/inspection_history_vm.dart';
import 'package:pokem_app/vm/inspection/state/inspection_create_state.dart';

class InspectionCreateVm extends Notifier<InspectionCreateState> {
  @override
  InspectionCreateState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const InspectionCreateState();
  }

  String? validateAmount(String? value, [int? unitPrice]) {
    final text = value ?? '';
    final amount = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) || amount == null || amount < 1) {
      return '검수할 카드 수량을 입력해주세요.';
    }
    final maximum = unitPrice == null || unitPrice == 0
        ? 214748
        : 2147483647 ~/ unitPrice;
    if (amount > maximum) return '현재 검수 단가로 신청 가능한 수량을 초과했습니다.';
    return null;
  }

  int? estimatedPrice(String text, int unitPrice) =>
      validateAmount(text, unitPrice) == null
      ? int.parse(text) * unitPrice
      : null;

  Future<void> submit(String text) async {
    if (state.locked) return;
    final error = validateAmount(text);
    if (error != null) {
      state = InspectionCreateState(error: error);
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = const InspectionCreateState(submitting: true);
    try {
      final request = await ref
          .read(inspectionRepositoryProvider)
          .create(int.parse(text), session.token);
      if (!ref.mounted ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      state = InspectionCreateState(request: request);
      ref.invalidate(inspectionHistoryVmProvider);
    } catch (e) {
      if (!ref.mounted ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      final uncertain = e is! InspectionException || e.uncertain;
      state = InspectionCreateState(
        uncertain: uncertain,
        error: uncertain
            ? '신청 결과를 확인하지 못했습니다. 중복 신청하지 말고 신청내역을 확인해주세요.'
            : e.message,
      );
      ref.invalidate(inspectionHistoryVmProvider);
      if (e is InspectionException && e.status == 401) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
    }
  }

  void newRequest() {
    if (state.request != null && !state.submitting) {
      state = const InspectionCreateState();
    }
  }
}

// 화면 재진입 시에도 결과 불확실 상태를 보존하고 인증 변경 시 초기화합니다.
final inspectionCreateVmProvider =
    NotifierProvider<InspectionCreateVm, InspectionCreateState>(
      InspectionCreateVm.new,
    );

// Director가 변경한 최신 단가를 신청 화면 진입 시 조회한다.
final inspectionUnitPriceProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final session = ref.watch(loginVmProvider.select((state) => state.session));
  if (session == null || session.isExpired) {
    throw const InspectionException('로그인이 필요합니다.');
  }
  return ref.read(inspectionRepositoryProvider).pricing(session.token);
});
