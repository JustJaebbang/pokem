class InspectionFeePaymentState {
  const InspectionFeePaymentState({
    this.busy = false,
    this.uncertain = false,
    this.completed = false,
    this.error,
  });
  final bool busy, uncertain, completed;
  final String? error;
}
