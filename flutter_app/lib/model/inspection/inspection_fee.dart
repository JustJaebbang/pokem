class InspectionFee {
  const InspectionFee({
    required this.number,
    required this.requestNumber,
    required this.status,
    required this.date,
    this.price,
  });
  final String number, requestNumber, status, date;
  final int? price;
  factory InspectionFee.fromJson(Map<String, dynamic> json) => InspectionFee(
    number: json['pay_no'] as String,
    requestNumber: json['inspection_request_inspection_request_no'] as String,
    status: json['pay_status'] as String,
    date: json['pay_date'] as String,
    price: json['pay_price'] as int?,
  );
}
