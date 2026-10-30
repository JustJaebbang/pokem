import 'package:pokem_app/model/auth/register_input.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/vm/auth/state/register_state.dart';
export 'package:pokem_app/vm/auth/state/register_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/auth/register_request.dart';

class RegisterVm extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  String? validateField(
    RegisterField field,
    String? value, {
    String password = '',
  }) {
    final text = value ?? '';
    switch (field) {
      case RegisterField.id:
        if (text.trim().isEmpty) return '아이디를 입력해주세요.';
        if (text.trim().length > 20) return '아이디는 20자 이하여야 합니다.';
        if (RegExp(r'\s').hasMatch(text.trim())) return '아이디에는 공백을 사용할 수 없습니다.';
      case RegisterField.password:
        if (text.trim().isEmpty) return '비밀번호를 입력해주세요.';
      case RegisterField.confirmation:
        if (text.isEmpty) return '비밀번호를 다시 입력해주세요.';
        if (text != password) return '비밀번호가 일치하지 않습니다.';
      case RegisterField.phone:
        if (!RegExp(r'^\+?[0-9\- ]{9,15}$').hasMatch(text.trim())) {
          return '전화번호를 확인해주세요.';
        }
      case RegisterField.email:
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text.trim()) ||
            text.trim().length > 255) {
          return '이메일 형식을 확인해주세요.';
        }
      case RegisterField.nickname:
        if (text.trim().isEmpty) return '닉네임 항목을 입력해주세요.';
        if (text.trim().length > 20) return '닉네임은 20자 이하여야 합니다.';
      case RegisterField.name:
        if (text.trim().isEmpty) return '이름 항목을 입력해주세요.';
        if (text.trim().length > 12) return '이름은 12자 이하여야 합니다.';
      case RegisterField.address:
        if (text.trim().isEmpty) return '주소 항목을 입력해주세요.';
        if (text.trim().length > 255) return '주소는 255자 이하여야 합니다.';
    }
    return null;
  }

  Future<String?> register(RegisterInput input) async {
    if (state.submitting || state.registeredId != null) return null;
    for (final entry in input.fields.entries) {
      final error = validateField(
        entry.key,
        entry.value,
        password: input.password,
      );
      if (error != null) {
        state = RegisterState(error: error);
        return null;
      }
    }
    final request = RegisterRequest(
      id: input.id,
      password: input.password,
      nickname: input.nickname,
      name: input.name,
      phone: input.phone,
      email: input.email,
      address: input.address,
    );
    state = const RegisterState(submitting: true);
    try {
      final id = await ref.read(authRepositoryProvider).register(request);
      if (!ref.mounted) return null;
      state = RegisterState(registeredId: id);
      return id;
    } catch (error) {
      if (ref.mounted) {
        state = RegisterState(
          error: error is AuthException
              ? error.message
              : '회원가입 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
        );
      }
      return null;
    }
  }
}

final registerVmProvider =
    NotifierProvider.autoDispose<RegisterVm, RegisterState>(RegisterVm.new);
