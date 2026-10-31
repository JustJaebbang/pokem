import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/repository/purchase/purchase_cancel_repository.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/purchase_cancel_vm.dart';
import 'package:pokem_app/view/purchase/purchase_cancel_view.dart';

import 'auth_test.dart' as auth;

const product = Purchase(
  code: 'PI1',
  productCode: 'P1',
  status: '거래중',
  title: '피카츄',
);
PurchaseCancellation cancellation({String status = '요청중'}) =>
    PurchaseCancellation(
      code: 'CAN1',
      purchaseCode: 'PI1',
      buyerId: 'tester',
      status: status,
      reason: '구매 의사 변경',
    );
Map<String, dynamic> jsonCancel({String status = '요청중'}) => {
  'purchase_cancel_code': 'CAN1',
  'purchase_item_purchase_item_code': 'PI1',
  'user_user_id': 'tester',
  'purchase_cancel_status': status,
  'purchase_cancel_reason': '구매 의사 변경',
};

class FakeCancelRepository implements PurchaseCancelRepository {
  PurchaseCancellation? current;
  int writes = 0, withdrawals = 0;
  Object? error;
  Completer<PurchaseCancellation>? pending;
  @override
  Future<PurchaseCancelSnapshot> snapshot(String code, String token) async =>
      PurchaseCancelSnapshot(product, current);
  @override
  Future<PurchaseCancellation> request(
    String code,
    String reason,
    String token,
  ) async {
    writes++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return current = cancellation();
  }

  @override
  Future<PurchaseCancellation> withdraw(
    PurchaseCancellation item,
    String token,
  ) async {
    withdrawals++;
    return current = cancellation(status: '철회');
  }
}

void main() {
  Future<ProviderContainer> start(FakeCancelRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        purchaseCancelRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    c.read(purchaseCancelVmProvider('PI1'));
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test(
    'cancellation and withdrawal use authenticated server contracts',
    () async {
      final api = PurchaseApiService(
        MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer token');
          if (r.method == 'GET') {
            expect(r.url.queryParameters, {'purchase_code': 'PI1'});
            return auth.response([jsonCancel()]);
          }
          if (r.url.path == '/purchase_cancel') {
            expect(jsonDecode(r.body), {
              'purchase_item_purchase_item_code': 'PI1',
              'purchase_cancel_reason': '구매 의사 변경',
            });
            return auth.response(jsonCancel(), 201);
          }
          expect(r.url.path, '/purchase_cancel/CAN1/withdraw');
          expect(jsonDecode(r.body), {});
          return auth.response(jsonCancel(status: '철회'));
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.cancellation('PI1', 'token'))?.code, 'CAN1');
      final item = await api.requestCancellation('PI1', '구매 의사 변경', 'token');
      expect((await api.withdrawCancellation(item, 'token')).status, '철회');
    },
  );
  test('reason validation and pending request block duplicate POST', () async {
    final repo = FakeCancelRepository()
      ..pending = Completer<PurchaseCancellation>();
    final c = await start(repo);
    final vm = c.read(purchaseCancelVmProvider('PI1').notifier);
    await vm.request(' ');
    expect(repo.writes, 0);
    final first = vm.request('구매 의사 변경');
    await vm.request('다른 이유');
    expect(repo.writes, 1);
    repo.pending!.complete(cancellation());
    await first;
    await vm.request('다른 이유');
    expect(repo.writes, 1);
  });
  test('withdrawal is allowed once and prevents a new request', () async {
    final repo = FakeCancelRepository()..current = cancellation();
    final c = await start(repo);
    final vm = c.read(purchaseCancelVmProvider('PI1').notifier);
    await vm.withdraw();
    await vm.withdraw();
    await vm.request('재신청');
    expect(repo.withdrawals, 1);
    expect(repo.writes, 0);
    expect(
      c.read(purchaseCancelVmProvider('PI1')).snapshot?.cancellation?.status,
      '철회',
    );
  });
  test('uncertain request stays blocked until GET finds its result', () async {
    final repo = FakeCancelRepository()
      ..error = const PurchaseException('lost', uncertain: true);
    final c = await start(repo);
    final provider = purchaseCancelVmProvider('PI1');
    final vm = c.read(provider.notifier);
    await vm.request('구매 의사 변경');
    await vm.request('다른 이유');
    await vm.load();
    expect(repo.writes, 1);
    expect(c.read(provider).pending, isNotNull);
    repo.current = cancellation();
    await vm.load();
    expect(c.read(provider).pending, isNull);
    expect(c.read(provider).snapshot?.cancellation?.status, '요청중');
  });
  test('late response after logout is ignored', () async {
    final repo = FakeCancelRepository()
      ..pending = Completer<PurchaseCancellation>();
    final c = await start(repo);
    final sent = c
        .read(purchaseCancelVmProvider('PI1').notifier)
        .request('구매 의사 변경');
    await c.read(loginVmProvider.notifier).logout();
    repo.pending!.complete(cancellation());
    await sent;
    expect(c.read(purchaseCancelVmProvider('PI1')).snapshot, isNull);
  });
  testWidgets(
    'buyer requests cancellation then withdraws through confirmation dialogs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeCancelRepository();
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: PurchaseCancelView(code: 'PI1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '구매 의사 변경');
      final submit = find.widgetWithText(FilledButton, '취소 신청하기');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(find.widgetWithText(FilledButton, '확인'));
      await tester.pumpAndSettle();
      expect(find.text('취소 상태 · 요청중'), findsOneWidget);
      expect(repo.writes, 1);
      final withdraw = find.widgetWithText(OutlinedButton, '취소 신청 철회');
      await tester.ensureVisible(withdraw);
      await tester.tap(withdraw);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '확인'));
      await tester.pumpAndSettle();
      expect(find.text('취소 상태 · 철회'), findsOneWidget);
      expect(repo.withdrawals, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
