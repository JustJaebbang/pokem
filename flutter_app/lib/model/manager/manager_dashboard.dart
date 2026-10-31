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
    this.expiresAt,
    this.returnCompanyCode,
  });
  final String code, inspectionCode, productCode, userId;
  final String? completedAt, expiresAt, returnCompanyCode;
  factory ConsignmentRecord.fromJson(Map<String, dynamic> json) =>
      ConsignmentRecord(
        code: json['post_consign_item_code'] as String,
        inspectionCode: json['inspect_inspect_code'] as String,
        productCode: json['sell_product_sell_product_code'] as String,
        userId: json['user_user_id'] as String,
        completedAt: json['post_consign_item_complete_date'] as String?,
        expiresAt: json['post_consign_item_expires_at'] as String?,
        returnCompanyCode: json['return_delivery_company_code'] as String?,
      );
}

class ProposalRecord {
  const ProposalRecord({
    required this.number,
    required this.caseCode,
    this.name,
    this.contents,
    this.date,
    this.status,
    this.managerId,
    this.directorId,
  });
  final String number, caseCode;
  final String? name, contents, date, status, managerId, directorId;
  factory ProposalRecord.fromJson(Map<String, dynamic> json) => ProposalRecord(
    number: json['proposal_no'] as String,
    caseCode: json['case_case_code'] as String,
    name: json['proposal_name'] as String?,
    contents: json['proposal_contents'] as String?,
    date: json['proposal_date'] as String?,
    status: json['proposal_status'] as String?,
    managerId: json['manager_manager_id'] as String?,
    directorId: json['director_director_id'] as String?,
  );
}

class OrderRecord {
  const OrderRecord({
    required this.number,
    required this.proposalNumber,
    required this.caseCode,
    required this.managerId,
    required this.companyCode,
    this.price,
    this.amount,
    this.date,
  });
  final String number, proposalNumber, caseCode, managerId, companyCode;
  final int? price, amount;
  final String? date;
  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
    number: json['order_no'] as String,
    proposalNumber: json['proposal_proposal_no'] as String,
    caseCode: json['case_case_code'] as String,
    managerId: json['manager_manager_id'] as String,
    companyCode: json['product_company_product_company_code'] as String,
    price: (json['order_price'] as num?)?.toInt(),
    amount: (json['order_amount'] as num?)?.toInt(),
    date: json['order_date'] as String?,
  );
}

class ReceiveRecord {
  const ReceiveRecord({
    required this.number,
    required this.orderNumber,
    required this.managerId,
    required this.companyCode,
    this.price,
    this.amount,
    this.date,
  });
  final String number, orderNumber, managerId, companyCode;
  final int? price, amount;
  final String? date;
  factory ReceiveRecord.fromJson(Map<String, dynamic> json) => ReceiveRecord(
    number: json['receive_no'] as String,
    orderNumber: json['order_order_no'] as String,
    managerId: json['manager_manager_id'] as String,
    companyCode: json['product_company_product_company_code'] as String,
    price: (json['receive_price'] as num?)?.toInt(),
    amount: (json['receive_amount'] as num?)?.toInt(),
    date: json['receive_date'] as String?,
  );
}

class CaseRecord {
  const CaseRecord({
    required this.code,
    required this.stock,
    this.serialNo,
    this.price,
  });
  final String code;
  final String? serialNo;
  final int stock;
  final int? price;
  factory CaseRecord.fromJson(Map<String, dynamic> json) => CaseRecord(
    code: json['case_code'] as String,
    serialNo: json['case_serial_no'] as String?,
    stock: (json['case_stock'] as num).toInt(),
    price: (json['case_price'] as num?)?.toInt(),
  );
}

class CompanyRecord {
  const CompanyRecord({required this.code, this.name});
  final String code;
  final String? name;
  factory CompanyRecord.product(Map<String, dynamic> json) => CompanyRecord(
    code: json['product_company_code'] as String,
    name: json['product_company_name'] as String?,
  );
  factory CompanyRecord.delivery(Map<String, dynamic> json) => CompanyRecord(
    code: json['delivery_company_code'] as String,
    name: json['delivery_company_name'] as String?,
  );
}

class ManagerDashboard {
  const ManagerDashboard({
    required this.requests,
    required this.inspections,
    required this.consignments,
    required this.proposals,
    required this.orders,
    required this.receives,
    required this.cases,
    required this.productCompanies,
    required this.deliveryCompanies,
  });
  final List<InspectionRequest> requests;
  final List<InspectionItem> inspections;
  final List<ConsignmentRecord> consignments;
  final List<ProposalRecord> proposals;
  final List<OrderRecord> orders;
  final List<ReceiveRecord> receives;
  final List<CaseRecord> cases;
  final List<CompanyRecord> productCompanies, deliveryCompanies;
  int countStatus(String status) =>
      inspections.where((item) => item.status == status).length;
  int get unassignedRequests =>
      requests.where((item) => item.managerId == null).length;
  int get pendingProposals =>
      proposals.where((item) => item.status == '대기').length;
  List<InspectionItem> get consignmentCandidates {
    final registered = consignments.map((item) => item.inspectionCode).toSet();
    return inspections
        .where(
          (item) =>
              item.status == '검수완료' &&
              item.choice == '대리판매' &&
              !registered.contains(item.code),
        )
        .toList();
  }
}

class ManagerException implements Exception {
  const ManagerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
