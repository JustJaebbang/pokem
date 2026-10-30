class BuyerProfile {
  const BuyerProfile({required this.address, required this.balance});
  final String address;
  final int balance;
  factory BuyerProfile.fromJson(Map<String, dynamic> json) => BuyerProfile(
    address: json['user_address'] as String,
    balance: json['user_money'] as int,
  );
}

class Purchase {
  const Purchase({
    required this.code,
    required this.productCode,
    required this.status,
    this.date,
    this.title,
    this.image,
    this.paidPrice,
    this.confirmedAt,
  });
  final String code;
  final String productCode;
  final String status;
  final String? date;
  final String? title;
  final String? image;
  final int? paidPrice;
  final String? confirmedAt;
  bool get isConfirmed => status == '구매확정' && confirmedAt != null;
  bool get canConfirm => status == '거래중' && confirmedAt == null;
  String get statusLabel => status == '구매확정' ? '거래완료' : status;
  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
    code: json['purchase_item_code'] as String,
    productCode: json['sell_product_sell_product_code'] as String,
    status: json['purchase_item_status'] as String? ?? '거래중',
    date: json['purchase_item_date'] as String?,
    title: json['sell_product_title'] as String?,
    image: json['sell_product_image'] as String?,
    paidPrice: json['cybermoney_pay_price'] as int?,
    confirmedAt: json['purchase_item_confirmed_at'] as String?,
  );
}

class PurchaseException implements Exception {
  const PurchaseException(this.message, {this.status, this.uncertain = false});
  final String message;
  final int? status;
  final bool uncertain;
  @override
  String toString() => message;
}

class PurchaseConfirmReceipt {
  const PurchaseConfirmReceipt({
    required this.code,
    required this.productCode,
    required this.confirmedAt,
  });
  final String code;
  final String productCode;
  final String confirmedAt;
}
