import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/sales/sale_record.dart';

class SalesApiService {
  SalesApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<List<SaleRecord>> history(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/sale_history');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const SalesException('API 서버 주소를 확인해주세요.');
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
        throw SalesException(
          response.statusCode == 401 ? '다시 로그인해주세요.' : '판매내역을 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>)
          .map((row) => SaleRecord.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw const SalesException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const SalesException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const SalesException('판매내역 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const SalesException('판매내역 응답을 확인하지 못했습니다.');
    }
  }
}
