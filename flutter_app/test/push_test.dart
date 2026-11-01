import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/push/push_target.dart';
import 'package:pokem_app/repository/push/push_repository.dart';
import 'package:pokem_app/service/push/push_device_service.dart';
import 'package:pokem_app/service/push/push_messaging_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/push/push_vm.dart';
import 'package:pokem_app/view/push/push_bridge.dart';

import 'auth_test.dart' as auth;

class Messaging extends PushMessagingService {
  final messages = StreamController<Map<String, dynamic>>.broadcast();
  final taps = StreamController<Map<String, dynamic>>.broadcast();
  final registrations = StreamController<String>.broadcast();
  bool granted = true;
  int revoked = 0;
  Completer<void>? gate;
  @override
  Future<void> initialize() async {}
  @override
  Stream<Map<String, dynamic>> get foreground => messages.stream;
  @override
  Stream<Map<String, dynamic>> get opened => taps.stream;
  @override
  Stream<String> get refreshed => registrations.stream;
  @override
  Future<Map<String, dynamic>?> initial() async => null;
  @override
  Future<bool> permission({bool ask = false}) async => granted;
  @override
  Future<String?> token() async {
    if (gate != null) {
      await gate!.future;
    }
    return 'registration-fid-123456789';
  }

  @override
  Future<void> revoke() async {
    revoked++;
  }

  Future<void> close() async {
    await messages.close();
    await taps.close();
    await registrations.close();
  }
}

class Devices extends PushDeviceService {
  Devices()
    : super(
        MockClient((_) async => auth.response({})),
        baseUrl: 'http://test.local',
      );
  bool allowed = true, failDelete = false;
  final operations = <String>[];
  @override
  Future<String> installation() async => 'a' * 32;
  @override
  Future<bool> wanted(String owner) async => allowed;
  @override
  Future<void> preference(String owner, bool value) async {
    allowed = value;
  }

  @override
  Future<void> update(String jwt, String id, String? token) async {
    operations.add(token == null ? 'delete' : 'put');
    if (token == null && failDelete) {
      throw const PushException();
    }
  }
}

class Repository extends PushRepository {
  Repository(super.messaging, super.devices);
  @override
  bool get available => true;
}

Map<String, dynamic> payload({String owner = 'tester'}) => {
  'target_type': 'inspection_results',
  'target_code': '20261031000001',
  'owner_id': owner,
  'event_id': 'inspection_complete:INS1',
};
AuthSession session() => AuthSession(
  token: 'jwt',
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  account: const AuthAccount(
    id: 'tester',
    name: 'tester',
    role: AccountRole.user,
  ),
);

void main() {
  test('push targets accept only known type and valid request numbers', () {
    expect(PushTarget.parse(payload())?.ownerId, 'tester');
    expect(
      PushTarget.parse({...payload(), 'target_type': 'arbitrary_route'}),
      isNull,
    );
    expect(PushTarget.parse({...payload(), 'target_code': '/admin'}), isNull);
    expect(PushTarget.parse({...payload(), 'owner_id': 42}), isNull);
  });
  test(
    'device API sends credentials only to authenticated device endpoint',
    () async {
      var calls = 0;
      final api = PushDeviceService(
        MockClient((r) async {
          calls++;
          expect(r.headers['Authorization'], 'Bearer jwt');
          expect(r.url.path, '/push/devices/${'a' * 32}');
          if (r.method == 'PUT') {
            expect(jsonDecode(r.body), {'fid': 'fid-value'});
          } else {
            expect(r.method, 'DELETE');
          }
          return auth.response({'registered': r.method == 'PUT'});
        }),
        baseUrl: 'http://test.local',
      );
      await api.update('jwt', 'a' * 32, 'fid-value');
      await api.update('jwt', 'a' * 32, null);
      expect(calls, 2);
    },
  );
  test('logout deletion waits for pending registration and revokes SDK registration', () async {
    final messaging = Messaging()..gate = Completer<void>();
    addTearDown(messaging.close);
    final devices = Devices();
    final repo = Repository(messaging, devices);
    final registration = repo.attach(session());
    await Future<void>.delayed(Duration.zero);
    final logout = repo.detach(session());
    messaging.gate!.complete();
    await registration;
    await logout;
    expect(devices.operations, ['put', 'delete']);
    expect(messaging.revoked, 1);
  });
  test('offline unregister still revokes SDK registration', () async {
    final messaging = Messaging();
    addTearDown(messaging.close);
    final devices = Devices()..failDelete = true;
    final repo = Repository(messaging, devices);
    await expectLater(repo.detach(session()), throwsA(isA<PushException>()));
    expect(messaging.revoked, 1);
  });
  test('opt-out remains disabled until explicit request', () async {
    final messaging = Messaging();
    addTearDown(messaging.close);
    final devices = Devices();
    final repo = Repository(messaging, devices);
    await repo.detach(session(), optOut: true);
    expect(await repo.attach(session()), isFalse);
    expect(devices.operations, ['delete']);
    expect(await repo.attach(session(), ask: true), isTrue);
    expect(devices.allowed, isTrue);
  });
  testWidgets(
    'foreground action and background tap open only the current owner target',
    (tester) async {
      final messaging = Messaging();
      addTearDown(messaging.close);
      final devices = Devices();
      final repo = Repository(messaging, devices);
      final login = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      final opened = <PushTarget>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(login),
            pushRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: PushBridge(
              onOpen: opened.add,
              child: const Scaffold(body: Text('home')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(
        tester.element(find.byType(PushBridge)),
      );
      await c
          .read(loginVmProvider.notifier)
          .login('tester', 'pw', remember: false);
      await tester.pumpAndSettle();
      messaging.messages.add(payload(owner: 'other'));
      await tester.pumpAndSettle();
      expect(find.text('검수가 완료되었습니다.'), findsNothing);
      messaging.messages.add(payload());
      await tester.pumpAndSettle();
      expect(find.text('검수가 완료되었습니다.'), findsOneWidget);
      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();
      expect(opened.length, 1);
      messaging.taps.add(payload());
      await tester.pumpAndSettle();
      expect(opened.length, 2);
      messaging.taps.add(payload());
      await tester.pumpAndSettle();
      expect(opened.length, 2);
      await c.read(loginVmProvider.notifier).logout();
      await tester.pumpAndSettle();
      messaging.taps.add({
        ...payload(),
        'event_id': 'inspection_complete:INS2',
      });
      await tester.pumpAndSettle();
      expect(opened.length, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
