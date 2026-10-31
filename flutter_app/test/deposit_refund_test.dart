import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/repository/inspection/inspection_fee_repository.dart';
import 'package:pokem_app/service/inspection/inspection_fee_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/deposit_refund_vm.dart';
import 'package:pokem_app/view/inspection/deposit_refund_view.dart';

import 'auth_test.dart' as auth;

Map<String, Object?> record(int id) => {
  'deposit_refund_no': 'REF$id',
  'pay_pay_no': 'PAY1',
  'deposit_refund_price': 5000,
  'deposit_refund_date': '2026-10-31 12:34:00',
};
void main() {
  Future<ProviderContainer> start(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final repo = InspectionFeeRepository(
      InspectionFeeApiService(
        MockClient(handler),
        baseUrl: 'http://test.local',
      ),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        inspectionFeeRepositoryProvider.overrideWithValue(repo),
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

  test('refund API filters payment with authenticated paging and rejects mismatches', () async {
    final api = InspectionFeeApiService(
      MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/deposit_refund');
        expect(r.headers['Authorization'], 'Bearer token');
        expect(r.url.queryParameters, {
          'pay_no': 'PAY1',
          'limit': '20',
          'offset': '20',
        });
        return auth.response([record(1)]);
      }),
      baseUrl: 'http://test.local',
    );
    final rows = await api.refunds('PAY1', 'token', offset: 20);
    expect(rows.single.price, 5000);
    expect(rows.single.zonedDate, '2026-10-31T12:34:00+09:00');
    final bad = InspectionFeeApiService(
      MockClient(
        (_) async => auth.response([
          {...record(1), 'pay_pay_no': 'OTHER'},
        ]),
      ),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      bad.refunds('PAY1', 'token'),
      throwsA(isA<InspectionException>()),
    );
  });
  test(
    'pagination preserves previous records on failure and retries same offset',
    () async {
      var fail = true;
      final offsets = <String>[];
      final c = await start((r) async {
        final offset = r.url.queryParameters['offset']!;
        offsets.add(offset);
        if (offset == '0') {
          return auth.response(List.generate(20, (i) => record(i)));
        }
        if (fail) return auth.response({}, 500);
        return auth.response([record(20)]);
      });
      final provider = depositRefundVmProvider('PAY1');
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      expect((await c.read(provider.future)).items.length, 20);
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).asData!.value.items.length, 20);
      expect(c.read(provider).asData!.value.error, isNotNull);
      fail = false;
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).asData!.value.items.length, 21);
      expect(c.read(provider).asData!.value.hasMore, isFalse);
      expect(offsets, ['0', '20', '20']);
    },
  );
  test('401 clears current session', () async {
    final c = await start((_) async => auth.response({}, 401));
    final provider = depositRefundVmProvider('PAY1');
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'refund view shows recorded amount and time without claiming transfer completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = (await tester.runAsync(
        () => start((_) async => auth.response([record(1)])),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: DepositRefundView(payNumber: 'PAY1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('5,000원'), findsOneWidget);
      expect(find.text('환급번호 REF1'), findsOneWidget);
      expect(find.textContaining('실제 입금 여부는 별도로 확인'), findsOneWidget);
      expect(find.text('송금완료'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty refund history is distinct from error', (tester) async {
    final c = (await tester.runAsync(
      () => start((_) async => auth.response([])),
    ))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: DepositRefundView(payNumber: 'PAY1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('등록된 환급내역이 없습니다.'), findsOneWidget);
  });
}
