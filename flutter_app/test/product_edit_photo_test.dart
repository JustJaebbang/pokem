import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_draft.dart';
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/repository/products/product_publish_repository.dart';
import 'package:pokem_app/service/products/product_photo_picker.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/product_edit_vm.dart';
import 'package:pokem_app/view/products/product_edit_view.dart';

import 'auth_test.dart' as auth;
import 'product_edit_test.dart' as edit;
import 'product_create_test.dart' as create;

class Uploader implements ProductPublishRepository {
  int uploads = 0;
  Object? error;
  Completer<String>? pending;
  @override
  Future<String> uploadPhoto(ProductPhoto photo, String token) async {
    uploads++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return '/media/products/new$uploads.png';
  }

  @override
  Future<Product> create(ProductDraft draft, String url, String token) async =>
      throw UnimplementedError();
}

class WaitingPicker extends create.FakePicker {
  final waiting = Completer<ProductPhoto?>();
  @override
  Future<ProductPhoto?> pick() => waiting.future;
}

void main() {
  Future<ProviderContainer> start(
    edit.FakeEditRepository repo,
    ProductPhotoPicker picker,
    Uploader uploader,
  ) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        productEditRepositoryProvider.overrideWithValue(repo),
        productPhotoPickerProvider.overrideWithValue(picker),
        productPublishRepositoryProvider.overrideWithValue(uploader),
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

  test(
    'new photo uploads on save and updated image path reaches PUT',
    () async {
      final repo = edit.FakeEditRepository();
      final picker = create.FakePicker();
      final uploader = Uploader();
      final c = await start(repo, picker, uploader);
      final vm = c.read(productEditVmProvider('P1').notifier);
      await vm.pickPhoto();
      expect(uploader.uploads, 0);
      expect(await vm.save(edit.input), isTrue);
      expect(uploader.uploads, 1);
      expect(repo.draft?.image, '/media/products/new1.png');
    },
  );
  test(
    'cancelled selection keeps preview and uploaded URL for retry',
    () async {
      final repo = edit.FakeEditRepository()
        ..error = const ProductException('save failure');
      final picker = create.FakePicker();
      final uploader = Uploader();
      final c = await start(repo, picker, uploader);
      final provider = productEditVmProvider('P1');
      final vm = c.read(provider.notifier);
      await vm.pickPhoto();
      expect(await vm.save(edit.input), isFalse);
      picker.selected = null;
      await vm.pickPhoto();
      expect(c.read(provider).photo, create.photo);
      expect(c.read(provider).uploadedUrl, '/media/products/new1.png');
      repo.error = null;
      expect(await vm.save(edit.input), isTrue);
      expect(uploader.uploads, 1);
    },
  );
  test(
    'replacement clears uploaded URL and original photo can be restored',
    () async {
      final repo = edit.FakeEditRepository()
        ..error = const ProductException('save failure');
      final picker = create.FakePicker();
      final uploader = Uploader();
      final c = await start(repo, picker, uploader);
      final provider = productEditVmProvider('P1');
      final vm = c.read(provider.notifier);
      await vm.pickPhoto();
      await vm.save(edit.input);
      picker.selected = ProductPhoto(
        bytes: create.photo.bytes,
        filename: 'replacement.png',
      );
      await vm.pickPhoto();
      expect(c.read(provider).uploadedUrl, isNull);
      await vm.save(edit.input);
      expect(uploader.uploads, 2);
      vm.useOriginalPhoto();
      expect(c.read(provider).photo, isNull);
      expect(c.read(provider).uploadedUrl, isNull);
      repo.error = null;
      await vm.save(edit.input);
      expect(repo.draft?.image, repo.current.image);
      expect(uploader.uploads, 2);
    },
  );
  test('failed upload does not update product and keeps selection', () async {
    final repo = edit.FakeEditRepository();
    final uploader = Uploader()
      ..error = const ProductException('upload failure');
    final c = await start(repo, create.FakePicker(), uploader);
    final provider = productEditVmProvider('P1');
    final vm = c.read(provider.notifier);
    await vm.pickPhoto();
    expect(await vm.save(edit.input), isFalse);
    expect(repo.writes, 0);
    expect(c.read(provider).photo, create.photo);
    expect(c.read(provider).saving, isFalse);
  });
  test('photo picker pending blocks save and overlapping selection', () async {
    final repo = edit.FakeEditRepository();
    final picker = WaitingPicker();
    final uploader = Uploader();
    final c = await start(repo, picker, uploader);
    final vm = c.read(productEditVmProvider('P1').notifier);
    final choosing = vm.pickPhoto();
    expect(await vm.save(edit.input), isFalse);
    await vm.pickPhoto();
    expect(uploader.uploads, 0);
    picker.waiting.complete(create.photo);
    await choosing;
    expect(c.read(productEditVmProvider('P1')).picking, isFalse);
  });
  test('logout during upload never sends product update afterwards', () async {
    final repo = edit.FakeEditRepository();
    final uploader = Uploader()..pending = Completer<String>();
    final c = await start(repo, create.FakePicker(), uploader);
    final vm = c.read(productEditVmProvider('P1').notifier);
    await vm.pickPhoto();
    final saving = vm.save(edit.input);
    await c.read(loginVmProvider.notifier).logout();
    uploader.pending!.complete('/media/products/late.png');
    expect(await saving, isFalse);
    expect(repo.writes, 0);
  });
  testWidgets(
    'edit photo opens picker shows inline errors and restores original',
    (tester) async {
      final picker = create.FakePicker()
        ..failure = MissingPluginException('not registered');
      final c = (await tester.runAsync(
        () => start(edit.FakeEditRepository(), picker, Uploader()),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: ProductEditView(code: 'P1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editProductPhoto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editPhotoError')), findsOneWidget);
      picker.failure = null;
      await tester.tap(find.byKey(const Key('editProductPhoto')));
      await tester.pumpAndSettle();
      expect(find.text('기존 사진 사용'), findsOneWidget);
      await tester.tap(find.text('기존 사진 사용'));
      await tester.pumpAndSettle();
      expect(c.read(productEditVmProvider('P1')).photo, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
