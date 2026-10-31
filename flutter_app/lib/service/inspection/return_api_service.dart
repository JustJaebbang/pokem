import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/inspection/return_item.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';

class ReturnApiService {
  ReturnApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<List<ReturnItem>> getReturns(
    String token, {
    String? inspectCode,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/return').replace(
        queryParameters: {
          'limit': '20',
          'offset': '$offset',
          'inspect_code': ?inspectCode,
        },
      );
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const InspectionException('API 서버 주소를 확인해주세요.');
      }
      final response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InspectionException(
          '반환내역을 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      final rows =
          (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
              .map((row) => ReturnItem.fromJson(row as Map<String, dynamic>))
              .toList();
      if (inspectCode != null &&
          rows.any((row) => row.inspectCode != inspectCode)) {
        throw const InspectionException('검수번호와 반환 정보가 일치하지 않습니다.');
      }
      return rows;
    } on TimeoutException {
      throw const InspectionException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const InspectionException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const InspectionException('반환내역 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const InspectionException('반환내역 응답을 확인하지 못했습니다.');
    }
  }
}
