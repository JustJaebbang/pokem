class DepositRefund {
  const DepositRefund({
    required this.number,
    required this.payNumber,
    this.price,
    this.date,
  });
  final String number, payNumber;
  final int? price;
  final String? date;
  String? get zonedDate => date == null
      ? null
      : RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(date!)
      ? date
      : '${date!.replaceFirst(' ', 'T')}+09:00';
  factory DepositRefund.fromJson(Map<String, dynamic> json) => DepositRefund(
    number: json['deposit_refund_no'] as String,
    payNumber: json['pay_pay_no'] as String,
    price: json['deposit_refund_price'] as int?,
    date: json['deposit_refund_date'] as String?,
  );
}
