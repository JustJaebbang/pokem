import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_edit.dart';

class ProductEditApiService {
  ProductEditApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<Product> update(
    String code,
    ProductEditDraft draft,
    String token,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/sell_product/${Uri.encodeComponent(code)}',
      );
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ProductException('API 서버 주소를 확인해주세요.');
      }
      final response = await _client
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(draft.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is Map && json['detail'] is String) {
            detail = json['detail'] as String;
          }
        } catch (_) {}
        throw ProductException(
          detail ?? '상품을 수정하지 못했습니다.',
          statusCode: response.statusCode,
        );
      }
      final product = Product.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (product.code != code) {
        throw const ProductException('상품 수정 결과를 확인하지 못했습니다. 새로고침으로 확인해주세요.');
      }
      return product;
    } on TimeoutException {
      throw const ProductException('응답이 늦어지고 있습니다. 새로고침으로 저장 여부를 확인해주세요.');
    } on http.ClientException {
      throw const ProductException('서버에 연결하지 못했습니다. 새로고침으로 저장 여부를 확인해주세요.');
    } on FormatException {
      throw const ProductException('상품 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const ProductException('상품 응답을 확인하지 못했습니다.');
    }
  }
}
