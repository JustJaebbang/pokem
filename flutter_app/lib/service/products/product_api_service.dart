import 'package:pokem_app/model/products/product_browse.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pokem_app/model/products/product.dart';

class ProductApiService {
  ProductApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<Object?> _get(String path) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ProductException('API 서버 주소를 확인해주세요.');
      }
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw const ProductException('상품을 찾을 수 없습니다.', statusCode: 404);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProductException(
          '상품을 불러오지 못했습니다. 다시 시도해주세요.',
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ProductException('서버 응답이 늦어지고 있습니다. 다시 시도해주세요.');
    } on http.ClientException {
      throw const ProductException('서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인해주세요.');
    } on FormatException {
      throw const ProductException('상품 응답 형식을 확인해주세요.');
    }
  }

  Future<List<Product>> getProducts({
    String? query,
    String? status,
    String? category,
    String? brand,
    ProductSort? sort,
    int? limit,
    int offset = 0,
    List<String>? codes,
  }) async {
    try {
      final params = <String, dynamic>{
        if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
        'status': ?status,
        'category': ?category,
        'brand': ?brand,
        if (sort != null) 'sort': sort.value,
        if (limit != null) 'limit': '$limit',
        if (limit != null || offset != 0) 'offset': '$offset',
        'codes': ?codes,
      };
      final path = params.isEmpty
          ? '/sell_product'
          : Uri(path: '/sell_product', queryParameters: params).toString();
      final json = await _get(path) as List<dynamic>;
      return json
          .map((row) => Product.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ProductException('상품 응답 형식을 확인해주세요.');
    }
  }

  Future<List<ProductClassification>> getFilters() async {
    try {
      final rows = await _get('/sell_product/filters') as List<dynamic>;
      return rows
          .map((r) => ProductClassification.fromJson(r as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ProductException('상품 분류를 불러오지 못했습니다.');
    }
  }

  Future<Product> getProduct(String code) async {
    try {
      return Product.fromJson(
        await _get('/sell_product/${Uri.encodeComponent(code)}')
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const ProductException('상품 응답 형식을 확인해주세요.');
    }
  }
}
