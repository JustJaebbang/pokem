class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.nickname,
    this.imageUrl,
    this.withdrawn = false,
  });
  final String id, nickname;
  final String? imageUrl;
  final bool withdrawn;
  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
    id: j['user_id'] as String,
    nickname: j['user_nickname'] as String,
    imageUrl: j['user_profile_image'] as String?,
    withdrawn: j['is_withdrawn'] as bool? ?? false,
  );
}

class PublicProfileException implements Exception {
  const PublicProfileException(this.message);
  final String message;
}
