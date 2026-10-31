import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/service/manager/manager_api_service.dart';

class ManagerRepository {
  ManagerRepository(this._api);
  final ManagerApiService _api;
  Future<ManagerDashboard> load(String token) async {
    try {
      final results = await Future.wait([
        _api.list(token, '/inspection_request'),
        _api.list(token, '/inspect'),
        _api.list(token, '/post_consign_item'),
        _api.list(token, '/proposal?limit=100'),
        _api.list(token, '/order?limit=100'),
        _api.list(token, '/receive?limit=100'),
        _api.list(token, '/case?limit=100'),
        _api.list(token, '/product_company?limit=100'),
        _api.list(token, '/delivery_company?limit=100'),
      ]);
      return ManagerDashboard(
        requests: results[0].map(InspectionRequest.fromJson).toList(),
        inspections: results[1].map(InspectionItem.fromJson).toList(),
        consignments: results[2].map(ConsignmentRecord.fromJson).toList(),
        proposals: results[3].map(ProposalRecord.fromJson).toList(),
        orders: results[4].map(OrderRecord.fromJson).toList(),
        receives: results[5].map(ReceiveRecord.fromJson).toList(),
        cases: results[6].map(CaseRecord.fromJson).toList(),
        productCompanies: results[7].map(CompanyRecord.product).toList(),
        deliveryCompanies: results[8].map(CompanyRecord.delivery).toList(),
      );
    } on TypeError {
      throw const ManagerException('매니저 응답 형식을 확인해주세요.');
    }
  }

  Future<void> createInspection(
    String token,
    String requestNumber,
    String serialCode, {
    String? grade,
    String? reason,
  }) => _api.createInspection(
    token,
    requestNumber,
    serialCode,
    grade: grade,
    reason: reason,
  );
  Future<void> startInspection(String token, String code) =>
      _api.startInspection(token, code);
  Future<void> completeInspection(
    String token,
    String code,
    String grade,
    String reason,
  ) => _api.completeInspection(token, code, grade, reason);

  Future<void> approveInspectionRequest(String token, String requestNumber) =>
      _api.approveInspectionRequest(token, requestNumber);

  Future<void> createConsignment(String token, Map<String, dynamic> body) =>
      _api.createConsignment(token, body);

  Future<void> createProposal(String token, Map<String, dynamic> body) =>
      _api.createProposal(token, body);

  Future<void> createOrder(String token, Map<String, dynamic> body) =>
      _api.createOrder(token, body);

  Future<void> createReceive(String token, Map<String, dynamic> body) =>
      _api.createReceive(token, body);
}
