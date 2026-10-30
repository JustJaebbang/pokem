import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokem_app/service/chat/chat_socket_service.dart';

void main() {
  test(
    'native WebSocket authenticates in first frame and exchanges messages',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? peer;
      final authenticated = Completer<void>();
      final echoed = Completer<void>();
      final serverEvents = server.listen((request) async {
        expect(request.uri.path, '/chat_room/CR_1/ws');
        expect(request.uri.query, isEmpty);
        peer = await WebSocketTransformer.upgrade(request);
        peer!.listen((raw) {
          final frame = jsonDecode(raw as String) as Map;
          if (frame['type'] == 'auth') {
            expect(frame, {'type': 'auth', 'access_token': 'test-token'});
            authenticated.complete();
            peer!.add(
              jsonEncode({
                'type': 'ready',
                'room_id': 'CR_1',
                'user_id': 'tester',
              }),
            );
          } else {
            expect(frame, {'chat_contents': '안녕'});
            peer!.add(
              jsonEncode({
                'type': 'message',
                'data': {'chat_contents': '안녕'},
              }),
            );
          }
        });
      });
      final connection = await ChatSocketService(
        baseUrl: 'http://127.0.0.1:${server.port}',
      ).connect('CR_1', 'test-token');
      addTearDown(() async {
        await connection.close();
        await peer?.close();
        await serverEvents.cancel();
        await server.close(force: true);
      });
      final subscription = connection.events.listen((raw) {
        final frame = jsonDecode(raw as String) as Map;
        if (frame['type'] == 'ready') connection.send({'chat_contents': '안녕'});
        if (frame['type'] == 'message') echoed.complete();
      });
      addTearDown(subscription.cancel);
      await authenticated.future.timeout(const Duration(seconds: 5));
      await echoed.future.timeout(const Duration(seconds: 5));
    },
  );
}
