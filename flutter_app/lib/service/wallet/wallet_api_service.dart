import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/wallet/wallet_models.dart';

class WalletApiService {
  WalletApiService(this._client, {required String baseUrl})
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
        throw const WalletException('API 서버 주소를 확인해주세요.');
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
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is Map && json['detail'] is String) {
            detail = json['detail'] as String;
          }
        } catch (_) {}
        throw WalletException(
          response.statusCode >= 500
              ? '처리 결과를 확인하지 못했습니다.'
              : detail ?? '요청을 처리하지 못했습니다.',
          status: response.statusCode,
          uncertain: writing && response.statusCode >= 500,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw WalletException('서버 응답이 늦어지고 있습니다.', uncertain: writing);
    } on http.ClientException {
      throw WalletException('서버에 연결하지 못했습니다.', uncertain: writing);
    } on FormatException {
      throw WalletException('서버 응답을 확인하지 못했습니다.', uncertain: writing);
    }
  }

  Future<int> balance(String id, String token) async {
    try {
      return (await _request('/user/${Uri.encodeComponent(id)}', token)
              as Map<String, dynamic>)['user_money']
          as int;
    } on TypeError {
      throw const WalletException('잔액을 확인하지 못했습니다.');
    }
  }

  Future<List<MoneyRecord>> history(MoneyAction action, String token) async {
    try {
      return (await _request('/${action.path}', token) as List<dynamic>)
          .map(
            (row) => MoneyRecord.fromJson(action, row as Map<String, dynamic>),
          )
          .toList();
    } on TypeError {
      throw const WalletException('내역을 확인하지 못했습니다.');
    }
  }

  Future<MoneyReceipt> transfer(
    MoneyAction action,
    String account,
    int amount,
    String token,
  ) async {
    try {
      final json = await _request(
        '/${action.path}',
        token,
        body: {
          '${action.path}_account': account,
          '${action.path}_price': amount,
        },
      ) as Map<String, dynamic>;
      return MoneyReceipt(
        MoneyRecord.fromJson(action, json),
        json['user_money'] as int,
      );
    } on TypeError {
      throw const WalletException('처리 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
