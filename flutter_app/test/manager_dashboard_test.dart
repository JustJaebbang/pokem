import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/repository/manager/manager_repository.dart';
import 'package:pokem_app/service/manager/manager_api_service.dart';
import 'package:pokem_app/vm/manager/manager_dashboard_vm.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

import 'auth_test.dart' as fixtures;

class ManagerLogin extends LoginVm {
  @override
  LoginState build() => LoginState(
    session: AuthSession(
      token: 'manager-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      account: const AuthAccount(
        id: 'manager1',
        name: '담당자',
        role: AccountRole.manager,
      ),
    ),
  );
}

final requestRow = {
  'inspection_request_no': '20261030000001',
  'user_user_id': 'collector',
  'inspection_request_amount': 2,
  'inspection_request_date': '2026-10-30 10:00:00',
};
Map<String, Object?> inspectionRow(String status) => {
  'inspect_code': 'INS_TEST-1',
  'inspect_requested_no': '20261030000001',
  'inspect_serial_code': 'TEST',
  'inspect_status': status,
  'user_user_id': 'collector',
};

void main() {
  test(
    'authenticated API load and inspection transitions follow server contract',
    () async {
      var status = '검수대기';
      var writes = 0;
      final repository = ManagerRepository(
        ManagerApiService(
          MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer manager-token');
            if (request.method == 'POST') {
              writes++;
              if (request.url.path.endsWith('/complete')) {
                expect(jsonDecode(request.body), {
                  'inspect_grade': 'A',
                  'inspect_grade_reason': '상태 양호',
                });
                status = '검수완료';
              } else {
                expect(request.url.path, '/inspect/INS_TEST-1/start');
                status = '검수중';
              }
              return fixtures.response(inspectionRow(status));
            }
            return fixtures.response(switch (request.url.path) {
              '/inspection_request' => [requestRow],
              '/inspect' => [inspectionRow(status)],
              _ => [],
            });
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          loginVmProvider.overrideWith(ManagerLogin.new),
          managerRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        managerDashboardVmProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      final vm = container.read(managerDashboardVmProvider.notifier);
      expect(
        container.read(managerDashboardVmProvider).data!.requests.single.amount,
        2,
      );
      expect(await vm.startInspection('INS_TEST-1'), isTrue);
      expect(
        container.read(managerDashboardVmProvider).data!.countStatus('검수중'),
        1,
      );
      expect(await vm.completeInspection('INS_TEST-1', ' ', ''), isFalse);
      expect(writes, 1);
      expect(
        await vm.completeInspection('INS_TEST-1', ' A ', ' 상태 양호 '),
        isTrue,
      );
      expect(
        container.read(managerDashboardVmProvider).data!.countStatus('검수완료'),
        1,
      );
    },
  );

  test('authorization failures preserve status and server detail', () async {
    final api = ManagerApiService(
      MockClient((_) async => fixtures.response({'detail': '권한 없음'}, 403)),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      api.list('token', '/inspect'),
      throwsA(
        isA<ManagerException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.message, 'message', '권한 없음'),
      ),
    );
  });

  for (final size in [
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(768, 1024),
    const Size(600, 960),
  ]) {
    testWidgets('manager dashboard supports $size and detail selection', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ManagerRepository(
        ManagerApiService(
          MockClient(
            (request) async => fixtures.response(switch (request.url.path) {
              '/inspection_request' => [requestRow],
              '/inspect' => [inspectionRow('검수대기')],
              _ => [],
            }),
          ),
          baseUrl: 'http://test.local',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginVmProvider.overrideWith(ManagerLogin.new),
            managerRepositoryProvider.overrideWithValue(repository),
          ],
          child: const PokemApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('운영 대시보드'), findsOneWidget);
      await tester.tap(find.text('20261030000001'));
      await tester.pumpAndSettle();
      expect(find.text('검수 신청 상세'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('검수 상품 등록'),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('managerDetail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('검수 상품 등록'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
