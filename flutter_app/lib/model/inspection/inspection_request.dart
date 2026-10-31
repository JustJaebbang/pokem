class InspectionRequest {
  const InspectionRequest({
    required this.number,
    this.date,
    this.amount,
    this.managerId,
  });
  final String number;
  final String? date;
  final int? amount;
  String? get zonedDate => date == null
      ? null
      : RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(date!)
      ? date
      : '${date!.replaceFirst(' ', 'T')}+09:00';
  final String? managerId;
  factory InspectionRequest.fromJson(Map<String, dynamic> json) =>
      InspectionRequest(
        number: json['inspection_request_no'] as String,
        date: json['inspection_request_date'] as String?,
        amount: json['inspection_request_amount'] as int?,
        managerId: json['manager_manager_id'] as String?,
      );
}

class InspectionException implements Exception {
  const InspectionException(
    this.message, {
    this.status,
    this.uncertain = false,
  });
  final String message;
  final int? status;
  final bool uncertain;
  @override
  String toString() => message;
}
