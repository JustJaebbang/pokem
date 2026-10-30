enum AccountRole {
  user('일반 사용자'),
  manager('매니저'),
  director('디렉터');

  const AccountRole(this.label);
  final String label;
}

class AuthAccount {
  const AuthAccount({required this.id, required this.name, required this.role});
  final String id;
  final String name;
  final AccountRole role;

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    final role = AccountRole.values.byName(json['role'] as String);
    final account = json['account'] as Map<String, dynamic>;
    final id = account['${role.name}_id'] as String;
    final name =
        account[role == AccountRole.user
            ? 'user_nickname'
            : '${role.name}_name'];
    return AuthAccount(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      role: role,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.account,
  });
  final String token;
  final DateTime expiresAt;
  final AuthAccount account;
  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
