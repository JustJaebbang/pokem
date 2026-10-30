import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';

class CheckoutData {
  const CheckoutData(this.product, this.buyer);
  final Product product;
  final BuyerProfile buyer;
}

class PurchaseRepository {
  PurchaseRepository(this._api, this._products);
  final PurchaseApiService _api;
  final ProductRepository _products;
  Future<CheckoutData> checkout(String code, String id, String token) async {
    final results = await Future.wait<Object>([
      _products.getProduct(code),
      _api.profile(id, token),
    ]);
    return CheckoutData(results[0] as Product, results[1] as BuyerProfile);
  }

  Future<Purchase> buy(String code, int price, String token) =>
      _api.buy(code, price, token);
  Future<List<Purchase>> history(String token) => _api.history(token);
  Future<Purchase> getPurchase(String code, String token) =>
      _api.getPurchase(code, token);
  Future<PurchaseConfirmReceipt> confirm(String code, String token) =>
      _api.confirm(code, token);
}
