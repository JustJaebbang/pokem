import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/product_payment.dart';
import 'package:pokem_app/service/wallet/payment_api_service.dart';
import 'package:pokem_app/repository/wallet/payment_repository.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wallet/payment_vm.dart';
import 'package:pokem_app/view/wallet/payment_history_view.dart';

import 'auth_test.dart' as auth;

Map<String, dynamic> row({String owner = 'tester', String code = 'PAY1'}) => {
  'cybermoney_pay_code': code,
  'cybermoney_pay_status': '결제취소',
  'cybermoney_pay_date': '2026-10-31T12:00:00+09:00',
  'cybermoney_pay_price': 9000,
  'purchase_item_purchase_item_code': 'BUY1',
  'user_user_id': owner,
  'sell_product_sell_product_code': 'P1',
  'sell_product_title': '피카츄',
  'sell_product_image': '',
};
void main() {
  test(
    'list and detail use authenticated GET without a user override',
    () async {
      final paths = <String>[];
      final repo = PaymentRepository(
        PaymentApiService(
          MockClient((r) async {
            expect(r.method, 'GET');
            expect(r.headers['Authorization'], 'Bearer token');
            expect(r.url.queryParameters, isEmpty);
            paths.add(r.url.path);
            return auth.response(
              r.url.path == '/cybermoney_pay' ? [row()] : row(),
            );
          }),
          baseUrl: 'http://test.local',
        ),
      );
      expect((await repo.history('tester', 'token')).single.amount, 9000);
      expect((await repo.detail('PAY1', 'tester', 'token')).status, '결제취소');
      expect(paths, ['/cybermoney_pay', '/cybermoney_pay/PAY1']);
    },
  );
  test('other owner and mismatched detail identity are rejected', () async {
    final repo = PaymentRepository(
      PaymentApiService(
        MockClient(
          (r) async => auth.response(
            r.url.path == '/cybermoney_pay'
                ? [row(owner: 'other')]
                : row(code: 'OTHER'),
          ),
        ),
        baseUrl: 'http://test.local',
      ),
    );
    await expectLater(
      repo.history('tester', 'token'),
      throwsA(isA<PaymentException>()),
    );
    await expectLater(
      repo.detail('PAY1', 'tester', 'token'),
      throwsA(isA<PaymentException>()),
    );
  });
  test('old response without product metadata keeps payment amount', () {
    final data = row()
      ..remove('sell_product_title')
      ..remove('sell_product_image')
      ..remove('sell_product_sell_product_code');
    final record = ProductPayment.fromJson(data);
    expect(record.amount, 9000);
    expect(record.displayTitle, '상품 정보 없음');
  });
  Future<ProviderContainer> start(PaymentRepository repo) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        paymentRepositoryProvider.overrideWithValue(repo),
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

  test('401 expires current session', () async {
    final c = await start(
      PaymentRepository(
        PaymentApiService(
          MockClient((_) async => auth.response({}, 401)),
          baseUrl: 'http://test.local',
        ),
      ),
    );
    final sub = c.listen(paymentHistoryVmProvider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(paymentHistoryVmProvider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'canceled payment keeps original amount and navigates to detail',
    (tester) async {
      final paths = <String>[];
      final repo = PaymentRepository(
        PaymentApiService(
          MockClient((r) async {
            paths.add(r.url.path);
            return auth.response(
              r.url.path == '/cybermoney_pay' ? [row()] : row(),
            );
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: PaymentHistoryView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('피카츄'), findsOneWidget);
      expect(find.text('9,000원'), findsOneWidget);
      expect(find.textContaining('결제취소 ·'), findsOneWidget);
      await tester.tap(find.text('피카츄'));
      await tester.pumpAndSettle();
      expect(find.text('결제 상세'), findsOneWidget);
      expect(find.text('원 결제금액 9,000원'), findsOneWidget);
      expect(find.text('결제번호 PAY1'), findsOneWidget);
      expect(find.text('구매번호 BUY1'), findsOneWidget);
      expect(paths, ['/cybermoney_pay', '/cybermoney_pay/PAY1']);
    },
  );
  testWidgets(
    'read failure is shown as error and retry can show empty history',
    (tester) async {
      var calls = 0;
      final repo = PaymentRepository(
        PaymentApiService(
          MockClient((_) async {
            calls++;
            return calls == 1 ? auth.response({}, 503) : auth.response([]);
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: PaymentHistoryView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('상품 결제내역이 없습니다.'), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('상품 결제내역이 없습니다.'), findsOneWidget);
      expect(calls, 2);
    },
  );
}
