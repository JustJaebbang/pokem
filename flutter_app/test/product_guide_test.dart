import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/card_info_guide.dart';
import 'package:pokem_app/view/products/product_create_view.dart';
import 'package:pokem_app/view/products/widgets/card_info_guide_sheet.dart';
import 'package:pokem_app/vm/products/product_guide_vm.dart';

import 'auth_test.dart' as auth;
import 'product_create_test.dart' as create;
import 'support/product_guide_fixture.dart';

void main() {
  test('guide preference is isolated by account and API server', () async {
    final storage = MemoryProductGuideStorage();
    final first = storage.repository(server: 'server-a');
    final other = storage.repository(server: 'server-b');
    await first.save('owner', true);
    expect(await first.hidden('owner'), isTrue);
    expect(await first.hidden('other'), isFalse);
    expect(await other.hidden('owner'), isFalse);
  });
  test('five examples follow API field order without changing sample leading zeros', () {
    expect(cardInfoGuideFields.map((f) => f.key), [
      'regulation',
      'packType',
      'element',
      'setNumber',
      'rarity',
    ]);
    expect(cardInfoGuideFields.map((f) => f.example), [
      'J',
      'M6a',
      '133',
      '103',
      'SAR',
    ]);
  });
  Future<void> mount(
    WidgetTester tester,
    MemoryProductGuideStorage storage,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            auth.repository(auth.MemoryStorage(), (_) => auth.response({})),
          ),
          productGuideRepositoryProvider.overrideWithValue(
            storage.repository(),
          ),
          productPhotoPickerProvider.overrideWithValue(create.FakePicker()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProductCreateView(),
                    ),
                  ),
                  child: const Text('상품 등록 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('상품 등록 열기'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first entry explains fields, opt-out survives reentry, manual help can restore it',
    (tester) async {
      final storage = MemoryProductGuideStorage();
      await mount(tester, storage);
      await open(tester);
      expect(find.byType(CardInfoGuideSheet), findsOneWidget);
      expect(find.text('카드 정보 입력 안내'), findsOneWidget);
      expect(find.text('카드 번호 (분자) · 133'), findsOneWidget);
      expect(find.text('세트 번호 (분모) · 103'), findsOneWidget);
      await tester.tap(find.text('카드 예시 확대해서 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 보지 않기'));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(storage.writes, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.byType(CardInfoGuideSheet), findsNothing);
      final title = find.byKey(const Key('product-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, '내 카드');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('카드 정보 입력 안내'));
      await tester.pumpAndSettle();
      expect(find.byType(CardInfoGuideSheet), findsOneWidget);
      await tester.tap(find.text('다시 보지 않기'));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(title).controller!.text, '내 카드');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.byType(CardInfoGuideSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unchecked confirmation shows again and failed preference save stays retryable',
    (tester) async {
      final storage = MemoryProductGuideStorage();
      await mount(tester, storage);
      await open(tester);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.byType(CardInfoGuideSheet), findsOneWidget);
      storage.failWrite = true;
      await tester.tap(find.text('다시 보지 않기'));
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('설정을 저장하지 못했습니다. 다시 시도해주세요.'), findsOneWidget);
      expect(find.byType(CardInfoGuideSheet), findsOneWidget);
      storage.failWrite = false;
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.byType(CardInfoGuideSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
