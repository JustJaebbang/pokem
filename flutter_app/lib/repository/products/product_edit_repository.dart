import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_edit.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/products/product_edit_api_service.dart';

class ProductEditRepository {
  ProductEditRepository(this._api, this._products);
  final ProductEditApiService _api;
  final ProductRepository _products;
  Future<Product> getProduct(String code) => _products.getProduct(code);
  Future<Product> update(String code, ProductEditDraft draft, String token) =>
      _api.update(code, draft, token);
}
