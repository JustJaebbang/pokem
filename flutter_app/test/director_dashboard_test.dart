import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/app.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/repository/director/director_repository.dart';
import 'package:pokem_app/service/director/director_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/director/director_dashboard_vm.dart';

import 'auth_test.dart' as fixtures;

class DirectorLogin extends LoginVm {
  @override
  LoginState build() => LoginState(
    session: AuthSession(
      token: 'director-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      account: const AuthAccount(
        id: 'director1',
        name: '총괄책임자',
        role: AccountRole.director,
      ),
    ),
  );
}

Map<String, Object?> proposal(String status) => {
  'proposal_no': '20261101000001',
  'proposal_name': '재고 발주',
  'proposal_contents': '케이스 재고를 보충합니다.',
  'proposal_date': '2026-11-01 10:00:00',
  'proposal_status': status,
  'case_case_code': 'CASE1',
  'manager_manager_id': 'manager1',
  'director_director_id': status == '대기' ? null : 'director1',
};

Map<String, Object?> dashboard(String status) => {
  'metrics': {
    'users': 7,
    'managers': 2,
    'unassigned_requests': 1,
    'inspections_in_progress': 2,
    'completed_inspections': 5,
    'active_consignments': 3,
    'pending_proposals': status == '대기' ? 1 : 0,
    'orders': 3,
    'deliveries_in_progress': 2,
    'returns_in_progress': 1,
    'payments': 4,
    'refunds': 2,
    'case_stock': 10,
  },
  'proposals': [proposal(status)],
  'managers': [
    {
      'manager_id': 'manager1',
      'manager_name': '담당자',
      'manager_phone': '010-0000-0000',
      'manager_email': 'manager@example.com',
      'manager_dept': '검수팀',
    },
  ],
  'cases': [
    {
      'case_code': 'CASE1',
      'case_serial_no': 'SERIAL1',
      'case_price': 1000,
      'case_stock': 10,
    },
  ],
};

DirectorRepository repository() {
  var status = '대기';
  return DirectorRepository(
    DirectorApiService(
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer director-token');
        if (request.method == 'PATCH') {
          expect(request.url.path, '/proposal/20261101000001/review');
          status =
              (jsonDecode(request.body) as Map)['proposal_status'] as String;
          return fixtures.response(proposal(status));
        }
        expect(request.url.path, '/director/dashboard');
        return fixtures.response(dashboard(status));
      }),
      baseUrl: 'http://test.local',
    ),
  );
}

void main() {
  test('director loads dashboard and reviews a pending proposal', () async {
    final container = ProviderContainer(
      overrides: [
        loginVmProvider.overrideWith(DirectorLogin.new),
        directorRepositoryProvider.overrideWithValue(repository()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      directorDashboardVmProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    final vm = container.read(directorDashboardVmProvider.notifier);
    expect(
      container
          .read(directorDashboardVmProvider)
          .data!
          .metrics
          .pendingProposals,
      1,
    );
    expect(await vm.review('20261101000001', '승인'), isTrue);
    expect(
      container.read(directorDashboardVmProvider).data!.proposals.single.status,
      '승인',
    );
  });

  for (final size in [
    const Size(1280, 800),
    const Size(768, 1024),
    const Size(600, 960),
  ]) {
    testWidgets('director login opens responsive dashboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginVmProvider.overrideWith(DirectorLogin.new),
            directorRepositoryProvider.overrideWithValue(repository()),
          ],
          child: const PokemApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('총괄 대시보드'), findsOneWidget);
      expect(find.text('결재 대기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
