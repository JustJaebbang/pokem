import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/notifications/app_notification.dart';

class NotificationsApiService {
  NotificationsApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<List<AppNotification>> get(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/notifications');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const NotificationsException('API 서버 주소를 확인해주세요.');
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
        throw NotificationsException(
          '알림을 불러오지 못했습니다.',
          status: response.statusCode,
        );
      }
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw const NotificationsException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const NotificationsException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const NotificationsException('알림 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const NotificationsException('알림 응답을 확인하지 못했습니다.');
    }
  }
}
