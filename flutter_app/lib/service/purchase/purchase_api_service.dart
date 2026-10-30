import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/purchase/purchase.dart';

class PurchaseApiService {
  PurchaseApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;

  Future<Object?> _request(
    String path,
    String token, {
    Map<String, Object>? body,
  }) async {
    final writing = body != null;
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const PurchaseException('API 서버 주소를 확인해주세요.');
      }
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (writing) 'Content-Type': 'application/json',
      };
      final response =
          await (writing
                  ? _client.post(uri, headers: headers, body: jsonEncode(body))
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['detail'] is String) {
            detail = decoded['detail'] as String;
          }
        } catch (_) {}
        throw PurchaseException(
          response.statusCode >= 500
              ? '결과를 확인하지 못했습니다. 구매내역을 확인해주세요.'
              : detail ?? '요청을 처리하지 못했습니다.',
          status: response.statusCode,
          uncertain: writing && response.statusCode >= 500,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw PurchaseException('서버 응답이 늦어지고 있습니다.', uncertain: writing);
    } on http.ClientException {
      throw PurchaseException('서버에 연결하지 못했습니다.', uncertain: writing);
    } on FormatException {
      throw PurchaseException('서버 응답을 확인하지 못했습니다.', uncertain: writing);
    }
  }

  Future<BuyerProfile> profile(String id, String token) async {
    try {
      return BuyerProfile.fromJson(
        await _request('/user/${Uri.encodeComponent(id)}', token)
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const PurchaseException('회원 정보를 확인하지 못했습니다.');
    }
  }

  Future<List<Purchase>> history(String token) async {
    try {
      return (await _request('/purchase_item', token) as List<dynamic>)
          .map((row) => Purchase.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const PurchaseException('구매내역을 확인하지 못했습니다.');
    }
  }

  Future<Purchase> buy(String code, int price, String token) async {
    try {
      return Purchase.fromJson(
        await _request(
          '/purchase_item',
          token,
          body: {
            'sell_product_sell_product_code': code,
            'expected_price': price,
          },
        ) as Map<String, dynamic>,
      );
    } on TypeError {
      throw const PurchaseException('결제 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
