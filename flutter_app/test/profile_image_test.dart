import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_draft.dart';
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/repository/products/product_publish_repository.dart';
import 'package:pokem_app/repository/profile/profile_repository.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/profile/profile_vm.dart';
import 'package:pokem_app/vm/profile/profile_summary_vm.dart';
import 'package:pokem_app/view/profile/profile_view.dart';

import 'auth_test.dart' as auth;
import 'profile_test.dart' as profile;
import 'product_create_test.dart' as create;

final uploaded = '/media/products/${'a' * 32}.jpg';

class Uploader implements ProductPublishRepository {
  int calls = 0;
  Object? error;
  Completer<String>? pending;
  @override
  Future<String> uploadPhoto(ProductPhoto photo, String token) async {
    calls++;
    if (error != null) throw error!;
    return pending?.future ?? uploaded;
  }

  @override
  Future<Product> create(ProductDraft draft, String url, String token) async =>
      throw UnimplementedError();
}

void main() {
  Future<ProviderContainer> start(
    ProfileRepository repository,
    create.FakePicker picker,
    Uploader uploader,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(repository),
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
    final sub = c.listen(profileVmProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test('photo selection only previews and save uploads once then updates profile and summary', () async {
    String? image;
    var puts = 0;
    final repository = profile.repository((r) {
      if (r.method == 'PUT') {
        puts++;
        image = (jsonDecode(r.body) as Map)['user_profile_image'] as String?;
      }
      return auth.response({
        ...profile.profileJson(),
        'user_profile_image': image,
      });
    });
    final uploader = Uploader();
    final c = await start(repository, create.FakePicker(), uploader);
    final summary = c.listen(profileSummaryVmProvider, (_, _) {});
    addTearDown(summary.close);
    await c.read(profileSummaryVmProvider.future);
    final vm = c.read(profileVmProvider.notifier);
    await vm.pickPhoto();
    expect(uploader.calls, 0);
    expect(c.read(profileVmProvider).photo, isNotNull);
    expect(await vm.save(profile.input), isTrue);
    expect(uploader.calls, 1);
    expect(puts, 1);
    expect(image, uploaded);
    expect((await c.read(profileSummaryVmProvider.future))!.imageUrl, uploaded);
  });
  test(
    'PUT failure preserves photo and uploaded URL for retry without reupload',
    () async {
      var fail = true;
      final urls = <dynamic>[];
      final repository = profile.repository((r) {
        if (r.method == 'PUT') {
          urls.add(jsonDecode(r.body)['user_profile_image']);
          if (fail) return auth.response({}, 500);
        }
        return auth.response({
          ...profile.profileJson(),
          'user_profile_image': r.method == 'GET' ? null : uploaded,
        });
      });
      final uploader = Uploader();
      final picker = create.FakePicker();
      final c = await start(repository, picker, uploader);
      final vm = c.read(profileVmProvider.notifier);
      await vm.pickPhoto();
      expect(await vm.save(profile.input), isFalse);
      expect(c.read(profileVmProvider).uploadedUrl, uploaded);
      picker.selected = null;
      await vm.pickPhoto();
      expect(c.read(profileVmProvider).photo, isNotNull);
      expect(c.read(profileVmProvider).uploadedUrl, uploaded);
      fail = false;
      expect(await vm.save(profile.input), isTrue);
      expect(uploader.calls, 1);
      expect(urls, [uploaded, uploaded]);
    },
  );
  test(
    'upload failure never changes profile and keeps selected photo',
    () async {
      var puts = 0;
      final repository = profile.repository((r) {
        if (r.method == 'PUT') puts++;
        return auth.response(profile.profileJson());
      });
      final uploader = Uploader()..error = const ProductException('업로드 실패');
      final c = await start(repository, create.FakePicker(), uploader);
      final vm = c.read(profileVmProvider.notifier);
      await vm.pickPhoto();
      expect(await vm.save(profile.input), isFalse);
      expect(puts, 0);
      expect(c.read(profileVmProvider).photo, isNotNull);
      expect(c.read(profileVmProvider).saving, isFalse);
    },
  );
  test('default photo uses explicit null without another upload', () async {
    Map? body;
    final repository = profile.repository((r) {
      if (r.method == 'PUT') body = jsonDecode(r.body) as Map;
      return auth.response({
        ...profile.profileJson(),
        'user_profile_image': r.method == 'GET' ? uploaded : null,
      });
    });
    final uploader = Uploader();
    final c = await start(repository, create.FakePicker(), uploader);
    final vm = c.read(profileVmProvider.notifier);
    vm.useDefaultPhoto();
    expect(await vm.save(profile.input), isTrue);
    expect(body!.containsKey('user_profile_image'), isTrue);
    expect(body!['user_profile_image'], isNull);
    expect(uploader.calls, 0);
  });
  test('logout during upload prevents profile PUT', () async {
    var puts = 0;
    final repository = profile.repository((r) {
      if (r.method == 'PUT') puts++;
      return auth.response(profile.profileJson());
    });
    final uploader = Uploader()..pending = Completer<String>();
    final c = await start(repository, create.FakePicker(), uploader);
    final vm = c.read(profileVmProvider.notifier);
    await vm.pickPhoto();
    final saving = vm.save(profile.input);
    await Future<void>.delayed(Duration.zero);
    await c.read(loginVmProvider.notifier).logout();
    uploader.pending!.complete(uploaded);
    expect(await saving, isFalse);
    expect(puts, 0);
  });
  test(
    'cancel photo edit preserves original without image field on save',
    () async {
      Map? body;
      final repository = profile.repository((r) {
        if (r.method == 'PUT') body = jsonDecode(r.body) as Map;
        return auth.response({
          ...profile.profileJson(),
          'user_profile_image': uploaded,
        });
      });
      final uploader = Uploader();
      final c = await start(repository, create.FakePicker(), uploader);
      final vm = c.read(profileVmProvider.notifier);
      await vm.pickPhoto();
      vm.cancelPhotoChange();
      expect(await vm.save(profile.input), isTrue);
      expect(body!.containsKey('user_profile_image'), isFalse);
      expect(uploader.calls, 0);
    },
  );
  testWidgets(
    'profile avatar opens picker and previews photo without uploading',
    (tester) async {
      final uploader = Uploader();
      final repository = profile.repository(
        (_) => auth.response(profile.profileJson()),
      );
      final c = (await tester.runAsync(
        () => start(repository, create.FakePicker(), uploader),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: ProfileView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profilePhoto')));
      await tester.pumpAndSettle();
      expect(c.read(profileVmProvider).photo, isNotNull);
      expect(uploader.calls, 0);
      expect(find.text('변경 취소'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
