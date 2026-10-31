class InspectionRequest {
  const InspectionRequest({
    required this.number,
    required this.userId,
    required this.amount,
    this.date,
    this.managerId,
  });
  final String number, userId;
  final int amount;
  final String? date, managerId;
  factory InspectionRequest.fromJson(Map<String, dynamic> json) =>
      InspectionRequest(
        number: json['inspection_request_no'] as String,
        userId: json['user_user_id'] as String,
        amount: (json['inspection_request_amount'] as int?) ?? 0,
        date: json['inspection_request_date'] as String?,
        managerId: json['manager_manager_id'] as String?,
      );
}

class InspectionItem {
  const InspectionItem({
    required this.code,
    required this.requestNumber,
    required this.serialCode,
    required this.status,
    required this.userId,
    this.grade,
    this.reason,
    this.choice,
    this.managerId,
  });
  final String code, requestNumber, serialCode, status, userId;
  final String? grade, reason, choice, managerId;
  factory InspectionItem.fromJson(Map<String, dynamic> json) => InspectionItem(
    code: json['inspect_code'] as String,
    requestNumber: json['inspect_requested_no'] as String,
    serialCode: json['inspect_serial_code'] as String,
    status: json['inspect_status'] as String,
    userId: json['user_user_id'] as String,
    grade: json['inspect_grade'] as String?,
    reason: json['inspect_grade_reason'] as String?,
    choice: json['inspect_user_choice'] as String?,
    managerId: json['manager_manager_id'] as String?,
  );
}

class ConsignmentRecord {
  const ConsignmentRecord({
    required this.code,
    required this.inspectionCode,
    required this.productCode,
    required this.userId,
    this.completedAt,
  });
  final String code, inspectionCode, productCode, userId;
  final String? completedAt;
  factory ConsignmentRecord.fromJson(Map<String, dynamic> json) =>
      ConsignmentRecord(
        code: json['post_consign_item_code'] as String,
        inspectionCode: json['inspect_inspect_code'] as String,
        productCode: json['sell_product_sell_product_code'] as String,
        userId: json['user_user_id'] as String,
        completedAt: json['post_consign_item_complete_date'] as String?,
      );
}

class ManagerDashboard {
  const ManagerDashboard({
    required this.requests,
    required this.inspections,
    required this.consignments,
  });
  final List<InspectionRequest> requests;
  final List<InspectionItem> inspections;
  final List<ConsignmentRecord> consignments;
  int countStatus(String status) =>
      inspections.where((item) => item.status == status).length;
}

class ManagerException implements Exception {
  const ManagerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
