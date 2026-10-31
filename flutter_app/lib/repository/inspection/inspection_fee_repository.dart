import 'package:pokem_app/model/inspection/inspection_fee.dart';
import 'package:pokem_app/service/inspection/inspection_fee_api_service.dart';

class InspectionFeeRepository {
  InspectionFeeRepository(this._api);
  final InspectionFeeApiService _api;
  Future<InspectionFee?> getFee(String number, String token) =>
      _api.getFee(number, token);
  Future<InspectionFee> complete(InspectionFee fee, String token) =>
      _api.complete(fee, token);
}
