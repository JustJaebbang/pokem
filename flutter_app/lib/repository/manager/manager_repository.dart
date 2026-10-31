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
      ]);
      return ManagerDashboard(
        requests: results[0].map(InspectionRequest.fromJson).toList(),
        inspections: results[1].map(InspectionItem.fromJson).toList(),
        consignments: results[2].map(ConsignmentRecord.fromJson).toList(),
      );
    } on TypeError {
      throw const ManagerException('매니저 응답 형식을 확인해주세요.');
    }
  }

  Future<void> createInspection(
    String token,
    String requestNumber,
    String serialCode,
  ) => _api.createInspection(token, requestNumber, serialCode);
  Future<void> startInspection(String token, String code) =>
      _api.startInspection(token, code);
  Future<void> completeInspection(
    String token,
    String code,
    String grade,
    String reason,
  ) => _api.completeInspection(token, code, grade, reason);
}
