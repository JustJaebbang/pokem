import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/products/product_delete.dart';

class ProductDeleteApiService {
  ProductDeleteApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<void> delete(String code, String token) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/sell_product/${Uri.encodeComponent(code)}',
      );
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ProductDeleteException('API 서버 주소를 확인해주세요.');
      }
      final response = await _client
          .delete(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = '상품을 삭제하지 못했습니다.';
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          if (body is Map && body['detail'] is String) {
            message = body['detail'] as String;
          }
        } catch (_) {}
        throw ProductDeleteException(
          message,
          status: response.statusCode,
          uncertain: response.statusCode >= 500,
        );
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map || body['sell_product_code'] != code) {
        throw const ProductDeleteException(
          '삭제 결과를 확인하지 못했습니다.',
          uncertain: true,
        );
      }
    } on TimeoutException {
      throw const ProductDeleteException('삭제 결과를 확인하지 못했습니다.', uncertain: true);
    } on http.ClientException {
      throw const ProductDeleteException('서버에 연결하지 못했습니다.', uncertain: true);
    } on FormatException {
      throw const ProductDeleteException('삭제 응답을 확인하지 못했습니다.', uncertain: true);
    }
  }
}
