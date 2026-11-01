class DirectorMetrics {
  const DirectorMetrics({
    required this.users,
    required this.managers,
    required this.unassignedRequests,
    required this.inspectionsInProgress,
    required this.completedInspections,
    required this.activeConsignments,
    required this.pendingProposals,
    required this.orders,
    required this.deliveriesInProgress,
    required this.returnsInProgress,
    required this.payments,
    required this.refunds,
    required this.caseStock,
    required this.withdrawnUsers,
  });
  final int users, managers, unassignedRequests, inspectionsInProgress;
  final int completedInspections, activeConsignments, pendingProposals, orders;
  final int deliveriesInProgress,
      returnsInProgress,
      payments,
      refunds,
      caseStock,
      withdrawnUsers;
  factory DirectorMetrics.fromJson(Map<String, dynamic> json) =>
      DirectorMetrics(
        users: json['users'] as int,
        managers: json['managers'] as int,
        unassignedRequests: json['unassigned_requests'] as int,
        inspectionsInProgress: json['inspections_in_progress'] as int,
        completedInspections: json['completed_inspections'] as int,
        activeConsignments: json['active_consignments'] as int,
        pendingProposals: json['pending_proposals'] as int,
        orders: json['orders'] as int,
        deliveriesInProgress: json['deliveries_in_progress'] as int,
        returnsInProgress: json['returns_in_progress'] as int,
        payments: json['payments'] as int,
        refunds: json['refunds'] as int,
        caseStock: json['case_stock'] as int,
        withdrawnUsers: json['withdrawn_users'] as int,
      );
}

class DirectorWithdrawal {
  const DirectorWithdrawal({
    required this.userId,
    required this.type,
    this.nickname,
    this.date,
    this.reason,
  });
  final String userId, type;
  final String? nickname, date, reason;
  factory DirectorWithdrawal.fromJson(Map<String, dynamic> json) =>
      DirectorWithdrawal(
        userId: json['user_id'] as String,
        nickname: json['user_nickname'] as String?,
        date: json['quit_date'] as String?,
        type: json['quit_type'] as String,
        reason: json['quit_reason'] as String?,
      );
}

class DirectorInspectionPipeline {
  const DirectorInspectionPipeline({
    required this.unassignedRequests,
    required this.waiting,
    required this.inProgress,
    required this.completed,
  });
  final int unassignedRequests, waiting, inProgress, completed;
  factory DirectorInspectionPipeline.fromJson(Map<String, dynamic> json) =>
      DirectorInspectionPipeline(
        unassignedRequests: json['unassigned_requests'] as int,
        waiting: json['waiting'] as int,
        inProgress: json['in_progress'] as int,
        completed: json['completed'] as int,
      );
}

class DirectorManagerInspectionStat {
  const DirectorManagerInspectionStat({
    required this.managerId,
    required this.total,
    required this.completed,
    required this.active,
    this.managerName,
  });
  final String managerId;
  final String? managerName;
  final int total, completed, active;
  factory DirectorManagerInspectionStat.fromJson(Map<String, dynamic> json) =>
      DirectorManagerInspectionStat(
        managerId: json['manager_id'] as String,
        managerName: json['manager_name'] as String?,
        total: json['total'] as int,
        completed: json['completed'] as int,
        active: json['active'] as int,
      );
}

class DirectorLowStockCase {
  const DirectorLowStockCase({
    required this.caseCode,
    required this.stock,
    required this.threshold,
  });
  final String caseCode;
  final int stock, threshold;
  factory DirectorLowStockCase.fromJson(Map<String, dynamic> json) =>
      DirectorLowStockCase(
        caseCode: json['case_code'] as String,
        stock: json['case_stock'] as int,
        threshold: json['threshold'] as int,
      );
}

class DirectorOutstandingOrder {
  const DirectorOutstandingOrder({
    required this.orderNo,
    required this.caseCode,
    required this.orderAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
    this.orderDate,
  });
  final String orderNo, caseCode;
  final String? orderDate;
  final int orderAmount, receivedAmount, outstandingAmount;
  factory DirectorOutstandingOrder.fromJson(Map<String, dynamic> json) =>
      DirectorOutstandingOrder(
        orderNo: json['order_no'] as String,
        orderDate: json['order_date'] as String?,
        caseCode: json['case_code'] as String,
        orderAmount: json['order_amount'] as int,
        receivedAmount: json['received_amount'] as int,
        outstandingAmount: json['outstanding_amount'] as int,
      );
}

class DirectorQuitTypeStat {
  const DirectorQuitTypeStat({required this.type, required this.count});
  final String type;
  final int count;
  factory DirectorQuitTypeStat.fromJson(Map<String, dynamic> json) =>
      DirectorQuitTypeStat(
        type: json['quit_type'] as String,
        count: json['count'] as int,
      );
}

class DirectorDelayedDelivery {
  const DirectorDelayedDelivery({
    required this.number,
    required this.managerId,
    required this.companyCode,
    this.date,
    this.status,
  });
  final String number, managerId, companyCode;
  final String? date, status;
  factory DirectorDelayedDelivery.fromJson(Map<String, dynamic> json) =>
      DirectorDelayedDelivery(
        number: json['delivery_no'] as String,
        date: json['delivery_date'] as String?,
        status: json['delivery_status'] as String?,
        managerId: json['manager_id'] as String,
        companyCode: json['company_code'] as String,
      );
}

class DirectorReturnWithoutDelivery {
  const DirectorReturnWithoutDelivery({
    required this.number,
    required this.status,
    required this.userId,
    this.managerId,
  });
  final String number, status, userId;
  final String? managerId;
  factory DirectorReturnWithoutDelivery.fromJson(Map<String, dynamic> json) =>
      DirectorReturnWithoutDelivery(
        number: json['return_no'] as String,
        status: json['return_status'] as String,
        userId: json['user_id'] as String,
        managerId: json['manager_id'] as String?,
      );
}

class DirectorOperationsStatistics {
  const DirectorOperationsStatistics({
    required this.pipeline,
    required this.managerInspections,
    required this.lowStockCases,
    required this.outstandingOrders,
    required this.delayedDeliveries,
    required this.returnsWithoutDelivery,
    required this.quitTypes,
    required this.delayedDeliveryItems,
    required this.returnWithoutDeliveryItems,
  });
  final DirectorInspectionPipeline pipeline;
  final List<DirectorManagerInspectionStat> managerInspections;
  final List<DirectorLowStockCase> lowStockCases;
  final List<DirectorOutstandingOrder> outstandingOrders;
  final int delayedDeliveries, returnsWithoutDelivery;
  final List<DirectorQuitTypeStat> quitTypes;
  final List<DirectorDelayedDelivery> delayedDeliveryItems;
  final List<DirectorReturnWithoutDelivery> returnWithoutDeliveryItems;
  factory DirectorOperationsStatistics.fromJson(Map<String, dynamic> json) =>
      DirectorOperationsStatistics(
        pipeline: DirectorInspectionPipeline.fromJson(
          json['pipeline'] as Map<String, dynamic>,
        ),
        managerInspections: (json['manager_inspections'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorManagerInspectionStat.fromJson)
            .toList(),
        lowStockCases: (json['low_stock_cases'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorLowStockCase.fromJson)
            .toList(),
        outstandingOrders: (json['outstanding_orders'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorOutstandingOrder.fromJson)
            .toList(),
        delayedDeliveries: json['delayed_deliveries'] as int,
        returnsWithoutDelivery: json['returns_without_delivery'] as int,
        quitTypes: (json['quit_types'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorQuitTypeStat.fromJson)
            .toList(),
        delayedDeliveryItems: (json['delayed_delivery_items'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorDelayedDelivery.fromJson)
            .toList(),
        returnWithoutDeliveryItems:
            (json['return_without_delivery_items'] as List)
                .cast<Map<String, dynamic>>()
                .map(DirectorReturnWithoutDelivery.fromJson)
                .toList(),
      );
}

class DirectorProposal {
  const DirectorProposal({
    required this.number,
    required this.caseCode,
    required this.status,
    this.name,
    this.contents,
    this.date,
    this.managerId,
    this.directorId,
  });
  final String number, caseCode, status;
  final String? name, contents, date, managerId, directorId;
  factory DirectorProposal.fromJson(Map<String, dynamic> json) =>
      DirectorProposal(
        number: json['proposal_no'] as String,
        caseCode: json['case_case_code'] as String,
        status: (json['proposal_status'] as String?) ?? '-',
        name: json['proposal_name'] as String?,
        contents: json['proposal_contents'] as String?,
        date: json['proposal_date'] as String?,
        managerId: json['manager_manager_id'] as String?,
        directorId: json['director_director_id'] as String?,
      );
}

class DirectorManager {
  const DirectorManager({
    required this.id,
    required this.name,
    required this.department,
    this.phone,
    this.email,
    this.active = true,
    this.updatedAt,
  });
  final String id, name, department;
  final String? phone, email;
  final bool active;
  final String? updatedAt;
  factory DirectorManager.fromJson(Map<String, dynamic> json) =>
      DirectorManager(
        id: json['manager_id'] as String,
        name: json['manager_name'] as String,
        department: json['manager_dept'] as String,
        phone: json['manager_phone'] as String?,
        email: json['manager_email'] as String?,
        active:
            json['manager_active'] == null ||
            json['manager_active'] == true ||
            json['manager_active'] == 1,
        updatedAt: json['manager_updated_at'] as String?,
      );
}

class DirectorSettings {
  const DirectorSettings({
    required this.lowStockThreshold,
    required this.deliveryDelayDays,
    required this.inspectionUnitPrice,
    required this.updatedAt,
  });
  final int lowStockThreshold, deliveryDelayDays, inspectionUnitPrice;
  final String updatedAt;
  factory DirectorSettings.fromJson(Map<String, dynamic> json) =>
      DirectorSettings(
        lowStockThreshold: (json['low_stock_threshold'] as num).toInt(),
        deliveryDelayDays: (json['delivery_delay_days'] as num).toInt(),
        inspectionUnitPrice: (json['inspection_unit_price'] as num).toInt(),
        updatedAt: json['updated_at'] as String,
      );
}

class DirectorStatisticsPage {
  const DirectorStatisticsPage({
    required this.kind,
    required this.total,
    required this.limit,
    required this.offset,
    required this.items,
  });
  final String kind;
  final int total, limit, offset;
  final List<Map<String, dynamic>> items;
  factory DirectorStatisticsPage.fromJson(Map<String, dynamic> json) =>
      DirectorStatisticsPage(
        kind: json['kind'] as String,
        total: (json['total'] as num).toInt(),
        limit: (json['limit'] as num).toInt(),
        offset: (json['offset'] as num).toInt(),
        items: (json['items'] as List)
            .map((item) => (item as Map).cast<String, dynamic>())
            .toList(),
      );
}

class DirectorCase {
  const DirectorCase({
    required this.code,
    required this.stock,
    this.serial,
    this.price,
  });
  final String code;
  final String? serial;
  final int stock;
  final int? price;
  factory DirectorCase.fromJson(Map<String, dynamic> json) => DirectorCase(
    code: json['case_code'] as String,
    serial: json['case_serial_no'] as String?,
    stock: (json['case_stock'] as num).toInt(),
    price: (json['case_price'] as num?)?.toInt(),
  );
}

class DirectorDashboard {
  const DirectorDashboard({
    required this.metrics,
    required this.proposals,
    required this.managers,
    required this.cases,
    required this.withdrawals,
    required this.statistics,
    required this.settings,
  });
  final DirectorMetrics metrics;
  final List<DirectorProposal> proposals;
  final List<DirectorManager> managers;
  final List<DirectorCase> cases;
  final List<DirectorWithdrawal> withdrawals;
  final DirectorOperationsStatistics statistics;
  final DirectorSettings settings;
  factory DirectorDashboard.fromJson(Map<String, dynamic> json) =>
      DirectorDashboard(
        metrics: DirectorMetrics.fromJson(
          json['metrics'] as Map<String, dynamic>,
        ),
        proposals: (json['proposals'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorProposal.fromJson)
            .toList(),
        managers: (json['managers'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorManager.fromJson)
            .toList(),
        cases: (json['cases'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorCase.fromJson)
            .toList(),
        withdrawals: (json['withdrawals'] as List)
            .cast<Map<String, dynamic>>()
            .map(DirectorWithdrawal.fromJson)
            .toList(),
        statistics: DirectorOperationsStatistics.fromJson(
          json['statistics'] as Map<String, dynamic>,
        ),
        settings: DirectorSettings.fromJson(
          json['settings'] as Map<String, dynamic>,
        ),
      );
}

class DirectorException implements Exception {
  const DirectorException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}
