import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/notifications/app_notification.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/notifications/notifications_repository.dart';
import 'package:pokem_app/service/notifications/notifications_api_service.dart';
import 'package:pokem_app/service/notifications/notification_read_storage.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/vm/products/product_search_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/view/notifications/notification_bell.dart';
import 'package:pokem_app/view/home/home_shell.dart';
import 'package:pokem_app/view/products/product_search_view.dart';

import 'auth_test.dart' as auth;
import 'support/wishlist_fixture.dart';

Map<String, dynamic> notice({String owner = 'tester'}) => {
  'id': 'fee:F1',
  'title': '검수비 결제가 준비되었습니다',
  'body': '결제를 확인해주세요.',
  'target_type': 'inspection_fee',
  'target_code': 'R1',
  'user_user_id': owner,
  'occurred_at': '2026-10-31T12:00:00+09:00',
};

class ReadStorage implements NotificationReadStorage {
  final values = <String, Set<String>>{};
  bool fail = false;
  @override
  Future<Set<String>> read(String key) async => {...?values[key]};
  @override
  Future<void> write(String key, Set<String> ids) async {
    if (fail) throw StateError('write');
    values[key] = {...ids};
  }
}

Product product(int i, String status) => Product(
  code: 'P$i',
  serialCode: 'SV$i',
  title: '카드 $i',
  image: '',
  description: '설명',
  price: 1000,
  grade: 'Unrank',
  status: status,
);
final cards = [product(1, '판매중'), product(2, '거래중'), product(3, '거래완료')];

class SearchProductsVm extends ProductsVm {
  @override
  ProductsState build() => ProductsState(products: AsyncData(cards));
}

void main() {
  NotificationsRepository repo(
    ReadStorage storage, {
    int status = 200,
    String owner = 'tester',
  }) => NotificationsRepository(
    NotificationsApiService(
      MockClient((r) async {
        expect(r.url.path, '/notifications');
        expect(r.method, 'GET');
        expect(r.headers['Authorization'], 'Bearer test-token');
        return auth.response(
          status == 200 ? [notice(owner: owner)] : {},
          status,
        );
      }),
      baseUrl: 'http://test.local',
    ),
    storage,
    namespace: 'test',
  );
  Future<ProviderContainer> start(NotificationsRepository repository) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        notificationsRepositoryProvider.overrideWithValue(repository),
        productsVmProvider.overrideWith(SearchProductsVm.new),
        wishlistRepositoryProvider.overrideWithValue(
          MemoryWishlistRepository(
            allProducts: cards,
            initialCodes: {'P1', 'P2', 'P3'},
          ),
        ),
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

  test('reads are persisted and scoped to environment and account', () async {
    final storage = ReadStorage();
    final repository = repo(storage);
    final c = await start(repository);
    final sub = c.listen(notificationsVmProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(notificationsVmProvider.future)).unread, 1);
    await c.read(notificationsVmProvider.notifier).markRead(id: 'fee:F1');
    expect(c.read(notificationsVmProvider).asData!.value.unread, 0);
    expect((await repository.get('tester', 'test-token')).unread, 0);
    expect(
      (await repo(storage, owner: 'other').get('other', 'test-token')).unread,
      1,
    );
  });
  test('wrong owner cannot enter inbox', () async {
    await expectLater(
      repo(ReadStorage(), owner: 'other').get('tester', 'test-token'),
      throwsA(isA<NotificationsException>()),
    );
  });
  test('read write failure restores unread state and shows error', () async {
    final storage = ReadStorage()..fail = true;
    final c = await start(repo(storage));
    final sub = c.listen(notificationsVmProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(notificationsVmProvider.future);
    await c.read(notificationsVmProvider.notifier).markRead();
    expect(c.read(notificationsVmProvider).asData!.value.unread, 1);
    expect(c.read(notificationsVmProvider).asData!.value.error, isNotNull);
  });
  test('401 logs out current account', () async {
    final c = await start(repo(ReadStorage(), status: 401));
    final sub = c.listen(notificationsVmProvider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(notificationsVmProvider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  test('market search only sells while wishlist search keeps trading and completed', () async {
    final c = await start(repo(ReadStorage()));
    final market = c.listen(productSearchResultsProvider(false), (_, _) {});
    final wishes = c.listen(productSearchResultsProvider(true), (_, _) {});
    addTearDown(market.close);
    addTearDown(wishes.close);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(productSearchResultsProvider(false)).asData!.value.length, 1);
    expect(c.read(productSearchResultsProvider(true)).asData!.value.length, 3);
    c.read(productSearchQueryProvider(true).notifier).search('SV3');
    expect(
      c.read(productSearchResultsProvider(true)).asData!.value.single.status,
      '거래완료',
    );
  });
  testWidgets('bell opens inbox and mark all clears unread badge', (
    tester,
  ) async {
    final c = (await tester.runAsync(() => start(repo(ReadStorage()))))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [NotificationBell()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    await tester.tap(find.byTooltip('알림'));
    await tester.pumpAndSettle();
    expect(find.text('검수비 결제가 준비되었습니다'), findsOneWidget);
    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });
  testWidgets('wishlist toolbar searches wishlist and bottom label is mypage', (
    tester,
  ) async {
    final c = (await tester.runAsync(() => start(repo(ReadStorage()))))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('마이페이지'), findsOneWidget);
    expect(find.text('나'), findsNothing);
    await tester.tap(find.text('관심'));
    await tester.pumpAndSettle();
    expect(find.text('관심목록'), findsOneWidget);
    await tester.tap(find.byTooltip('관심상품 검색'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProductSearchView>(find.byType(ProductSearchView))
          .wishlistOnly,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'SV3');
    await tester.pumpAndSettle();
    expect(find.text('카드 3'), findsOneWidget);
    expect(find.text('카드 1'), findsNothing);
    expect(find.textContaining('거래완료'), findsOneWidget);
  });
}
