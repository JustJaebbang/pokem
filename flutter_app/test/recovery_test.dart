import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/repository/auth/recovery_repository.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';
import 'package:pokem_app/vm/auth/recovery_vm.dart';
import 'package:pokem_app/view/auth/recovery_view.dart';

import 'auth_test.dart' as auth;

void main() {
  const challenge = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  test(
    'repository uses recovery endpoints without login and validates response',
    () async {
      final repo = RecoveryRepository(
        AuthApiService(
          MockClient((r) async {
            expect(r.headers['Authorization'], isNull);
            final body = jsonDecode(r.body) as Map;
            if (r.url.path.endsWith('/request')) {
              expect(body, {
                'purpose': 'reset_password',
                'email': 'test@example.com',
                'user_id': 'tester',
              });
              return auth.response({
                'challenge_id': challenge,
                'expires_in': 300,
                'retry_after': 60,
              });
            }
            expect(body, {
              'challenge_id': challenge,
              'code': '123456',
              'new_password': 'password8',
            });
            return auth.response({'user_ids': [], 'message': '변경 완료'});
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final result = await repo.request(
        RecoveryPurpose.resetPassword,
        ' test@example.com ',
        ' tester ',
      );
      expect(result.id, challenge);
      expect(
        (await repo.complete(challenge, '123456', 'password8')).message,
        '변경 완료',
      );
    },
  );
  test(
    'vm rejects invalid input and duplicate send without requests',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final repo = RecoveryRepository(
        AuthApiService(
          MockClient((r) async {
            calls++;
            await gate.future;
            return auth.response({
              'challenge_id': challenge,
              'expires_in': 300,
              'retry_after': 60,
            });
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = ProviderContainer(
        overrides: [recoveryRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final provider = recoveryVmProvider(RecoveryPurpose.resetPassword);
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final vm = c.read(provider.notifier);
      await vm.request('bad', 'tester');
      expect(calls, 0);
      await vm.request('test@example.com', '');
      expect(calls, 0);
      final first = vm.request('test@example.com', 'tester');
      await Future<void>.delayed(Duration.zero);
      await vm.request('test@example.com', 'tester');
      expect(calls, 1);
      gate.complete();
      await first;
      await vm.request('test@example.com', 'tester');
      expect(calls, 1);
      await vm.complete('123456', 'short', 'short');
      expect(c.read(provider).error, contains('8~128'));
      await vm.complete('123456', 'password8', 'different');
      expect(c.read(provider).error, contains('일치하지'));
      expect(calls, 1);
    },
  );
  testWidgets('email proof displays IDs then returns to login', (tester) async {
    final repo = RecoveryRepository(
      AuthApiService(
        MockClient(
          (r) async => auth.response(
            r.url.path.endsWith('/request')
                ? {
                    'challenge_id': challenge,
                    'expires_in': 300,
                    'retry_after': 60,
                  }
                : {
                    'user_ids': ['tester'],
                    'message': '가입한 아이디를 확인해주세요.',
                  },
          ),
        ),
        baseUrl: 'http://test.local',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recoveryRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RecoveryView()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('tester'), findsNothing);
    expect(find.text('다시 보내기 (60초)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.ensureVisible(find.text('아이디 확인'));
    await tester.tap(find.text('아이디 확인'));
    await tester.pumpAndSettle();
    expect(find.text('tester'), findsOneWidget);
    expect(find.text('로그인으로 돌아가기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('malformed response never creates proof state', () async {
    final repo = RecoveryRepository(
      AuthApiService(
        MockClient((_) async => auth.response({'challenge_id': 'bad'})),
        baseUrl: 'http://test.local',
      ),
    );
    await expectLater(
      repo.request(RecoveryPurpose.findId, 'test@example.com', ''),
      throwsA(isA<AuthException>()),
    );
  });
}
