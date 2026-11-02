import 'dart:convert';
import 'dart:typed_data';

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
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/repository/products/product_publish_repository.dart';
import 'package:pokem_app/service/products/product_publish_api_service.dart';
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
final productRow = {
  'sell_product_code': 'SELL-001',
  'sell_product_serial_code': 'CARD-001',
  'sell_product_title': '판매 중인 카드',
  'sell_product_image': '',
  'sell_product_contents': '상품 설명',
  'sell_product_sell_price': 15000,
  'sell_product_grade': 'A',
  'sell_product_sell_status': '판매중',
  'seller_user_id': 'inspection-owner',
  'sale_type': 'consign',
};

void main() {
  test(
    'consignment photo is uploaded before the returned URL is registered',
    () async {
      Map<String, dynamic>? consignmentBody;
      var uploads = 0;
      final managerRepository = ManagerRepository(
        ManagerApiService(
          MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path == '/post_consign_item') {
              consignmentBody =
                  jsonDecode(request.body) as Map<String, dynamic>;
              return fixtures.response({});
            }
            return fixtures.response(switch (request.url.path) {
              '/inspect' => [
                {
                  'inspect_code': 'INS-CONSIGN-1',
                  'inspect_requested_no': '20261102000001',
                  'inspect_serial_code': 'J_m6a_001_103_C',
                  'inspect_status': '검수완료',
                  'inspect_user_choice': '대리판매',
                  'user_user_id': 'collector',
                  'manager_manager_id': 'manager1',
                },
              ],
              '/delivery_company' => [
                {
                  'delivery_company_code': 'D1',
                  'delivery_company_name': '배송업체',
                },
              ],
              _ => [],
            });
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final publishRepository = ProductPublishRepository(
        ProductPublishApiService(
          MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/sell_product/image');
            uploads++;
            return fixtures.response({
              'sell_product_image': '/media/products/manager-photo.jpg',
            }, 201);
          }),
          baseUrl: 'http://test.local',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          loginVmProvider.overrideWith(ManagerLogin.new),
          managerRepositoryProvider.overrideWithValue(managerRepository),
          productPublishRepositoryProvider.overrideWithValue(publishRepository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        managerDashboardVmProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      final success = await container
          .read(managerDashboardVmProvider.notifier)
          .createConsignmentWithPhoto(
            inspectionCode: 'INS-CONSIGN-1',
            title: '대리판매 카드',
            photo: ProductPhoto(
              bytes: Uint8List.fromList([1, 2, 3]),
              filename: 'card.jpg',
            ),
            contents: '상품 설명',
            price: '12000',
            returnCompanyCode: 'D1',
          );

      expect(success, isTrue);
      expect(uploads, 1);
      expect(
        consignmentBody?['sell_product_image'],
        '/media/products/manager-photo.jpg',
      );
      expect(consignmentBody?['inspect_inspect_code'], 'INS-CONSIGN-1');
    },
  );

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

  test('inspection result creation sends grade and reason together', () async {
    late Map<String, dynamic> body;
    final api = ManagerApiService(
      MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return fixtures.response({});
      }),
      baseUrl: 'http://test.local',
    );

    await api.createInspection(
      'token',
      '20261030000001',
      'CARD-001',
      grade: 'A',
      reason: '표면 상태 양호',
    );

    expect(body['inspect_requested_no'], '20261030000001');
    expect(body['inspect_serial_code'], 'CARD-001');
    expect(body['inspect_grade'], 'A');
    expect(body['inspect_grade_reason'], '표면 상태 양호');
  });

  test('manager business actions use the matching API contracts', () async {
    final calls = <String>[];
    final api = ManagerApiService(
      MockClient((request) async {
        calls.add('${request.method} ${request.url.path} ${request.body}');
        return fixtures.response({});
      }),
      baseUrl: 'http://test.local',
    );

    await api.approveInspectionRequest('token', '20261030000001');
    await api.createProposal('token', {
      'proposal_name': '재고 확보',
      'proposal_contents': '케이스 발주',
      'case_case_code': 'CASE1',
    });
    await api.createOrder('token', {
      'proposal_proposal_no': 'P1',
      'order_price': 10000,
      'order_amount': 2,
      'product_company_product_company_code': 'COMPANY1',
    });
    await api.createReceive('token', {
      'order_order_no': 'O1',
      'receive_price': 10000,
      'receive_amount': 2,
    });
    await api.createConsignment('token', {
      'inspect_inspect_code': 'INS1',
      'sell_product_title': '카드',
    });
    await api.assignReturn('token', 'R1');
    await api.createDelivery('token', {
      'return_no': 'R1',
      'delivery_company_delivery_company_code': 'D1',
    });
    await api.updateDeliveryStatus('token', 'D1', '배송중');
    await api.setConsignmentReturnCompany('token', 'C1', 'D1');
    await api.createReceipt('token', {
      'pay_pay_no': 'PAY1',
      'receipt_amount': 1,
      'sell_product_sell_product_code': 'SELL1',
    });
    await api.createRefund('token', 'PAY1');
    await api.createCase('token', {
      'case_serial_no': 'CASE-SERIAL',
      'case_price': 1000,
      'case_stock': 0,
    });
    await api.createProductCompany('token', {
      'product_company_code': 'P1',
      'product_company_name': '제조사',
    });
    await api.createDeliveryCompany('token', {
      'delivery_company_code': 'D1',
      'delivery_company_name': '배송사',
    });
    await api.createDiscard('token', 'SELL1');
    await api.updateCase('token', 'CASE1', {
      'case_price': 2000,
      'case_stock': 3,
    });
    await api.updateProductCompany('token', 'P1', '새 제조사명');
    await api.updateDeliveryCompany('token', 'D1', '새 배송사명');
    await api.cancelReceive('token', 'RECEIVE1');

    expect(
      calls[0],
      startsWith('PATCH /inspection_request/20261030000001/manager'),
    );
    expect(calls[1], contains('POST /proposal'));
    expect(calls[2], contains('POST /order'));
    expect(calls[3], contains('POST /receive'));
    expect(calls[4], contains('POST /post_consign_item'));
    expect(calls[2], contains('"order_amount":2'));
    expect(calls[5], startsWith('PATCH /return/R1/manager'));
    expect(calls[6], contains('POST /delivery'));
    expect(calls[7], contains('PATCH /delivery/D1/status'));
    expect(calls[8], contains('PATCH /post_consign_item/C1/return-company'));
    expect(calls[9], contains('POST /receipt'));
    expect(calls[10], contains('POST /deposit_refund'));
    expect(calls[11], contains('POST /case'));
    expect(calls[12], contains('POST /product_company'));
    expect(calls[13], contains('POST /delivery_company'));
    expect(calls[14], contains('POST /discard'));
    expect(calls[15], contains('PATCH /case/CASE1'));
    expect(calls[16], contains('PATCH /product_company/P1'));
    expect(calls[17], contains('PATCH /delivery_company/D1'));
    expect(calls[18], contains('DELETE /receive/RECEIVE1'));
  });

  testWidgets('consignment form selects a photo instead of entering an URL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ManagerRepository(
      ManagerApiService(
        MockClient(
          (request) async => fixtures.response(switch (request.url.path) {
            '/inspect' => [
              {
                'inspect_code': 'INS-CONSIGN-1',
                'inspect_requested_no': '20261102000001',
                'inspect_serial_code': 'J_m6a_001_103_C',
                'inspect_status': '검수완료',
                'inspect_user_choice': '대리판매',
                'user_user_id': 'collector',
                'manager_manager_id': 'manager1',
              },
            ],
            '/delivery_company' => [
              {'delivery_company_code': 'D1', 'delivery_company_name': '배송업체'},
            ],
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

    await tester.tap(find.text('대리판매').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('대리판매 작성'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('selectConsignmentPhoto')), findsOneWidget);
    expect(find.text('상품 사진 선택'), findsOneWidget);
    expect(find.text('상품 이미지 URL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selling products tab is between dashboard and requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ManagerRepository(
      ManagerApiService(
        MockClient((request) async {
          if (request.url.path == '/sell_product') {
            expect(request.url.queryParameters['status'], '판매중');
            expect(request.url.queryParameters['sort'], 'newest');
            return fixtures.response([productRow]);
          }
          return fixtures.response([]);
        }),
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

    final dashboardTop = tester.getTopLeft(find.text('통합')).dy;
    final productsTop = tester.getTopLeft(find.text('판매상품')).dy;
    final requestsTop = tester.getTopLeft(find.text('검수신청')).dy;
    expect(productsTop, greaterThan(dashboardTop));
    expect(productsTop, lessThan(requestsTop));

    await tester.tap(find.text('판매상품'));
    await tester.pumpAndSettle();
    expect(find.text('판매 중 상품'), findsOneWidget);
    expect(find.text('판매 중인 카드'), findsOneWidget);
    await tester.tap(find.text('판매 중인 카드'));
    await tester.pumpAndSettle();
    expect(find.text('판매상품 상세'), findsOneWidget);
    expect(find.text('15000원'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('inspection-owner'),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('managerDetail')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('inspection-owner'), findsOneWidget);
    expect(find.text('대리판매'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager menus scroll when destinations exceed the viewport', (
    tester,
  ) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final repository = ManagerRepository(
        ManagerApiService(
          MockClient((_) async => fixtures.response([])),
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
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(const Size(800, 420));
    final vertical = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('managerNavigationScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(vertical.position.maxScrollExtent, greaterThan(0));

    await pumpAt(const Size(600, 960));
    final horizontal = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('managerBottomNavigationScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
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
      expect(find.text('통합 대시보드'), findsOneWidget);
      await tester.tap(find.text('검수신청 접수'));
      await tester.pumpAndSettle();
      expect(find.text('검수신청 작성'), findsOneWidget);
      await tester.tap(find.text('20261030000001'));
      await tester.pumpAndSettle();
      expect(find.text('검수신청 상세'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('신청 승인·담당 배정'),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('managerDetail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('신청 승인·담당 배정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
