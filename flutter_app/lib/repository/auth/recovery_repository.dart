import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/auth/recovery.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';

class RecoveryRepository {
  RecoveryRepository(this._api);
  final AuthApiService _api;
  Future<RecoveryChallenge> request(
    RecoveryPurpose purpose,
    String email,
    String id,
  ) async {
    final data = await _api.requestRecovery({
      'purpose': purpose.value,
      'email': email.trim(),
      if (purpose == RecoveryPurpose.resetPassword) 'user_id': id.trim(),
    });
    try {
      final result = RecoveryChallenge(
        data['challenge_id'] as String,
        data['expires_in'] as int,
        data['retry_after'] as int,
      );
      if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(result.id) ||
          result.expiresIn <= 0 ||
          result.retryAfter <= 0) {
        throw const FormatException();
      }
      return result;
    } catch (_) {
      throw const AuthException('인증 요청 응답을 확인해주세요. 다시 요청해주세요.');
    }
  }

  Future<RecoveryResult> complete(
    String challenge,
    String code,
    String? password,
  ) async {
    final data = await _api.completeRecovery({
      'challenge_id': challenge,
      'code': code.trim(),
      'new_password': ?password,
    });
    try {
      return RecoveryResult(
        List<String>.from(data['user_ids'] as List),
        data['message'] as String,
      );
    } catch (_) {
      throw const AuthException('처리 결과를 확인하지 못했습니다. 로그인 화면에서 계정을 확인해주세요.');
    }
  }
}
