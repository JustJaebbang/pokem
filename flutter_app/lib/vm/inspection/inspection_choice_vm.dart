import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/vm/mypage/pending_actions_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/model/inspection/inspection_result.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/inspection_results_vm.dart';
import 'package:pokem_app/vm/inspection/state/inspection_choice_state.dart';

class InspectionChoiceVm extends Notifier<InspectionChoiceState> {
  InspectionChoiceVm(this.code);
  final String code;
  @override
  InspectionChoiceState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const InspectionChoiceState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> choose(InspectionChoice choice) async {
    if (state.busy || state.uncertain || state.result != null) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = const InspectionChoiceState(busy: true);
    var submitted = false;
    try {
      final repo = ref.read(inspectionRepositoryProvider);
      final item = await repo.result(code, session.token);
      if (!_current(session.token)) return;
      if (item.hasChoice) {
        _complete(item);
        return;
      }
      if (!item.canChoose) {
        state = const InspectionChoiceState(error: '검수완료 후 선택할 수 있습니다.');
        ref.invalidate(inspectionResultsVmProvider(item.requestNumber));
        ref.invalidate(pendingActionsVmProvider);
        ref.invalidate(notificationsVmProvider);
        return;
      }
      submitted = true;
      final saved = await repo.choose(code, choice, session.token);
      if (_current(session.token)) _complete(saved);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = submitted && (e is! InspectionException || e.uncertain);
      state = InspectionChoiceState(
        uncertain: uncertain,
        error: uncertain
            ? '선택 결과를 확인하지 못했습니다. 처리 상태를 확인해주세요.'
            : e is InspectionException
            ? e.message
            : '검수 정보를 확인하지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  Future<void> checkResult() async {
    if (state.busy || !state.uncertain) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const InspectionChoiceState(busy: true, uncertain: true);
    try {
      final item = await ref
          .read(inspectionRepositoryProvider)
          .result(code, session.token);
      if (!_current(session.token)) return;
      if (item.hasChoice) {
        _complete(item);
      } else {
        state = const InspectionChoiceState(
          uncertain: true,
          error: '아직 선택이 확인되지 않았습니다. 잠시 후 다시 확인해주세요.',
        );
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = InspectionChoiceState(
        uncertain: true,
        error: e is InspectionException ? e.message : '처리 상태를 확인하지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  void _complete(InspectionResult item) {
    state = InspectionChoiceState(result: item);
    ref.invalidate(inspectionResultsVmProvider(item.requestNumber));
    ref.invalidate(pendingActionsVmProvider);
    ref.invalidate(notificationsVmProvider);
  }

  Future<void> _unauthorized(Object e) async {
    if (e is InspectionException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final inspectionChoiceVmProvider =
    NotifierProvider.family<InspectionChoiceVm, InspectionChoiceState, String>(
      InspectionChoiceVm.new,
    );
