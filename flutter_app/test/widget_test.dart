import 'support/wishlist_fixture.dart';

import 'package:pokem_app/core/providers/data_providers.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/repository/auth/auth_repository.dart';
import 'package:http/http.dart' as http;

import 'auth_test.dart' as fixtures;
import 'product_test.dart' as products;

void main() {
  Future<void> showLogin(WidgetTester tester, AuthRepository repo) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          wishlistRepositoryProvider.overrideWithValue(
            MemoryWishlistRepository(),
          ),
          productRepositoryProvider.overrideWithValue(
            products.repository((_) => fixtures.response([])),
          ),
        ],
        child: const PokemApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty fields show validation without sending credentials', (
    tester,
  ) async {
    var requests = 0;
    final repo = fixtures.repository(fixtures.MemoryStorage(), (_) {
      requests++;
      return fixtures.response(fixtures.loginResponse());
    });
    await showLogin(tester, repo);
    await tester.ensureVisible(find.byKey(const Key('loginSubmit')));
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('아이디를 입력해주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해주세요.'), findsOneWidget);
    expect(requests, 0);
  });

  testWidgets(
    'successful login displays verified role then logout returns to form',
    (tester) async {
      final repo = fixtures.repository(
        fixtures.MemoryStorage(),
        (_) => fixtures.response(fixtures.loginResponse()),
      );
      await showLogin(tester, repo);
      await tester.enterText(find.byKey(const Key('loginId')), 'tester');
      await tester.enterText(find.byKey(const Key('loginPassword')), 'pw');
      await tester.ensureVisible(find.byKey(const Key('loginSubmit')));
      await tester.tap(find.byKey(const Key('loginSubmit')));
      await tester.pumpAndSettle();
      expect(find.text('카드수집가님, 반가워요.'), findsOneWidget);
      await tester.tap(find.text('나'));
      await tester.pumpAndSettle();
      expect(find.text('일반 사용자 · tester'), findsOneWidget);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loginId')), findsOneWidget);
    },
  );

  testWidgets('server rejection stays on login and shows message', (
    tester,
  ) async {
    final repo = fixtures.repository(
      fixtures.MemoryStorage(),
      (_) => fixtures.response({'detail': '비밀번호가 일치하지 않습니다.'}, 401),
    );
    await showLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('loginId')), 'tester');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'wrong');
    await tester.ensureVisible(find.byKey(const Key('loginSubmit')));
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);
    expect(find.byKey(const Key('loginId')), findsOneWidget);
  });

  testWidgets('loading disables login and expires to reauthentication', (
    tester,
  ) async {
    final completer = Completer<http.Response>();
    final repo = fixtures.repository(
      fixtures.MemoryStorage(),
      (_) => completer.future,
    );
    await showLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('loginId')), 'tester');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'pw');
    await tester.ensureVisible(find.byKey(const Key('loginSubmit')));
    await tester.tap(find.byKey(const Key('loginSubmit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('loginSubmit')))
          .onPressed,
      isNull,
    );
    completer.complete(fixtures.response(fixtures.loginResponse(expiresIn: 1)));
    await tester.pumpAndSettle();
    expect(find.text('카드수집가님, 반가워요.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('로그인이 만료되었습니다. 다시 로그인해주세요.'), findsOneWidget);
  });

  testWidgets('small screen and keyboard stay scrollable', (tester) async {
    final repo = fixtures.repository(
      fixtures.MemoryStorage(),
      (_) => fixtures.response(fixtures.loginResponse()),
    );
    await showLogin(tester, repo);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('loginPassword')));
    await tester.enterText(find.byKey(const Key('loginPassword')), 'pw');
    await tester.ensureVisible(find.byKey(const Key('loginSubmit')));
    expect(tester.takeException(), isNull);
  });
}
