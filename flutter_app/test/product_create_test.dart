import 'support/wishlist_fixture.dart';

import 'package:pokem_app/model/products/product_form_input.dart';
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/core/providers/data_providers.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokem_app/view/products/product_create_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/model/products/product_draft.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_publish_repository.dart';
import 'package:pokem_app/service/products/product_photo_picker.dart';
import 'package:pokem_app/service/products/product_publish_api_service.dart';
import 'package:pokem_app/vm/products/product_create_vm.dart';

import 'auth_test.dart' as auth;
import 'product_test.dart' as products;

const draft = ProductDraft(
  regulation: 'SV',
  packType: 'pack',
  element: 'card',
  setNumber: '001',
  rarity: 'R',
  title: '피카츄',
  description: '깨끗합니다.',
  price: 10000,
);
const formInput = ProductFormInput(
  regulation: 'SV',
  packType: 'pack',
  element: 'card',
  setNumber: '001',
  rarity: 'R',
  title: '피카츄',
  description: '깨끗합니다.',
  price: '10000',
);
final photo = ProductPhoto(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP8z4AATAxEcQAz0QEHOoQ+uAAAAABJRU5ErkJggg==',
  ),
  filename: 'phone.png',
);

class FakePicker extends ProductPhotoPicker {
  ProductPhoto? selected = photo;
  Object? failure;
  @override
  Future<ProductPhoto?> pick() async {
    if (failure != null) throw failure!;
    return selected;
  }

  @override
  Future<ProductPhoto?> recover() async => null;
}

ProductPublishRepository publisher(
  FutureOr<http.Response> Function(http.Request) handler,
) => ProductPublishRepository(
  ProductPublishApiService(
    MockClient((r) async => await handler(r)),
    baseUrl: 'http://test.local',
  ),
);

void main() {
  testWidgets(
    'photo plugin errors appear beside upload, without claiming permission denial',
    (tester) async {
      final picker = FakePicker()
        ..failure = MissingPluginException('not registered');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [productPhotoPickerProvider.overrideWithValue(picker)],
          child: const MaterialApp(home: ProductCreateView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('사진 업로드'), findsOneWidget);
      await tester.tap(find.byKey(const Key('selectProductPhoto')));
      await tester.pumpAndSettle();
      final message = find.byKey(const Key('photoError'));
      expect(message, findsOneWidget);
      expect(tester.getTopLeft(message).dy, lessThan(600));
      expect(find.textContaining('사진 접근 권한을 확인해주세요'), findsNothing);
      expect(find.textContaining('카탈로그 선택 화면'), findsNothing);
      picker.failure = PlatformException(code: 'photo_access_denied');
      await tester.tap(find.byKey(const Key('selectProductPhoto')));
      await tester.pumpAndSettle();
      expect(find.textContaining('사진 접근이 허용되지 않았습니다.'), findsOneWidget);
    },
  );

  test('photo multipart and create JSON share authenticated token; grade and owner are server defaults', () async {
    final repo = publisher((request) {
      expect(request.headers['Authorization'], 'Bearer test-token');
      if (request.url.path == '/sell_product/image') {
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(
          utf8.decode(request.bodyBytes, allowMalformed: true),
          contains('name="file"'),
        );
        return auth.response({
          'sell_product_image': '/media/products/photo.png',
        }, 201);
      }
      expect(request.url.path, '/sell_product');
      final body = jsonDecode(request.body) as Map;
      expect(body, draft.toJson('/media/products/photo.png'));
      expect(body.containsKey('sell_product_grade'), isFalse);
      expect(body.containsKey('user_user_id'), isFalse);
      return auth.response(products.productJson(), 201);
    });
    final url = await repo.uploadPhoto(photo, 'test-token');
    expect((await repo.create(draft, url, 'test-token')).code, 'P-1');
  });

  test('upload rejects empty and oversized files before request', () async {
    final repo = publisher((_) => throw StateError('must not call'));
    for (final bytes in [Uint8List(0), Uint8List(5 * 1024 * 1024 + 1)]) {
      await expectLater(
        repo.uploadPhoto(
          ProductPhoto(bytes: bytes, filename: 'photo.png'),
          'token',
        ),
        throwsA(isA<ProductException>()),
      );
    }
  });

  test(
    'vm blocks double submit and reuses uploaded photo after catalog error',
    () async {
      var uploads = 0, creates = 0;
      final waiting = Completer<http.Response>();
      final publish = publisher((r) {
        if (r.url.path == '/sell_product/image') {
          uploads++;
          return auth.response({
            'sell_product_image': '/media/products/photo.png',
          }, 201);
        }
        creates++;
        return creates == 1
            ? waiting.future
            : auth.response(products.productJson(), 201);
      });
      final session = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      await session.login('tester', 'pw', remember: false);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(session),
          wishlistRepositoryProvider.overrideWithValue(
            MemoryWishlistRepository(),
          ),
          productPublishRepositoryProvider.overrideWithValue(publish),
          productPhotoPickerProvider.overrideWithValue(FakePicker()),
        ],
      );
      final subscription = container.listen(productCreateVmProvider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      final vm = container.read(productCreateVmProvider.notifier);
      expect(await vm.submit(formInput), isNull);
      expect(
        container.read(productCreateVmProvider).photoError,
        contains('사진'),
      );
      await vm.pickPhoto();
      final first = vm.submit(formInput);
      expect(await vm.submit(formInput), isNull);
      await Future<void>.delayed(Duration.zero);
      waiting.complete(auth.response({'detail': '카탈로그에 존재하지 않는 상품입니다.'}, 404));
      expect(await first, isNull);
      expect(container.read(productCreateVmProvider).error, contains('카탈로그'));
      expect((await vm.submit(formInput))?.code, 'P-1');
      expect(uploads, 1);
      expect(creates, 2);
    },
  );

  testWidgets(
    'register tab uploads one photo then creates product and refreshes sale-only home',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var created = false, uploads = 0, creates = 0;
      final session = auth.repository(
        auth.MemoryStorage(),
        (_) => auth.response(auth.loginResponse()),
      );
      final publish = publisher((r) {
        if (r.url.path == '/sell_product/image') {
          uploads++;
          return auth.response({
            'sell_product_image': '/media/products/photo.png',
          }, 201);
        }
        creates++;
        created = true;
        return auth.response(products.productJson(), 201);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(session),
            wishlistRepositoryProvider.overrideWithValue(
              MemoryWishlistRepository(),
            ),
            productPublishRepositoryProvider.overrideWithValue(publish),
            productPhotoPickerProvider.overrideWithValue(FakePicker()),
            productRepositoryProvider.overrideWithValue(
              products.repository(
                (_) => auth.response(created ? [products.productJson()] : []),
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
      await tester.tap(find.text('등록'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('selectProductPhoto')));
      await tester.pumpAndSettle();
      final values = {
        'title': '피카츄',
        'regulation': 'SV',
        'packType': 'pack',
        'element': 'card',
        'setNumber': '001',
        'rarity': 'R',
        'description': '깨끗합니다.',
        'price': '10000',
      };
      for (final entry in values.entries) {
        final field = find.byKey(Key('product-${entry.key}'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, entry.value);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(const Key('submitProduct')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitProduct')));
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(creates, 1);
      expect(find.text('상품이 등록되었습니다.'), findsOneWidget);
      expect(find.text('피카츄 카드'), findsOneWidget);
    },
  );
}
