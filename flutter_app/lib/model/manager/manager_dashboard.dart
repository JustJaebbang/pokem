import 'package:pokem_app/model/products/product.dart';

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

class ReturnRecord {
  const ReturnRecord({
    required this.number,
    required this.inspectionCode,
    required this.userId,
    required this.status,
    this.managerId,
  });
  final String number, inspectionCode, userId, status;
  final String? managerId;
  factory ReturnRecord.fromJson(Map<String, dynamic> json) => ReturnRecord(
    number: json['return_no'] as String,
    inspectionCode: json['inspect_inspect_code'] as String,
    userId: json['user_user_id'] as String,
    status: (json['return_status'] as String?) ?? '반환접수',
    managerId: json['manager_manager_id'] as String?,
  );
}

class DeliveryRecord {
  const DeliveryRecord({
    required this.number,
    required this.status,
    required this.userId,
    required this.managerId,
    required this.companyCode,
    this.purchaseCode,
    this.returnNumber,
    this.productCode,
    this.inspectionCode,
    this.date,
  });
  final String number, status, userId, managerId;
  final String? companyCode;
  final String? purchaseCode, returnNumber, productCode, inspectionCode, date;
  factory DeliveryRecord.fromJson(Map<String, dynamic> json) => DeliveryRecord(
    number: json['delivery_no'] as String,
    status: (json['delivery_status'] as String?) ?? '배송준비',
    userId: json['user_user_id'] as String,
    managerId: json['manager_manager_id'] as String,
    companyCode: json['delivery_company_delivery_company_code'] as String?,
    purchaseCode: json['purchase_item_code'] as String?,
    returnNumber: json['return_no'] as String?,
    productCode: json['sell_product_sell_product_code'] as String?,
    inspectionCode: json['inspect_inspect_code'] as String?,
    date: json['delivery_date'] as String?,
  );
}

class DeliveryStatusHistoryRecord {
  const DeliveryStatusHistoryRecord({
    required this.id,
    required this.deliveryNumber,
    required this.changedStatus,
    required this.managerId,
    required this.changedAt,
    this.previousStatus,
    this.memo,
  });
  final int id;
  final String deliveryNumber, changedStatus, managerId, changedAt;
  final String? previousStatus, memo;
  factory DeliveryStatusHistoryRecord.fromJson(Map<String, dynamic> json) =>
      DeliveryStatusHistoryRecord(
        id: (json['history_id'] as num).toInt(),
        deliveryNumber: json['delivery_no'] as String,
        previousStatus: json['previous_status'] as String?,
        changedStatus: json['changed_status'] as String,
        managerId: json['manager_id'] as String,
        changedAt: json['changed_at'] as String,
        memo: json['memo'] as String?,
      );
}

class PayRecord {
  const PayRecord({
    required this.number,
    required this.status,
    required this.userId,
    required this.managerId,
    required this.requestNumber,
    this.price,
    this.date,
  });
  final String number, status, userId, managerId, requestNumber;
  final int? price;
  final String? date;
  factory PayRecord.fromJson(Map<String, dynamic> json) => PayRecord(
    number: json['pay_no'] as String,
    status: json['pay_status'] as String,
    userId: json['user_user_id'] as String,
    managerId: json['manager_manager_id'] as String,
    requestNumber: json['inspection_request_inspection_request_no'] as String,
    price: (json['pay_price'] as num?)?.toInt(),
    date: json['pay_date'] as String?,
  );
}

class ReceiptRecord {
  const ReceiptRecord({
    required this.number,
    required this.payNumber,
    required this.productCode,
    required this.userId,
    required this.managerId,
    this.amount,
    this.date,
  });
  final String number, payNumber, productCode, userId, managerId;
  final int? amount;
  final String? date;
  factory ReceiptRecord.fromJson(Map<String, dynamic> json) => ReceiptRecord(
    number: json['receipt_no'] as String,
    payNumber: json['pay_pay_no'] as String,
    productCode: json['sell_product_sell_product_code'] as String,
    userId: json['user_user_id'] as String,
    managerId: json['manager_manager_id'] as String,
    amount: (json['receipt_amount'] as num?)?.toInt(),
    date: json['receipt_date'] as String?,
  );
}

class RefundRecord {
  const RefundRecord({
    required this.number,
    required this.payNumber,
    required this.userId,
    required this.managerId,
    this.price,
    this.date,
  });
  final String number, payNumber, userId, managerId;
  final int? price;
  final String? date;
  factory RefundRecord.fromJson(Map<String, dynamic> json) => RefundRecord(
    number: json['deposit_refund_no'] as String,
    payNumber: json['pay_pay_no'] as String,
    userId: json['user_user_id'] as String,
    managerId: json['manager_manager_id'] as String,
    price: (json['deposit_refund_price'] as num?)?.toInt(),
    date: json['deposit_refund_date'] as String?,
  );
}

class DiscardRecord {
  const DiscardRecord({
    required this.productCode,
    required this.managerId,
    this.date,
  });
  final String productCode, managerId;
  final String? date;
  factory DiscardRecord.fromJson(Map<String, dynamic> json) => DiscardRecord(
    productCode: json['sell_product_sell_product_code'] as String,
    managerId: json['manager_manager_id'] as String,
    date: json['discard_date'] as String?,
  );
}

class PurchaseRecord {
  const PurchaseRecord({
    required this.code,
    required this.userId,
    required this.productCode,
    required this.status,
    this.date,
    this.title,
  });
  final String code, userId, productCode, status;
  final String? date, title;
  factory PurchaseRecord.fromJson(Map<String, dynamic> json) => PurchaseRecord(
    code: json['purchase_item_code'] as String,
    userId: json['user_user_id'] as String,
    productCode: json['sell_product_sell_product_code'] as String,
    status: (json['purchase_item_status'] as String?) ?? '거래중',
    date: json['purchase_item_date'] as String?,
    title: json['sell_product_title'] as String?,
  );
}

class ManagerDashboard {
  const ManagerDashboard({
    required this.products,
    required this.requests,
    required this.inspections,
    required this.consignments,
    required this.proposals,
    required this.orders,
    required this.receives,
    required this.cases,
    required this.productCompanies,
    required this.deliveryCompanies,
    required this.returns,
    required this.deliveries,
    required this.deliveryHistories,
    required this.pays,
    required this.receipts,
    required this.refunds,
    required this.discards,
    required this.purchases,
  });
  final List<Product> products;
  final List<InspectionRequest> requests;
  final List<InspectionItem> inspections;
  final List<ConsignmentRecord> consignments;
  final List<ProposalRecord> proposals;
  final List<OrderRecord> orders;
  final List<ReceiveRecord> receives;
  final List<CaseRecord> cases;
  final List<CompanyRecord> productCompanies, deliveryCompanies;
  final List<ReturnRecord> returns;
  final List<DeliveryRecord> deliveries;
  final List<DeliveryStatusHistoryRecord> deliveryHistories;
  final List<PayRecord> pays;
  final List<ReceiptRecord> receipts;
  final List<RefundRecord> refunds;
  final List<DiscardRecord> discards;
  final List<PurchaseRecord> purchases;
  int countStatus(String status) =>
      inspections.where((item) => item.status == status).length;
  int get unassignedRequests =>
      requests.where((item) => item.managerId == null).length;
  int get pendingProposals =>
      proposals.where((item) => item.status == '대기').length;
  int get unassignedReturns =>
      returns.where((item) => item.managerId == null).length;
  int receivedAmount(String orderNumber) => receives
      .where((item) => item.orderNumber == orderNumber)
      .fold(0, (sum, item) => sum + (item.amount ?? 0));
  int remainingAmount(OrderRecord order) =>
      ((order.amount ?? 0) - receivedAmount(order.number)).clamp(0, 2147483647);
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
