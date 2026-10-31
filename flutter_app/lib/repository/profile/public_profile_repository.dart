import 'package:pokem_app/model/profile/public_profile.dart';
import 'package:pokem_app/service/profile/public_profile_api_service.dart';

class PublicProfileRepository {
  PublicProfileRepository(this._api);
  final PublicProfileApiService _api;
  Future<PublicProfile> get(String id) async {
    final profile = await _api.get(id);
    if (profile.id != id) {
      throw const PublicProfileException('요청한 사용자와 프로필이 일치하지 않습니다.');
    }
    return profile;
  }
}
