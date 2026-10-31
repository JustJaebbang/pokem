import 'package:pokem_app/model/inspection/inspection_result.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/repository/inspection/inspection_repository.dart';
import 'package:pokem_app/service/inspection/inspection_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/inspection_create_vm.dart';
import 'package:pokem_app/view/inspection/inspection_history_view.dart';

import 'auth_test.dart' as auth;

const request = InspectionRequest(
  number: '20261030000001',
  amount: 2,
  date: '2026-10-30 12:34:00',
);

class FakeInspectionRepository implements InspectionRepository {
  @override
  Future<List<InspectionResult>> results(String number, String token) async =>
      [];
  @override
  Future<InspectionResult> result(String code, String token) async =>
      throw UnimplementedError();
  @override
  Future<InspectionResult> choose(
    String code,
    InspectionChoice choice,
    String token,
  ) async => throw UnimplementedError();
  int creates = 0;
  Object? error;
  Completer<InspectionRequest>? pending;
  final requests = <InspectionRequest>[];
  @override
  Future<List<InspectionRequest>> history(String token) async => requests;
  @override
  Future<InspectionRequest> create(int amount, String token) async {
    creates++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    requests.add(request);
    return request;
  }
}

void main() {
  Future<ProviderContainer> start(FakeInspectionRepository repo) async {
    final session = auth.repository(
      auth.MemoryStorage(),
      (_) => auth.response(auth.loginResponse()),
    );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(session),
        inspectionRepositoryProvider.overrideWithValue(repo),
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
    'create sends count only and history uses same authenticated endpoint',
    () async {
      final json = {
        'inspection_request_no': request.number,
        'inspection_request_amount': 2,
        'inspection_request_date': request.date,
        'manager_manager_id': null,
      };
      final api = InspectionApiService(
        MockClient((r) async {
          expect(r.url.path, '/inspection_request');
          expect(r.headers['Authorization'], 'Bearer token');
          if (r.method == 'POST') {
            expect(jsonDecode(r.body), {'inspection_request_amount': 2});
            return auth.response(json, 201);
          }
          return auth.response([json]);
        }),
        baseUrl: 'http://test.local',
      );
      expect((await api.create(2, 'token')).number, request.number);
      expect((await api.history('token')).single.managerId, isNull);
      expect(request.zonedDate, '2026-10-30T12:34:00+09:00');
    },
  );
  test(
    'invalid count never reaches API and duplicate submissions are blocked',
    () async {
      final repo = FakeInspectionRepository()
        ..pending = Completer<InspectionRequest>();
      final c = await start(repo);
      final vm = c.read(inspectionCreateVmProvider.notifier);
      for (final count in ['', '0', '-1', '1.5', '214749', '2147483648']) {
        await vm.submit(count);
      }
      expect(repo.creates, 0);
      final first = vm.submit('2');
      await vm.submit('2');
      expect(repo.creates, 1);
      repo.pending!.complete(request);
      await first;
      await vm.submit('2');
      expect(repo.creates, 1);
      expect(
        c.read(inspectionCreateVmProvider).request?.number,
        request.number,
      );
    },
  );
  test(
    'ambiguous create stays blocked after view subscription closes',
    () async {
      final repo = FakeInspectionRepository()
        ..error = const InspectionException('lost', uncertain: true);
      final c = await start(repo);
      final sub = c.listen(inspectionCreateVmProvider, (_, _) {});
      final vm = c.read(inspectionCreateVmProvider.notifier);
      await vm.submit('2');
      sub.close();
      vm.newRequest();
      await vm.submit('2');
      expect(repo.creates, 1);
      expect(c.read(inspectionCreateVmProvider).uncertain, isTrue);
    },
  );
  test('401 clears session and late create is ignored after logout', () async {
    final repo = FakeInspectionRepository()
      ..error = const InspectionException('expired', status: 401);
    final c = await start(repo);
    await c.read(inspectionCreateVmProvider.notifier).submit('2');
    expect(c.read(loginVmProvider).session, isNull);
    final lateRepo = FakeInspectionRepository()
      ..pending = Completer<InspectionRequest>();
    final late = await start(lateRepo);
    final pending = late.read(inspectionCreateVmProvider.notifier).submit('2');
    await late.read(loginVmProvider.notifier).logout();
    lateRepo.pending!.complete(request);
    await pending;
    expect(late.read(inspectionCreateVmProvider).request, isNull);
  });
  test(
    'malformed successful response and network loss are ambiguous',
    () async {
      for (final handler in <Future<http.Response> Function(http.Request)>[
        (_) async => auth.response({}),
        (_) async => throw http.ClientException('offline'),
      ]) {
        final api = InspectionApiService(
          MockClient(handler),
          baseUrl: 'http://test.local',
        );
        await expectLater(
          api.create(2, 'token'),
          throwsA(
            isA<InspectionException>().having(
              (e) => e.uncertain,
              'uncertain',
              true,
            ),
          ),
        );
      }
    },
  );
  testWidgets('small screen request flow shows receipt and updated history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeInspectionRepository();
    final c = (await tester.runAsync(() => start(repo)))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: InspectionHistoryView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('검수신청 내역이 없습니다.'), findsOneWidget);
    await tester.tap(find.text('신청하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.pumpAndSettle();
    expect(find.text('총 검수비 20,000원'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '신청하기'));
    await tester.pumpAndSettle();
    expect(find.text('검수신청이 접수되었습니다.'), findsOneWidget);
    expect(repo.creates, 1);
    await tester.tap(find.text('신청내역 보기'));
    await tester.pumpAndSettle();
    expect(find.text('2장'), findsOneWidget);
    expect(find.text('담당자 배정 전'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
