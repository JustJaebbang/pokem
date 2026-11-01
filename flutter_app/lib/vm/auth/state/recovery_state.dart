import 'package:pokem_app/model/auth/recovery.dart';

class RecoveryState {
  const RecoveryState({
    this.busy = false,
    this.challenge,
    this.result,
    this.error,
    this.secondsLeft = 0,
    this.resendIn = 0,
  });
  final bool busy;
  final RecoveryChallenge? challenge;
  final RecoveryResult? result;
  final String? error;
  final int secondsLeft, resendIn;
  RecoveryState copyWith({
    bool? busy,
    RecoveryChallenge? challenge,
    RecoveryResult? result,
    String? error,
    bool clearError = false,
    int? secondsLeft,
    int? resendIn,
  }) => RecoveryState(
    busy: busy ?? this.busy,
    challenge: challenge ?? this.challenge,
    result: result ?? this.result,
    error: clearError ? null : error ?? this.error,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    resendIn: resendIn ?? this.resendIn,
  );
}
