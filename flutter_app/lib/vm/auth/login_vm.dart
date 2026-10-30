import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/vm/auth/state/login_state.dart';
export 'package:pokem_app/vm/auth/state/login_state.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/model/auth/auth_session.dart';

class LoginVm extends Notifier<LoginState> {
  Timer? _expiryTimer;

  @override
  LoginState build() {
    ref.onDispose(() => _expiryTimer?.cancel());
    Future.microtask(restoreSession);
    return const LoginState(restoring: true);
  }

  Future<void> restoreSession() async {
    try {
      final session = await ref.read(authRepositoryProvider).restore();
      if (!ref.mounted) return;
      state = LoginState(session: session);
      _scheduleExpiry(session);
    } catch (error) {
      if (ref.mounted) state = LoginState(error: _message(error));
    }
  }

  String? validateId(String? value) =>
      value == null || value.trim().isEmpty ? '아이디를 입력해주세요.' : null;
  String? validatePassword(String? value) =>
      value == null || value.isEmpty ? '비밀번호를 입력해주세요.' : null;

  Future<void> login(
    String id,
    String password, {
    required bool remember,
  }) async {
    if (state.restoring || state.submitting) return;
    final error = validateId(id) ?? validatePassword(password);
    if (error != null) {
      state = LoginState(error: error);
      return;
    }
    state = const LoginState(submitting: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(id.trim(), password, remember: remember);
      if (!ref.mounted) return;
      state = LoginState(session: session);
      _scheduleExpiry(session);
    } catch (error) {
      if (ref.mounted) state = LoginState(error: _message(error));
    }
  }

  Future<void> logout({bool expired = false}) async {
    _expiryTimer?.cancel();
    final previous = state.session;
    state = LoginState(session: previous, submitting: true);
    try {
      await ref.read(authRepositoryProvider).logout();
      if (ref.mounted) {
        state = LoginState(error: expired ? '로그인이 만료되었습니다. 다시 로그인해주세요.' : null);
      }
    } catch (error) {
      if (ref.mounted) {
        state = LoginState(
          session: expired ? null : previous,
          error: '저장된 로그인 정보를 삭제하지 못했습니다. 다시 시도해주세요.',
        );
      }
    }
  }

  void _scheduleExpiry(AuthSession? session) {
    _expiryTimer?.cancel();
    if (session == null) return;
    final remaining = session.expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => logout(expired: true),
    );
  }

  String _message(Object error) => error is AuthException
      ? error.message
      : '로그인 처리 중 오류가 발생했습니다. 다시 시도해주세요.';
}

final loginVmProvider = NotifierProvider<LoginVm, LoginState>(LoginVm.new);
