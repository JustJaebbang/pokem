import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/mypage/pending_actions.dart';
import 'package:pokem_app/repository/mypage/pending_actions_repository.dart';
import 'package:pokem_app/service/mypage/pending_actions_api_service.dart';
import 'package:pokem_app/repository/inspection/inspection_fee_repository.dart';
import 'package:pokem_app/service/inspection/inspection_fee_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/mypage/pending_actions_vm.dart';
import 'package:pokem_app/view/mypage/pending_actions_card.dart';
import 'package:pokem_app/view/inspection/inspection_fee_view.dart';

import 'auth_test.dart' as auth;

Map<String, dynamic> counts({bool empty = false}) => {
  'fee_count': empty ? 0 : 1,
  'choice_count': empty ? 0 : 2,
  'cancel_count': empty ? 0 : 3,
  'fee_request_no': empty ? null : 'R1',
  'choice_request_no': empty ? null : 'R2',
};
void main() {
  Future<ProviderContainer> start(PendingActionsRepository repo) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        pendingActionsRepositoryProvider.overrideWithValue(repo),
        inspectionFeeRepositoryProvider.overrideWithValue(
          InspectionFeeRepository(
            InspectionFeeApiService(
              MockClient((_) async => auth.response([])),
              baseUrl: 'http://test.local',
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    return c;
  }

  test(
    'counts use authenticated GET without accepting another user id',
    () async {
      final api = PendingActionsApiService(
        MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.path, '/mypage/pending-actions');
          expect(r.url.queryParameters, isEmpty);
          expect(r.headers['Authorization'], 'Bearer token');
          return auth.response(counts());
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.get('token')).choices, 2);
    },
  );
  test(
    'missing target and negative counts are errors, not empty state',
    () async {
      for (final data in [
        {...counts(), 'fee_request_no': null},
        {...counts(), 'choice_count': -1},
      ]) {
        final api = PendingActionsApiService(
          MockClient((_) async => auth.response(data)),
          baseUrl: 'http://test.local',
        );
        await expectLater(
          api.get('token'),
          throwsA(isA<PendingActionsException>()),
        );
      }
    },
  );
  test('401 logs out current session', () async {
    final c = await start(
      PendingActionsRepository(
        PendingActionsApiService(
          MockClient((_) async => auth.response({}, 401)),
          baseUrl: 'http://test.local',
        ),
      ),
    );
    final sub = c.listen(pendingActionsVmProvider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(pendingActionsVmProvider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'card shows distinct units and opens pending fee directly then refreshes',
    (tester) async {
      var calls = 0;
      final repository = PendingActionsRepository(
        PendingActionsApiService(
          MockClient((_) async {
            calls++;
            return auth.response(counts());
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repository)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: PendingActionsCard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1건 ›'), findsOneWidget);
      expect(find.text('2장 ›'), findsOneWidget);
      expect(find.text('3건 ›'), findsOneWidget);
      await tester.tap(find.text('검수비 결제 대기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<InspectionFeeView>(find.byType(InspectionFeeView)).number,
        'R1',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );
  testWidgets(
    'read failure does not pretend no pending work and retry shows real empty state',
    (tester) async {
      var calls = 0;
      final repository = PendingActionsRepository(
        PendingActionsApiService(
          MockClient((_) async {
            calls++;
            return calls == 1
                ? auth.response({}, 503)
                : auth.response(counts(empty: true));
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repository)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: PendingActionsCard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('지금 처리할 일이 없습니다.'), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('지금 처리할 일이 없습니다.'), findsOneWidget);
      expect(find.text('검수비 결제 대기'), findsNothing);
    },
  );
}
