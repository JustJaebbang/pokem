typedef DeliverySource = ({String? purchaseCode, String? returnNo});

class Delivery {
  const Delivery({
    required this.number,
    required this.userId,
    required this.companyCode,
    this.purchaseCode,
    this.returnNo,
    this.date,
    this.status,
  });
  final String number, userId, companyCode;
  final String? purchaseCode, returnNo, date, status;
  bool matches(DeliverySource source) => source.purchaseCode != null
      ? purchaseCode == source.purchaseCode && returnNo == null
      : returnNo == source.returnNo && purchaseCode == null;
  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    number: json['delivery_no'] as String,
    userId: json['user_user_id'] as String,
    companyCode: json['delivery_company_delivery_company_code'] as String,
    purchaseCode: json['purchase_item_code'] as String?,
    returnNo: json['return_no'] as String?,
    date: json['delivery_date'] as String?,
    status: json['delivery_status'] as String?,
  );
}

class DeliveryException implements Exception {
  const DeliveryException(this.message, {this.status});
  final String message;
  final int? status;
}
