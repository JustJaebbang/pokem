class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.nickname,
    required this.phone,
    required this.email,
    required this.address,
  });
  final String id, name, nickname, phone, email, address;
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['user_id'] as String,
    name: json['user_name'] as String,
    nickname: json['user_nickname'] as String,
    phone: json['user_phone'] as String,
    email: json['user_email'] as String,
    address: json['user_address'] as String,
  );
}

class ProfileInput {
  const ProfileInput({
    required this.phone,
    required this.email,
    required this.address,
  });
  final String phone, email, address;
  Map<String, String> toJson() => {
    'user_phone': phone.trim(),
    'user_email': email.trim(),
    'user_address': address.trim(),
  };
}
