import 'package:pokem_app/model/wallet/product_payment.dart';
import 'package:pokem_app/service/wallet/payment_api_service.dart';

class PaymentRepository {
  PaymentRepository(this._api);
  final PaymentApiService _api;
  Future<List<ProductPayment>> history(String ownerId, String token) async {
    final rows = await _api.history(token);
    if (rows.any((r) => r.ownerId != ownerId)) {
      throw const PaymentException('결제내역의 사용자가 일치하지 않습니다.');
    }
    return rows;
  }

  Future<ProductPayment> detail(
    String code,
    String ownerId,
    String token,
  ) async {
    final row = await _api.detail(code, token);
    if (row.code != code || row.ownerId != ownerId) {
      throw const PaymentException('요청한 결제내역과 응답이 일치하지 않습니다.');
    }
    return row;
  }
}
