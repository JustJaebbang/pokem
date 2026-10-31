import 'package:pokem_app/model/review/review_record.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/service/review/review_api_service.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';

class ReviewRepository {
  ReviewRepository(this._api, this._purchases);
  final ReviewApiService _api;
  final PurchaseApiService _purchases;
  Future<List<ReviewRecord>> list(String productCode) => _api.list(productCode);
  Future<List<ReviewRecord>> listForSeller(String sellerId) =>
      _api.listForSeller(sellerId);
  Future<ReviewSnapshot> snapshot(String code, String token) async {
    final purchase = await _purchases.getPurchase(code, token);
    final rows = (await _api.list(purchase.productCode))
        .where((row) => row.purchaseCode == code)
        .toList();
    if (rows.length > 1) throw const ReviewException('후기 정보가 중복되어 있습니다.');
    return ReviewSnapshot(purchase, rows.firstOrNull);
  }

  Future<ReviewRecord> create(
    Purchase purchase,
    int rating,
    String contents,
    String token,
  ) async {
    final result = await _api.create(purchase.code, rating, contents, token);
    if (result.productCode != purchase.productCode) {
      throw const ReviewException('후기 저장 결과를 확인하지 못했습니다.', uncertain: true);
    }
    return result;
  }
}
