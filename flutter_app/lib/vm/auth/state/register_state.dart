class RegisterState {
  const RegisterState({this.submitting = false, this.registeredId, this.error});
  final bool submitting;
  final String? registeredId;
  final String? error;
}
