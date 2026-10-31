import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/review/review_record.dart';
import 'package:pokem_app/repository/review/review_repository.dart';
import 'package:pokem_app/service/review/review_api_service.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/review/review_vm.dart';
import 'package:pokem_app/view/review/review_view.dart';

import 'auth_test.dart' as auth;

const purchase = Purchase(
  code: 'PI1',
  productCode: 'P1',
  title: '피카츄',
  status: '구매확정',
  confirmedAt: '2026-10-31T12:00:00+09:00',
);
const written = ReviewRecord(
  code: 'R1',
  purchaseCode: 'PI1',
  productCode: 'P1',
  userId: 'tester',
  rating: 4,
  contents: '좋은 거래였습니다.',
  date: '2026-10-31T12:34:00+09:00',
);
Map<String, dynamic> jsonReview({String purchaseCode = 'PI1'}) => {
  'review_code': 'R1',
  'purchase_item_purchase_item_code': purchaseCode,
  'sell_product_sell_product_code': 'P1',
  'user_user_id': 'tester',
  'review_rating': 4,
  'review_contents': '좋은 거래였습니다.',
  'review_date': written.date,
};

class FakeReviewRepository implements ReviewRepository {
  @override
  Future<List<ReviewRecord>> listForSeller(String sellerId) async =>
      review == null ? [] : [review!];
  Purchase current = purchase;
  ReviewRecord? review;
  int writes = 0;
  Object? error;
  Completer<ReviewRecord>? pending;
  @override
  Future<List<ReviewRecord>> list(String code) async =>
      review == null ? [] : [review!];
  @override
  Future<ReviewSnapshot> snapshot(String code, String token) async =>
      ReviewSnapshot(current, review);
  @override
  Future<ReviewRecord> create(
    Purchase purchase,
    int rating,
    String contents,
    String token,
  ) async {
    writes++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return review = written;
  }
}

void main() {
  Future<ProviderContainer> start(FakeReviewRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        reviewRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    c.read(reviewVmProvider('PI1'));
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test(
    'review API sends only purchase code rating contents and lists by product',
    () async {
      final api = ReviewApiService(
        MockClient((r) async {
          if (r.method == 'GET') {
            expect(r.url.queryParameters, {'sell_product_code': 'P1'});
            return auth.response([jsonReview()]);
          }
          expect(r.headers['Authorization'], 'Bearer token');
          expect(r.url.path, '/review');
          expect(jsonDecode(r.body), {
            'purchase_item_purchase_item_code': 'PI1',
            'review_rating': 4,
            'review_contents': '좋은 거래였습니다.',
          });
          return auth.response(jsonReview(), 201);
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.list('P1')).single.rating, 4);
      expect((await api.create('PI1', 4, '좋은 거래였습니다.', 'token')).code, 'R1');
    },
  );
  test('repository selects existing review of this purchase only', () async {
    final client = MockClient(
      (r) async => r.url.path.startsWith('/purchase_item')
          ? auth.response({
              'purchase_item_code': 'PI1',
              'sell_product_sell_product_code': 'P1',
              'purchase_item_status': '구매확정',
              'purchase_item_confirmed_at': '2026-10-31T12:00:00+09:00',
            })
          : auth.response([jsonReview(purchaseCode: 'OTHER'), jsonReview()]),
    );
    final repo = ReviewRepository(
      ReviewApiService(client, baseUrl: 'http://test.local'),
      PurchaseApiService(client, baseUrl: 'http://test.local'),
    );
    expect((await repo.snapshot('PI1', 'token')).review?.purchaseCode, 'PI1');
  });
  test('rating and contents are validated before submission', () async {
    final repo = FakeReviewRepository();
    final c = await start(repo);
    final vm = c.read(reviewVmProvider('PI1').notifier);
    await vm.save('좋은 거래');
    expect(repo.writes, 0);
    vm.rate(4);
    await vm.save(' ');
    expect(repo.writes, 0);
    expect(vm.validateContents(List.filled(501, 'a').join()), isNotNull);
    await vm.save('좋은 거래였습니다.');
    expect(repo.writes, 1);
  });
  test('unconfirmed purchase and existing review do not submit', () async {
    final repo = FakeReviewRepository()
      ..current = const Purchase(code: 'PI1', productCode: 'P1', status: '거래중');
    final c = await start(repo);
    final vm = c.read(reviewVmProvider('PI1').notifier);
    vm.rate(4);
    await vm.save('후기');
    expect(repo.writes, 0);
    repo.current = purchase;
    repo.review = written;
    await vm.load();
    await vm.save('다른 후기');
    expect(repo.writes, 0);
  });
  test(
    'concurrent and post-success submissions cannot duplicate review',
    () async {
      final repo = FakeReviewRepository()..pending = Completer<ReviewRecord>();
      final c = await start(repo);
      final vm = c.read(reviewVmProvider('PI1').notifier);
      vm.rate(4);
      final first = vm.save('후기');
      await vm.save('후기');
      expect(repo.writes, 1);
      repo.pending!.complete(written);
      await first;
      await vm.save('후기');
      expect(repo.writes, 1);
    },
  );
  test(
    'uncertain save is not repeated and resolves from existing review',
    () async {
      final repo = FakeReviewRepository()
        ..error = const ReviewException('lost', uncertain: true);
      final c = await start(repo);
      final provider = reviewVmProvider('PI1');
      final vm = c.read(provider.notifier);
      vm.rate(4);
      await vm.save('후기');
      await vm.save('후기');
      await vm.load();
      expect(repo.writes, 1);
      expect(c.read(provider).uncertain, isTrue);
      repo.review = written;
      await vm.load();
      expect(c.read(provider).snapshot?.review?.code, 'R1');
      expect(c.read(provider).uncertain, isFalse);
    },
  );
  test('401 logs out and late save after logout is ignored', () async {
    final repo = FakeReviewRepository()
      ..error = const ReviewException('expired', status: 401);
    final c = await start(repo);
    final vm = c.read(reviewVmProvider('PI1').notifier);
    vm.rate(4);
    await vm.save('후기');
    expect(c.read(loginVmProvider).session, isNull);
    final later = FakeReviewRepository()..pending = Completer<ReviewRecord>();
    final d = await start(later);
    final writer = d.read(reviewVmProvider('PI1').notifier);
    writer.rate(4);
    final sent = writer.save('후기');
    await d.read(loginVmProvider.notifier).logout();
    later.pending!.complete(written);
    await sent;
    expect(d.read(reviewVmProvider('PI1')).snapshot, isNull);
  });
  testWidgets('small screen writer selects stars then displays saved review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeReviewRepository();
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: ReviewView(code: 'PI1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4점'));
    await tester.enterText(find.byType(TextFormField), '좋은 거래였습니다.');
    final submit = find.widgetWithText(FilledButton, '후기 등록');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(find.text('내 후기'), findsOneWidget);
    expect(find.text('좋은 거래였습니다.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
