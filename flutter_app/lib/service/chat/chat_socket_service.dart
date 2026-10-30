import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pokem_app/model/chat/chat_models.dart';

abstract class ChatConnection {
  Stream<Object?> get events;
  int? get closeCode;
  void send(Map<String, Object> data);
  Future<void> close();
}

class IoChatConnection implements ChatConnection {
  IoChatConnection(this.socket);
  final WebSocket socket;
  @override
  Stream<Object?> get events => socket;
  @override
  int? get closeCode => socket.closeCode;
  @override
  void send(Map<String, Object> data) => socket.add(jsonEncode(data));
  @override
  Future<void> close() async {
    await socket.close();
  }
}

class ChatSocketService {
  ChatSocketService({required this.baseUrl});
  final String baseUrl;
  Future<ChatConnection> connect(String roomId, String token) async {
    final base = Uri.parse(baseUrl);
    if (!['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
      throw const ChatException('서버 주소를 확인해주세요.');
    }
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat_room/${Uri.encodeComponent(roomId)}/ws',
    ).replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
    var timedOut = false;
    final pending = WebSocket.connect(uri.toString());
    unawaited(
      pending.then<void>((socket) async {
        if (timedOut) await socket.close();
      }, onError: (Object error, StackTrace stack) {}),
    );
    final socket = await pending.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        timedOut = true;
        throw const ChatException('채팅 연결 시간이 초과되었습니다.');
      },
    );
    socket.pingInterval = const Duration(seconds: 20);
    final connection = IoChatConnection(socket);
    connection.send({'type': 'auth', 'access_token': token});
    return connection;
  }
}
