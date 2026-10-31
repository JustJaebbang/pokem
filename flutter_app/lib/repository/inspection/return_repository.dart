import 'package:pokem_app/model/inspection/return_item.dart';
import 'package:pokem_app/service/inspection/return_api_service.dart';

class ReturnRepository {
  ReturnRepository(this._api);
  final ReturnApiService _api;
  Future<List<ReturnItem>> getReturns(
    String token, {
    String? inspectCode,
    int offset = 0,
  }) => _api.getReturns(token, inspectCode: inspectCode, offset: offset);
}
