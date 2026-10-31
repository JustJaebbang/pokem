import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/profile/quit_state.dart';
import 'package:pokem_app/service/profile/quit_api_service.dart';
import 'package:pokem_app/repository/profile/quit_repository.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/profile/quit_vm.dart';
import 'package:pokem_app/view/profile/quit_view.dart';

import 'auth_test.dart' as auth;

class FakeQuit implements QuitRepository {
  int money = 0, writes = 0;
  Object? error;
  Completer<void>? pending;
  @override
  Future<int> balance(String id, String token) async => money;
  @override
  Future<void> quit(String id, String token, String reason) async {
    writes++;
    if (error != null) throw error!;
    if (pending != null) await pending!.future;
  }
}

class Storage extends auth.MemoryStorage {
  bool fail = false;
  @override
  Future<void> clear() async {
    if (fail) throw StateError('storage');
    await super.clear();
  }
}

void main() {
  test(
    'authenticated DELETE sends optional reason and validates identity',
    () async {
      final repo = QuitRepository(
        QuitApiService(
          MockClient((r) async {
            expect(r.method, 'DELETE');
            expect(r.url.path, '/user/tester');
            expect(r.headers['Authorization'], 'Bearer token');
            expect(jsonDecode(r.body), {'quit_reason': null});
            return auth.response({
              'user_id': 'tester',
              'quit_date': '2026-10-31T12:00:00+09:00',
            });
          }),
          baseUrl: 'http://test.local',
        ),
      );
      await repo.quit('tester', 'token', '');
    },
  );
  test('409 is definite and malformed success is uncertain', () async {
    for (final status in [409, 200]) {
      final repo = QuitRepository(
        QuitApiService(
          MockClient(
            (_) async => auth.response({'detail': '연결된 기록이 있습니다.'}, status),
          ),
          baseUrl: 'http://test.local',
        ),
      );
      await expectLater(
        repo.quit('tester', 'token', ''),
        throwsA(
          isA<QuitException>().having(
            (e) => e.uncertain,
            'uncertain',
            status == 200,
          ),
        ),
      );
    }
  });
  Future<ProviderContainer> start(FakeQuit repo, {Storage? storage}) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            storage ?? Storage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        quitRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: true);
    c.read(quitVmProvider);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('balance consent and reason guards block requests', () async {
    final repo = FakeQuit()..money = 10;
    final c = await start(repo);
    final vm = c.read(quitVmProvider.notifier);
    await vm.submit('', acknowledged: true);
    expect(repo.writes, 0);
    repo.money = 0;
    await vm.load();
    await vm.submit('', acknowledged: false);
    expect(repo.writes, 0);
    await vm.submit('x' * 201, acknowledged: true);
    expect(repo.writes, 0);
  });
  test(
    'double submit blocked and successful quit removes stored session',
    () async {
      final repo = FakeQuit()..pending = Completer<void>();
      final storage = Storage();
      final c = await start(repo, storage: storage);
      final vm = c.read(quitVmProvider.notifier);
      final first = vm.submit('', acknowledged: true);
      await vm.submit('', acknowledged: true);
      expect(repo.writes, 1);
      repo.pending!.complete();
      await first;
      expect(c.read(loginVmProvider).session, isNull);
      expect(c.read(authRepositoryProvider).session, isNull);
      expect(storage.value, isNull);
    },
  );
  test('definite rejection keeps session and allows correction', () async {
    final repo = FakeQuit()
      ..error = const QuitException('연결된 기록이 있습니다.', status: 409);
    final c = await start(repo);
    await c.read(quitVmProvider.notifier).submit('', acknowledged: true);
    expect(c.read(loginVmProvider).session, isNotNull);
    expect(c.read(quitVmProvider).uncertain, isFalse);
    expect(c.read(quitVmProvider).busy, isFalse);
  });
  test('ambiguous deletion cannot be resent even after status check', () async {
    final repo = FakeQuit()
      ..error = const QuitException('timeout', uncertain: true);
    final c = await start(repo);
    final vm = c.read(quitVmProvider.notifier);
    await vm.submit('', acknowledged: true);
    await vm.load();
    await vm.submit('', acknowledged: true);
    expect(repo.writes, 1);
    expect(c.read(quitVmProvider).uncertain, isTrue);
    expect(c.read(loginVmProvider).session, isNotNull);
  });
  test(
    'successful server deletion does not restore session on storage failure',
    () async {
      final storage = Storage();
      final c = await start(FakeQuit(), storage: storage);
      storage.fail = true;
      await c.read(quitVmProvider.notifier).submit('', acknowledged: true);
      expect(c.read(loginVmProvider).session, isNull);
      expect(c.read(authRepositoryProvider).session, isNull);
    },
  );
  testWidgets('confirmation cancel does not send delete', (tester) async {
    final repo = FakeQuit();
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: QuitView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '회원탈퇴'));
    await tester.tap(find.widgetWithText(FilledButton, '회원탈퇴'));
    await tester.pumpAndSettle();
    expect(find.text('탈퇴하시겠어요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
  });
}
