import 'package:pokem_app/model/products/product_browse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/consignment/consignment.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/consignment/consignment_repository.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/consignment/consignment_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/consignment/consignment_vm.dart';
import 'package:pokem_app/view/consignment/consignment_view.dart';

import 'auth_test.dart' as auth;
import 'product_edit_test.dart' as edit;

Map<String, dynamic> record({
  String owner = 'tester',
  String code = 'CON1',
  String inspect = 'INS1',
  String intention = '대리판매',
  String? completed,
}) => {
  'post_consign_item_code': code,
  'inspect_inspect_code': inspect,
  'sell_product_sell_product_code': 'P1',
  'user_user_id': owner,
  'post_consign_item_date': '2026-10-31T12:00:00+09:00',
  'post_consign_item_complete_date': completed,
  'post_consign_item_expires_at': '2026-11-14T12:00:00',
  'post_consign_item_intention': intention,
};

class Products implements ProductRepository {
  @override
  Future<List<ProductClassification>> getFilters() async => [];
  Product value = edit.product(type: 'consign');
  Object? error;
  int reads = 0;
  @override
  Future<Product> getProduct(String code) async {
    reads++;
    if (error != null) throw error!;
    return value;
  }

  @override
  Future<List<Product>> getProducts({
    String? query,
    String? status,
    String? category,
    String? brand,
    ProductSort? sort,
    int? limit,
    int offset = 0,
    List<String>? codes,
  }) async => [value];
}

ConsignmentRepository repo(Map<String, dynamic> item, Products products) =>
    ConsignmentRepository(
      ConsignmentApiService(
        MockClient(
          (r) async =>
              auth.response(r.url.path == '/post_consign_item' ? [item] : item),
        ),
        baseUrl: 'http://test.local',
      ),
      products,
    );
void main() {
  test('inspection lookup joins current product and validates token', () async {
    final paths = <String>[];
    final products = Products();
    final repository = ConsignmentRepository(
      ConsignmentApiService(
        MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer token');
          paths.add(r.url.path);
          return auth.response(
            r.url.path == '/post_consign_item' ? [record()] : record(),
          );
        }),
        baseUrl: 'http://test.local',
      ),
      products,
    );
    final detail = await repository.get(
      (code: null, inspectCode: 'INS1'),
      'tester',
      'token',
    );
    expect(detail!.product!.title, '기존 상품');
    expect(detail.status, '판매중');
    expect(paths, ['/post_consign_item', '/post_consign_item/CON1']);
  });
  test('not registered is empty, server errors are not empty', () async {
    final repository = ConsignmentRepository(
      ConsignmentApiService(
        MockClient((_) async => auth.response([])),
        baseUrl: 'http://test.local',
      ),
      Products(),
    );
    expect(
      await repository.get(
        (code: null, inspectCode: 'INS1'),
        'tester',
        'token',
      ),
      isNull,
    );
    final api = ConsignmentApiService(
      MockClient((_) async => auth.response({}, 503)),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      api.list('token'),
      throwsA(
        isA<ConsignmentException>().having((e) => e.status, 'status', 503),
      ),
    );
  });
  test(
    'wrong owner and mismatched registration are rejected before product query',
    () async {
      for (final item in [record(owner: 'other'), record(code: 'OTHER')]) {
        final products = Products();
        await expectLater(
          repo(
            item,
            products,
          ).get((code: 'CON1', inspectCode: null), 'tester', 'token'),
          throwsA(isA<ConsignmentException>()),
        );
        expect(products.reads, 0);
      }
    },
  );
  test('returned and completed status follow server record, missing product preserves dates', () async {
    final products = Products()
      ..error = const ProductException('상품을 찾을 수 없습니다.', statusCode: 404);
    final returned = await repo(
      record(intention: '반환'),
      products,
    ).get((code: 'CON1', inspectCode: null), 'tester', 'token');
    expect(returned!.status, '반환으로 전환됨');
    expect(returned.product, isNull);
    expect(returned.item.expiresAt, isNotNull);
    expect(returned.productError, isNotNull);
    final completed = await repo(
      record(completed: '2026-11-01T12:00:00+09:00'),
      Products(),
    ).get((code: 'CON1', inspectCode: null), 'tester', 'token');
    expect(completed!.status, '거래완료');
  });
  test('wrong product owner never appears in detail', () async {
    final detail = await repo(
      record(),
      Products()..value = edit.product(owner: 'other', type: 'consign'),
    ).get((code: 'CON1', inspectCode: null), 'tester', 'token');
    expect(detail!.product, isNull);
    expect(detail.productError, isNotNull);
  });
  Future<ProviderContainer> start(ConsignmentRepository repository) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        consignmentRepositoryProvider.overrideWithValue(repository),
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

  test('401 logs out current user', () async {
    final c = await start(
      ConsignmentRepository(
        ConsignmentApiService(
          MockClient((_) async => auth.response({}, 401)),
          baseUrl: 'http://test.local',
        ),
        Products(),
      ),
    );
    final provider = consignmentVmProvider((code: 'CON1', inspectCode: null));
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'registered item displays linked product, deadline and detail action',
    (tester) async {
      final c = (await tester.runAsync(
        () => start(repo(record(), Products())),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: ConsignmentView(source: (code: 'CON1', inspectCode: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('기존 상품'), findsOneWidget);
      expect(find.text('검수번호 INS1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('판매 기한'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('판매 기한'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('판매상품 보기'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('판매상품 보기'), findsOneWidget);
      expect(find.textContaining('판정 사유'), findsNothing);
    },
  );
  testWidgets(
    'return conversion offers return history even when product missing',
    (tester) async {
      final c = (await tester.runAsync(
        () => start(
          repo(
            record(intention: '반환'),
            Products()..error = const ProductException('상품을 찾을 수 없습니다.'),
          ),
        ),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: ConsignmentView(source: (code: 'CON1', inspectCode: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('반환으로 전환됨'), findsOneWidget);
      expect(find.text('상품 정보 다시 불러오기'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('반환내역 보기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('반환내역 보기'), findsOneWidget);
    },
  );
}
