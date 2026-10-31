import 'package:pokem_app/view/home/product_filters.dart';
import 'package:pokem_app/vm/products/product_search_vm.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/repository/wishlist/wishlist_repository.dart';
import 'package:pokem_app/service/products/product_api_service.dart';
import 'package:pokem_app/service/wishlist/wishlist_api_service.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/view/products/product_search_view.dart';

import 'auth_test.dart' as auth;
import 'product_test.dart' as products;

void main() {
  testWidgets(
    'category and brand selections reset paging and survive sorting',
    (tester) async {
      final requests = <Uri>[];
      final repository = products.repository((r) {
        if (r.url.path == '/sell_product/filters') {
          return auth.response([
            {'category': '포켓몬', 'brand': '브랜드A'},
            {'category': '유희왕', 'brand': '브랜드B'},
          ]);
        }
        requests.add(r.url);
        return auth.response([products.productJson()]);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [productRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: ProductFilters())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('포켓몬'));
      await tester.pumpAndSettle();
      expect(find.text('브랜드B'), findsNothing);
      await tester.tap(find.text('브랜드A'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['category'], '포켓몬');
      expect(requests.last.queryParameters['brand'], '브랜드A');
      expect(requests.last.queryParameters['status'], '판매중');
      expect(requests.last.queryParameters['offset'], '0');
      final c = ProviderScope.containerOf(
        tester.element(find.byType(ProductFilters)),
      );
      await c
          .read(productsVmProvider.notifier)
          .changeSort(ProductSort.priceAsc);
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['brand'], '브랜드A');
      expect(requests.last.queryParameters['sort'], 'price_asc');
      await tester.tap(find.text('유희왕'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['category'], '유희왕');
      expect(requests.last.queryParameters.containsKey('brand'), isFalse);
    },
  );

  test(
    'server search query and paging parameters are encoded correctly',
    () async {
      final api = ProductApiService(
        MockClient((r) async {
          expect(r.url.queryParameters, {
            'q': '피카츄 100%',
            'status': '판매중',
            'sort': 'price_asc',
            'limit': '20',
            'offset': '20',
          });
          expect(r.headers['Authorization'], isNull);
          return auth.response([]);
        }),
        baseUrl: 'http://test.local',
      );
      await api.getProducts(
        query: ' 피카츄 100% ',
        status: '판매중',
        sort: ProductSort.priceAsc,
        limit: 20,
        offset: 20,
      );
    },
  );
  Future<ProviderContainer> start(ProductRepository repository) async {
    final c = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    final ready = Completer<void>();
    final sub = c.listen(productsVmProvider, (_, next) {
      if (!next.products.isLoading && !ready.isCompleted) ready.complete();
    });
    addTearDown(sub.close);
    await ready.future;
    return c;
  }

  test(
    'failed next page keeps rows and retries same offset without duplicates',
    () async {
      var fail = true;
      final offsets = <String>[];
      final repository = products.repository((r) {
        final offset = r.url.queryParameters['offset']!;
        offsets.add(offset);
        if (offset == '0') {
          return auth.response(
            List.generate(20, (i) => products.productJson(code: 'P$i')),
          );
        }
        return fail
            ? auth.response({}, 503)
            : auth.response([
                products.productJson(code: 'P19'),
                products.productJson(code: 'P20'),
              ]);
      });
      final c = await start(repository);
      final vm = c.read(productsVmProvider.notifier);
      await vm.loadMore();
      expect(c.read(productsVmProvider).products.asData!.value.length, 20);
      expect(c.read(productsVmProvider).pageError, isNotNull);
      fail = false;
      await vm.loadMore();
      expect(c.read(productsVmProvider).products.asData!.value.length, 21);
      expect(offsets, ['0', '20', '20']);
      expect(c.read(productsVmProvider).hasMore, isFalse);
    },
  );
  test('late old sort response never overwrites newer price sort', () async {
    final old = Completer<http.Response>();
    final repository = products.repository(
      (r) => r.url.queryParameters['sort'] == 'newest'
          ? old.future
          : auth.response([products.productJson(code: 'PRICE')]),
    );
    final c = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(productsVmProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await c.read(productsVmProvider.notifier).changeSort(ProductSort.priceAsc);
    old.complete(auth.response([products.productJson(code: 'OLD')]));
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(productsVmProvider).products.asData!.value.single.code,
      'PRICE',
    );
  });
  test(
    'wishlist fetches only requested codes and keeps all sale statuses',
    () async {
      final productRepo = products.repository((r) {
        expect(r.url.queryParametersAll['codes'], ['P2', 'P3']);
        expect(r.url.queryParameters.containsKey('status'), isFalse);
        return auth.response([
          products.productJson(code: 'P2', status: '거래중'),
          products.productJson(code: 'P3', status: '거래완료'),
        ]);
      });
      final wishes = WishlistApiService(
        MockClient(
          (_) async => auth.response([
            for (final code in ['P2', 'P3'])
              {
                'sell_product_sell_product_code': code,
                'user_user_id': 'tester',
                'wishlist_status': '관심',
              },
          ]),
        ),
        baseUrl: 'http://test.local',
      );
      final snapshot = await WishlistRepository(
        wishes,
        productRepo,
      ).getSnapshot('tester', 'token');
      expect(snapshot.products.length, 2);
      expect(snapshot.products.last.status, '거래완료');
    },
  );
  testWidgets(
    'market search debounces typing and sort sends a new server request',
    (tester) async {
      final queries = <String?>[];
      final sorts = <String?>[];
      final repository = products.repository((r) {
        queries.add(r.url.queryParameters['q']);
        sorts.add(r.url.queryParameters['sort']);
        return auth.response([]);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [productRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: ProductSearchView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'p');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'pi');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'pikachu');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(queries, [null, 'pikachu']);
      await tester.tap(find.text('최신순'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('낮은 가격순').last);
      await tester.pumpAndSettle();
      expect(sorts.last, 'price_asc');
      expect(queries.last, 'pikachu');
    },
  );
  test(
    'server collation matches are preserved without local query filtering',
    () async {
      final repository = products.repository(
        (r) => auth.response(
          r.url.queryParameters['q'] == 'pokemon'
              ? [products.productJson(title: 'Pokémon 카드')]
              : [],
        ),
      );
      final c = ProviderContainer(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(productSearchResultsProvider(false), (_, _) {});
      addTearDown(sub.close);
      c.read(productSearchQueryProvider(false).notifier).search('pokemon');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(
        c.read(productSearchResultsProvider(false)).asData!.value.single.title,
        'Pokémon 카드',
      );
    },
  );
}
