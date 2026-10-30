import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/purchase_confirm_vm.dart';
import 'package:pokem_app/view/purchase/purchase_history_view.dart';

import 'auth_test.dart' as auth;
import 'purchase_test.dart' as purchase;

const ready = Purchase(
  code: 'PI1',
  productCode: 'P1',
  title: '피카츄',
  paidPrice: 10000,
  status: '거래중',
);
const done = Purchase(
  code: 'PI1',
  productCode: 'P1',
  title: '피카츄',
  paidPrice: 10000,
  status: '구매확정',
  confirmedAt: '2026-10-30T12:00:00+09:00',
);
const receipt = PurchaseConfirmReceipt(
  code: 'PI1',
  productCode: 'P1',
  confirmedAt: '2026-10-30T12:00:00+09:00',
);

class ConfirmRepository extends purchase.FakePurchaseRepository {
  Purchase current = ready;
  int confirms = 0;
  int reads = 0;
  Object? readError;
  Completer<PurchaseConfirmReceipt>? confirmation;
  @override
  Future<Purchase> getPurchase(String code, String token) async {
    reads++;
    if (readError != null) throw readError!;
    return current;
  }

  @override
  Future<PurchaseConfirmReceipt> confirm(String code, String token) async {
    confirms++;
    if (error != null) throw error!;
    if (confirmation != null) return confirmation!.future;
    current = done;
    return receipt;
  }

  @override
  Future<List<Purchase>> history(String token) async => [current];
}

void main() {
  Future<ProviderContainer> start(ConfirmRepository repo) async {
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
    return c;
  }

  test(
    'confirmation uses authenticated POST with no price or seller input',
    () async {
      final api = PurchaseApiService(
        MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/purchase_item/PI1/confirm');
          expect(r.headers['Authorization'], 'Bearer token');
          expect(jsonDecode(r.body), {});
          return auth.response({
            'purchase_item_code': 'PI1',
            'sell_product_code': 'P1',
            'post_item_complete_date': receipt.confirmedAt,
            'sell_product_sell_status': '거래완료',
          });
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.confirm('PI1', 'token')).productCode, 'P1');
    },
  );
  test('unreadable confirmation success remains uncertain', () async {
    final api = PurchaseApiService(
      MockClient((_) async => auth.response({})),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      api.confirm('PI1', 'token'),
      throwsA(
        isA<PurchaseException>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
  });
  test('cancelled or already confirmed purchase never posts again', () async {
    final repo = ConfirmRepository()
      ..current = const Purchase(
        code: 'PI1',
        productCode: 'P1',
        status: '취소요청',
      );
    final c = await start(repo);
    final vm = c.read(purchaseConfirmVmProvider('PI1').notifier);
    await vm.confirm();
    expect(repo.confirms, 0);
    expect(c.read(purchaseConfirmVmProvider('PI1')).error, isNotNull);
    repo.current = done;
    await vm.confirm();
    expect(repo.confirms, 0);
    expect(c.read(purchaseConfirmVmProvider('PI1')).confirmed, isTrue);
    expect(done.statusLabel, '거래완료');
    expect(done.canConfirm, isFalse);
  });
  test('duplicate confirmation is blocked before and after response', () async {
    final repo = ConfirmRepository()
      ..confirmation = Completer<PurchaseConfirmReceipt>();
    final c = await start(repo);
    final vm = c.read(purchaseConfirmVmProvider('PI1').notifier);
    final first = vm.confirm();
    await Future<void>.delayed(Duration.zero);
    await vm.confirm();
    expect(repo.confirms, 1);
    repo.confirmation!.complete(receipt);
    await first;
    await vm.confirm();
    expect(repo.confirms, 1);
    expect(c.read(purchaseConfirmVmProvider('PI1')).confirmed, isTrue);
  });
  test(
    'uncertain response reconciles with GET and never repeats POST',
    () async {
      final repo = ConfirmRepository()
        ..error = const PurchaseException('lost', uncertain: true);
      final c = await start(repo);
      final provider = purchaseConfirmVmProvider('PI1');
      final vm = c.read(provider.notifier);
      await vm.confirm();
      final sub = c.listen(provider, (_, _) {});
      sub.close();
      await vm.confirm();
      await vm.checkResult();
      expect(repo.confirms, 1);
      expect(c.read(provider).uncertain, isTrue);
      repo.current = done;
      await vm.checkResult();
      expect(c.read(provider).confirmed, isTrue);
      expect(repo.confirms, 1);
    },
  );
  test('read failure before submitting is safe to retry', () async {
    final repo = ConfirmRepository()
      ..readError = const PurchaseException('offline');
    final c = await start(repo);
    final vm = c.read(purchaseConfirmVmProvider('PI1').notifier);
    await vm.confirm();
    expect(repo.confirms, 0);
    expect(c.read(purchaseConfirmVmProvider('PI1')).uncertain, isFalse);
    repo.readError = null;
    await vm.confirm();
    expect(repo.confirms, 1);
  });
  test('conflict preserves server error without reporting success', () async {
    final repo = ConfirmRepository()
      ..error = const PurchaseException('취소 요청 중입니다.', status: 409);
    final c = await start(repo);
    await c.read(purchaseConfirmVmProvider('PI1').notifier).confirm();
    final state = c.read(purchaseConfirmVmProvider('PI1'));
    expect(state.confirmed, isFalse);
    expect(state.uncertain, isFalse);
    expect(state.error, contains('취소'));
  });
  test(
    '401 logs out and late confirmation cannot affect a logged out session',
    () async {
      final repo = ConfirmRepository()
        ..error = const PurchaseException('expired', status: 401);
      final c = await start(repo);
      await c.read(purchaseConfirmVmProvider('PI1').notifier).confirm();
      expect(c.read(loginVmProvider).session, isNull);
      final lateRepo = ConfirmRepository()
        ..confirmation = Completer<PurchaseConfirmReceipt>();
      final late = await start(lateRepo);
      final sent = late
          .read(purchaseConfirmVmProvider('PI1').notifier)
          .confirm();
      await Future<void>.delayed(Duration.zero);
      await late.read(loginVmProvider.notifier).logout();
      lateRepo.confirmation!.complete(receipt);
      await sent;
      expect(late.read(purchaseConfirmVmProvider('PI1')).confirmed, isFalse);
    },
  );
  testWidgets(
    'dialog cancellation sends nothing and approval displays completed trade',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ConfirmRepository();
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: PurchaseHistoryView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '구매확정'));
      await tester.pumpAndSettle();
      expect(find.text('상품을 받으셨나요?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(repo.confirms, 0);
      expect(repo.reads, 0);
      await tester.tap(find.widgetWithText(OutlinedButton, '구매확정'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '구매확정'));
      await tester.pumpAndSettle();
      expect(repo.confirms, 1);
      expect(find.text('거래완료'), findsOneWidget);
      expect(find.text('구매확정 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
