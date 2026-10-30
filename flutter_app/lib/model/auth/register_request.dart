class RegisterRequest {
  const RegisterRequest({
    required this.id,
    required this.password,
    required this.nickname,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });
  final String id;
  final String password;
  final String nickname;
  final String name;
  final String phone;
  final String email;
  final String address;

  Map<String, String> toJson() => {
    'user_id': id.trim(),
    'user_password': password,
    'user_nickname': nickname.trim(),
    'user_name': name.trim(),
    'user_phone': phone.trim(),
    'user_email': email.trim(),
    'user_address': address.trim(),
  };
}
