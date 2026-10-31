import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/manager/manager_dashboard.dart';

class ManagerApiService {
  ManagerApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<Object?> _request(
    String token,
    String path, {
    Map<String, dynamic>? body,
    String method = 'GET',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ManagerException('API 서버 주소를 확인해주세요.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final encodedBody = body == null ? null : jsonEncode(body);
      final response = await switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = switch (response.statusCode) {
          401 => '인증이 만료되었습니다. 다시 로그인해주세요.',
          403 => '관리자 권한이 필요합니다.',
          409 => '처리 상태가 변경되었습니다. 새로고침 후 확인해주세요.',
          _ => '관리자 업무를 처리하지 못했습니다. 다시 시도해주세요.',
        };
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map && data['detail'] is String) {
            message = data['detail'] as String;
          }
        } on FormatException {
          /* Keep the status-specific message. */
        }
        throw ManagerException(message, statusCode: response.statusCode);
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ManagerException('서버 응답이 늦어지고 있습니다. 처리 여부를 새로고침으로 확인해주세요.');
    } on http.ClientException {
      throw const ManagerException('서버에 연결할 수 없습니다. 네트워크와 API 주소를 확인해주세요.');
    } on FormatException {
      throw const ManagerException('서버 응답 형식을 확인해주세요.');
    }
  }

  Future<List<Map<String, dynamic>>> list(String token, String path) async {
    try {
      return (await _request(token, path) as List).cast<Map<String, dynamic>>();
    } on TypeError {
      throw const ManagerException('서버 응답 형식을 확인해주세요.');
    }
  }

  Future<void> createInspection(
    String token,
    String requestNumber,
    String serialCode, {
    String? grade,
    String? reason,
  }) async {
    await _request(
      token,
      '/inspect',
      method: 'POST',
      body: {
        'inspect_requested_no': requestNumber,
        'inspect_serial_code': serialCode,
        'inspect_grade': ?grade,
        'inspect_grade_reason': ?reason,
      },
    );
  }

  Future<void> startInspection(String token, String code) async {
    await _request(
      token,
      '/inspect/${Uri.encodeComponent(code)}/start',
      method: 'POST',
    );
  }

  Future<void> completeInspection(
    String token,
    String code,
    String grade,
    String reason,
  ) async {
    await _request(
      token,
      '/inspect/${Uri.encodeComponent(code)}/complete',
      method: 'POST',
      body: {'inspect_grade': grade, 'inspect_grade_reason': reason},
    );
  }

  Future<void> approveInspectionRequest(String token, String requestNumber) =>
      _request(
        token,
        '/inspection_request/${Uri.encodeComponent(requestNumber)}/manager',
        method: 'PATCH',
        body: const {},
      );

  Future<void> createConsignment(String token, Map<String, dynamic> body) =>
      _request(token, '/post_consign_item', method: 'POST', body: body);

  Future<void> createProposal(String token, Map<String, dynamic> body) =>
      _request(token, '/proposal', method: 'POST', body: body);

  Future<void> createOrder(String token, Map<String, dynamic> body) =>
      _request(token, '/order', method: 'POST', body: body);

  Future<void> createReceive(String token, Map<String, dynamic> body) =>
      _request(token, '/receive', method: 'POST', body: body);
}
