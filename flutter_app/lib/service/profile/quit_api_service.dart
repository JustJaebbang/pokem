import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/profile/quit_state.dart';

class QuitApiService {
  QuitApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<Map<String, dynamic>> request(
    String id,
    String token, {
    bool deleting = false,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/user/${Uri.encodeComponent(id)}');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const QuitException('API 서버 주소를 확인해주세요.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final response =
          await (deleting
                  ? _client.delete(
                      uri,
                      headers: headers,
                      body: jsonEncode({'quit_reason': reason}),
                    )
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = '요청을 처리하지 못했습니다.';
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map && body['detail'] is String) {
            message = body['detail'] as String;
          }
        } catch (_) {}
        throw QuitException(
          message,
          status: response.statusCode,
          uncertain: deleting && response.statusCode >= 500,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on TimeoutException {
      throw QuitException('서버 응답이 늦어지고 있습니다.', uncertain: deleting);
    } on http.ClientException {
      throw QuitException('서버에 연결하지 못했습니다.', uncertain: deleting);
    } on FormatException {
      throw QuitException('서버 응답을 확인하지 못했습니다.', uncertain: deleting);
    } on TypeError {
      throw QuitException('서버 응답을 확인하지 못했습니다.', uncertain: deleting);
    }
  }
}
