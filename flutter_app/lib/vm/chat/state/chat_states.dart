import 'package:pokem_app/model/chat/chat_models.dart';

class ChatStartState {
  const ChatStartState({this.opening = false, this.error});
  final bool opening;
  final String? error;
}

class ChatRoomsState {
  const ChatRoomsState({
    this.loading = false,
    this.rooms = const [],
    this.hasMore = false,
    this.error,
  });
  final bool loading, hasMore;
  final List<ChatRoom> rooms;
  final String? error;
}

class ChatRoomState {
  const ChatRoomState({
    this.room,
    this.userId = '',
    this.messages = const [],
    this.connecting = true,
    this.ready = false,
    this.sending = false,
    this.closed = false,
    this.error,
    this.sentRevision = 0,
  });
  final ChatRoom? room;
  final String userId;
  final List<ChatMessage> messages;
  final bool connecting, ready, sending, closed;
  final String? error;
  final int sentRevision;
  bool get canSend => ready && !connecting && !sending && !closed;
  ChatRoomState copyWith({
    ChatRoom? room,
    List<ChatMessage>? messages,
    bool? connecting,
    bool? ready,
    bool? sending,
    bool? closed,
    String? error,
    bool clearError = false,
    int? sentRevision,
  }) => ChatRoomState(
    room: room ?? this.room,
    userId: userId,
    messages: messages ?? this.messages,
    connecting: connecting ?? this.connecting,
    ready: ready ?? this.ready,
    sending: sending ?? this.sending,
    closed: closed ?? this.closed,
    error: clearError ? null : error ?? this.error,
    sentRevision: sentRevision ?? this.sentRevision,
  );
}
