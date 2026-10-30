class PurchaseConfirmState {
  const PurchaseConfirmState({
    this.busy = false,
    this.confirmed = false,
    this.uncertain = false,
    this.error,
  });
  final bool busy;
  final bool confirmed;
  final bool uncertain;
  final String? error;
}
