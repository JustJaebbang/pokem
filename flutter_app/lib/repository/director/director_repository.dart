import 'package:pokem_app/model/director/director_dashboard.dart';
import 'package:pokem_app/service/director/director_api_service.dart';

class DirectorRepository {
  const DirectorRepository(this._api);
  final DirectorApiService _api;
  Future<DirectorDashboard> load(
    String token, {
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) async => DirectorDashboard.fromJson(
    await _api.dashboard(
      token,
      dateFrom: dateFrom,
      dateTo: dateTo,
      managerId: managerId,
      inspectStatus: inspectStatus,
    ),
  );
  Future<void> reviewProposal(String token, String number, String status) =>
      _api.reviewProposal(token, number, status);

  Future<DirectorSettings> updateSettings(
    String token, {
    required int lowStockThreshold,
    required int deliveryDelayDays,
    required int inspectionUnitPrice,
  }) async => DirectorSettings.fromJson(
    await _api.updateSettings(token, {
      'low_stock_threshold': lowStockThreshold,
      'delivery_delay_days': deliveryDelayDays,
      'inspection_unit_price': inspectionUnitPrice,
    }),
  );

  Future<DirectorStatisticsPage> statistics(
    String token,
    String kind, {
    required int limit,
    required int offset,
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) async => DirectorStatisticsPage.fromJson(
    await _api.statistics(
      token,
      kind,
      limit: limit,
      offset: offset,
      dateFrom: dateFrom,
      dateTo: dateTo,
      managerId: managerId,
      inspectStatus: inspectStatus,
    ),
  );

  Future<void> createManager(String token, Map<String, dynamic> values) async {
    await _api.createManager(token, values);
  }

  Future<Map<String, dynamic>> createReferenceData(
    String token,
    String path,
    Map<String, dynamic> values,
  ) => _api.createReferenceData(token, path, values);

  Future<void> updateManager(
    String token,
    String managerId,
    Map<String, dynamic> values,
  ) async {
    await _api.updateManager(token, managerId, values);
  }

  Future<({List<int> bytes, String filename})> exportStatistics(
    String token,
    String kind,
    String format, {
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) => _api.exportStatistics(
    token,
    kind,
    format,
    dateFrom: dateFrom,
    dateTo: dateTo,
    managerId: managerId,
    inspectStatus: inspectStatus,
  );
}
