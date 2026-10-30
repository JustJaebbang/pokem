import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/repository/chat/chat_repository.dart';
import 'package:pokem_app/service/chat/chat_api_service.dart';
import 'package:pokem_app/service/chat/chat_socket_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/chat/chat_room_vm.dart';
import 'package:pokem_app/vm/chat/chat_start_vm.dart';
import 'package:pokem_app/view/chat/chat_room_view.dart';

import 'auth_test.dart' as auth;

const fixtureRoom = ChatRoom(
  id: 'CR_1',
  name: '피카츄 카드',
  status: '대화중',
  productCode: 'P-1',
  buyerId: 'tester',
  sellerId: 'seller',
);
ChatMessage message(int seq, {String text = '안녕하세요', String user = 'seller'}) =>
    ChatMessage(
      seq: seq,
      text: text,
      time: DateTime.utc(2026, 10, 30, 1),
      roomId: 'CR_1',
      userId: user,
    );
Map<String, Object> event(ChatMessage m) => {
  'type': 'message',
  'data': {
    'chat_seq': m.seq,
    'chat_contents': m.text,
    'chat_time': m.time.toIso8601String(),
    'chat_room_chat_room_id': m.roomId,
    'user_user_id': m.userId,
  },
};

class FakeConnection implements ChatConnection {
  final controller = StreamController<Object?>();
  final sent = <Map<String, Object>>[];
  bool closed = false;
  @override
  int? closeCode;
  @override
  Stream<Object?> get events => controller.stream;
  @override
  void send(Map<String, Object> data) {
    sent.add(data);
  }

  void emit(Map<String, Object> data) {
    controller.add(jsonEncode(data));
  }

  @override
  Future<void> close() async {
    closed = true;
    unawaited(controller.close());
  }
}

class FakeChatRepository implements ChatRepository {
  final connections = <FakeConnection>[];
  final history = <ChatMessage>[];
  final cursors = <int>[];
  String? openedCode;
  ChatRoom currentRoom = fixtureRoom;
  Completer<List<ChatMessage>>? historyGate;
  Object? openError;
  @override
  ChatApiService get api => throw UnimplementedError();
  @override
  ChatSocketService get socket => throw UnimplementedError();
  @override
  Future<ChatRoom> open(String code, String token) async {
    openedCode = code;
    if (openError != null) throw openError!;
    return currentRoom;
  }

  @override
  Future<ChatRoom> room(String id, String token) async => currentRoom;
  @override
  Future<List<ChatRoom>> rooms(String token, int offset) async =>
      offset == 0 ? [currentRoom] : [];
  @override
  Future<List<ChatMessage>> messages(String id, String token, int after) async {
    cursors.add(after);
    if (historyGate != null) return historyGate!.future;
    return history.where((m) => m.seq > after).take(100).toList();
  }

  @override
  Future<ChatConnection> connect(String id, String token) async {
    final c = FakeConnection();
    connections.add(c);
    c.emit({'type': 'ready', 'room_id': id, 'user_id': 'tester'});
    return c;
  }
}

void main() {
  test(
    'HTTP chat contract uses token and product only, with history cursor',
    () async {
      final api = ChatApiService(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {
              'sell_product_sell_product_code': 'P-1',
            });
            return auth.response({
              'chat_room_id': 'CR_1',
              'chat_room_name': '카드',
              'chat_room_status': '대화중',
              'sell_product_sell_product_code': 'P-1',
              'inquirer_user_id': 'tester',
              'seller_user_id': 'seller',
            }, 201);
          }
          expect(request.url.path, '/chat_room/CR_1/messages');
          expect(request.url.queryParameters['after_chat_seq'], '20');
          expect(request.url.queryParameters['limit'], '100');
          return auth.response([event(message(21))['data']]);
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.open('P-1', 'token')).id, 'CR_1');
      expect((await api.messages('CR_1', 'token', 20)).single.seq, 21);
    },
  );

  Future<ProviderContainer> start(
    FakeChatRepository repo, {
    bool roomVm = true,
  }) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        chatRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    if (roomVm) {
      final sub = c.listen(chatRoomVmProvider('CR_1'), (_, _) {});
      addTearDown(sub.close);
    }
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('room creation surfaces server self-chat error', () async {
    final repo = FakeChatRepository()
      ..openError = const ChatException('본인 상품에는 문의할 수 없습니다.', status: 409);
    final c = await start(repo, roomVm: false);
    final sub = c.listen(chatStartVmProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(chatStartVmProvider.notifier).open('P-1'), isNull);
    expect(c.read(chatStartVmProvider).error, contains('본인'));
  });

  test(
    'history paginates beyond 100 and socket duplicates merge by sequence',
    () async {
      final repo = FakeChatRepository()
        ..history.addAll(List.generate(101, (i) => message(i + 1)));
      final c = await start(repo);
      expect(repo.cursors, [0, 100]);
      expect(c.read(chatRoomVmProvider('CR_1')).messages, hasLength(101));
      repo.connections.single.emit(event(message(101)));
      repo.connections.single.emit(event(message(102)));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatRoomVmProvider('CR_1')).messages, hasLength(102));
      expect(c.read(chatRoomVmProvider('CR_1')).canSend, isTrue);
    },
  );

  test(
    'socket arriving during history recovery does not skip earlier messages',
    () async {
      final repo = FakeChatRepository()
        ..historyGate = Completer<List<ChatMessage>>();
      final c = await start(repo);
      repo.connections.single.emit(event(message(3)));
      await Future<void>.delayed(Duration.zero);
      repo.historyGate!.complete([message(1), message(2), message(3)]);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatRoomVmProvider('CR_1')).messages.map((m) => m.seq), [
        1,
        2,
        3,
      ]);
    },
  );

  test(
    'send waits for server echo and rejects blank or long messages',
    () async {
      final repo = FakeChatRepository();
      final c = await start(repo);
      final vm = c.read(chatRoomVmProvider('CR_1').notifier);
      vm.send(' ');
      expect(repo.connections.single.sent, isEmpty);
      vm.send('a' * 501);
      expect(repo.connections.single.sent, isEmpty);
      vm.send(' 보냅니다 ');
      expect(repo.connections.single.sent.single, {'chat_contents': '보냅니다'});
      expect(c.read(chatRoomVmProvider('CR_1')).sending, isTrue);
      expect(c.read(chatRoomVmProvider('CR_1')).messages, isEmpty);
      vm.send('duplicate');
      expect(repo.connections.single.sent, hasLength(1));
      repo.connections.single.emit(
        event(message(1, text: '보냅니다', user: 'tester')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(chatRoomVmProvider('CR_1')).sending, isFalse);
      expect(c.read(chatRoomVmProvider('CR_1')).sentRevision, 1);
    },
  );

  test(
    'reconnect recovers saved messages without resending uncertain text',
    () async {
      final repo = FakeChatRepository()..history.add(message(1));
      final c = await start(repo);
      final vm = c.read(chatRoomVmProvider('CR_1').notifier);
      vm.send('전송');
      repo.history.add(message(2, text: '전송', user: 'tester'));
      await repo.connections.first.close();
      await Future<void>.delayed(Duration.zero);
      await vm.reconnect();
      await Future<void>.delayed(Duration.zero);
      expect(repo.connections, hasLength(2));
      expect(repo.connections.last.sent, isEmpty);
      expect(c.read(chatRoomVmProvider('CR_1')).messages.map((m) => m.seq), [
        1,
        2,
      ]);
      expect(c.read(chatRoomVmProvider('CR_1')).sentRevision, 1);
    },
  );

  test(
    'closed rooms load history without connecting and are read-only',
    () async {
      final repo = FakeChatRepository()
        ..currentRoom = const ChatRoom(
          id: 'CR_1',
          name: '카드',
          status: '종료',
          productCode: 'P-1',
          buyerId: 'tester',
          sellerId: 'seller',
        )
        ..history.add(message(1));
      final c = await start(repo);
      expect(repo.connections, isEmpty);
      expect(c.read(chatRoomVmProvider('CR_1')).messages, hasLength(1));
      expect(c.read(chatRoomVmProvider('CR_1')).canSend, isFalse);
    },
  );

  test(
    'authentication errors stop connection and clear login session',
    () async {
      final repo = FakeChatRepository();
      final c = await start(repo);
      repo.connections.single.emit({
        'type': 'error',
        'status': 401,
        'detail': '만료',
      });
      await Future<void>.delayed(Duration.zero);
      expect(c.read(loginVmProvider).session, isNull);
    },
  );

  testWidgets(
    'chat screen displays incoming bubble and clears composer only after echo',
    (tester) async {
      final repo = FakeChatRepository();
      final session = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(session),
            chatRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: ChatRoomView(roomId: 'CR_1')),
        ),
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ChatRoomView)),
      );
      c.read(loginVmProvider);
      await tester.pump();
      await c
          .read(loginVmProvider.notifier)
          .login('tester', 'pw', remember: false);
      await tester.pumpAndSettle();
      // 로그인 전에 열린 첫 인스턴스의 연결은 재생성되므로 최신 연결을 사용한다.
      await tester.enterText(find.byKey(const Key('chatComposer')), '안녕');
      await tester.tap(find.byKey(const Key('sendChat')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chatComposer')))
            .controller!
            .text,
        '안녕',
      );
      repo.connections.last.emit(event(message(1, text: '안녕', user: 'tester')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-1')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('chatComposer')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
}
