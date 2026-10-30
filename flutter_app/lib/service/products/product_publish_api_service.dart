import 'package:pokem_app/model/products/product_photo.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_draft.dart';

class ProductPublishApiService {
  ProductPublishApiService(this._client, {required String baseUrl})
    : _base = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _base;
  Future<Map<String, dynamic>> _perform(http.BaseRequest request) async {
    try {
      final result = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(result)
          .timeout(const Duration(seconds: 45));
      Object? body;
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        /* non-JSON error */
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body is! Map<String, dynamic>) {
          throw const ProductException('서버 응답 형식을 확인해주세요.');
        }
        return body;
      }
      final detail = body is Map && body['detail'] is String
          ? body['detail'] as String
          : null;
      throw ProductException(
        response.statusCode >= 500
            ? '서버에서 등록을 처리하지 못했습니다. 목록에서 등록 여부를 확인해주세요.'
            : detail ?? '상품 등록 요청을 확인해주세요.',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const ProductException(
        '응답 시간이 초과되었습니다. 다시 등록하기 전에 목록에서 등록 여부를 확인해주세요.',
      );
    } on http.ClientException {
      throw const ProductException(
        '서버 연결이 끊겼습니다. 다시 등록하기 전에 목록에서 등록 여부를 확인해주세요.',
      );
    }
  }

  Uri _uri(String path) {
    final uri = Uri.parse('$_base$path');
    if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      throw const ProductException('API 서버 주소를 확인해주세요.');
    }
    return uri;
  }

  Future<String> uploadPhoto(ProductPhoto photo, String token) async {
    if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
      throw const ProductException('사진은 0바이트보다 크고 5MB 이하여야 합니다.');
    }
    final request = http.MultipartRequest('POST', _uri('/sell_product/image'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          photo.bytes,
          filename: photo.filename,
        ),
      );
    final body = await _perform(request);
    final url = body['sell_product_image'];
    if (url is! String || url.isEmpty) {
      throw const ProductException('이미지 업로드 응답을 확인해주세요.');
    }
    return url;
  }

  Future<Product> create(ProductDraft draft, String url, String token) async {
    final request = http.Request('POST', _uri('/sell_product'))
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      })
      ..body = jsonEncode(draft.toJson(url));
    final json = await _perform(request);
    try {
      return Product.fromJson(json);
    } on TypeError {
      throw const ProductException('등록 응답 형식이 올바르지 않습니다. 목록에서 등록 여부를 확인해주세요.');
    }
  }
}
