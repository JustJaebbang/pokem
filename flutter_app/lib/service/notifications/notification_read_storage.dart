import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class NotificationReadStorage {
  Future<Set<String>> read(String accountKey);
  Future<void> write(String accountKey, Set<String> ids);
}

class SecureNotificationReadStorage implements NotificationReadStorage {
  final _storage = const FlutterSecureStorage();
  String key(String accountKey) =>
      'pokem.notifications.read.v1.${Uri.encodeComponent(accountKey)}';
  @override
  Future<Set<String>> read(String accountKey) async {
    final value = await _storage.read(key: key(accountKey));
    if (value == null) return {};
    try {
      return (jsonDecode(value) as List).cast<String>().toSet();
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  @override
  Future<void> write(String accountKey, Set<String> ids) =>
      _storage.write(key: key(accountKey), value: jsonEncode(ids.toList()));
}
