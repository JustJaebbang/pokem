class ProductPayment {
  const ProductPayment({
    required this.code,
    required this.purchaseCode,
    required this.ownerId,
    required this.amount,
    required this.status,
    required this.date,
    this.productCode,
    this.title,
    this.image,
  });
  final String code, purchaseCode, ownerId, status, date;
  final int amount;
  final String? productCode, title, image;
  String get displayTitle =>
      title == null || title!.trim().isEmpty ? '상품 정보 없음' : title!;
  factory ProductPayment.fromJson(Map<String, dynamic> j) => ProductPayment(
    code: j['cybermoney_pay_code'] as String,
    purchaseCode: j['purchase_item_purchase_item_code'] as String,
    ownerId: j['user_user_id'] as String,
    amount: j['cybermoney_pay_price'] as int,
    status: j['cybermoney_pay_status'] as String,
    date: j['cybermoney_pay_date'] as String,
    productCode: j['sell_product_sell_product_code'] as String?,
    title: j['sell_product_title'] as String?,
    image: j['sell_product_image'] as String?,
  );
}

class PaymentException implements Exception {
  const PaymentException(this.message, {this.status});
  final String message;
  final int? status;
}
