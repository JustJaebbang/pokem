import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_delete.dart';
import 'package:pokem_app/repository/products/product_delete_repository.dart';
import 'package:pokem_app/service/products/product_delete_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/product_delete_vm.dart';
import 'package:pokem_app/view/products/product_delete_view.dart';

import 'auth_test.dart' as auth;
import 'product_edit_test.dart' as edit;

class FakeDelete implements ProductDeleteRepository {
  Product value = edit.product();
  Object? readError, deleteError;
  Completer<void>? pending;
  int deletes = 0;
  @override
  Future<Product> getProduct(String code) async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> delete(String code, String token) async {
    deletes++;
    if (deleteError != null) throw deleteError!;
    if (pending != null) await pending!.future;
  }
}

void main() {
  test(
    'DELETE sends authentication and validates returned product code',
    () async {
      final api = ProductDeleteApiService(
        MockClient((r) async {
          expect(r.method, 'DELETE');
          expect(r.url.path, '/sell_product/P1');
          expect(r.headers['Authorization'], 'Bearer token');
          return auth.response({'sell_product_code': 'P1'});
        }),
        baseUrl: 'http://test.local',
      );
      await api.delete('P1', 'token');
      final bad = ProductDeleteApiService(
        MockClient((_) async => auth.response({'sell_product_code': 'OTHER'})),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        bad.delete('P1', 'token'),
        throwsA(
          isA<ProductDeleteException>().having(
            (e) => e.uncertain,
            'uncertain',
            true,
          ),
        ),
      );
    },
  );
  test('foreign key rejection preserves message and is definite', () async {
    final api = ProductDeleteApiService(
      MockClient((_) async => auth.response({'detail': '연결된 기록이 있습니다.'}, 409)),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      api.delete('P1', 'token'),
      throwsA(
        isA<ProductDeleteException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.uncertain, 'uncertain', false),
      ),
    );
  });
  Future<ProviderContainer> start(FakeDelete repo) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        productDeleteRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    await c.read(productDeleteVmProvider('P1').notifier).load();
    return c;
  }

  test('other owners consignments and trading/completed products cannot be deleted', () async {
    for (final product in [
      edit.product(owner: 'other'),
      edit.product(type: 'consign'),
      edit.product(status: '거래중'),
      edit.product(status: '거래완료'),
    ]) {
      final repo = FakeDelete()..value = product;
      final c = await start(repo);
      await c.read(productDeleteVmProvider('P1').notifier).submit();
      expect(repo.deletes, 0);
      expect(c.read(productDeleteVmProvider('P1')).product, isNull);
    }
  });
  test('duplicate requests are blocked and success becomes deleted', () async {
    final repo = FakeDelete()..pending = Completer<void>();
    final c = await start(repo);
    final vm = c.read(productDeleteVmProvider('P1').notifier);
    final first = vm.submit();
    await vm.submit();
    expect(repo.deletes, 1);
    repo.pending!.complete();
    await first;
    expect(c.read(productDeleteVmProvider('P1')).deleted, isTrue);
  });
  test(
    'unknown result blocks repeat DELETE and reconciles only on 404',
    () async {
      final repo = FakeDelete()
        ..deleteError = const ProductDeleteException(
          'timeout',
          uncertain: true,
        );
      final c = await start(repo);
      final vm = c.read(productDeleteVmProvider('P1').notifier);
      await vm.submit();
      await vm.load();
      await vm.submit();
      expect(repo.deletes, 1);
      expect(c.read(productDeleteVmProvider('P1')).uncertain, isTrue);
      repo.readError = const ProductException('missing', statusCode: 404);
      await vm.load();
      expect(c.read(productDeleteVmProvider('P1')).deleted, isTrue);
    },
  );
  test('server refusal requires reloading eligibility before retry', () async {
    final repo = FakeDelete()
      ..deleteError = const ProductDeleteException('거래중입니다.', status: 409);
    final c = await start(repo);
    final vm = c.read(productDeleteVmProvider('P1').notifier);
    await vm.submit();
    await vm.submit();
    expect(repo.deletes, 1);
    expect(c.read(productDeleteVmProvider('P1')).product, isNull);
  });
  testWidgets('closing confirmation never sends DELETE', (tester) async {
    final repo = FakeDelete();
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: ProductDeleteView(code: 'P1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기존 상품'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '상품 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('상품을 삭제하시겠어요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
  });
}
