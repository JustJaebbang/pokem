import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/delivery/delivery.dart';

class DeliveryApiService {
  DeliveryApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<dynamic> _get(
    String path,
    String token, {
    Map<String, String>? query,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const DeliveryException('API 서버 주소를 확인해주세요.');
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
        throw DeliveryException(
          response.statusCode == 404
              ? '배송 정보를 찾을 수 없습니다.'
              : '배송 정보를 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const DeliveryException('서버 응답이 늦어지고 있습니다. 다시 시도해주세요.');
    } on http.ClientException {
      throw const DeliveryException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const DeliveryException('배송 정보 응답을 확인하지 못했습니다.');
    }
  }

  Future<List<Delivery>> list(String token, int offset) async {
    try {
      final rows = await _get(
        '/delivery',
        token,
        query: {'limit': '100', 'offset': '$offset'},
      ) as List;
      return rows
          .map((row) => Delivery.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const DeliveryException('배송 정보 응답을 확인하지 못했습니다.');
    }
  }

  Future<Delivery> detail(String number, String token) async {
    try {
      final row = Delivery.fromJson(
        await _get('/delivery/${Uri.encodeComponent(number)}', token)
            as Map<String, dynamic>,
      );
      if (row.number != number) {
        throw const DeliveryException('배송번호가 일치하지 않습니다.');
      }
      return row;
    } on TypeError {
      throw const DeliveryException('배송 정보 응답을 확인하지 못했습니다.');
    }
  }
}
