import 'package:pokem_app/model/auth/register_input.dart';
import 'package:pokem_app/core/providers/data_providers.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pokem_app/app.dart';
import 'package:pokem_app/model/auth/register_request.dart';
import 'package:pokem_app/repository/auth/auth_repository.dart';
import 'package:pokem_app/vm/auth/register_vm.dart';

import 'auth_test.dart' as fixtures;

const request = RegisterRequest(
  id: ' tester ',
  password: ' pw ',
  nickname: ' 수집가 ',
  name: ' 홍길동 ',
  phone: '01012345678',
  email: 'test@example.com',
  address: ' 서울시 상세주소 ',
);

const input = RegisterInput(
  id: 'tester',
  password: ' pw ',
  confirmation: ' pw ',
  nickname: '수집가',
  name: '홍길동',
  phone: '01012345678',
  email: 'test@example.com',
  address: '서울시 상세주소',
);

void main() {
  test('registration uses user contract and creates no session or stored credentials', () async {
    final storage = fixtures.MemoryStorage();
    final repo = fixtures.repository(storage, (req) {
      expect(req.method, 'POST');
      expect(req.url.path, '/user');
      expect(req.headers['Authorization'], isNull);
      final body = jsonDecode(req.body) as Map;
      expect(body, request.toJson());
      expect(body['user_password'], ' pw ');
      expect(body['user_id'], 'tester');
      expect(body.containsKey('password_confirm'), isFalse);
      expect(body.containsKey('user_money'), isFalse);
      return fixtures.response({'user_id': 'tester'}, 201);
    });
    expect(await repo.register(request), 'tester');
    expect(repo.session, isNull);
    expect(storage.value, isNull);
  });

  test('register vm blocks duplicate requests and allows retry after duplicate ID error', () async {
    final waiting = Completer<http.Response>();
    var calls = 0;
    final repo = fixtures.repository(fixtures.MemoryStorage(), (_) {
      calls++;
      return calls == 1
          ? waiting.future
          : fixtures.response({'user_id': 'tester'}, 201);
    });
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(registerVmProvider, (_, _) {});
    addTearDown(subscription.close);
    final vm = container.read(registerVmProvider.notifier);
    final first = vm.register(input);
    expect(await vm.register(input), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    waiting.complete(fixtures.response({'detail': '이미 사용 중인 아이디입니다.'}, 409));
    expect(await first, isNull);
    expect(container.read(registerVmProvider).error, '이미 사용 중인 아이디입니다.');
    expect(await vm.register(input), 'tester');
    expect(calls, 2);
  });

  Future<void> openRegistration(
    WidgetTester tester,
    AuthRepository repo,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const PokemApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('registerId')), findsOneWidget);
  }

  Future<void> fillRegistration(
    WidgetTester tester, {
    String confirm = 'test-password',
  }) async {
    final values = {
      'registerId': 'tester',
      'registerNickname': '수집가',
      'registerName': '홍길동',
      'registerPassword': 'test-password',
      'registerConfirm': confirm,
      'registerAddress': '서울시 상세주소',
      'registerPhone': '01012345678',
      'registerEmail': 'test@example.com',
    };
    for (final entry in values.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
  }

  testWidgets('successful registration returns to login with ID prefilled', (
    tester,
  ) async {
    var calls = 0;
    final repo = fixtures.repository(fixtures.MemoryStorage(), (_) {
      calls++;
      return fixtures.response({'user_id': 'tester'}, 201);
    });
    await openRegistration(tester, repo);
    await fillRegistration(tester);
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const Key('loginId')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('loginId')))
          .controller!
          .text,
      'tester',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('loginPassword')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('회원가입이 완료되었습니다. 로그인해주세요.'), findsOneWidget);
  });

  testWidgets('password mismatch makes no network request', (tester) async {
    var calls = 0;
    final repo = fixtures.repository(fixtures.MemoryStorage(), (_) {
      calls++;
      return fixtures.response({'user_id': 'tester'}, 201);
    });
    await openRegistration(tester, repo);
    await fillRegistration(tester, confirm: 'different');
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('duplicate ID is shown without losing form input', (
    tester,
  ) async {
    final repo = fixtures.repository(
      fixtures.MemoryStorage(),
      (_) => fixtures.response({'detail': '이미 사용 중인 아이디입니다.'}, 409),
    );
    await openRegistration(tester, repo);
    await fillRegistration(tester);
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 아이디입니다.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('registerId')))
          .controller!
          .text,
      'tester',
    );
    expect(find.byKey(const Key('registerSubmit')), findsOneWidget);
  });

  testWidgets('required fields, small screen and keyboard do not overflow', (
    tester,
  ) async {
    var calls = 0;
    final repo = fixtures.repository(fixtures.MemoryStorage(), (_) {
      calls++;
      return fixtures.response({'user_id': 'tester'}, 201);
    });
    await openRegistration(tester, repo);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('아이디를 입력해주세요.'), findsOneWidget);
    expect(find.text('이메일 형식을 확인해주세요.'), findsOneWidget);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
