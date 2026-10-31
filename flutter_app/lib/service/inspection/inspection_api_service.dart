import 'package:pokem_app/model/inspection/inspection_result.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/inspection/inspection_request.dart';

class InspectionApiService {
  InspectionApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<Object?> _request(
    String token, {
    int? amount,
    String path = '/inspection_request',
    InspectionChoice? choice,
  }) async {
    final writing = amount != null || choice != null;
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const InspectionException('API 서버 주소를 확인해주세요.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (writing) 'Content-Type': 'application/json',
      };
      final response =
          await (choice != null
                  ? _client.put(
                      uri,
                      headers: headers,
                      body: jsonEncode({'inspect_user_choice': choice.label}),
                    )
                  : writing
                  ? _client.post(
                      uri,
                      headers: headers,
                      body: jsonEncode({'inspection_request_amount': amount}),
                    )
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is Map && json['detail'] is String) {
            detail = json['detail'] as String;
          }
        } catch (_) {}
        throw InspectionException(
          response.statusCode >= 500
              ? '요청 결과를 확인하지 못했습니다.'
              : detail ?? '요청을 처리하지 못했습니다.',
          status: response.statusCode,
          uncertain: writing && response.statusCode >= 500,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw InspectionException('서버 응답이 늦어지고 있습니다.', uncertain: writing);
    } on http.ClientException {
      throw InspectionException('서버에 연결하지 못했습니다.', uncertain: writing);
    } on FormatException {
      throw InspectionException('서버 응답을 확인하지 못했습니다.', uncertain: writing);
    }
  }

  Future<List<InspectionRequest>> history(String token) async {
    try {
      return (await _request(token) as List<dynamic>)
          .map((row) => InspectionRequest.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const InspectionException('신청내역을 확인하지 못했습니다.');
    }
  }

  Future<InspectionRequest> create(int amount, String token) async {
    try {
      return InspectionRequest.fromJson(
        await _request(token, amount: amount) as Map<String, dynamic>,
      );
    } on TypeError {
      throw const InspectionException('신청 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }

  Future<List<InspectionResult>> results(String number, String token) async {
    try {
      return (await _request(
            token,
            path: '/inspect?request_no=${Uri.encodeComponent(number)}',
          ) as List<dynamic>)
          .map((row) => InspectionResult.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const InspectionException('검수 결과를 확인하지 못했습니다.');
    }
  }

  Future<InspectionResult> result(String code, String token) async {
    try {
      return InspectionResult.fromJson(
        await _request(token, path: '/inspect/${Uri.encodeComponent(code)}')
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const InspectionException('검수 결과를 확인하지 못했습니다.');
    }
  }

  Future<InspectionResult> choose(
    String code,
    InspectionChoice choice,
    String token,
  ) async {
    try {
      final item = InspectionResult.fromJson(
        await _request(
          token,
          path: '/inspect/${Uri.encodeComponent(code)}/choice',
          choice: choice,
        ) as Map<String, dynamic>,
      );
      if (item.code != code ||
          item.choice != choice.label ||
          item.status != '검수완료') {
        throw const InspectionException('선택 결과를 확인하지 못했습니다.', uncertain: true);
      }
      return item;
    } on TypeError {
      throw const InspectionException('선택 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
