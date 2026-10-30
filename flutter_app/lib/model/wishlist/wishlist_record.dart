import 'package:pokem_app/model/products/product.dart';

class WishlistRecord {
  const WishlistRecord({
    required this.code,
    required this.userId,
    required this.isWished,
  });
  final String code, userId;
  final bool isWished;
  factory WishlistRecord.fromJson(Map<String, dynamic> json) {
    final status = json['wishlist_status'] as String;
    if (status != '관심' && status != '해제') {
      throw const FormatException('Invalid wishlist status');
    }
    return WishlistRecord(
      code: json['sell_product_sell_product_code'] as String,
      userId: json['user_user_id'] as String,
      isWished: status == '관심',
    );
  }
}

class WishlistSnapshot {
  const WishlistSnapshot({required this.codes, required this.products});
  final Set<String> codes;
  final List<Product> products;
}
