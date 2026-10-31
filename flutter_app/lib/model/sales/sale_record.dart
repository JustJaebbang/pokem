class SaleRecord {
  const SaleRecord({
    required this.code,
    required this.productCode,
    required this.type,
    this.title,
    this.image,
    this.status,
    this.askingPrice,
    this.paidPrice,
    this.postedAt,
    this.completedAt,
  });
  final String code, productCode, type;
  final String? title, image, status, postedAt, completedAt;
  final int? askingPrice, paidPrice;
  String get typeLabel => type == 'consign' ? '대리판매' : '일반판매';
  int? get displayPrice => status == '판매중' ? askingPrice : paidPrice;
  String get priceLabel => status == '판매중' ? '판매가' : '결제금액';
  factory SaleRecord.fromJson(Map<String, dynamic> json) => SaleRecord(
    code: json['sale_code'] as String,
    productCode: json['product_code'] as String,
    type: json['sale_type'] as String,
    title: json['title'] as String?,
    image: json['image'] as String?,
    status: json['status'] as String?,
    askingPrice: json['asking_price'] as int?,
    paidPrice: json['paid_price'] as int?,
    postedAt: json['posted_at'] as String?,
    completedAt: json['completed_at'] as String?,
  );
}

class SalesException implements Exception {
  const SalesException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}
