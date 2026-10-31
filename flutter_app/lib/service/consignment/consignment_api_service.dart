import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/consignment/consignment.dart';

class ConsignmentApiService {
  ConsignmentApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<dynamic> _get(String path, String token) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const ConsignmentException('API 서버 주소를 확인해주세요.');
      }
      final r = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw ConsignmentException(
          r.statusCode == 404 ? '대리판매 등록을 찾을 수 없습니다.' : '대리판매 정보를 불러오지 못했습니다.',
          status: r.statusCode,
        );
      }
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on TimeoutException {
      throw const ConsignmentException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const ConsignmentException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const ConsignmentException('대리판매 응답을 확인하지 못했습니다.');
    }
  }

  Future<List<Consignment>> list(String token) async {
    try {
      final rows = await _get('/post_consign_item', token) as List;
      return rows
          .map((r) => Consignment.fromJson(r as Map<String, dynamic>))
          .toList();
    } on TypeError {
      throw const ConsignmentException('대리판매 응답을 확인하지 못했습니다.');
    }
  }

  Future<Consignment> detail(String code, String token) async {
    try {
      return Consignment.fromJson(
        await _get('/post_consign_item/${Uri.encodeComponent(code)}', token)
            as Map<String, dynamic>,
      );
    } on TypeError {
      throw const ConsignmentException('대리판매 응답을 확인하지 못했습니다.');
    }
  }
}
