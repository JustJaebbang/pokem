import 'package:pokem_app/view/wallet/wallet_view.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/wallet_ledger.dart';
import 'package:pokem_app/service/wallet/wallet_ledger_api_service.dart';
import 'package:pokem_app/repository/wallet/wallet_ledger_repository.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_ledger_vm.dart';
import 'package:pokem_app/view/wallet/wallet_ledger_view.dart';

import 'auth_test.dart' as auth;

Map<String, dynamic> record(
  int index, {
  String kind = 'recharge',
  int amount = 1000,
  String owner = 'tester',
}) => {
  'event_id': '$kind:$index',
  'kind': kind,
  'amount': amount,
  'occurred_at': '2026-10-31T12:00:00+09:00',
  'user_user_id': owner,
  'source_code': '$index',
};

class InlineWalletVm extends WalletVm {
  @override
  Future<WalletSnapshot> build() async => const WalletSnapshot(12000, []);
}

void main() {
  Future<ProviderContainer> start(
    WalletLedgerRepository repo, {
    bool inline = false,
  }) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        walletLedgerRepositoryProvider.overrideWithValue(repo),
        if (inline) walletVmProvider.overrideWith(InlineWalletVm.new),
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

  test('direction and offset are passed to authenticated read API', () async {
    final api = WalletLedgerApiService(
      MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/wallet/transactions');
        expect(r.url.queryParameters, {
          'limit': '30',
          'offset': '30',
          'direction': 'out',
        });
        expect(r.headers['Authorization'], 'Bearer token');
        return auth.response([record(1, kind: 'payment', amount: -9000)]);
      }),
      baseUrl: 'http://test.local',
    );
    expect(
      (await api.page('token', LedgerDirection.outgoing, 30)).single.amount,
      -9000,
    );
  });
  test(
    'wrong owner and wrong direction never appear as valid history',
    () async {
      for (final data in [record(1, owner: 'other'), record(1, amount: -100)]) {
        final repo = WalletLedgerRepository(
          WalletLedgerApiService(
            MockClient((_) async => auth.response([data])),
            baseUrl: 'http://test.local',
          ),
        );
        await expectLater(
          repo.page('tester', 'token', LedgerDirection.incoming, 0),
          throwsA(isA<LedgerException>()),
        );
      }
    },
  );
  test('load more failure preserves rows and retries same offset', () async {
    var fail = true;
    final offsets = <String>[];
    final repo = WalletLedgerRepository(
      WalletLedgerApiService(
        MockClient((r) async {
          final offset = r.url.queryParameters['offset']!;
          offsets.add(offset);
          if (offset == '0') {
            return auth.response(List.generate(30, (i) => record(i)));
          }
          return fail ? auth.response({}, 503) : auth.response([record(30)]);
        }),
        baseUrl: 'http://test.local',
      ),
    );
    final c = await start(repo);
    final provider = walletLedgerVmProvider(LedgerDirection.all);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await c.read(provider.future);
    await c.read(provider.notifier).loadMore();
    expect(c.read(provider).asData!.value.items.length, 30);
    expect(c.read(provider).asData!.value.error, isNotNull);
    fail = false;
    await c.read(provider.notifier).loadMore();
    expect(c.read(provider).asData!.value.items.length, 31);
    expect(c.read(provider).asData!.value.hasMore, isFalse);
    expect(offsets, ['0', '30', '30']);
  });
  test('401 logs out current account', () async {
    final repo = WalletLedgerRepository(
      WalletLedgerApiService(
        MockClient((_) async => auth.response({}, 401)),
        baseUrl: 'http://test.local',
      ),
    );
    final c = await start(repo);
    final provider = walletLedgerVmProvider(LedgerDirection.all);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'signed payment and refund stay separate and direction filter reloads',
    (tester) async {
      final directions = <String?>[];
      final repo = WalletLedgerRepository(
        WalletLedgerApiService(
          MockClient((r) async {
            final direction = r.url.queryParameters['direction'];
            directions.add(direction);
            final credit = record(1, kind: 'refund', amount: 9000);
            final debit = record(2, kind: 'payment', amount: -9000);
            return auth.response(
              direction == 'in' ? [credit] : [credit, debit],
            );
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: WalletLedgerView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+9,000원'), findsOneWidget);
      expect(find.text('-9,000원'), findsOneWidget);
      expect(find.text('취소 환불'), findsOneWidget);
      expect(find.text('상품 결제'), findsOneWidget);
      await tester.tap(find.text('입금'));
      await tester.pumpAndSettle();
      expect(find.text('상품 결제'), findsNothing);
      expect(directions, [null, 'in']);
      await tester.tap(find.text('취소 환불'));
      await tester.pumpAndSettle();
      expect(find.text('내역번호 1'), findsOneWidget);
    },
  );
  testWidgets('seller credit has no buyer payment detail link', (tester) async {
    final data = record(1, kind: 'sale_credit', amount: 11000)
      ..['payment_code'] = 'BUYER_PAYMENT';
    final repo = WalletLedgerRepository(
      WalletLedgerApiService(
        MockClient((_) async => auth.response([data])),
        baseUrl: 'http://test.local',
      ),
    );
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: WalletLedgerView()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('판매대금 입금'));
    await tester.pumpAndSettle();
    expect(find.text('결제 상세 보기'), findsNothing);
  });
  testWidgets('wallet shows ledger inline and filters without navigating', (
    tester,
  ) async {
    final directions = <String?>[];
    final repo = WalletLedgerRepository(
      WalletLedgerApiService(
        MockClient((r) async {
          final direction = r.url.queryParameters['direction'];
          directions.add(direction);
          return auth.response([
            if (direction != 'out') record(1, kind: 'refund', amount: 9000),
            if (direction != 'in') record(2, kind: 'payment', amount: -9000),
          ]);
        }),
        baseUrl: 'http://test.local',
      ),
    );
    final c = (await tester.runAsync(() => start(repo, inline: true)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: WalletView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12,000원'), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(WalletLedgerView), findsNothing);
    await tester.scrollUntilVisible(
      find.text('입금'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('입금'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('+9,000원'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('+9,000원'), findsOneWidget);
    expect(find.text('상품 결제'), findsNothing);
    expect(directions, [null, 'in']);
    await tester.tap(find.byTooltip('새로고침'));
    await tester.pumpAndSettle();
    expect(directions.last, 'in');
    expect(directions.length, greaterThanOrEqualTo(3));
    expect(find.byType(WalletView), findsOneWidget);
  });
}
