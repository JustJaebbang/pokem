import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class PushDeviceService {
  PushDeviceService(
    this.client, {
    required this.baseUrl,
    FlutterSecureStorage? storage,
  }) : storage = storage ?? const FlutterSecureStorage();
  final http.Client client;
  final String baseUrl;
  final FlutterSecureStorage storage;
  Future<String> installation() async {
    final key = 'push.installation.$baseUrl';
    final saved = await storage.read(key: key);
    if (saved != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(saved)) {
      return saved;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.write(key: key, value: id);
    return id;
  }

  Future<bool> wanted(String owner) async =>
      await storage.read(key: 'push.enabled.$baseUrl.$owner') != 'false';
  Future<void> preference(String owner, bool value) =>
      storage.write(key: 'push.enabled.$baseUrl.$owner', value: '$value');
  Future<void> update(String jwt, String id, String? token) async {
    final uri = Uri.parse(baseUrl).resolve('/push/devices/$id');
    final headers = {
      'Authorization': 'Bearer $jwt',
      'Content-Type': 'application/json',
    };
    final response =
        await (token == null
                ? client.delete(uri, headers: headers)
                : client.put(
                    uri,
                    headers: headers,
                    body: jsonEncode({'fid': token}),
                  ))
            .timeout(const Duration(seconds: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PushException();
    }
  }
}

class PushException implements Exception {
  const PushException();
}
