import 'package:pokem_app/model/purchase/purchase_cancellation.dart';

class SellerCancelDecisionState {
  const SellerCancelDecisionState({
    this.busy = false,
    this.uncertain = false,
    this.result,
    this.error,
  });
  final bool busy, uncertain;
  final PurchaseCancellation? result;
  final String? error;
}
