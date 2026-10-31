import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/model/inspection/inspection_result.dart';
import 'package:pokem_app/service/inspection/inspection_api_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/inspection_choice_vm.dart';
import 'package:pokem_app/view/inspection/inspection_results_view.dart';

import 'auth_test.dart' as auth;
import 'inspection_test.dart' as inspection;

InspectionResult item({String status = '검수완료', String? choice = '의사확인대기'}) =>
    InspectionResult(
      code: 'INS-1',
      requestNumber: '20261030000001',
      serialCode: 'SV-1',
      status: status,
      grade: 'A',
      choice: choice,
    );
Map<String, dynamic> jsonItem({String? choice = '의사확인대기'}) => {
  'inspect_code': 'INS-1',
  'inspect_requested_no': '20261030000001',
  'inspect_serial_code': 'SV-1',
  'inspect_status': '검수완료',
  'inspect_grade': 'A',
  'inspect_grade_reason': '표면 상태 양호',
  'inspect_user_choice': choice,
};

class ResultsRepository extends inspection.FakeInspectionRepository {
  InspectionResult current = item();
  int writes = 0;
  Completer<InspectionResult>? pendingChoice;
  @override
  Future<List<InspectionResult>> results(String number, String token) async => [
    current,
  ];
  @override
  Future<InspectionResult> result(String code, String token) async => current;
  @override
  Future<InspectionResult> choose(
    String code,
    InspectionChoice choice,
    String token,
  ) async {
    writes++;
    if (error != null) throw error!;
    if (pendingChoice != null) return pendingChoice!.future;
    current = item(choice: choice.label);
    return current;
  }
}

void main() {
  Future<ProviderContainer> start(ResultsRepository repo) async {
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

  test('result query filters request number and both choices use authenticated PUT', () async {
    final api = InspectionApiService(
      MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer token');
        if (r.method == 'GET') {
          expect(r.url.path, '/inspect');
          expect(r.url.queryParameters, {'request_no': '20261030000001'});
          return auth.response([jsonItem()]);
        }
        expect(r.method, 'PUT');
        expect(r.url.path, '/inspect/INS-1/choice');
        final body = jsonDecode(r.body) as Map;
        expect(body.keys, ['inspect_user_choice']);
        return auth.response(
          jsonItem(choice: body['inspect_user_choice'] as String),
        );
      }),
      baseUrl: 'http://test.local',
    );
    expect((await api.results('20261030000001', 'token')).single.grade, 'A');
    for (final choice in InspectionChoice.values) {
      expect((await api.choose('INS-1', choice, 'token')).choice, choice.label);
    }
  });
  test('non-complete and already chosen cards never send choice', () async {
    final repo = ResultsRepository()
      ..current = item(status: '검수중', choice: null);
    final c = await start(repo);
    final vm = c.read(inspectionChoiceVmProvider('INS-1').notifier);
    await vm.choose(InspectionChoice.returnItem);
    expect(repo.writes, 0);
    repo.current = item(choice: '대리판매');
    await vm.choose(InspectionChoice.returnItem);
    expect(repo.writes, 0);
    expect(c.read(inspectionChoiceVmProvider('INS-1')).result?.choice, '대리판매');
  });
  test('concurrent and post-success choices cannot submit twice', () async {
    final repo = ResultsRepository()
      ..pendingChoice = Completer<InspectionResult>();
    final c = await start(repo);
    final vm = c.read(inspectionChoiceVmProvider('INS-1').notifier);
    final first = vm.choose(InspectionChoice.returnItem);
    await Future<void>.delayed(Duration.zero);
    await vm.choose(InspectionChoice.consign);
    expect(repo.writes, 1);
    repo.pendingChoice!.complete(item(choice: '반환'));
    await first;
    await vm.choose(InspectionChoice.consign);
    expect(repo.writes, 1);
  });
  test('lost response never repeats PUT and recovers by GET', () async {
    final repo = ResultsRepository()
      ..error = const InspectionException('lost', uncertain: true);
    final c = await start(repo);
    final vm = c.read(inspectionChoiceVmProvider('INS-1').notifier);
    await vm.choose(InspectionChoice.consign);
    await vm.choose(InspectionChoice.returnItem);
    await vm.checkResult();
    expect(repo.writes, 1);
    expect(c.read(inspectionChoiceVmProvider('INS-1')).uncertain, isTrue);
    repo.current = item(choice: '대리판매');
    await vm.checkResult();
    expect(c.read(inspectionChoiceVmProvider('INS-1')).result?.choice, '대리판매');
    expect(repo.writes, 1);
  });
  test('401 logs out and late choice after logout is ignored', () async {
    final repo = ResultsRepository()
      ..error = const InspectionException('expired', status: 401);
    final c = await start(repo);
    await c
        .read(inspectionChoiceVmProvider('INS-1').notifier)
        .choose(InspectionChoice.returnItem);
    expect(c.read(loginVmProvider).session, isNull);
    final lateRepo = ResultsRepository()
      ..pendingChoice = Completer<InspectionResult>();
    final late = await start(lateRepo);
    final sent = late
        .read(inspectionChoiceVmProvider('INS-1').notifier)
        .choose(InspectionChoice.returnItem);
    await Future<void>.delayed(Duration.zero);
    await late.read(loginVmProvider.notifier).logout();
    lateRepo.pendingChoice!.complete(item(choice: '반환'));
    await sent;
    expect(late.read(inspectionChoiceVmProvider('INS-1')).result, isNull);
  });
  test('mismatched successful choice response remains uncertain', () async {
    final api = InspectionApiService(
      MockClient((_) async => auth.response(jsonItem(choice: '대리판매'))),
      baseUrl: 'http://test.local',
    );
    await expectLater(
      api.choose('INS-1', InspectionChoice.returnItem, 'token'),
      throwsA(
        isA<InspectionException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
  });
  testWidgets(
    'result screen shows grade without internal reason and confirms return only after approval',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ResultsRepository();
      final c = (await tester.runAsync(() => start(repo)))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: InspectionResultsView(number: '20261030000001'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('등급 · A'), findsOneWidget);
      expect(find.textContaining('표면 상태 양호'), findsNothing);
      expect(find.textContaining('판정 사유'), findsNothing);
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '반환'));
      await tester.tap(find.widgetWithText(OutlinedButton, '반환'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      expect(find.textContaining('선택 후에는 변경할 수 없습니다.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(find.widgetWithText(OutlinedButton, '반환'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '선택하기'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(find.textContaining('반환을 선택했습니다.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '대리판매'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
