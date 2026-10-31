import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/wallet/product_payment.dart';

class PaymentApiService {
  PaymentApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<dynamic> _get(String path, String token) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const PaymentException('API 서버 주소를 확인해주세요.');
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
        throw PaymentException(
          response.statusCode == 404 ? '결제내역을 찾을 수 없습니다.' : '결제내역을 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const PaymentException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const PaymentException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const PaymentException('결제내역 응답을 확인하지 못했습니다.');
    }
  }

  Future<List<ProductPayment>> history(String token) async {
    try {
      return (await _get('/cybermoney_pay', token) as List)
          .map((r) => ProductPayment.fromJson(r as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const PaymentException('결제내역 응답을 확인하지 못했습니다.');
    }
  }

  Future<ProductPayment> detail(String code, String token) async {
    try {
      return ProductPayment.fromJson(
        await _get('/cybermoney_pay/${Uri.encodeComponent(code)}', token)
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const PaymentException('결제내역 응답을 확인하지 못했습니다.');
    }
  }
}
