import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/repository/inspection/return_repository.dart';
import 'package:pokem_app/service/inspection/return_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/return_vm.dart';
import 'package:pokem_app/view/inspection/return_view.dart';

import 'auth_test.dart' as auth;

Map<String, Object?> record(int n) => {
  'return_no': 'RET$n',
  'inspect_inspect_code': 'INS$n',
  'manager_manager_id': n == 1 ? 'M' : null,
};
void main() {
  Future<ProviderContainer> start(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final repo = ReturnRepository(
      ReturnApiService(MockClient(handler), baseUrl: 'http://test.local'),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        returnRepositoryProvider.overrideWithValue(repo),
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

  test(
    'return query sends optional inspect filter with authentication',
    () async {
      final api = ReturnApiService(
        MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.path, '/return');
          expect(r.headers['Authorization'], 'Bearer token');
          expect(r.url.queryParameters, {
            'inspect_code': 'INS1',
            'limit': '20',
            'offset': '20',
          });
          return auth.response([record(1)]);
        }),
        baseUrl: 'http://test.local',
      );
      expect(
        (await api.getReturns(
          'token',
          inspectCode: 'INS1',
          offset: 20,
        )).single.number,
        'RET1',
      );
      final bad = ReturnApiService(
        MockClient((_) async => auth.response([record(2)])),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        bad.getReturns('token', inspectCode: 'INS1'),
        throwsA(isA<InspectionException>()),
      );
    },
  );
  test(
    'return pages preserve records on failure and retry the same offset',
    () async {
      var fail = true;
      final offsets = <String>[];
      final c = await start((r) async {
        final offset = r.url.queryParameters['offset']!;
        offsets.add(offset);
        expect(r.url.queryParameters.containsKey('inspect_code'), isFalse);
        if (offset == '0') return auth.response(List.generate(20, record));
        if (fail) return auth.response({}, 500);
        return auth.response([record(20)]);
      });
      final provider = returnVmProvider(null);
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      expect((await c.read(provider.future)).items.length, 20);
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).asData!.value.items.length, 20);
      fail = false;
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).asData!.value.items.length, 21);
      expect(c.read(provider).asData!.value.hasMore, isFalse);
      expect(offsets, ['0', '20', '20']);
    },
  );
  test('401 clears current login', () async {
    final c = await start((_) async => auth.response({}, 401));
    final provider = returnVmProvider(null);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets(
    'small screen shows return numbers and actual manager assignment only',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = (await tester.runAsync(
        () => start((_) async => auth.response([record(0), record(1)])),
      ))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: ReturnView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('반환번호 RET0'), findsOneWidget);
      expect(find.text('담당자 배정 전'), findsOneWidget);
      expect(find.text('담당자 배정됨'), findsOneWidget);
      expect(find.text('배송완료'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty return list is visible', (tester) async {
    final c = (await tester.runAsync(
      () => start((_) async => auth.response([])),
    ))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: ReturnView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('등록된 반환내역이 없습니다.'), findsOneWidget);
  });
}
