import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';

class SellerCancelRepository {
  SellerCancelRepository(this._api);
  final PurchaseApiService _api;
  Future<List<PurchaseCancellation>> requests(
    String sellerId,
    String token,
  ) async =>
      (await _api.cancellations(token))
          .where((item) => item.sellerId == sellerId)
          .toList();
  Future<PurchaseCancellation> get(String code, String token) =>
      _api.getCancellation(code, token);
  Future<PurchaseCancellation> decide(
    PurchaseCancellation current,
    CancelDecision decision,
    String reason,
    String token,
  ) => _api.decideCancellation(current, decision, reason, token);
}
