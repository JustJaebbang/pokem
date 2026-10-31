class QuitState {
  const QuitState({
    this.loading = false,
    this.busy = false,
    this.uncertain = false,
    this.balance,
    this.error,
  });
  final bool loading, busy, uncertain;
  final int? balance;
  final String? error;
}

class QuitException implements Exception {
  const QuitException(this.message, {this.status, this.uncertain = false});
  final String message;
  final int? status;
  final bool uncertain;
}
