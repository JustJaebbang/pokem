import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/vm/mypage/pending_actions_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_fee.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/inspection_fee_vm.dart';
import 'package:pokem_app/vm/inspection/state/inspection_fee_payment_state.dart';

class InspectionFeePaymentVm extends Notifier<InspectionFeePaymentState> {
  InspectionFeePaymentVm(this.number);
  final String number;
  @override
  InspectionFeePaymentState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const InspectionFeePaymentState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> complete(InspectionFee fee) async {
    if (state.busy ||
        state.uncertain ||
        state.completed ||
        fee.requestNumber != number ||
        fee.status != '결제대기' ||
        fee.price == null ||
        fee.price! < 0) {
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = const InspectionFeePaymentState(busy: true);
    try {
      await ref
          .read(inspectionFeeRepositoryProvider)
          .complete(fee, session.token);
      if (_current(session.token)) _completed();
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = e is! InspectionException || e.uncertain;
      state = InspectionFeePaymentState(
        uncertain: uncertain,
        error: uncertain ? '결제 결과를 확인하지 못했습니다. 처리 상태를 확인해주세요.' : e.message,
      );
      ref.invalidate(inspectionFeeVmProvider(number));
      await _unauthorized(e);
    }
  }

  Future<void> checkResult() async {
    if (state.busy || !state.uncertain) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const InspectionFeePaymentState(busy: true, uncertain: true);
    try {
      final fee = await ref
          .read(inspectionFeeRepositoryProvider)
          .getFee(number, session.token);
      if (!_current(session.token)) return;
      if (fee?.status == '결제완료') {
        _completed();
      } else {
        state = const InspectionFeePaymentState(
          uncertain: true,
          error: '아직 결제완료가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.',
        );
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = InspectionFeePaymentState(
        uncertain: true,
        error: e is InspectionException ? e.message : '처리 상태를 확인하지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  void _completed() {
    state = const InspectionFeePaymentState(completed: true);
    ref.invalidate(pendingActionsVmProvider);
    ref.invalidate(notificationsVmProvider);
    ref.invalidate(inspectionFeeVmProvider(number));
  }

  Future<void> _unauthorized(Object e) async {
    if (e is InspectionException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final inspectionFeePaymentVmProvider =
    NotifierProvider.family<
      InspectionFeePaymentVm,
      InspectionFeePaymentState,
      String
    >(InspectionFeePaymentVm.new);
