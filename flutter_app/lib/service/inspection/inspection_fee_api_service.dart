import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/inspection/inspection_fee.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';

class InspectionFeeApiService {
  InspectionFeeApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<InspectionFee?> getFee(String number, String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/pay')
          .replace(queryParameters: {'request_no': number, 'limit': '2'});
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const InspectionException('API 서버 주소를 확인해주세요.');
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
        throw InspectionException(
          '검수비 정보를 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (rows.isEmpty) return null;
      if (rows.length != 1) {
        throw const InspectionException('검수비 정보가 중복되어 있습니다. 담당자에게 확인해주세요.');
      }
      final fee = InspectionFee.fromJson(rows.single as Map<String, dynamic>);
      if (fee.requestNumber != number) {
        throw const InspectionException('신청번호와 결제 정보가 일치하지 않습니다.');
      }
      return fee;
    } on TimeoutException {
      throw const InspectionException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const InspectionException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const InspectionException('검수비 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const InspectionException('검수비 응답을 확인하지 못했습니다.');
    }
  }

  Future<InspectionFee> complete(InspectionFee fee, String token) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/pay/${Uri.encodeComponent(fee.number)}/complete',
      );
      final response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'expected_price': fee.price}),
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
        throw InspectionException(
          detail ?? '결제 결과를 확인하지 못했습니다.',
          status: response.statusCode,
          uncertain: response.statusCode >= 500,
        );
      }
      final result = InspectionFee.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (result.number != fee.number ||
          result.requestNumber != fee.requestNumber ||
          result.status != '결제완료') {
        throw const InspectionException('결제 결과를 확인하지 못했습니다.', uncertain: true);
      }
      return result;
    } on TimeoutException {
      throw const InspectionException('결제 결과를 확인하지 못했습니다.', uncertain: true);
    } on http.ClientException {
      throw const InspectionException('결제 결과를 확인하지 못했습니다.', uncertain: true);
    } on FormatException {
      throw const InspectionException('결제 결과를 확인하지 못했습니다.', uncertain: true);
    } on TypeError {
      throw const InspectionException('결제 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
