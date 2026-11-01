import 'package:pokem_app/service/products/product_guide_storage.dart';
import 'package:pokem_app/repository/products/product_guide_repository.dart';

class MemoryProductGuideStorage implements ProductGuideStorage {
  final values = <String, bool>{};
  bool defaultHidden = false;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<bool> hidden(String key) async => values[key] ?? defaultHidden;
  @override
  Future<void> save(String key, bool hidden) async {
    writes++;
    if (failWrite) throw StateError('storage unavailable');
    values[key] = hidden;
  }

  ProductGuideRepository repository({String server = 'test'}) =>
      ProductGuideRepository(this, server: server);
}
