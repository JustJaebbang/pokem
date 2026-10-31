import 'package:pokem_app/model/products/product_browse.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/service/products/product_api_service.dart';

class ProductRepository {
  ProductRepository(this._api);
  final ProductApiService _api;
  Future<List<Product>> getProducts({
    String? query,
    String? status,
    String? category,
    String? brand,
    ProductSort? sort,
    int? limit,
    int offset = 0,
    List<String>? codes,
  }) => _api.getProducts(
    query: query,
    status: status,
    category: category,
    brand: brand,
    sort: sort,
    limit: limit,
    offset: offset,
    codes: codes,
  );
  Future<List<ProductClassification>> getFilters() => _api.getFilters();
  Future<Product> getProduct(String code) => _api.getProduct(code);
}
