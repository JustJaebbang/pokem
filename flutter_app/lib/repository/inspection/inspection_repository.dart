import 'package:pokem_app/model/inspection/inspection_result.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/service/inspection/inspection_api_service.dart';

class InspectionRepository {
  InspectionRepository(this._api);
  final InspectionApiService _api;
  Future<List<InspectionRequest>> history(String token) => _api.history(token);
  Future<InspectionRequest> create(int amount, String token) =>
      _api.create(amount, token);
  Future<List<InspectionResult>> results(String number, String token) =>
      _api.results(number, token);
  Future<InspectionResult> result(String code, String token) =>
      _api.result(code, token);
  Future<InspectionResult> choose(
    String code,
    InspectionChoice choice,
    String token,
  ) => _api.choose(code, choice, token);
}
