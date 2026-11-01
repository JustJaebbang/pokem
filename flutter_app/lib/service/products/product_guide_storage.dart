import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ProductGuideStorage {
  Future<bool> hidden(String key);
  Future<void> save(String key, bool hidden);
}

class SecureProductGuideStorage implements ProductGuideStorage {
  final _storage = const FlutterSecureStorage();
  @override
  Future<bool> hidden(String key) async =>
      await _storage.read(key: key) == 'true';
  @override
  Future<void> save(String key, bool hidden) =>
      _storage.write(key: key, value: '$hidden');
}
