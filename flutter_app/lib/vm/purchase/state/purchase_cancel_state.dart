import 'package:pokem_app/model/purchase/purchase_cancellation.dart';

enum CancelPending { request, withdraw }

class PurchaseCancelState {
  const PurchaseCancelState({
    this.snapshot,
    this.loading = true,
    this.busy = false,
    this.pending,
    this.error,
  });
  final PurchaseCancelSnapshot? snapshot;
  final bool loading, busy;
  final CancelPending? pending;
  final String? error;
}
