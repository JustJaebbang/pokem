import 'package:pokem_app/model/purchase/purchase.dart';

class PurchaseCancellation {
  const PurchaseCancellation({
    required this.code,
    required this.purchaseCode,
    required this.buyerId,
    required this.status,
    required this.reason,
    this.responseReason,
    this.sellerId,
    this.date,
  });
  final String code, purchaseCode, buyerId, status, reason;
  final String? responseReason, sellerId, date;
  factory PurchaseCancellation.fromJson(Map<String, dynamic> json) =>
      PurchaseCancellation(
        code: json['purchase_cancel_code'] as String,
        purchaseCode: json['purchase_item_purchase_item_code'] as String,
        buyerId: json['user_user_id'] as String,
        status: json['purchase_cancel_status'] as String,
        reason: json['purchase_cancel_reason'] as String,
        responseReason: json['response_reason'] as String?,
        sellerId: json['seller_user_id'] as String?,
        date: json['purchase_cancel_date'] as String?,
      );
}

class PurchaseCancelSnapshot {
  const PurchaseCancelSnapshot(this.purchase, this.cancellation);
  final Purchase purchase;
  final PurchaseCancellation? cancellation;
  bool get canRequest => cancellation == null && purchase.canConfirm;
}

enum CancelDecision {
  approve('승인', 'approve'),
  reject('거절', 'reject');

  const CancelDecision(this.label, this.path);
  final String label, path;
}
