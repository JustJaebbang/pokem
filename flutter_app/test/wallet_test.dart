import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/repository/wallet/wallet_repository.dart';
import 'package:pokem_app/service/wallet/wallet_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wallet/money_transfer_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:pokem_app/view/wallet/money_transfer_view.dart';

import 'auth_test.dart' as auth;

class FakeWalletRepository implements WalletRepository {
  int money = 50000;
  int calls = 0;
  Object? error;
  Completer<MoneyReceipt>? pending;
  @override
  Future<int> balance(String id, String token) async => money;
  @override
  Future<WalletSnapshot> snapshot(String id, String token) async =>
      WalletSnapshot(money, []);
  @override
  Future<MoneyReceipt> transfer(
    MoneyAction action,
    String account,
    int amount,
    String token,
  ) async {
    calls++;
    expect(account, '테스트은행 123456');
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    money += action == MoneyAction.recharge ? amount : -amount;
    return MoneyReceipt(
      MoneyRecord(action: action, seq: calls, amount: amount),
      money,
    );
  }
}

void main() {
  Future<ProviderContainer> start(
    FakeWalletRepository repo,
    MoneyAction action,
  ) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        walletRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    c.read(moneyTransferVmProvider(action));
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  for (final action in MoneyAction.values) {
    test(
      '${action.label} uses distinct API fields and server-selected user',
      () async {
        final api = WalletApiService(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/${action.path}');
            expect(request.headers['Authorization'], 'Bearer token');
            expect(jsonDecode(request.body), {
              '${action.path}_account': '은행 123',
              '${action.path}_price': 10000,
            });
            return auth.response({
              '${action.path}_seq': 1,
              '${action.path}_price': 10000,
              '${action.path}_date': '2026-10-30',
              '${action.path}_account': '은행 123',
              'user_money': 40000,
            }, 201);
          }),
          baseUrl: 'http://test.local',
        );
        final receipt = await api.transfer(action, '은행 123', 10000, 'token');
        expect(receipt.balance, 40000);
        expect(receipt.record.action, action);
      },
    );
    test(
      '${action.label} validates input and blocks duplicate/post-success submissions',
      () async {
        final repo = FakeWalletRepository()
          ..pending = Completer<MoneyReceipt>();
        final c = await start(repo, action);
        final vm = c.read(moneyTransferVmProvider(action).notifier);
        await vm.submit();
        expect(repo.calls, 0);
        for (final amount in ['', '0', '-1', '1.5', '2147483648']) {
          expect(vm.validateAmount(amount), isNotNull);
        }
        vm.accountChanged('  테스트은행 123456  ');
        vm.amountChanged('10000');
        final first = vm.submit();
        await vm.submit();
        expect(repo.calls, 1);
        repo.pending!.complete(
          MoneyReceipt(
            MoneyRecord(action: action, seq: 1, amount: 10000),
            40000,
          ),
        );
        await first;
        await vm.submit();
        expect(repo.calls, 1);
        expect(c.read(moneyTransferVmProvider(action)).balance, 40000);
        expect(c.read(moneyTransferVmProvider(action)).receipt, isNotNull);
      },
    );
  }
  test('insufficient funds and recharge overflow never reach API', () async {
    final repo = FakeWalletRepository()..money = 10000;
    final c = await start(repo, MoneyAction.exchange);
    final exchange = c.read(
      moneyTransferVmProvider(MoneyAction.exchange).notifier,
    );
    exchange.accountChanged('테스트은행 123456');
    exchange.amountChanged('10001');
    await exchange.submit();
    expect(repo.calls, 0);
    repo.money = 2147483640;
    final recharge = c.read(
      moneyTransferVmProvider(MoneyAction.recharge).notifier,
    );
    await Future<void>.delayed(Duration.zero);
    recharge.accountChanged('테스트은행 123456');
    recharge.amountChanged('8');
    await recharge.submit();
    expect(repo.calls, 0);
  });
  test(
    'ambiguous response remains locked after reopening and refreshing',
    () async {
      final repo = FakeWalletRepository()
        ..error = const WalletException('lost', uncertain: true);
      final c = await start(repo, MoneyAction.recharge);
      final provider = moneyTransferVmProvider(MoneyAction.recharge);
      final vm = c.read(provider.notifier);
      vm.accountChanged('테스트은행 123456');
      vm.amountChanged('10000');
      await vm.submit();
      final sub = c.listen(provider, (_, _) {});
      sub.close();
      await c.read(provider.notifier).refreshBalance();
      vm.newTransfer();
      await vm.submit();
      expect(c.read(provider).uncertain, isTrue);
      expect(repo.calls, 1);
    },
  );
  test('successful transfer invalidates wallet balance', () async {
    final repo = FakeWalletRepository();
    final c = await start(repo, MoneyAction.recharge);
    final sub = c.listen(walletVmProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(walletVmProvider.future)).balance, 50000);
    final vm = c.read(moneyTransferVmProvider(MoneyAction.recharge).notifier);
    vm.accountChanged('테스트은행 123456');
    vm.addAmount(10000);
    await vm.submit();
    expect((await c.read(walletVmProvider.future)).balance, 60000);
  });
  test('expired token clears login rather than retrying transfer', () async {
    final repo = FakeWalletRepository()
      ..error = const WalletException('expired', status: 401);
    final c = await start(repo, MoneyAction.exchange);
    final vm = c.read(moneyTransferVmProvider(MoneyAction.exchange).notifier);
    vm.accountChanged('테스트은행 123456');
    vm.amountChanged('10000');
    await vm.submit();
    expect(c.read(loginVmProvider).session, isNull);
    expect(repo.calls, 1);
  });
  test('late response after logout cannot restore wallet form', () async {
    final repo = FakeWalletRepository()..pending = Completer<MoneyReceipt>();
    final c = await start(repo, MoneyAction.exchange);
    final provider = moneyTransferVmProvider(MoneyAction.exchange);
    final vm = c.read(provider.notifier);
    vm.accountChanged('테스트은행 123456');
    vm.amountChanged('10000');
    final sent = vm.submit();
    await c.read(loginVmProvider.notifier).logout();
    repo.pending!.complete(
      const MoneyReceipt(
        MoneyRecord(action: MoneyAction.exchange, seq: 1, amount: 10000),
        40000,
      ),
    );
    await sent;
    expect(c.read(provider).receipt, isNull);
    expect(c.read(provider).account, isEmpty);
  });
  test('repository merges charge and exchange history newest first', () async {
    final api = WalletApiService(
      MockClient((request) async {
        if (request.url.path.startsWith('/user/')) {
          return auth.response({'user_money': 9000});
        }
        final action = request.url.path == '/recharge'
            ? MoneyAction.recharge
            : MoneyAction.exchange;
        return auth.response([
          {
            '${action.path}_seq': 1,
            '${action.path}_price': 1000,
            '${action.path}_date': action == MoneyAction.recharge
                ? '2026-10-29'
                : '2026-10-30',
          },
        ]);
      }),
      baseUrl: 'http://test.local',
    );
    final wallet = await WalletRepository(api).snapshot('tester', 'token');
    expect(wallet.balance, 9000);
    expect(wallet.records.map((r) => r.action), [
      MoneyAction.exchange,
      MoneyAction.recharge,
    ]);
  });
  test(
    'unreadable success, network loss, and server errors are ambiguous',
    () async {
      for (final status in [201, 500, 409]) {
        final api = WalletApiService(
          MockClient((_) async => http.Response('invalid', status)),
          baseUrl: 'http://test.local',
        );
        await expectLater(
          api.transfer(MoneyAction.exchange, '은행', 1000, 'token'),
          throwsA(
            isA<WalletException>().having(
              (e) => e.uncertain,
              'uncertain',
              status != 409,
            ),
          ),
        );
      }
      final api = WalletApiService(
        MockClient((_) async => throw http.ClientException('offline')),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        api.transfer(MoneyAction.recharge, '은행', 1000, 'token'),
        throwsA(
          isA<WalletException>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
    },
  );
  testWidgets('small screen charge confirms amount then shows server balance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeWalletRepository();
    final c = (await tester.runAsync(() => start(repo, MoneyAction.recharge)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: MoneyTransferView(action: MoneyAction.recharge),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '테스트은행 123456');
    final quick = find.text('+10,000원');
    await tester.ensureVisible(quick);
    await tester.tap(quick);
    await tester.pumpAndSettle();
    final send = find.widgetWithText(FilledButton, '충전하기');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    await tester.tap(find.widgetWithText(FilledButton, '확인'));
    await tester.pumpAndSettle();
    expect(find.text('충전이 완료되었습니다.'), findsOneWidget);
    expect(find.text('60,000원'), findsOneWidget);
    expect(repo.calls, 1);
    expect(tester.takeException(), isNull);
  });
}
