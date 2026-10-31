import 'dart:convert';

import 'package:pokem_app/core/storage/session_storage.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/auth/register_request.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final AuthApiService _api;
  final SessionStorage _storage;
  AuthSession? _session;
  AuthSession? get session => _session?.isExpired == false ? _session : null;

  Future<String> register(RegisterRequest request) async {
    final json = await _api.register(request.toJson());
    final id = json['user_id'];
    if (id is! String || id != request.id.trim()) {
      throw const AuthException('회원가입 응답 형식을 확인해주세요. 가입 여부를 확인한 뒤 로그인해주세요.');
    }
    return id;
  }

  Future<AuthSession> login(
    String id,
    String password, {
    required bool remember,
  }) async {
    final json = await _api.login(id, password);
    late final AuthSession result;
    try {
      final token = json['access_token'] as String;
      final seconds = json['expires_in'] as int;
      if (token.isEmpty || seconds <= 0 || json['token_type'] != 'bearer') {
        throw const FormatException('Invalid session');
      }
      result = AuthSession(
        token: token,
        expiresAt: DateTime.now().add(Duration(seconds: seconds)),
        account: AuthAccount.fromJson(json),
      );
    } catch (_) {
      throw const AuthException('로그인 응답 형식이 올바르지 않습니다.');
    }
    // 비밀번호·회원정보는 저장하지 않는다. 자동로그인 해제 시 이전 저장 값도 제거한다.
    if (remember) {
      await _storage.write(
        jsonEncode({
          'token': result.token,
          'expires_at': result.expiresAt.toUtc().toIso8601String(),
        }),
      );
    } else {
      await _storage.clear();
    }
    _session = result;
    return result;
  }

  Future<AuthSession?> restore() async {
    final raw = await _storage.read();
    if (raw == null) return null;
    late final String token;
    late final DateTime expiresAt;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      token = saved['token'] as String;
      expiresAt = DateTime.parse(saved['expires_at'] as String);
      if (token.isEmpty || !expiresAt.isAfter(DateTime.now())) {
        await _storage.clear();
        return null;
      }
    } on FormatException {
      await _storage.clear();
      return null;
    } on TypeError {
      await _storage.clear();
      return null;
    }
    try {
      final account = AuthAccount.fromJson(await _api.me(token));
      if (!expiresAt.isAfter(DateTime.now())) {
        await _storage.clear();
        return null;
      }
      return _session = AuthSession(
        token: token,
        expiresAt: expiresAt,
        account: account,
      );
    } on AuthException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _storage.clear();
        return null;
      }
      rethrow;
    } on FormatException {
      throw const AuthException('계정 응답 형식을 확인해주세요.');
    } on TypeError {
      throw const AuthException('계정 응답 형식을 확인해주세요.');
    } on ArgumentError {
      throw const AuthException('계정 역할을 확인해주세요.');
    }
  }

  void forgetSession() {
    _session = null;
  }

  Future<void> logout() async {
    await _storage.clear();
    _session = null;
  }
}
