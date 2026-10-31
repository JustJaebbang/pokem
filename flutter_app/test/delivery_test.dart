import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/model/delivery/delivery.dart';
import 'package:pokem_app/repository/delivery/delivery_repository.dart';
import 'package:pokem_app/service/delivery/delivery_api_service.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/delivery/delivery_vm.dart';
import 'package:pokem_app/view/delivery/delivery_view.dart';

import 'auth_test.dart' as auth;

Map<String, dynamic> row({
  String number = 'D1',
  String? purchase = 'P1',
  String? returnNo,
  String owner = 'tester',
}) => {
  'delivery_no': number,
  'purchase_item_code': purchase,
  'return_no': returnNo,
  'user_user_id': owner,
  'delivery_company_delivery_company_code': 'COMPANY1',
  'delivery_status': '배송준비',
  'delivery_date': '2026-10-31 12:00:00',
};
void main() {
  test(
    'find follows pages and fetches matching purchase detail with token',
    () async {
      final offsets = <String>[];
      final repo = DeliveryRepository(
        DeliveryApiService(
          MockClient((r) async {
            expect(r.headers['Authorization'], 'Bearer token');
            if (r.url.path == '/delivery/D1') return auth.response(row());
            expect(r.url.path, '/delivery');
            expect(r.url.queryParameters['limit'], '100');
            offsets.add(r.url.queryParameters['offset']!);
            return auth.response(
              offsets.length == 1
                  ? List.generate(
                      100,
                      (i) => row(number: 'OTHER$i', purchase: 'OTHER$i'),
                    )
                  : [row()],
            );
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final delivery = await repo.find(
        (purchaseCode: 'P1', returnNo: null),
        'tester',
        'token',
      );
      expect(delivery!.number, 'D1');
      expect(offsets, ['0', '100']);
    },
  );
  test(
    'return uses exact return number and empty final page means unregistered',
    () async {
      final repo = DeliveryRepository(
        DeliveryApiService(
          MockClient(
            (r) async => auth.response(
              r.url.path == '/delivery/D1'
                  ? row(purchase: null, returnNo: 'R1')
                  : [row(purchase: null, returnNo: 'R1')],
            ),
          ),
          baseUrl: 'http://test.local',
        ),
      );
      expect(
        (await repo.find(
          (purchaseCode: null, returnNo: 'R1'),
          'tester',
          'token',
        ))!.returnNo,
        'R1',
      );
      expect(
        await repo.find(
          (purchaseCode: 'P1', returnNo: null),
          'tester',
          'token',
        ),
        isNull,
      );
    },
  );
  test(
    'rejects mismatched detail and other owners instead of showing their data',
    () async {
      for (final otherOwner in [true, false]) {
        final repo = DeliveryRepository(
          DeliveryApiService(
            MockClient(
              (r) async => auth.response(
                r.url.path == '/delivery'
                    ? [row(owner: otherOwner ? 'other' : 'tester')]
                    : row(purchase: 'OTHER'),
              ),
            ),
            baseUrl: 'http://test.local',
          ),
        );
        await expectLater(
          repo.find((purchaseCode: 'P1', returnNo: null), 'tester', 'token'),
          throwsA(isA<DeliveryException>()),
        );
      }
    },
  );
  test('401 is preserved, malformed responses are errors', () async {
    for (final status in [401, 200]) {
      final api = DeliveryApiService(
        MockClient((_) async => auth.response({'detail': 'bad'}, status)),
        baseUrl: 'http://test.local',
      );
      await expectLater(
        api.list('token', 0),
        throwsA(
          isA<DeliveryException>().having(
            (e) => e.status,
            'status',
            status == 401 ? 401 : null,
          ),
        ),
      );
    }
  });
  Future<ProviderContainer> start(DeliveryRepository repo) async {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        deliveryRepositoryProvider.overrideWithValue(repo),
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

  test('VM logs out expired session on 401', () async {
    final c = await start(
      DeliveryRepository(
        DeliveryApiService(
          MockClient((_) async => auth.response({}, 401)),
          baseUrl: 'http://test.local',
        ),
      ),
    );
    final provider = deliveryVmProvider((purchaseCode: 'P1', returnNo: null));
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);
    try {
      await c.read(provider.future);
    } catch (_) {}
    expect(c.read(loginVmProvider).session, isNull);
  });
  testWidgets('screen shows internal delivery number and registration date', (
    tester,
  ) async {
    final repo = DeliveryRepository(
      DeliveryApiService(
        MockClient(
          (r) async =>
              auth.response(r.url.path == '/delivery' ? [row()] : row()),
        ),
        baseUrl: 'http://test.local',
      ),
    );
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: DeliveryView(source: (purchaseCode: 'P1', returnNo: null)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('배송준비'), findsOneWidget);
    expect(find.text('배송번호 D1'), findsOneWidget);
    expect(find.textContaining('배송 등록일'), findsOneWidget);
    expect(find.textContaining('운송장'), findsNothing);
  });
  testWidgets('unregistered delivery has empty message and refresh', (
    tester,
  ) async {
    var calls = 0;
    final repo = DeliveryRepository(
      DeliveryApiService(
        MockClient((_) async {
          calls++;
          return auth.response([]);
        }),
        baseUrl: 'http://test.local',
      ),
    );
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: DeliveryView(source: (purchaseCode: null, returnNo: 'R1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 등록된 배송 정보가 없습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('새로고침'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
