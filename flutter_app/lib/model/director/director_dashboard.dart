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
  });
  final int users, managers, unassignedRequests, inspectionsInProgress;
  final int completedInspections, activeConsignments, pendingProposals, orders;
  final int deliveriesInProgress,
      returnsInProgress,
      payments,
      refunds,
      caseStock;
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
  });
  final String id, name, department;
  final String? phone, email;
  factory DirectorManager.fromJson(Map<String, dynamic> json) =>
      DirectorManager(
        id: json['manager_id'] as String,
        name: json['manager_name'] as String,
        department: json['manager_dept'] as String,
        phone: json['manager_phone'] as String?,
        email: json['manager_email'] as String?,
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
  });
  final DirectorMetrics metrics;
  final List<DirectorProposal> proposals;
  final List<DirectorManager> managers;
  final List<DirectorCase> cases;
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
      );
}

class DirectorException implements Exception {
  const DirectorException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}
