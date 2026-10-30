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
  testWidgets(
    'fee screen shows server amount and no unsupported payment action',
    (tester) async {
      final c = (await tester.runAsync(() async {
        final session = auth.repository(
          auth.MemoryStorage(),
          (_) => auth.response(auth.loginResponse()),
        );
        final repo = InspectionFeeRepository(
          InspectionFeeApiService(
            MockClient((_) async => auth.response([fee()])),
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
      expect(find.byType(FilledButton), findsNothing);
    },
  );
}
