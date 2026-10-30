import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/service/products/product_api_service.dart';

class ProductRepository {
  ProductRepository(this._api);
  final ProductApiService _api;
  Future<List<Product>> getProducts() => _api.getProducts();
  Future<Product> getProduct(String code) => _api.getProduct(code);
}
