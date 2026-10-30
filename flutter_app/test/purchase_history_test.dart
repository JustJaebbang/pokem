import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/purchase/purchase_history_view.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

import 'auth_test.dart' as auth;
import 'purchase_test.dart' as purchase;

void main() {
  test(
    'history parses product details and original paid amount in one request',
    () async {
      final api = PurchaseApiService(
        MockClient((request) async {
          expect(request.url.path, '/purchase_item');
          expect(request.headers['Authorization'], 'Bearer token');
          return auth.response([
            {
              'purchase_item_code': 'PI1',
              'sell_product_sell_product_code': 'P1',
              'purchase_item_status': '거래중',
              'purchase_item_date': '2026-10-30T12:34:00+09:00',
              'sell_product_title': '피카츄',
              'sell_product_image': '/media/products/card.jpg',
              'cybermoney_pay_price': 10000,
            },
          ]);
        }),
        baseUrl: 'http://test.local',
      );
      final row = (await api.history('token')).single;
      expect(row.title, '피카츄');
      expect(row.image, '/media/products/card.jpg');
      expect(row.paidPrice, 10000);
      expect(row.date, '2026-10-30T12:34:00+09:00');
    },
  );
  test('legacy responses keep missing price unknown', () {
    final row = Purchase.fromJson({
      'purchase_item_code': 'PI1',
      'sell_product_sell_product_code': 'P1',
    });
    expect(row.paidPrice, isNull);
    expect(row.title, isNull);
  });
  test('purchase time formats minutes and handles missing dates', () {
    expect(formatPurchaseTime('2026-10-30T12:34:00'), '2026.10.30 12:34');
    expect(formatPurchaseTime(null), '구매 시간 확인 불가');
    expect(formatPurchaseTime('bad'), '구매 시간 확인 불가');
  });
  testWidgets(
    'small screen history shows thumbnail title amount and purchase time',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = purchase.FakePurchaseRepository()
        ..purchases = [
          const Purchase(
            code: 'PI1',
            productCode: 'P1',
            status: '거래중',
            title: '피카츄',
            image: '',
            paidPrice: 10000,
            date: '2026-10-30T12:34:00',
          ),
          const Purchase(code: 'PI2', productCode: 'P2', status: '거래취소'),
        ];
      final c = (await tester.runAsync(() async {
        final session = auth.repository(
          auth.MemoryStorage(),
          (_) => auth.response(auth.loginResponse()),
        );
        final c = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(session),
            purchaseRepositoryProvider.overrideWithValue(repo),
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
          child: const MaterialApp(home: PurchaseHistoryView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('피카츄'), findsOneWidget);
      expect(find.text('10,000원'), findsOneWidget);
      expect(find.text('2026.10.30 12:34'), findsOneWidget);
      expect(find.byType(ProductImage), findsNWidgets(2));
      expect(find.text('상품 정보 없음'), findsOneWidget);
      expect(find.text('금액 확인 불가'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
