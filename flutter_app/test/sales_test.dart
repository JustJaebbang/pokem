import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/sales/sale_record.dart';
import 'package:pokem_app/repository/sales/sales_repository.dart';
import 'package:pokem_app/service/sales/sales_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/sales/sales_vm.dart';
import 'package:pokem_app/view/sales/sales_view.dart';

import 'auth_test.dart' as auth;

Map<String, Object?> record({String status = '거래완료'}) => {
  'sale_code': 'S1',
  'sale_type': 'consign',
  'product_code': 'P1',
  'title': '피카츄',
  'image': '',
  'status': status,
  'asking_price': 99000,
  'paid_price': 10000,
  'posted_at': '2026-10-30T10:00:00',
  'completed_at': status == '거래완료' ? '2026-10-30T12:34:00' : null,
};
void main() {
  Future<ProviderContainer> start(SalesRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        salesRepositoryProvider.overrideWithValue(repo),
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
    'sale history uses bearer token and does not send user override',
    () async {
      final api = SalesApiService(
        MockClient((r) async {
          expect(r.url.path, '/sale_history');
          expect(r.url.queryParameters, isEmpty);
          expect(r.headers['Authorization'], 'Bearer token');
          return auth.response([record()]);
        }),
        baseUrl: 'http://test.local',
      );
      final row = (await api.history('token')).single;
      expect(row.displayPrice, 10000);
      expect(row.typeLabel, '대리판매');
      expect(SaleRecord.fromJson(record(status: '판매중')).displayPrice, 99000);
      expect(
        SaleRecord.fromJson({...record(), 'paid_price': null}).displayPrice,
        isNull,
      );
    },
  );
  test('malformed response, server failure and offline response become useful errors', () async {
    for (final handler in <Future<http.Response> Function(http.Request)>[
      (_) async => auth.response({}),
      (_) async => auth.response({}, 500),
      (_) async => throw http.ClientException('offline'),
    ]) {
      final api = SalesApiService(
        MockClient(handler),
        baseUrl: 'http://test.local',
      );
      await expectLater(api.history('token'), throwsA(isA<SalesException>()));
    }
  });
  test('401 logs out current session', () async {
    final c = await start(
      SalesRepository(
        SalesApiService(
          MockClient((_) async => auth.response({}, 401)),
          baseUrl: 'http://test.local',
        ),
      ),
    );
    final sub = c.listen(salesVmProvider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(salesVmProvider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'sales screen shows product original price type state and time on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = SalesRepository(
        SalesApiService(
          MockClient((_) async => auth.response([record()])),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: SalesView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('피카츄'), findsOneWidget);
      expect(find.text('결제금액 10,000원'), findsOneWidget);
      expect(find.text('대리판매 · 거래완료'), findsOneWidget);
      expect(find.text('거래완료 2026.10.30 12:34'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty history is visible', (tester) async {
    final repo = SalesRepository(
      SalesApiService(
        MockClient((_) async => auth.response([])),
        baseUrl: 'http://test.local',
      ),
    );
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: SalesView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('판매내역이 없습니다.'), findsOneWidget);
  });
}
