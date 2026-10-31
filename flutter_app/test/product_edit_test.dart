import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_edit.dart';
import 'package:pokem_app/repository/products/product_edit_repository.dart';
import 'package:pokem_app/service/products/product_edit_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/product_edit_vm.dart';
import 'package:pokem_app/view/products/product_edit_view.dart';

import 'auth_test.dart' as auth;

Product product({
  String owner = 'tester',
  String? type = 'direct',
  String status = '판매중',
}) => Product(
  code: 'P1',
  serialCode: 'SV1',
  title: '기존 상품',
  image: '',
  description: '기존 설명',
  price: 10000,
  grade: 'Unrank',
  status: status,
  sellerId: owner,
  saleType: type,
);
const input = ProductEditInput(
  title: '새 상품',
  description: '새 설명',
  price: '20000',
);

class FakeEditRepository implements ProductEditRepository {
  Product current = product();
  int writes = 0;
  ProductEditDraft? draft;
  Object? error;
  Completer<Product>? pending;
  @override
  Future<Product> getProduct(String code) async => current;
  @override
  Future<Product> update(
    String code,
    ProductEditDraft draft,
    String token,
  ) async {
    writes++;
    this.draft = draft;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return current;
  }
}

void main() {
  Future<ProviderContainer> start(FakeEditRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        productEditRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await c
        .read(loginVmProvider.notifier)
        .login('tester', 'pw', remember: false);
    final sub = c.listen(productEditVmProvider('P1'), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('PUT sends editable fields and preserves original image only', () async {
    final api = ProductEditApiService(
      MockClient((r) async {
        expect(r.method, 'PUT');
        expect(r.url.path, '/sell_product/P1');
        expect(r.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(r.body), {
          'sell_product_title': '새 상품',
          'sell_product_contents': '새 설명',
          'sell_product_sell_price': 20000,
          'sell_product_image': '/media/products/original.jpg',
        });
        return auth.response({
          'sell_product_code': 'P1',
          'sell_product_serial_code': 'SV1',
          'sell_product_title': '새 상품',
          'sell_product_image': '/media/products/original.jpg',
          'sell_product_contents': '새 설명',
          'sell_product_sell_price': 20000,
          'sell_product_grade': 'Unrank',
          'sell_product_sell_status': '판매중',
        });
      }),
      baseUrl: 'http://test.local',
    );
    expect(
      (await api.update(
        'P1',
        const ProductEditDraft(
          title: '새 상품',
          description: '새 설명',
          price: 20000,
          image: '/media/products/original.jpg',
        ),
        'token',
      )).price,
      20000,
    );
  });
  test('only own direct and selling products can be edited', () async {
    for (final current in [
      product(owner: 'other'),
      product(type: 'consign'),
      product(type: null),
      product(status: '거래중'),
      product(status: '거래완료'),
    ]) {
      final repo = FakeEditRepository()..current = current;
      final c = await start(repo);
      expect(c.read(productEditVmProvider('P1')).canEdit, isFalse);
      expect(
        await c.read(productEditVmProvider('P1').notifier).save(input),
        isFalse,
      );
      expect(repo.writes, 0);
    }
  });
  test(
    'validation blocks bad input and duplicate saves while pending',
    () async {
      final repo = FakeEditRepository()..pending = Completer<Product>();
      final c = await start(repo);
      final vm = c.read(productEditVmProvider('P1').notifier);
      expect(
        await vm.save(
          const ProductEditInput(title: ' ', description: '説明', price: '0'),
        ),
        isFalse,
      );
      expect(repo.writes, 0);
      expect(vm.validatePrice('1.5'), isNotNull);
      expect(vm.validatePrice('2147483648'), isNotNull);
      final first = vm.save(input);
      expect(await vm.save(input), isFalse);
      expect(repo.writes, 1);
      expect(repo.draft?.image, repo.current.image);
      repo.pending!.complete(product());
      expect(await first, isTrue);
    },
  );
  test('state conflict stops saves until latest product is reloaded', () async {
    final repo = FakeEditRepository()
      ..error = const ProductException('판매중인 상품만 수정할 수 있습니다.', statusCode: 409);
    final c = await start(repo);
    final vm = c.read(productEditVmProvider('P1').notifier);
    expect(await vm.save(input), isFalse);
    expect(c.read(productEditVmProvider('P1')).canEdit, isFalse);
    await vm.save(input);
    expect(repo.writes, 1);
    repo.current = product(status: '거래중');
    await vm.load();
    expect(c.read(productEditVmProvider('P1')).canEdit, isFalse);
  });
  test('401 clears session and late save after logout is ignored', () async {
    final repo = FakeEditRepository()
      ..error = const ProductException('expired', statusCode: 401);
    final c = await start(repo);
    await c.read(productEditVmProvider('P1').notifier).save(input);
    expect(c.read(loginVmProvider).session, isNull);
    final lateRepo = FakeEditRepository()..pending = Completer<Product>();
    final d = await start(lateRepo);
    final sent = d.read(productEditVmProvider('P1').notifier).save(input);
    await d.read(loginVmProvider.notifier).logout();
    lateRepo.pending!.complete(product());
    expect(await sent, isFalse);
    expect(d.read(productEditVmProvider('P1')).product, isNull);
  });
  testWidgets(
    'edit form preserves user input when save fails on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeEditRepository()
        ..error = const ProductException('저장 실패');
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: ProductEditView(code: 'P1')),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.byKey(const Key('editTitle'));
      await tester.ensureVisible(title);
      await tester.enterText(title, '새 상품');
      final save = find.widgetWithText(FilledButton, '저장');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(tester.widget<TextFormField>(title).controller!.text, '새 상품');
      expect(find.text('저장 실패'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
