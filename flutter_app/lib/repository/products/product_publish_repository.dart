import 'package:pokem_app/model/products/product_photo.dart';

import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_draft.dart';
import 'package:pokem_app/service/products/product_publish_api_service.dart';

class ProductPublishRepository {
  ProductPublishRepository(this._api);
  final ProductPublishApiService _api;
  Future<String> uploadPhoto(ProductPhoto photo, String token) =>
      _api.uploadPhoto(photo, token);
  Future<Product> create(ProductDraft draft, String url, String token) =>
      _api.create(draft, url, token);
}
