import 'package:pokem_app/model/profile/quit_state.dart';
import 'package:pokem_app/service/profile/quit_api_service.dart';

class QuitRepository {
  QuitRepository(this._api);
  final QuitApiService _api;
  Future<int> balance(String id, String token) async {
    final json = await _api.request(id, token);
    if (json['user_id'] != id || json['user_money'] is! int) {
      throw const QuitException('회원정보를 확인하지 못했습니다.');
    }
    return json['user_money'] as int;
  }

  Future<void> quit(String id, String token, String reason) async {
    final json = await _api.request(
      id,
      token,
      deleting: true,
      reason: reason.isEmpty ? null : reason,
    );
    if (json['user_id'] != id ||
        json['quit_date'] is! String ||
        DateTime.tryParse(json['quit_date'] as String) == null) {
      throw const QuitException('탈퇴 결과를 확인하지 못했습니다.', uncertain: true);
    }
  }
}
