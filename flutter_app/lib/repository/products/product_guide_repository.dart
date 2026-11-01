import 'package:pokem_app/service/products/product_guide_storage.dart';

class ProductGuideRepository {
  ProductGuideRepository(this.storage, {required this.server});
  final ProductGuideStorage storage;
  final String server;
  String _key(String owner) =>
      'pokem.product-guide.v1.${Uri.encodeComponent(server)}.${Uri.encodeComponent(owner)}';
  Future<bool> hidden(String owner) => storage.hidden(_key(owner));
  Future<void> save(String owner, bool hidden) =>
      storage.save(_key(owner), hidden);
}
