import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/service/chat/chat_api_service.dart';
import 'package:pokem_app/service/chat/chat_socket_service.dart';

class ChatRepository {
  ChatRepository(this.api, this.socket);
  final ChatApiService api;
  final ChatSocketService socket;
  Future<ChatRoom> open(String code, String token) => api.open(code, token);
  Future<ChatRoom> room(String id, String token) => api.room(id, token);
  Future<List<ChatRoom>> rooms(String token, int offset) =>
      api.rooms(token, offset);
  Future<List<ChatMessage>> messages(String id, String token, int after) =>
      api.messages(id, token, after);
  Future<ChatConnection> connect(String id, String token) =>
      socket.connect(id, token);
}
