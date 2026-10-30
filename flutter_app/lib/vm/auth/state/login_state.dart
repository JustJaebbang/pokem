import 'package:pokem_app/model/auth/auth_session.dart';

class LoginState {
  const LoginState({
    this.restoring = false,
    this.submitting = false,
    this.session,
    this.error,
  });
  bool get isCustomer => session?.account.role == AccountRole.user;
  final bool restoring;
  final bool submitting;
  final AuthSession? session;
  final String? error;
}
