import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/products/product_delete_api_service.dart';

class ProductDeleteRepository {
  ProductDeleteRepository(this._api, this._products);
  final ProductDeleteApiService _api;
  final ProductRepository _products;
  Future<Product> getProduct(String code) => _products.getProduct(code);
  Future<void> delete(String code, String token) => _api.delete(code, token);
}
