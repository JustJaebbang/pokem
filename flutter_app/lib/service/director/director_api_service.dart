import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/director/director_dashboard.dart';

class DirectorApiService {
  DirectorApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> _request(
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
                  : method == 'POST'
                  ? _client.post(uri, headers: headers, body: jsonEncode(body))
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
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const DirectorException('서버 응답이 지연되고 있습니다.');
    } on http.ClientException {
      throw const DirectorException('서버에 연결할 수 없습니다.');
    } on FormatException {
      throw const DirectorException('서버 응답 형식을 확인해주세요.');
    }
  }

  String _query(Map<String, String?> values) {
    final entries = values.entries.where(
      (entry) => entry.value?.isNotEmpty == true,
    );
    return entries.isEmpty
        ? ''
        : '?${entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value!)}').join('&')}';
  }

  Future<Map<String, dynamic>> dashboard(
    String token, {
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) async => (await _request(
    token,
    '/director/dashboard${_query({'date_from': dateFrom, 'date_to': dateTo, 'manager_id': managerId, 'inspect_status': inspectStatus})}',
  ) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> updateSettings(
    String token,
    Map<String, dynamic> values,
  ) async => (await _request(
    token,
    '/director/settings',
    method: 'PATCH',
    body: values,
  ) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> statistics(
    String token,
    String kind, {
    required int limit,
    required int offset,
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) async => (await _request(
    token,
    '/director/statistics/${Uri.encodeComponent(kind)}${_query({'limit': '$limit', 'offset': '$offset', 'date_from': dateFrom, 'date_to': dateTo, 'manager_id': managerId, 'inspect_status': inspectStatus})}',
  ) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> createManager(
    String token,
    Map<String, dynamic> values,
  ) async =>
      (await _request(token, '/manager', method: 'POST', body: values) as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> updateManager(
    String token,
    String managerId,
    Map<String, dynamic> values,
  ) async => (await _request(
    token,
    '/manager/${Uri.encodeComponent(managerId)}',
    method: 'PATCH',
    body: values,
  ) as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> createReferenceData(
    String token,
    String path,
    Map<String, dynamic> values,
  ) async => (await _request(token, path, method: 'POST', body: values) as Map)
      .cast<String, dynamic>();

  Future<({List<int> bytes, String filename})> exportStatistics(
    String token,
    String kind,
    String format, {
    String? dateFrom,
    String? dateTo,
    String? managerId,
    String? inspectStatus,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/director/statistics/${Uri.encodeComponent(kind)}/export${_query({'format': format, 'date_from': dateFrom, 'date_to': dateTo, 'manager_id': managerId, 'inspect_status': inspectStatus})}',
    );
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': '*/*'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DirectorException(
        '통계 파일을 내려받지 못했습니다.',
        statusCode: response.statusCode,
      );
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
    return (
      bytes: response.bodyBytes,
      filename: match?.group(1) ?? 'director_statistics.$format',
    );
  }

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
