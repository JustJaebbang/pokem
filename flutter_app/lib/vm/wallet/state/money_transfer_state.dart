import 'package:pokem_app/model/wallet/wallet_models.dart';

class MoneyTransferState {
  const MoneyTransferState({
    this.account = '',
    this.amount = '',
    this.balance,
    this.loading = true,
    this.submitting = false,
    this.uncertain = false,
    this.error,
    this.receipt,
  });
  final String account;
  final String amount;
  final int? balance;
  final bool loading;
  final bool submitting;
  final bool uncertain;
  final String? error;
  final MoneyReceipt? receipt;
  bool get locked => submitting || uncertain || receipt != null;
  MoneyTransferState copyWith({
    String? account,
    String? amount,
    int? balance,
    bool? loading,
    bool? submitting,
    bool? uncertain,
    String? error,
    bool clearError = false,
    MoneyReceipt? receipt,
  }) => MoneyTransferState(
    account: account ?? this.account,
    amount: amount ?? this.amount,
    balance: balance ?? this.balance,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    uncertain: uncertain ?? this.uncertain,
    error: clearError ? null : error ?? this.error,
    receipt: receipt ?? this.receipt,
  );
}
