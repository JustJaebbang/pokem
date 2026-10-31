import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/review/review_record.dart';

class ReviewApiService {
  ReviewApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<Object?> _request(
    String path, {
    String? token,
    Map<String, Object>? body,
  }) async {
    final writing = body != null;
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ReviewException('API 서버 주소를 확인해주세요.');
      }
      final headers = {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
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
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is Map && json['detail'] is String) {
            detail = json['detail'] as String;
          }
        } catch (_) {}
        throw ReviewException(
          detail ?? '후기 요청을 처리하지 못했습니다.',
          status: response.statusCode,
          uncertain: writing && response.statusCode >= 500,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw ReviewException('서버 응답이 늦어지고 있습니다.', uncertain: writing);
    } on http.ClientException {
      throw ReviewException('서버에 연결하지 못했습니다.', uncertain: writing);
    } on FormatException {
      throw ReviewException('후기 응답을 확인하지 못했습니다.', uncertain: writing);
    }
  }

  Future<List<ReviewRecord>> list(String productCode) async {
    try {
      final rows =
          (await _request(
                '/review?sell_product_code=${Uri.encodeComponent(productCode)}',
              ) as List<dynamic>)
              .map((row) => ReviewRecord.fromJson(row as Map<String, dynamic>))
              .toList();
      if (rows.any((row) => row.productCode != productCode)) {
        throw const ReviewException('상품과 후기 정보가 일치하지 않습니다.');
      }
      return rows;
    } on TypeError {
      throw const ReviewException('후기 응답을 확인하지 못했습니다.');
    }
  }

  Future<List<ReviewRecord>> listForSeller(String sellerId) async {
    try {
      return (await _request(
            '/review?seller_user_id=${Uri.encodeComponent(sellerId)}',
          ) as List<dynamic>)
          .map((row) => ReviewRecord.fromJson(row as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ReviewException('판매자 후기 응답을 확인하지 못했습니다.');
    }
  }

  Future<ReviewRecord> create(
    String purchaseCode,
    int rating,
    String contents,
    String token,
  ) async {
    try {
      final result = ReviewRecord.fromJson(
        await _request(
          '/review',
          token: token,
          body: {
            'purchase_item_purchase_item_code': purchaseCode,
            'review_rating': rating,
            'review_contents': contents,
          },
        ) as Map<String, dynamic>,
      );
      if (result.purchaseCode != purchaseCode) {
        throw const ReviewException('후기 저장 결과를 확인하지 못했습니다.', uncertain: true);
      }
      return result;
    } on TypeError {
      throw const ReviewException('후기 저장 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
