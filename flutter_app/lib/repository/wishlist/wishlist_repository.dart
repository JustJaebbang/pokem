import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/wishlist/wishlist_record.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/wishlist/wishlist_api_service.dart';

class WishlistRepository {
  WishlistRepository(this._api, this._products);
  final WishlistApiService _api;
  final ProductRepository _products;
  Future<WishlistSnapshot> getSnapshot(String userId, String token) async {
    final records = await _api.getRecords(userId, token);
    if (records.any((r) => r.userId != userId)) {
      throw const ProductException('관심상품의 사용자 정보를 확인해주세요.');
    }
    final codes = records.where((r) => r.isWished).map((r) => r.code).toSet();
    if (codes.isEmpty) {
      return WishlistSnapshot(codes: codes, products: const []);
    }
    final all = await _products.getProducts();
    final byCode = {for (final p in all) p.code: p};
    return WishlistSnapshot(
      codes: codes,
      products: [
        for (final code in codes)
          if (byCode.containsKey(code)) byCode[code]!,
      ],
    );
  }

  Future<WishlistRecord> setWished(
    String userId,
    String code,
    bool wished,
    String token,
  ) => _api.setWished(userId, code, wished, token);
}
