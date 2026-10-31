import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/auth/recovery.dart';
import 'package:pokem_app/vm/auth/state/recovery_state.dart';
export 'package:pokem_app/model/auth/recovery.dart';

class RecoveryVm extends Notifier<RecoveryState> {
  RecoveryVm(this.purpose);
  final RecoveryPurpose purpose;
  Timer? _timer;
  DateTime? _expires, _resend;
  @override
  RecoveryState build() {
    ref.onDispose(() => _timer?.cancel());
    return const RecoveryState();
  }

  String message(Object e) =>
      e is AuthException ? e.message : '요청을 처리하지 못했습니다. 다시 시도해주세요.';
  Future<void> request(String email, String id) async {
    if (state.busy || state.resendIn > 0 || state.result != null) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
        email.trim().length > 254) {
      state = state.copyWith(error: '가입한 이메일 주소를 입력해주세요.');
      return;
    }
    if (purpose == RecoveryPurpose.resetPassword && id.trim().isEmpty) {
      state = state.copyWith(error: '아이디를 입력해주세요.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final challenge = await ref
          .read(recoveryRepositoryProvider)
          .request(purpose, email, id);
      if (!ref.mounted) return;
      _expires = DateTime.now().add(Duration(seconds: challenge.expiresIn));
      _resend = DateTime.now().add(Duration(seconds: challenge.retryAfter));
      state = RecoveryState(
        challenge: challenge,
        secondsLeft: challenge.expiresIn,
        resendIn: challenge.retryAfter,
      );
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final now = DateTime.now();
        state = state.copyWith(
          secondsLeft: ((_expires!.difference(now).inMilliseconds) / 1000)
              .ceil()
              .clamp(0, 3600),
          resendIn: ((_resend!.difference(now).inMilliseconds) / 1000)
              .ceil()
              .clamp(0, 3600),
        );
        if (state.secondsLeft == 0) _timer?.cancel();
      });
    } catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false, error: message(e));
    }
  }

  Future<void> complete(
    String code,
    String password,
    String confirmation,
  ) async {
    if (state.busy || state.result != null) return;
    String? error;
    if (state.challenge == null || state.secondsLeft <= 0) {
      error = '인증번호를 다시 요청해주세요.';
    } else if (!RegExp(r'^[0-9]{6}$').hasMatch(code.trim())) {
      error = '인증번호 6자리를 입력해주세요.';
    } else if (purpose == RecoveryPurpose.resetPassword &&
        (password.length < 8 || password.length > 128)) {
      error = '비밀번호는 8~128자로 입력해주세요.';
    } else if (purpose == RecoveryPurpose.resetPassword &&
        password != confirmation) {
      error = '비밀번호가 일치하지 않습니다.';
    }
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref
          .read(recoveryRepositoryProvider)
          .complete(
            state.challenge!.id,
            code,
            purpose == RecoveryPurpose.resetPassword ? password : null,
          );
      if (!ref.mounted) return;
      _timer?.cancel();
      state = state.copyWith(busy: false, result: result, clearError: true);
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          busy: false,
          error:
              purpose == RecoveryPurpose.resetPassword &&
                  (e is! AuthException ||
                      e.statusCode == null ||
                      e.statusCode! >= 500)
              ? '비밀번호 변경 여부를 확인하지 못했습니다. 로그인 화면에서 새 비밀번호로 확인해주세요.'
              : message(e),
        );
      }
    }
  }
}

final recoveryVmProvider = NotifierProvider.autoDispose
    .family<RecoveryVm, RecoveryState, RecoveryPurpose>(RecoveryVm.new);
