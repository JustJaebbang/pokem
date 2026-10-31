import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/profile/state/profile_state.dart';

class ProfileVm extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(load);
    return const ProfileState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  String? validatePhone(String? value) =>
      RegExp(r'^\+?[0-9\- ]{9,15}$').hasMatch((value ?? '').trim())
      ? null
      : '전화번호를 확인해주세요.';
  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    return text.length <= 255 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : '이메일 형식을 확인해주세요.';
  }

  String? validateAddress(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '주소를 입력해주세요.';
    if (text.length > 255) return '주소는 255자 이하여야 합니다.';
    return null;
  }

  Future<void> load() async {
    if (!ref.mounted || state.saving) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const ProfileState();
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getProfile(session.account.id, session.token);
      if (_current(session.token)) {
        state = ProfileState(profile: profile, loading: false);
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = ProfileState(
        loading: false,
        error: e is AuthException ? e.message : '회원정보를 불러오지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  Future<bool> save(ProfileInput input) async {
    if (state.loading || state.saving || state.profile == null) return false;
    final error =
        validatePhone(input.phone) ??
        validateEmail(input.email) ??
        validateAddress(input.address);
    if (error != null) {
      state = ProfileState(
        profile: state.profile,
        loading: false,
        error: error,
      );
      return false;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return false;
    }
    final previous = state.profile;
    state = ProfileState(profile: previous, loading: false, saving: true);
    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .update(session.account.id, input, session.token);
      if (!_current(session.token)) return false;
      state = ProfileState(profile: updated, loading: false);
      return true;
    } catch (e) {
      if (!_current(session.token)) return false;
      state = ProfileState(
        profile: previous,
        loading: false,
        error: e is AuthException ? e.message : '회원정보를 저장하지 못했습니다.',
      );
      await _unauthorized(e);
      return false;
    }
  }

  Future<void> _unauthorized(Object e) async {
    if (e is AuthException && e.statusCode == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final profileVmProvider = NotifierProvider.autoDispose<ProfileVm, ProfileState>(
  ProfileVm.new,
);
