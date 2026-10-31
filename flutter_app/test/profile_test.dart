import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/repository/profile/profile_repository.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/profile/profile_vm.dart';
import 'package:pokem_app/view/profile/profile_view.dart';

import 'auth_test.dart' as auth;

Map<String, Object> profileJson({String address = '서울'}) => {
  'user_id': 'tester',
  'user_name': '이름',
  'user_nickname': '수집가',
  'user_phone': '01012345678',
  'user_email': 'test@example.com',
  'user_address': address,
};
ProfileRepository repository(
  FutureOr<http.Response> Function(http.Request) handler,
) => ProfileRepository(
  AuthApiService(
    MockClient((r) async => handler(r)),
    baseUrl: 'http://test.local',
  ),
);
const input = ProfileInput(
  phone: '01098765432',
  email: 'new@example.com',
  address: '부산',
);
void main() {
  Future<ProviderContainer> start(ProfileRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        profileRepositoryProvider.overrideWithValue(repo),
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

  test('profile update uses PUT and sends only editable fields', () async {
    final repo = repository((r) {
      expect(r.method, 'PUT');
      expect(r.url.path, '/user/tester');
      expect(r.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(r.body), {
        'user_phone': '01098765432',
        'user_email': 'new@example.com',
        'user_address': '부산',
      });
      return auth.response(profileJson(address: '부산'));
    });
    expect((await repo.update('tester', input, 'token')).address, '부산');
  });
  test(
    'invalid input never reaches update API and duplicate save is blocked',
    () async {
      var writes = 0;
      final pending = Completer<http.Response>();
      final c = await start(
        repository((r) {
          if (r.method == 'GET') return auth.response(profileJson());
          writes++;
          return pending.future;
        }),
      );
      final vm = c.read(profileVmProvider.notifier);
      expect(
        await vm.save(const ProfileInput(phone: '', email: '', address: '')),
        isFalse,
      );
      expect(writes, 0);
      final first = vm.save(input);
      await Future<void>.delayed(Duration.zero);
      expect(await vm.save(input), isFalse);
      expect(writes, 1);
      pending.complete(auth.response(profileJson(address: '부산')));
      expect(await first, isTrue);
      expect(c.read(profileVmProvider).profile?.address, '부산');
    },
  );
  test(
    '401 clears session and late save response after logout is ignored',
    () async {
      final c = await start(
        repository(
          (r) => auth.response(profileJson(), r.method == 'GET' ? 200 : 401),
        ),
      );
      expect(await c.read(profileVmProvider.notifier).save(input), isFalse);
      expect(c.read(loginVmProvider).session, isNull);
      final pending = Completer<http.Response>();
      final late = await start(
        repository(
          (r) =>
              r.method == 'GET' ? auth.response(profileJson()) : pending.future,
        ),
      );
      final save = late.read(profileVmProvider.notifier).save(input);
      await Future<void>.delayed(Duration.zero);
      await late.read(loginVmProvider.notifier).logout();
      pending.complete(auth.response(profileJson(address: '부산')));
      expect(await save, isFalse);
      expect(late.read(profileVmProvider).profile, isNull);
    },
  );
  testWidgets('small screen edit preserves input after save failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = (await tester.runAsync(
      () => start(
        repository(
          (r) => r.method == 'GET'
              ? auth.response(profileJson())
              : auth.response({'detail': '저장 실패'}, 500),
        ),
      ),
    ))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: ProfileView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('수집가'), findsOneWidget);
    final address = find.byKey(const Key('profileAddress'));
    await tester.ensureVisible(address);
    await tester.enterText(address, '부산');
    final button = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(address).controller!.text, '부산');
    expect(c.read(profileVmProvider).error, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
