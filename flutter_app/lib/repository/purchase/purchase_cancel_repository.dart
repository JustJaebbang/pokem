import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';

class PurchaseCancelRepository {
  PurchaseCancelRepository(this._api);
  final PurchaseApiService _api;
  Future<PurchaseCancelSnapshot> snapshot(String code, String token) async {
    final results = await Future.wait<Object?>([
      _api.getPurchase(code, token),
      _api.cancellation(code, token),
    ]);
    return PurchaseCancelSnapshot(
      results[0] as Purchase,
      results[1] as PurchaseCancellation?,
    );
  }

  Future<PurchaseCancellation> request(
    String code,
    String reason,
    String token,
  ) => _api.requestCancellation(code, reason, token);
  Future<PurchaseCancellation> withdraw(
    PurchaseCancellation current,
    String token,
  ) => _api.withdrawCancellation(current, token);
}
