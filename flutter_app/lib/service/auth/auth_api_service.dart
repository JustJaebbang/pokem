import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pokem_app/model/auth/auth_session.dart';

class AuthApiService {
  AuthApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> requestRecovery(Map<String, Object?> data) =>
      _request(
        '/auth/recovery/request',
        body: data,
        timeout: const Duration(seconds: 30),
      );
  Future<Map<String, dynamic>> completeRecovery(Map<String, Object?> data) =>
      _request('/auth/recovery/complete', body: data);

  Future<Map<String, dynamic>> login(String id, String password) =>
      _request('/auth/login', body: {'login_id': id, 'password': password});
  Future<Map<String, dynamic>> register(Map<String, String> data) =>
      _request('/user', body: data);
  Future<Map<String, dynamic>> me(String token) =>
      _request('/auth/me', token: token);

  Future<Map<String, dynamic>> profile(String id, String token) =>
      _request('/user/${Uri.encodeComponent(id)}', token: token);
  Future<Map<String, dynamic>> updateProfile(
    String id,
    Map<String, Object?> data,
    String token,
  ) => _request(
    '/user/${Uri.encodeComponent(id)}',
    token: token,
    body: data,
    put: true,
  );

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, Object?>? body,
    String? token,
    bool put = false,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const AuthException('API 서버 주소 설정을 확인해주세요.');
      }
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response =
          await (body == null
                  ? _client.get(uri, headers: headers)
                  : put
                  ? _client.put(uri, headers: headers, body: jsonEncode(body))
                  : _client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid response');
        }
        return decoded;
      }
      String? detail;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['detail'] is String) {
          detail = decoded['detail'] as String;
        }
      } catch (_) {
        /* HTML 오류 응답도 공통 메시지로 처리한다. */
      }
      final message = response.statusCode >= 500
          ? '서버에서 요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.'
          : detail ??
                (response.statusCode == 401
                    ? '아이디 또는 비밀번호를 확인해주세요.'
                    : '요청을 처리할 수 없습니다.');
      throw AuthException(message, statusCode: response.statusCode);
    } on TimeoutException {
      throw const AuthException('서버 응답이 늦어지고 있습니다. 다시 시도해주세요.');
    } on http.ClientException {
      throw const AuthException('서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해주세요.');
    } on FormatException {
      throw const AuthException('서버 응답 형식을 확인해주세요.');
    }
  }
}
