import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokem_app/model/profile/public_profile.dart';

class PublicProfileApiService {
  PublicProfileApiService(this._client, {required String baseUrl})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final http.Client _client;
  final String _baseUrl;
  Future<PublicProfile> get(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/profiles/${Uri.encodeComponent(id)}');
      if (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
        throw const PublicProfileException('API 서버 주소를 확인해주세요.');
      }
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const PublicProfileException('프로필을 불러오지 못했습니다.');
      }
      return PublicProfile.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on TimeoutException {
      throw const PublicProfileException('서버 응답이 늦어지고 있습니다.');
    } on http.ClientException {
      throw const PublicProfileException('서버에 연결하지 못했습니다.');
    } on FormatException {
      throw const PublicProfileException('프로필 응답을 확인하지 못했습니다.');
    } on TypeError {
      throw const PublicProfileException('프로필 응답을 확인하지 못했습니다.');
    }
  }
}
