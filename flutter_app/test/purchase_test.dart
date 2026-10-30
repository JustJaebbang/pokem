import 'package:flutter/material.dart';
import 'package:pokem_app/view/purchase/checkout_view.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/repository/purchase/purchase_repository.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/checkout_vm.dart';

import 'auth_test.dart' as auth;

const product = Product(
  code: 'P-1',
  serialCode: 'card',
  title: '피카츄',
  image: '',
  description: '',
  price: 10000,
  grade: 'Unrank',
  status: '판매중',
);
const purchase = Purchase(code: 'PI-1', productCode: 'P-1', status: '거래중');

class FakePurchaseRepository implements PurchaseRepository {
  @override
  Future<Purchase> getPurchase(String code, String token) async =>
      purchases.firstWhere((p) => p.code == code);
  @override
  Future<PurchaseConfirmReceipt> confirm(String code, String token) async =>
      throw UnimplementedError();
  int balance = 20000;
  int calls = 0;
  Object? error;
  Completer<Purchase>? pending;
  List<Purchase> purchases = [];
  @override
  Future<CheckoutData> checkout(String code, String id, String token) async =>
      CheckoutData(product, BuyerProfile(address: '서울', balance: balance));
  @override
  Future<Purchase> buy(String code, int price, String token) async {
    calls++;
    expect(price, 10000);
    if (error != null) throw error!;
    return pending == null ? purchase : pending!.future;
  }

  @override
  Future<List<Purchase>> history(String token) async => purchases;
}

void main() {
  Future<ProviderContainer> start(FakePurchaseRepository repo) async {
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
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    final sub = c.listen(checkoutVmProvider('P-1'), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  testWidgets('small screen checkout shows confirmed payment success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakePurchaseRepository();
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: CheckoutView(code: 'P-1')),
      ),
    );
    await tester.pumpAndSettle();
    final agreement = find.byType(CheckboxListTile);
    await tester.ensureVisible(agreement);
    await tester.tap(agreement);
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, '10,000원 결제하기');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('결제가 완료되었습니다.'), findsOneWidget);
    expect(repo.calls, 1);
    expect(tester.takeException(), isNull);
  });
  test('requires sufficient funds and agreement', () async {
    final repo = FakePurchaseRepository()..balance = 5000;
    final c = await start(repo);
    final vm = c.read(checkoutVmProvider('P-1').notifier);
    await vm.pay();
    vm.agree(true);
    await vm.pay();
    expect(repo.calls, 0);
  });
  test('duplicate taps and post-success taps never submit twice', () async {
    final repo = FakePurchaseRepository()..pending = Completer<Purchase>();
    final c = await start(repo);
    final vm = c.read(checkoutVmProvider('P-1').notifier);
    vm.agree(true);
    final first = vm.pay();
    await vm.pay();
    expect(repo.calls, 1);
    expect(c.read(checkoutVmProvider('P-1')).paying, isTrue);
    repo.pending!.complete(purchase);
    await first;
    await vm.pay();
    expect(repo.calls, 1);
    expect(c.read(checkoutVmProvider('P-1')).purchase?.code, 'PI-1');
  });
  test('ambiguous result blocks retries and recovers from history', () async {
    final repo = FakePurchaseRepository()
      ..error = const PurchaseException('timeout', uncertain: true);
    final c = await start(repo);
    final vm = c.read(checkoutVmProvider('P-1').notifier);
    vm.agree(true);
    await vm.pay();
    await vm.load();
    vm.agree(true);
    await vm.pay();
    await vm.checkResult();
    expect(repo.calls, 1);
    expect(c.read(checkoutVmProvider('P-1')).uncertain, isTrue);
    repo.purchases = [purchase];
    await vm.checkResult();
    expect(c.read(checkoutVmProvider('P-1')).purchase?.code, 'PI-1');
    expect(repo.calls, 1);
  });
  test('price conflict requires refresh and renewed agreement', () async {
    final repo = FakePurchaseRepository()
      ..error = const PurchaseException('가격 변경', status: 409);
    final c = await start(repo);
    final vm = c.read(checkoutVmProvider('P-1').notifier);
    vm.agree(true);
    await vm.pay();
    expect(c.read(checkoutVmProvider('P-1')).data, isNull);
    await vm.load();
    expect(c.read(checkoutVmProvider('P-1')).agreed, isFalse);
  });
  test('401 clears login session', () async {
    final repo = FakePurchaseRepository()
      ..error = const PurchaseException('expired', status: 401);
    final c = await start(repo);
    final vm = c.read(checkoutVmProvider('P-1').notifier);
    vm.agree(true);
    await vm.pay();
    expect(c.read(loginVmProvider).session, isNull);
  });
  test('API sends product and agreed price using bearer token', () async {
    final api = PurchaseApiService(
      MockClient((r) async {
        expect(r.method, 'POST');
        expect(r.url.path, '/purchase_item');
        expect(r.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(r.body), {
          'sell_product_sell_product_code': 'P-1',
          'expected_price': 10000,
        });
        return auth.response({
          'purchase_item_code': 'PI-1',
          'sell_product_sell_product_code': 'P-1',
          'purchase_item_status': '거래중',
        }, 201);
      }),
      baseUrl: 'http://test.local',
    );
    expect((await api.buy('P-1', 10000, 'token')).code, 'PI-1');
  });
  test('unreadable success and server errors require reconciliation', () async {
    for (final status in [201, 500, 409]) {
      final api = PurchaseApiService(
        MockClient((r) async => http.Response('broken', status)),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        api.buy('P-1', 10000, 'token'),
        throwsA(
          isA<PurchaseException>().having(
            (e) => e.uncertain,
            'uncertain',
            status != 409,
          ),
        ),
      );
    }
  });
}
