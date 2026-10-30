import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/chat/chat_models.dart';

class ChatApiService {
  ChatApiService(this.client, {required String baseUrl})
    : base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client client;
  final String base;
  Future<Object?> _request(
    String path,
    String token, {
    Map<String, String>? body,
  }) async {
    try {
      final uri = Uri.parse('$base$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ChatException('서버 주소를 확인해주세요.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 15));
      Object? json;
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}
      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      final detail = json is Map && json['detail'] is String
          ? json['detail'] as String
          : null;
      throw ChatException(
        response.statusCode >= 500
            ? '채팅을 불러오지 못했습니다.'
            : detail ?? '채팅 요청을 확인해주세요.',
        status: response.statusCode,
      );
    } on TimeoutException {
      throw const ChatException('서버 응답이 늦어지고 있습니다. 다시 시도해주세요.');
    } on http.ClientException {
      throw const ChatException('서버에 연결할 수 없습니다.');
    }
  }

  Future<T> _parse<T>(
    Future<Object?> response,
    T Function(Object?) parse,
  ) async {
    try {
      return parse(await response);
    } on TypeError {
      throw const ChatException('채팅 응답 형식을 확인해주세요.');
    } on FormatException {
      throw const ChatException('채팅 응답 형식을 확인해주세요.');
    }
  }

  Future<ChatRoom> open(String code, String token) => _parse(
    _request(
      '/chat_room',
      token,
      body: {'sell_product_sell_product_code': code},
    ),
    (j) => ChatRoom.fromJson(j as Map<String, dynamic>),
  );
  Future<ChatRoom> room(String id, String token) => _parse(
    _request('/chat_room/${Uri.encodeComponent(id)}', token),
    (j) => ChatRoom.fromJson(j as Map<String, dynamic>),
  );
  Future<List<ChatRoom>> rooms(String token, int offset) => _parse(
    _request('/chat_room?limit=50&offset=$offset', token),
    (j) => (j as List)
        .map((v) => ChatRoom.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
  Future<List<ChatMessage>> messages(
    String id,
    String token,
    int after,
  ) => _parse(
    _request(
      '/chat_room/${Uri.encodeComponent(id)}/messages?after_chat_seq=$after&limit=100',
      token,
    ),
    (j) => (j as List)
        .map((v) => ChatMessage.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
}
