import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final AuthApiService _api;
  Future<UserProfile> getProfile(String id, String token) async {
    try {
      return UserProfile.fromJson(await _api.profile(id, token));
    } on TypeError {
      throw const AuthException('회원정보를 확인하지 못했습니다.');
    }
  }

  Future<UserProfile> update(
    String id,
    ProfileInput input,
    String token,
  ) async {
    try {
      return UserProfile.fromJson(
        await _api.updateProfile(id, input.toJson(), token),
      );
    } on TypeError {
      throw const AuthException('저장 결과를 확인하지 못했습니다. 회원정보를 다시 불러와 확인해주세요.');
    }
  }
}
