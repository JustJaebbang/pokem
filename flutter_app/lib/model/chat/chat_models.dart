class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.status,
    required this.productCode,
    required this.buyerId,
    required this.sellerId,
    this.otherNickname,
    this.otherImage,
    this.otherWithdrawn = false,
  });
  final String id, name, status, productCode, buyerId, sellerId;
  final String? otherNickname, otherImage;
  final bool otherWithdrawn;
  String displayOther(String userId) => otherWithdrawn
      ? '탈퇴한 사용자'
      : otherNickname?.trim().isNotEmpty == true
      ? otherNickname!
      : otherId(userId);
  String? get displayOtherImage => otherWithdrawn ? null : otherImage;
  bool get isClosed => status == '종료';
  String otherId(String userId) => userId == buyerId ? sellerId : buyerId;
  factory ChatRoom.fromJson(Map<String, dynamic> j) => ChatRoom(
    id: j['chat_room_id'] as String,
    name: j['chat_room_name'] as String? ?? '상품 문의',
    status: j['chat_room_status'] as String,
    productCode: j['sell_product_sell_product_code'] as String,
    buyerId: j['inquirer_user_id'] as String,
    sellerId: j['seller_user_id'] as String,
    otherNickname: j['other_user_nickname'] as String?,
    otherImage: j['other_user_profile_image'] as String?,
    otherWithdrawn: j['other_user_withdrawn'] as bool? ?? false,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.seq,
    required this.text,
    required this.time,
    required this.roomId,
    required this.userId,
  });
  final int seq;
  final String text, roomId, userId;
  final DateTime time;
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    seq: j['chat_seq'] as int,
    text: j['chat_contents'] as String,
    time: DateTime.parse(j['chat_time'] as String),
    roomId: j['chat_room_chat_room_id'] as String,
    userId: j['user_user_id'] as String,
  );
}

class ChatException implements Exception {
  const ChatException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}
