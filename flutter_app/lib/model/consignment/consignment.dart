import 'package:pokem_app/model/products/product.dart';

typedef ConsignmentSource = ({String? code, String? inspectCode});

class Consignment {
  const Consignment({
    required this.code,
    required this.inspectCode,
    required this.productCode,
    required this.ownerId,
    this.registeredAt,
    this.completedAt,
    this.expiresAt,
    this.intention,
  });
  final String code, inspectCode, productCode, ownerId;
  final String? registeredAt, completedAt, expiresAt, intention;
  bool get returning => intention == '반환';
  factory Consignment.fromJson(Map<String, dynamic> j) => Consignment(
    code: j['post_consign_item_code'] as String,
    inspectCode: j['inspect_inspect_code'] as String,
    productCode: j['sell_product_sell_product_code'] as String,
    ownerId: j['user_user_id'] as String,
    registeredAt: j['post_consign_item_date'] as String?,
    completedAt: j['post_consign_item_complete_date'] as String?,
    expiresAt: j['post_consign_item_expires_at'] as String?,
    intention: j['post_consign_item_intention'] as String?,
  );
}

class ConsignmentDetail {
  const ConsignmentDetail(this.item, {this.product, this.productError});
  final Consignment item;
  final Product? product;
  final String? productError;
  String get status => item.returning
      ? '반환으로 전환됨'
      : item.completedAt != null
      ? '거래완료'
      : product?.status ?? '상품 상태 확인 불가';
}

class ConsignmentException implements Exception {
  const ConsignmentException(this.message, {this.status});
  final String message;
  final int? status;
}
