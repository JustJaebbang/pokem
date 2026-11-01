import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/director/director_dashboard.dart';

class DirectorApiService {
  DirectorApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> _request(
    String token,
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response =
          await (method == 'PATCH'
                  ? _client.patch(uri, headers: headers, body: jsonEncode(body))
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = '총괄 업무를 처리하지 못했습니다.';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['detail'] is String) {
            message = decoded['detail'] as String;
          }
        } on FormatException {
          /* 상태별 기본 문구를 유지한다. */
        }
        throw DirectorException(message, statusCode: response.statusCode);
      }
      return (jsonDecode(utf8.decode(response.bodyBytes)) as Map)
          .cast<String, dynamic>();
    } on TimeoutException {
      throw const DirectorException('서버 응답이 지연되고 있습니다.');
    } on http.ClientException {
      throw const DirectorException('서버에 연결할 수 없습니다.');
    } on FormatException {
      throw const DirectorException('서버 응답 형식을 확인해주세요.');
    }
  }

  Future<Map<String, dynamic>> dashboard(String token) =>
      _request(token, '/director/dashboard');
  Future<void> reviewProposal(
    String token,
    String number,
    String status,
  ) async {
    await _request(
      token,
      '/proposal/${Uri.encodeComponent(number)}/review',
      method: 'PATCH',
      body: {'proposal_status': status},
    );
  }
}
