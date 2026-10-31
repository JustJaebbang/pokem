import 'package:pokem_app/model/profile/user_profile.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.loading = true,
    this.saving = false,
    this.error,
  });
  final UserProfile? profile;
  final bool loading, saving;
  final String? error;
}
