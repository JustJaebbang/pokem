import 'package:pokem_app/model/sales/sale_record.dart';
import 'package:pokem_app/service/sales/sales_api_service.dart';

class SalesRepository {
  SalesRepository(this._api);
  final SalesApiService _api;
  Future<List<SaleRecord>> history(String token) => _api.history(token);
}
