import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/repository/purchase/seller_cancel_repository.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/seller_cancel_decision_vm.dart';
import 'package:pokem_app/view/purchase/seller_cancel_view.dart';

import 'auth_test.dart' as auth;

PurchaseCancellation item({String status = '요청중', String seller = 'tester'}) =>
    PurchaseCancellation(
      code: 'CAN1',
      purchaseCode: 'PI1',
      buyerId: 'buyer',
      sellerId: seller,
      status: status,
      reason: '구매 의사 변경',
    );
Map<String, dynamic> jsonItem({
  String status = '요청중',
  String seller = 'tester',
}) => {
  'purchase_cancel_code': 'CAN1',
  'purchase_item_purchase_item_code': 'PI1',
  'user_user_id': 'buyer',
  'seller_user_id': seller,
  'purchase_cancel_status': status,
  'purchase_cancel_reason': '구매 의사 변경',
};

class FakeSellerCancelRepository implements SellerCancelRepository {
  PurchaseCancellation current = item();
  int writes = 0;
  Object? error;
  Completer<PurchaseCancellation>? pending;
  @override
  Future<List<PurchaseCancellation>> requests(
    String seller,
    String token,
  ) async => [current];
  @override
  Future<PurchaseCancellation> get(String code, String token) async => current;
  @override
  Future<PurchaseCancellation> decide(
    PurchaseCancellation current,
    CancelDecision decision,
    String reason,
    String token,
  ) async {
    writes++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return this.current = item(status: decision.label);
  }
}

void main() {
  Future<ProviderContainer> start(FakeSellerCancelRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        sellerCancelRepositoryProvider.overrideWithValue(repo),
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

  test('seller list excludes requests where user is only buyer', () async {
    final api = PurchaseApiService(
      MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer token');
        return auth.response([
          jsonItem(),
          {...jsonItem(seller: 'other'), 'user_user_id': 'tester'},
          jsonItem(seller: 'other'),
        ]);
      }),
      baseUrl: 'http://test.local',
    );
    expect(
      (await SellerCancelRepository(api).requests('tester', 'token')).length,
      1,
    );
  });
  test(
    'approval and rejection send only optional reason with authentication',
    () async {
      for (final decision in CancelDecision.values) {
        final api = PurchaseApiService(
          MockClient((r) async {
            expect(r.method, 'POST');
            expect(r.url.path, '/purchase_cancel/CAN1/${decision.path}');
            expect(r.headers['Authorization'], 'Bearer token');
            expect(jsonDecode(r.body), {'response_reason': '확인 완료'});
            return auth.response(jsonItem(status: decision.label));
          }),
          baseUrl: 'http://test.local',
        );
        expect(
          (await api.decideCancellation(
            item(),
            decision,
            '확인 완료',
            'token',
          )).status,
          decision.label,
        );
      }
    },
  );
  test('withdrawn requests and other sellers are never processed', () async {
    final repo = FakeSellerCancelRepository()..current = item(status: '철회');
    final c = await start(repo);
    await c
        .read(sellerCancelDecisionVmProvider('CAN1').notifier)
        .decide(CancelDecision.approve, '');
    expect(repo.writes, 0);
    final other = FakeSellerCancelRepository()..current = item(seller: 'other');
    final d = await start(other);
    await d
        .read(sellerCancelDecisionVmProvider('CAN1').notifier)
        .decide(CancelDecision.approve, '');
    expect(other.writes, 0);
    expect(d.read(sellerCancelDecisionVmProvider('CAN1')).error, isNotNull);
  });
  test('duplicate decisions and post-success reversal are blocked', () async {
    final repo = FakeSellerCancelRepository()
      ..pending = Completer<PurchaseCancellation>();
    final c = await start(repo);
    final vm = c.read(sellerCancelDecisionVmProvider('CAN1').notifier);
    final first = vm.decide(CancelDecision.approve, '');
    await Future<void>.delayed(Duration.zero);
    await vm.decide(CancelDecision.reject, '');
    expect(repo.writes, 1);
    repo.pending!.complete(item(status: '승인'));
    await first;
    await vm.decide(CancelDecision.reject, '');
    expect(repo.writes, 1);
    expect(c.read(sellerCancelDecisionVmProvider('CAN1')).result?.status, '승인');
  });
  test(
    'uncertain response blocks different decision and reconciles with GET',
    () async {
      final repo = FakeSellerCancelRepository()
        ..error = const PurchaseException('lost', uncertain: true);
      final c = await start(repo);
      final provider = sellerCancelDecisionVmProvider('CAN1');
      final vm = c.read(provider.notifier);
      await vm.decide(CancelDecision.approve, '');
      await vm.decide(CancelDecision.reject, '');
      await vm.checkResult();
      expect(repo.writes, 1);
      expect(c.read(provider).uncertain, isTrue);
      repo.current = item(status: '승인');
      await vm.checkResult();
      expect(c.read(provider).result?.status, '승인');
    },
  );
  test('conflict preserves server error and 401 logs out', () async {
    final repo = FakeSellerCancelRepository()
      ..error = const PurchaseException('이미 처리된 요청입니다.', status: 409);
    final c = await start(repo);
    final vm = c.read(sellerCancelDecisionVmProvider('CAN1').notifier);
    await vm.decide(CancelDecision.approve, '');
    expect(c.read(sellerCancelDecisionVmProvider('CAN1')).result, isNull);
    expect(
      c.read(sellerCancelDecisionVmProvider('CAN1')).error,
      contains('이미 처리'),
    );
    repo.error = const PurchaseException('expired', status: 401);
    await vm.decide(CancelDecision.approve, '');
    expect(c.read(loginVmProvider).session, isNull);
  });
  test('late decision after logout does not restore state', () async {
    final repo = FakeSellerCancelRepository()
      ..pending = Completer<PurchaseCancellation>();
    final c = await start(repo);
    final sent = c
        .read(sellerCancelDecisionVmProvider('CAN1').notifier)
        .decide(CancelDecision.approve, '');
    await Future<void>.delayed(Duration.zero);
    await c.read(loginVmProvider.notifier).logout();
    repo.pending!.complete(item(status: '승인'));
    await sent;
    expect(c.read(sellerCancelDecisionVmProvider('CAN1')).result, isNull);
  });
  for (final decision in CancelDecision.values) {
    testWidgets(
      'seller ${decision.label} dialog requires confirmation and updates status',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeSellerCancelRepository();
        final c = (await tester.runAsync(() => start(repo)))!;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: const MaterialApp(home: SellerCancelView()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('구매 의사 변경'), findsOneWidget);
        final button = find.widgetWithText(OutlinedButton, decision.label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.writes, 0);
        await tester.tap(find.widgetWithText(TextButton, '돌아가기'));
        await tester.pumpAndSettle();
        expect(repo.writes, 0);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '확인 완료');
        await tester.tap(find.widgetWithText(FilledButton, decision.label));
        await tester.pumpAndSettle();
        expect(repo.writes, 1);
        expect(find.text('취소 상태 · ${decision.label}'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, '승인'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
