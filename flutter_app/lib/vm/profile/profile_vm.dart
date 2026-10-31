import 'package:flutter/services.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/profile/profile_summary_vm.dart';
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
    if (!ref.mounted || state.saving || state.picking) return;
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
    if (state.loading ||
        state.saving ||
        state.picking ||
        state.profile == null) {
      return false;
    }
    final error =
        validatePhone(input.phone) ??
        validateEmail(input.email) ??
        validateAddress(input.address);
    if (error != null) {
      state = state.copyWith(error: error);
      return false;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return false;
    }
    final previous = state.profile;
    state = state.copyWith(saving: true, clearError: true);
    try {
      var image = state.uploadedUrl;
      if (state.photo != null && image == null) {
        image = await ref
            .read(productPublishRepositoryProvider)
            .uploadPhoto(state.photo!, session.token);
        if (!_current(session.token)) return false;
        state = state.copyWith(uploadedUrl: image);
      }
      final effective = ProfileInput(
        phone: input.phone,
        email: input.email,
        address: input.address,
        updateImage:
            state.photo != null || state.removeImage || input.updateImage,
        imageUrl: state.removeImage ? null : image ?? input.imageUrl,
      );
      final updated = await ref
          .read(profileRepositoryProvider)
          .update(session.account.id, effective, session.token);
      if (!_current(session.token)) return false;
      state = ProfileState(profile: updated, loading: false);
      ref.invalidate(profileSummaryVmProvider);
      return true;
    } catch (e) {
      if (!_current(session.token)) return false;
      state = state.copyWith(
        profile: previous,
        saving: false,
        error: e is AuthException
            ? e.message
            : e is ProductException
            ? e.message
            : '회원정보를 저장하지 못했습니다.',
      );
      await _unauthorized(e);
      return false;
    }
  }

  Future<void> pickPhoto() async {
    if (state.loading ||
        state.saving ||
        state.picking ||
        state.profile == null) {
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = state.copyWith(picking: true, clearError: true);
    try {
      final photo = await ref.read(productPhotoPickerProvider).pick();
      if (!_current(session.token)) return;
      if (photo == null) {
        state = state.copyWith(picking: false);
        return;
      }
      if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
        throw const ProductException('사진은 0바이트보다 크고 5MB 이하여야 합니다.');
      }
      state = state.copyWith(
        photo: photo,
        picking: false,
        removeImage: false,
        clearUploaded: true,
      );
    } catch (e) {
      if (!_current(session.token)) return;
      state = state.copyWith(
        picking: false,
        error: e is ProductException
            ? e.message
            : e is PlatformException &&
                  [
                    'photo_access_denied',
                    'photo_access_restricted',
                  ].contains(e.code)
            ? '기기 설정에서 사진 접근 권한을 확인해주세요.'
            : '사진을 열지 못했습니다. 다시 시도해주세요.',
      );
    }
  }

  void useDefaultPhoto() {
    if (state.loading || state.saving || state.picking) return;
    state = state.copyWith(
      removeImage: true,
      clearPhoto: true,
      clearUploaded: true,
      clearError: true,
    );
  }

  void cancelPhotoChange() {
    if (state.loading || state.saving || state.picking) return;
    state = state.copyWith(
      removeImage: false,
      clearPhoto: true,
      clearUploaded: true,
      clearError: true,
    );
  }

  Future<void> _unauthorized(Object e) async {
    if ((e is AuthException && e.statusCode == 401) ||
        (e is ProductException && e.statusCode == 401)) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final profileVmProvider = NotifierProvider.autoDispose<ProfileVm, ProfileState>(
  ProfileVm.new,
);
