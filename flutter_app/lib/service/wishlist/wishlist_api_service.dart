import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/wishlist/wishlist_record.dart';

class WishlistApiService {
  WishlistApiService(this._client, {required String baseUrl})
    : _base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _base;
  Future<Object?> _request(
    String method,
    String path,
    String token, {
    Map<String, String>? body,
  }) async {
    try {
      final uri = Uri.parse('$_base$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ProductException('API 서버 주소를 확인해주세요.');
      }
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final result = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(result)
          .timeout(const Duration(seconds: 15));
      Object? json;
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        /* error body can be non-JSON */
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      final detail = json is Map && json['detail'] is String
          ? json['detail'] as String
          : null;
      throw ProductException(
        response.statusCode >= 500
            ? '관심상품을 처리하지 못했습니다. 다시 시도해주세요.'
            : detail ?? '관심상품 요청을 확인해주세요.',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ProductException('응답이 늦어지고 있습니다. 새로고침해 관심상품을 확인해주세요.');
    } on http.ClientException {
      throw const ProductException('서버에 연결할 수 없습니다. 다시 시도해주세요.');
    } on FormatException {
      throw const ProductException('관심상품 응답 형식을 확인해주세요.');
    }
  }

  Future<List<WishlistRecord>> getRecords(String userId, String token) async {
    try {
      final rows = await _request(
        'GET',
        '/wishlist/${Uri.encodeComponent(userId)}',
        token,
      ) as List<dynamic>;
      return rows
          .map((row) => WishlistRecord.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ProductException('관심상품 응답 형식을 확인해주세요.');
    } on FormatException {
      throw const ProductException('관심상품 응답 형식을 확인해주세요.');
    }
  }

  Future<WishlistRecord> setWished(
    String userId,
    String code,
    bool wished,
    String token,
  ) async {
    try {
      final json = await _request(
        wished ? 'POST' : 'DELETE',
        wished
            ? '/wishlist'
            : '/wishlist/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(code)}',
        token,
        body: wished ? {'sell_product_sell_product_code': code} : null,
      );
      final record = WishlistRecord.fromJson(json as Map<String, dynamic>);
      if (record.userId != userId ||
          record.code != code ||
          record.isWished != wished) {
        throw const FormatException('Wishlist mismatch');
      }
      return record;
    } on TypeError {
      throw const ProductException('관심상품 응답 형식을 확인해주세요.');
    } on FormatException {
      throw const ProductException('관심상품 응답을 확인하지 못했습니다. 새로고침해주세요.');
    }
  }
}
