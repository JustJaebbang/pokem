import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/profile/quit_state.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class QuitVm extends Notifier<QuitState> {
  @override
  QuitState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(load);
    return const QuitState(loading: true);
  }

  bool current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> load() async {
    if (state.busy) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.account.role != AccountRole.user) {
      state = const QuitState(error: '일반 사용자 계정으로 로그인해주세요.');
      return;
    }
    final uncertain = state.uncertain;
    state = QuitState(loading: true, uncertain: uncertain);
    try {
      final balance = await ref
          .read(quitRepositoryProvider)
          .balance(session.account.id, session.token);
      if (!current(session.token)) return;
      state = QuitState(
        balance: balance,
        uncertain: uncertain,
        error: uncertain
            ? '아직 계정이 조회됩니다. 탈퇴 결과가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.'
            : null,
      );
    } catch (e) {
      if (!current(session.token)) return;
      state = QuitState(
        uncertain: uncertain,
        error: e is QuitException ? e.message : '회원정보를 불러오지 못했습니다.',
      );
      if (e is QuitException && [401, 404].contains(e.status)) {
        await ref
            .read(loginVmProvider.notifier)
            .finishWithdrawal(confirmed: false);
      }
    }
  }

  Future<void> submit(String reason, {required bool acknowledged}) async {
    if (state.loading || state.busy || state.uncertain) return;
    if (!acknowledged) {
      state = QuitState(balance: state.balance, error: '탈퇴 안내를 확인해주세요.');
      return;
    }
    if (reason.trim().length > 200) {
      state = QuitState(
        balance: state.balance,
        error: '탈퇴 사유는 200자 이내로 입력해주세요.',
      );
      return;
    }
    if (state.balance != 0) {
      state = QuitState(balance: state.balance, error: '포켐머니 잔액을 확인하고 정리해주세요.');
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.account.role != AccountRole.user) return;
    state = const QuitState(busy: true, balance: 0);
    try {
      await ref
          .read(quitRepositoryProvider)
          .quit(session.account.id, session.token, reason.trim());
      if (current(session.token)) {
        await ref
            .read(loginVmProvider.notifier)
            .finishWithdrawal(confirmed: true);
      }
    } catch (e) {
      if (!current(session.token)) return;
      final uncertain = e is! QuitException || e.uncertain;
      state = QuitState(
        balance: 0,
        uncertain: uncertain,
        error: uncertain ? '탈퇴 결과를 확인하지 못했습니다. 처리 상태 확인을 눌러주세요.' : e.message,
      );
      if (e is QuitException && [401, 404].contains(e.status)) {
        await ref
            .read(loginVmProvider.notifier)
            .finishWithdrawal(confirmed: false);
      }
    }
  }
}

final quitVmProvider = NotifierProvider<QuitVm, QuitState>(QuitVm.new);
