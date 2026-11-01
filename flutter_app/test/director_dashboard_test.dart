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
    'withdrawn_users': 1,
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
  'withdrawals': [
    {
      'user_id': 'retired-user',
      'user_nickname': '탈퇴사용자',
      'quit_date': '2026-11-01T12:00:00+09:00',
      'quit_type': '서비스 불만',
      'quit_reason': '응답이 느립니다.',
    },
  ],
  'statistics': {
    'pipeline': {
      'unassigned_requests': 1,
      'waiting': 2,
      'in_progress': 1,
      'completed': 5,
    },
    'manager_inspections': [
      {
        'manager_id': 'manager1',
        'manager_name': '담당자',
        'total': 8,
        'completed': 5,
        'active': 3,
      },
    ],
    'low_stock_cases': [
      {'case_code': 'CASE1', 'case_stock': 3, 'threshold': 10},
    ],
    'outstanding_orders': [
      {
        'order_no': 'ORDER1',
        'order_date': '2026-11-01 09:00:00',
        'case_code': 'CASE1',
        'order_amount': 10,
        'received_amount': 4,
        'outstanding_amount': 6,
      },
    ],
    'delayed_deliveries': 2,
    'returns_without_delivery': 1,
    'quit_types': [
      {'quit_type': '서비스 불만', 'count': 1},
    ],
    'delayed_delivery_items': [
      {
        'delivery_no': 'DELIVERY1',
        'delivery_date': '2026-10-28 09:00:00',
        'delivery_status': '배송준비',
        'manager_id': 'manager1',
        'company_code': 'COMPANY1',
      },
    ],
    'return_without_delivery_items': [
      {
        'return_no': 'RETURN1',
        'return_status': '반환접수',
        'user_id': 'user1',
        'manager_id': 'manager1',
      },
    ],
  },
  'settings': {
    'low_stock_threshold': 10,
    'delivery_delay_days': 3,
    'inspection_unit_price': 10000,
    'updated_at': '2026-11-01 10:00:00',
  },
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
        if (request.url.path.startsWith('/director/statistics/')) {
          return fixtures.response({
            'kind': 'inspections',
            'total': 1,
            'limit': 20,
            'offset': 0,
            'items': [
              {'inspect_code': 'INS-1', 'inspect_status': '검수완료'},
            ],
          });
        }
        expect(request.url.path, '/director/dashboard');
        return fixtures.response(dashboard(status));
      }),
      baseUrl: 'http://test.local',
    ),
  );
}

void main() {
  test(
    'director reference-data API sends authenticated POST payloads',
    () async {
      final requests = <String>[];
      final api = DirectorApiService(
        MockClient((request) async {
          requests.add('${request.method} ${request.url.path} ${request.body}');
          return fixtures.response(jsonDecode(request.body) as Object);
        }),
        baseUrl: 'http://test.local',
      );
      await api.createReferenceData('director-token', '/case', {
        'case_serial_no': 'CASE-SERIAL',
        'case_stock': 0,
      });
      await api.createReferenceData('director-token', '/card_info', {
        'cardinfo_serial_code': 'J_m6a_010_103_C',
        'cardinfo_category': '카드',
        'cardinfo_brand': '포켓몬',
        'cardinfo_standard': '63 × 88 mm',
      });
      expect(requests[0], contains('POST /case'));
      expect(requests[1], contains('POST /card_info'));
    },
  );

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

  testWidgets('director can inspect withdrawal type and reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('종류: 서비스 불만'), findsOneWidget);
    expect(find.textContaining('사유: 응답이 느립니다.'), findsOneWidget);
  });

  testWidgets('analytics tab renders graphs and operational tables', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    await tester.tap(find.text('상세 통계'));
    await tester.pumpAndSettle();
    expect(find.text('검수 단계별 현황'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.text('매니저별 검수 상세'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('미입고 발주'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('미입고 발주'), findsOneWidget);
    expect(find.byType(DataTable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reference-data tab exposes four registration forms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
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

    await tester.tap(find.text('기준정보'));
    await tester.pumpAndSettle();
    expect(find.text('기준정보 등록'), findsOneWidget);
    expect(find.text('케이스'), findsOneWidget);
    expect(find.text('배송업체'), findsOneWidget);
    expect(find.text('제조업체'), findsOneWidget);
    expect(find.text('카드 카탈로그'), findsOneWidget);
    expect(find.text('새 데이터 등록'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
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
      expect(find.text('운영 위험 요약'), findsOneWidget);
      expect(find.text('상세 통계 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
