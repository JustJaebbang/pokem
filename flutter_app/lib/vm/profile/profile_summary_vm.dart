import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class ProfileSummaryVm extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) return null;
    try {
      return await ref
          .read(profileRepositoryProvider)
          .getProfile(session.account.id, session.token);
    } on AuthException catch (e) {
      if (e.statusCode == 401 &&
          ref.mounted &&
          ref.read(authRepositoryProvider).session?.token == session.token) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      rethrow;
    }
  }
}

final profileSummaryVmProvider =
    AsyncNotifierProvider.autoDispose<ProfileSummaryVm, UserProfile?>(
      ProfileSummaryVm.new,
      retry: (_, _) => null,
    );
