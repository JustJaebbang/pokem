enum RecoveryPurpose {
  findId('find_id', '아이디 찾기'),
  resetPassword('reset_password', '비밀번호 찾기');

  const RecoveryPurpose(this.value, this.label);
  final String value, label;
}

class RecoveryChallenge {
  const RecoveryChallenge(this.id, this.expiresIn, this.retryAfter);
  final String id;
  final int expiresIn, retryAfter;
}

class RecoveryResult {
  const RecoveryResult(this.ids, this.message);
  final List<String> ids;
  final String message;
}
