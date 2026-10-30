import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/wishlist/wishlist_repository.dart';
import 'package:pokem_app/service/wishlist/wishlist_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

import 'auth_test.dart' as auth;
import 'product_test.dart' as products;
import 'support/wishlist_fixture.dart';

Map<String, dynamic> row(
  String code, {
  bool wished = true,
  String user = 'tester',
}) => {
  'sell_product_sell_product_code': code,
  'user_user_id': user,
  'wishlist_status': wished ? '관심' : '해제',
};
final card = Product.fromJson(products.productJson());

void main() {
  test(
    'authenticated API encodes IDs and sends only product code when adding',
    () async {
      var calls = 0;
      final api = WishlistApiService(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          calls++;
          switch (request.method) {
            case 'GET':
              expect(
                request.url.toString(),
                'http://test.local/wishlist/user%201',
              );
              return auth.response([row('P #1', user: 'user 1')]);
            case 'POST':
              expect(request.url.path, '/wishlist');
              expect(jsonDecode(request.body), {
                'sell_product_sell_product_code': 'P #1',
              });
              return auth.response(row('P #1', user: 'user 1'));
            default:
              expect(request.method, 'DELETE');
              expect(
                request.url.toString(),
                'http://test.local/wishlist/user%201/P%20%231',
              );
              return auth.response(row('P #1', wished: false, user: 'user 1'));
          }
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.getRecords('user 1', 'token')).single.isWished, isTrue);
      expect(
        (await api.setWished('user 1', 'P #1', true, 'token')).isWished,
        isTrue,
      );
      expect(
        (await api.setWished('user 1', 'P #1', false, 'token')).isWished,
        isFalse,
      );
      expect(calls, 3);
    },
  );

  test(
    'repository joins once and keeps wished cards in every sale status',
    () async {
      var productCalls = 0;
      final api = WishlistApiService(
        MockClient(
          (_) async =>
              auth.response([row('P-2'), row('P-1'), row('P-3'), row('P-4')]),
        ),
        baseUrl: 'http://test.local',
      );
      final repo = WishlistRepository(
        api,
        products.repository((_) {
          productCalls++;
          return auth.response([
            products.productJson(),
            products.productJson(code: 'P-2', title: '리자몽'),
            products.productJson(code: 'P-3', status: '거래중'),
            products.productJson(code: 'P-4', status: '거래완료'),
          ]);
        }),
      );
      final snapshot = await repo.getSnapshot('tester', 'token');
      expect(snapshot.products.map((p) => p.code), [
        'P-2',
        'P-1',
        'P-3',
        'P-4',
      ]);
      expect(snapshot.codes, containsAll(['P-3', 'P-4']));
      expect(productCalls, 1);
    },
  );

  Future<ProviderContainer> startVm(
    MemoryWishlistRepository wishes, {
    String role = 'user',
  }) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse(role: role)),
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        wishlistRepositoryProvider.overrideWithValue(wishes),
      ],
    );
    addTearDown(container.dispose);
    container.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    final sub = container.listen(wishlistVmProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  test('failed removal keeps heart and list; retry succeeds', () async {
    final wishes = MemoryWishlistRepository(
      allProducts: [card],
      initialCodes: {card.code},
    )..changeError = const ProductException('처리 실패');
    final container = await startVm(wishes);
    await container.read(wishlistVmProvider.notifier).toggle(card);
    expect(container.read(wishlistVmProvider).isWished(card.code), isTrue);
    expect(container.read(wishlistVmProvider).products, hasLength(1));
    expect(container.read(wishlistVmProvider).error, '처리 실패');
    wishes.changeError = null;
    await container.read(wishlistVmProvider.notifier).toggle(card);
    expect(container.read(wishlistVmProvider).isWished(card.code), isFalse);
    expect(container.read(wishlistVmProvider).products, isEmpty);
  });

  test('pending product blocks duplicate toggles and refresh races', () async {
    final wishes = MemoryWishlistRepository(allProducts: [card])
      ..changeGate = Completer<void>();
    final container = await startVm(wishes);
    final vm = container.read(wishlistVmProvider.notifier);
    final first = vm.toggle(card);
    expect(container.read(wishlistVmProvider).isWished(card.code), isTrue);
    expect(container.read(wishlistVmProvider).products.single.code, card.code);
    expect(wishes.codes, isEmpty);
    await vm.toggle(card);
    await vm.refresh();
    expect(wishes.changes, 1);
    expect(wishes.loads, 1);
    expect(container.read(wishlistVmProvider).canToggle(card), isFalse);
    wishes.changeGate!.complete();
    await first;
    expect(container.read(wishlistVmProvider).isWished(card.code), isTrue);
    expect(container.read(wishlistVmProvider).canToggle(card), isTrue);
  });

  test('removal updates before response and rollback preserves another pending add', () async {
    final other = Product.fromJson(products.productJson(code: 'P-2'));
    final wishes =
        MemoryWishlistRepository(
            allProducts: [card, other],
            initialCodes: {card.code},
          )
          ..changeGate = Completer<void>()
          ..changeError = const ProductException('처리 실패');
    final container = await startVm(wishes);
    final vm = container.read(wishlistVmProvider.notifier);
    final remove = vm.toggle(card);
    expect(container.read(wishlistVmProvider).products, isEmpty);
    expect(container.read(wishlistVmProvider).isWished(card.code), isFalse);
    final add = vm.toggle(other);
    expect(container.read(wishlistVmProvider).isWished(other.code), isTrue);
    wishes.changeGate!.complete();
    await remove;
    await add;
    expect(container.read(wishlistVmProvider).isWished(card.code), isTrue);
    expect(container.read(wishlistVmProvider).isWished(other.code), isFalse);
    expect(container.read(wishlistVmProvider).products.map((p) => p.code), [
      card.code,
    ]);
  });

  test('late load cannot restore another session after logout', () async {
    final wishes = MemoryWishlistRepository(
      allProducts: [card],
      initialCodes: {card.code},
    )..loadGate = Completer<void>();
    final container = await startVm(wishes);
    expect(container.read(wishlistVmProvider).loading, isTrue);
    await container.read(loginVmProvider.notifier).logout();
    expect(container.read(wishlistVmProvider).canManage, isFalse);
    wishes.loadGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(wishlistVmProvider).codes, isEmpty);
  });

  test('non-user roles cannot load or change wishes', () async {
    final wishes = MemoryWishlistRepository(allProducts: [card]);
    final container = await startVm(wishes, role: 'manager');
    await container.read(wishlistVmProvider.notifier).toggle(card);
    expect(wishes.loads, 0);
    expect(wishes.changes, 0);
  });

  test('expired server session returns to login', () async {
    final wishes = MemoryWishlistRepository()
      ..loadError = const ProductException('expired', statusCode: 401);
    final container = await startVm(wishes);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(loginVmProvider).session, isNull);
    expect(container.read(wishlistVmProvider).codes, isEmpty);
  });

  testWidgets('detail heart updates interest tab and can be removed there', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final wishes = MemoryWishlistRepository(allProducts: [card]);
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(session),
          wishlistRepositoryProvider.overrideWithValue(wishes),
          productRepositoryProvider.overrideWithValue(
            products.repository(
              (request) => auth.response(
                request.url.path == '/sell_product'
                    ? [products.productJson()]
                    : products.productJson(),
              ),
            ),
          ),
        ],
        child: const PokemApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PokemApp)),
    );
    await container
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('product-P-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-P-1')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('관심 등록'), findsOneWidget);
    await tester.tap(find.byTooltip('관심 등록'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('관심 해제'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('관심'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wished-product-P-1')), findsOneWidget);
    await tester.tap(find.byTooltip('관심 해제'));
    await tester.pumpAndSettle();
    expect(find.text('관심상품이 없습니다.'), findsOneWidget);
    expect(wishes.changes, 2);
  });
}
