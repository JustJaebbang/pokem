import 'dart:convert';

import 'package:pokem_app/model/inspection/inspection_fee.dart';
import 'package:pokem_app/vm/inspection/inspection_fee_payment_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/repository/inspection/inspection_fee_repository.dart';
import 'package:pokem_app/service/inspection/inspection_fee_api_service.dart';
import 'package:pokem_app/view/inspection/inspection_fee_view.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

import 'auth_test.dart' as auth;

Map<String, Object?> fee({int? price = 15000}) => {
  'pay_no': 'PAY1',
  'pay_status': '결제대기',
  'pay_price': price,
  'pay_date': '2026-10-30 12:00:00',
  'inspection_request_inspection_request_no': '20261030000001',
};
void main() {
  test(
    'fee lookup filters by request and preserves zero and absent prices',
    () async {
      for (final price in [15000, 0, null]) {
        final api = InspectionFeeApiService(
          MockClient((r) async {
            expect(r.url.path, '/pay');
            expect(r.url.queryParameters, {
              'request_no': '20261030000001',
              'limit': '2',
            });
            expect(r.headers['Authorization'], 'Bearer token');
            return auth.response([fee(price: price)]);
          }),
          baseUrl: 'http://test.local',
        );
        expect((await api.getFee('20261030000001', 'token'))?.price, price);
      }
    },
  );
  test('empty fee differs from duplicate or mismatched data', () async {
    final empty = InspectionFeeApiService(
      MockClient((_) async => auth.response([])),
      baseUrl: 'http://test.local',
    );
    expect(await empty.getFee('20261030000001', 'token'), isNull);
    for (final rows in [
      [fee(), fee()],
      [
        {...fee(), 'inspection_request_inspection_request_no': 'wrong'},
      ],
    ]) {
      final api = InspectionFeeApiService(
        MockClient((_) async => auth.response(rows)),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        api.getFee('20261030000001', 'token'),
        throwsA(isA<InspectionException>()),
      );
    }
  });
  test(
    'ambiguous completion blocks repeat POST and reconciles from query',
    () async {
      var posts = 0;
      var paid = false;
      final session = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      final repo = InspectionFeeRepository(
        InspectionFeeApiService(
          MockClient((r) async {
            if (r.method == 'POST') {
              posts++;
              return auth.response({}, 500);
            }
            return auth.response([
              {...fee(), if (paid) 'pay_status': '결제완료'},
            ]);
          }),
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
      final provider = inspectionFeePaymentVmProvider('20261030000001');
      final vm = c.read(provider.notifier);
      final current = InspectionFee.fromJson(fee());
      await vm.complete(current);
      await vm.complete(current);
      expect(posts, 1);
      expect(c.read(provider).uncertain, isTrue);
      paid = true;
      await vm.checkResult();
      expect(c.read(provider).completed, isTrue);
      expect(posts, 1);
    },
  );
  testWidgets('fee button records completion and hides itself', (tester) async {
    var paid = false;
    final c = (await tester.runAsync(() async {
      final session = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      final repo = InspectionFeeRepository(
        InspectionFeeApiService(
          MockClient((r) async {
            if (r.method == 'POST') {
              expect(r.url.path, '/pay/PAY1/complete');
              expect(jsonDecode(r.body), {'expected_price': 15000});
              paid = true;
              return auth.response({...fee(), 'pay_status': '결제완료'});
            }
            return auth.response([
              {...fee(), if (paid) 'pay_status': '결제완료'},
            ]);
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(session),
          inspectionFeeRepositoryProvider.overrideWithValue(repo),
        ],
      );
      c.read(loginVmProvider);
      await Future<void>.delayed(Duration.zero);
      await c
          .read(loginVmProvider.notifier)
          .login('tester', 'pw', remember: false);
      return c;
    }))!;
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: InspectionFeeView(number: '20261030000001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('15,000원'), findsOneWidget);
    expect(find.text('결제대기'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '15,000원 결제하기'));
    await tester.pumpAndSettle();
    expect(paid, isTrue);
    expect(find.text('결제완료'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
