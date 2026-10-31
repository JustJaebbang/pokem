import 'support/wishlist_fixture.dart';

import 'package:pokem_app/core/media/product_image_url.dart';
import 'package:pokem_app/core/providers/data_providers.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/products/product_api_service.dart';
import 'package:pokem_app/vm/products/products_vm.dart';

import 'auth_test.dart' as auth;

Map<String, dynamic> productJson({
  String code = 'P-1',
  String title = '피카츄 카드',
  String status = '판매중',
  int price = 12000,
}) => {
  'sell_product_code': code,
  'sell_product_serial_code': 'SV_card_001',
  'seq': 1,
  'sell_product_title': title,
  'sell_product_image': '',
  'sell_product_contents': '깨끗한 카드입니다.',
  'sell_product_sell_price': price,
  'sell_product_grade': 'Unrank',
  'sell_product_sell_status': status,
};
ProductRepository repository(
  FutureOr<http.Response> Function(http.Request) handler,
) => ProductRepository(
  ProductApiService(
    MockClient((request) async => await handler(request)),
    baseUrl: 'http://test.local',
  ),
);

void main() {
  test(
    'list and detail use actual public API contract and encoded product code',
    () async {
      final repo = repository((request) {
        expect(request.headers['Authorization'], isNull);
        if (request.url.path == '/sell_product') {
          return auth.response([productJson()]);
        }
        expect(
          request.url.toString(),
          'http://test.local/sell_product/P%20%231',
        );
        return auth.response(productJson(code: 'P #1'));
      });
      expect((await repo.getProducts()).single.title, '피카츄 카드');
      expect((await repo.getProduct('P #1')).code, 'P #1');
    },
  );

  test(
    'invalid data, offline server and missing product have usable errors',
    () async {
      for (final body in [
        {'wrong': true},
        [
          {'bad': 'row'},
        ],
      ]) {
        await expectLater(
          repository((_) => auth.response(body)).getProducts(),
          throwsA(isA<ProductException>()),
        );
      }
      await expectLater(
        repository((_) => auth.response({}, 404)).getProduct('missing'),
        throwsA(
          isA<ProductException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      await expectLater(
        repository((_) => throw http.ClientException('offline')).getProducts(),
        throwsA(isA<ProductException>()),
      );
    },
  );

  test('filter combines query and status and resolves image paths', () {
    final products = [
      Product.fromJson(productJson()),
      Product.fromJson(productJson(code: 'P-2', title: '리자몽', status: '거래완료')),
      Product.fromJson(
        productJson(code: 'P-3', title: '거래중 카드', status: '거래중'),
      ),
    ];
    expect(filterProducts(products, '피카츄').single.code, 'P-1');
    expect(filterProducts(products, '리자몽'), isEmpty);
    expect(filterProducts(products, 'sv_CARD'), hasLength(1));
    expect(
      resolveProductImage(
        '/media/products/a.png',
        baseUrl: 'http://server:8000',
      ),
      'http://server:8000/media/products/a.png',
    );
    expect(
      resolveProductImage('https://cdn.test/a.jpg'),
      'https://cdn.test/a.jpg',
    );
    expect(resolveProductImage('javascript:alert(1)'), isNull);
    expect(resolveProductImage(''), isNull);
    expect(formatWon(12000), '12,000원');
  });

  Future<void> showHome(
    WidgetTester tester,
    ProductRepository products, {
    int expiresIn = 1800,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sessionRepo = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse(expiresIn: expiresIn)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(sessionRepo),
          wishlistRepositoryProvider.overrideWithValue(
            MemoryWishlistRepository(),
          ),
          productRepositoryProvider.overrideWithValue(products),
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
  }

  testWidgets('home uses toolbar search and detail keeps the search query', (
    tester,
  ) async {
    var detailCalls = 0;
    final repo = repository((request) {
      if (request.url.path == '/sell_product') {
        return auth.response([
          productJson(),
          productJson(code: 'P-2', title: '리자몽'),
          productJson(code: 'P-3', title: '완료된 카드', status: '거래완료'),
          productJson(code: 'P-4', title: '거래중 카드', status: '거래중'),
        ]);
      }
      detailCalls++;
      return auth.response(productJson(title: '피카츄 카드 최신', price: 15000));
    });
    await showHome(tester, repo);
    expect(find.text('피카츄 카드'), findsOneWidget);
    expect(find.text('완료된 카드'), findsNothing);
    expect(find.text('거래중 카드'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('상품 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '피카츄');
    await tester.pumpAndSettle();
    expect(find.text('리자몽'), findsNothing);
    await tester.tap(find.text('피카츄 카드'));
    await tester.pumpAndSettle();
    expect(detailCalls, 1);
    expect(find.text('피카츄 카드 최신'), findsOneWidget);
    expect(find.text('15,000원'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '피카츄',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('관심'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('리자몽'), findsOneWidget);
  });

  testWidgets('empty list and local search misses are clear', (tester) async {
    await showHome(tester, repository((_) => auth.response([])));
    expect(find.text('표시할 상품이 없습니다.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('failed load retries and product cards fit a small screen', (
    tester,
  ) async {
    var calls = 0;
    await showHome(
      tester,
      repository((_) {
        calls++;
        return calls == 1
            ? auth.response({}, 500)
            : auth.response([productJson()]);
      }),
    );
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.ensureVisible(find.text('다시 시도'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('피카츄 카드'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('product-P-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final own in [true, false]) {
    testWidgets(
      'detail ${own ? 'hides' : 'shows'} chat and buy actions by owner',
      (tester) async {
        final row = {
          ...productJson(),
          'seller_user_id': own ? 'tester' : 'seller',
        };
        await showHome(
          tester,
          repository(
            (request) => auth.response(
              request.url.path == '/sell_product' ? [row] : row,
            ),
          ),
        );
        await tester.ensureVisible(find.byKey(const ValueKey('product-P-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('product-P-1')));
        await tester.pumpAndSettle();
        expect(find.text('상품 상세'), findsOneWidget);
        expect(find.text('채팅하기'), own ? findsNothing : findsOneWidget);
        expect(find.text('구매하기'), own ? findsNothing : findsOneWidget);
      },
    );
  }

  testWidgets('expiry on detail pops protected navigation back to login', (
    tester,
  ) async {
    await showHome(
      tester,
      repository(
        (request) => auth.response(
          request.url.path == '/sell_product' ? [productJson()] : productJson(),
        ),
      ),
      expiresIn: 5,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('product-P-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-P-1')));
    await tester.pumpAndSettle();
    expect(find.text('상품 상세'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loginId')), findsOneWidget);
    expect(find.text('상품 상세'), findsNothing);
  });
}
