import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:pokem_app/vm/wallet/state/money_transfer_state.dart';

class MoneyTransferVm extends Notifier<MoneyTransferState> {
  MoneyTransferVm(this.action);
  final MoneyAction action;
  static const maxMoney = 2147483647;
  @override
  MoneyTransferState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(refreshBalance);
    return const MoneyTransferState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  String? validateAccount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '은행명과 계좌번호를 입력해주세요.';
    if (text.length > 45) return '계좌 정보는 45자 이내로 입력해주세요.';
    return null;
  }

  String? validateAmount(String? value) {
    final text = value ?? '';
    final amount = int.tryParse(text);
    if (!RegExp(r'^\d+$').hasMatch(text) || amount == null || amount <= 0) {
      return '금액을 입력해주세요.';
    }
    if (amount > maxMoney) return '금액은 2,147,483,647원 이하여야 합니다.';
    final balance = state.balance;
    if (balance != null && action == MoneyAction.exchange && amount > balance) {
      return '포켐머니 잔액이 부족합니다.';
    }
    if (balance != null &&
        action == MoneyAction.recharge &&
        amount > maxMoney - balance) {
      return '충전 가능한 잔액 한도를 초과합니다.';
    }
    return null;
  }

  void accountChanged(String value) {
    if (!state.locked) state = state.copyWith(account: value, clearError: true);
  }

  void amountChanged(String value) {
    if (!state.locked) state = state.copyWith(amount: value, clearError: true);
  }

  void addAmount(int value) {
    if (state.locked) return;
    final amount = (int.tryParse(state.amount) ?? 0) + value;
    if (amount > maxMoney) {
      state = state.copyWith(error: '금액은 2,147,483,647원 이하여야 합니다.');
      return;
    }
    state = state.copyWith(amount: amount.toString(), clearError: true);
  }

  Future<void> refreshBalance() async {
    if (!ref.mounted || state.submitting) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final balance = await ref
          .read(walletRepositoryProvider)
          .balance(session.account.id, session.token);
      if (_current(session.token)) {
        state = state.copyWith(balance: balance, loading: false);
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = state.copyWith(
        loading: false,
        error: e is WalletException ? e.message : '잔액을 불러오지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  Future<void> submit() async {
    if (state.locked || state.loading) return;
    final validation =
        validateAccount(state.account) ?? validateAmount(state.amount);
    if (validation != null || state.balance == null) {
      state = state.copyWith(error: validation ?? '잔액을 먼저 확인해주세요.');
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final receipt = await ref
          .read(walletRepositoryProvider)
          .transfer(
            action,
            state.account.trim(),
            int.parse(state.amount),
            session.token,
          );
      if (!_current(session.token)) return;
      state = state.copyWith(
        submitting: false,
        balance: receipt.balance,
        receipt: receipt,
      );
      ref.invalidate(walletVmProvider);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = e is! WalletException || e.uncertain;
      state = state.copyWith(
        submitting: false,
        uncertain: uncertain,
        error: uncertain
            ? '처리 결과를 확인하지 못했습니다. 다시 요청하지 말고 내역을 확인해주세요.'
            : e.message,
      );
      ref.invalidate(walletVmProvider);
      await _unauthorized(e);
    }
  }

  void newTransfer() {
    if (state.receipt == null || state.submitting || state.uncertain) return;
    state = MoneyTransferState(balance: state.balance, loading: false);
    Future.microtask(refreshBalance);
  }

  Future<void> _unauthorized(Object e) async {
    if (e is WalletException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

// 응답 유실 후 화면을 닫고 다시 열어도 같은 세션에서는 재요청을 막습니다.
final moneyTransferVmProvider =
    NotifierProvider.family<MoneyTransferVm, MoneyTransferState, MoneyAction>(
      MoneyTransferVm.new,
    );
