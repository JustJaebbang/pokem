import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/service/manager/manager_api_service.dart';

class ManagerRepository {
  ManagerRepository(this._api);
  final ManagerApiService _api;

  Future<List<Map<String, dynamic>>> _allPages(
    String token,
    String path,
  ) async {
    const pageSize = 100;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      // 서버 제한인 100건씩 끝까지 읽어 100건 이후 데이터가 누락되지 않게 한다.
      final separator = path.contains('?') ? '&' : '?';
      final page = await _api.list(
        token,
        '$path${separator}limit=$pageSize&offset=$offset',
      );
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<ManagerDashboard> load(String token) async {
    try {
      final results = await Future.wait([
        _allPages(
          token,
          '/sell_product?status=${Uri.encodeComponent('판매중')}&sort=newest',
        ),
        _api.list(token, '/inspection_request'),
        _api.list(token, '/inspect'),
        _api.list(token, '/post_consign_item'),
        _allPages(token, '/proposal'),
        _allPages(token, '/order'),
        _allPages(token, '/receive'),
        _allPages(token, '/case'),
        _allPages(token, '/product_company'),
        _allPages(token, '/delivery_company'),
        _allPages(token, '/return'),
        _allPages(token, '/delivery'),
        _allPages(token, '/delivery/status-history'),
        _allPages(token, '/pay'),
        _allPages(token, '/receipt'),
        _allPages(token, '/deposit_refund'),
        _allPages(token, '/discard'),
        _allPages(token, '/purchase_item/manager/all'),
      ]);
      return ManagerDashboard(
        products: results[0].map(Product.fromJson).toList(),
        requests: results[1].map(InspectionRequest.fromJson).toList(),
        inspections: results[2].map(InspectionItem.fromJson).toList(),
        consignments: results[3].map(ConsignmentRecord.fromJson).toList(),
        proposals: results[4].map(ProposalRecord.fromJson).toList(),
        orders: results[5].map(OrderRecord.fromJson).toList(),
        receives: results[6].map(ReceiveRecord.fromJson).toList(),
        cases: results[7].map(CaseRecord.fromJson).toList(),
        productCompanies: results[8].map(CompanyRecord.product).toList(),
        deliveryCompanies: results[9].map(CompanyRecord.delivery).toList(),
        returns: results[10].map(ReturnRecord.fromJson).toList(),
        deliveries: results[11].map(DeliveryRecord.fromJson).toList(),
        deliveryHistories: results[12]
            .map(DeliveryStatusHistoryRecord.fromJson)
            .toList(),
        pays: results[13].map(PayRecord.fromJson).toList(),
        receipts: results[14].map(ReceiptRecord.fromJson).toList(),
        refunds: results[15].map(RefundRecord.fromJson).toList(),
        discards: results[16].map(DiscardRecord.fromJson).toList(),
        purchases: results[17].map(PurchaseRecord.fromJson).toList(),
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

  Future<void> assignReturn(String token, String number) =>
      _api.assignReturn(token, number);
  Future<void> createDelivery(String token, Map<String, dynamic> body) =>
      _api.createDelivery(token, body);
  Future<void> updateDeliveryStatus(
    String token,
    String number,
    String status, {
    String? memo,
  }) => _api.updateDeliveryStatus(token, number, status, memo: memo);
  Future<void> setConsignmentReturnCompany(
    String token,
    String code,
    String company,
  ) => _api.setConsignmentReturnCompany(token, code, company);
  Future<void> updatePayStatus(String token, String number, String status) =>
      _api.updatePayStatus(token, number, status);
  Future<void> createReceipt(String token, Map<String, dynamic> body) =>
      _api.createReceipt(token, body);
  Future<void> createRefund(String token, String payNumber) =>
      _api.createRefund(token, payNumber);
  Future<void> createCase(String token, Map<String, dynamic> body) =>
      _api.createCase(token, body);
  Future<void> createProductCompany(String token, Map<String, dynamic> body) =>
      _api.createProductCompany(token, body);
  Future<void> createDeliveryCompany(String token, Map<String, dynamic> body) =>
      _api.createDeliveryCompany(token, body);
  Future<void> createDiscard(String token, String productCode) =>
      _api.createDiscard(token, productCode);
  Future<void> updateCase(
    String token,
    String code,
    Map<String, dynamic> body,
  ) => _api.updateCase(token, code, body);
  Future<void> updateProductCompany(String token, String code, String name) =>
      _api.updateProductCompany(token, code, name);
  Future<void> updateDeliveryCompany(String token, String code, String name) =>
      _api.updateDeliveryCompany(token, code, name);
  Future<void> cancelReceive(String token, String number) =>
      _api.cancelReceive(token, number);
  Future<void> cancelReceipt(String token, String number) =>
      _api.cancelReceipt(token, number);
}
