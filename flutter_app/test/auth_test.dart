import 'package:pokem_app/core/providers/data_providers.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokem_app/core/storage/session_storage.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';
import 'package:pokem_app/repository/auth/auth_repository.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class MemoryStorage implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

Map<String, dynamic> loginResponse({
  String role = 'user',
  int expiresIn = 1800,
}) => {
  'access_token': 'test-token',
  'token_type': 'bearer',
  'expires_in': expiresIn,
  'role': role,
  'account': {
    '${role}_id': 'tester',
    if (role == 'user') 'user_nickname': '카드수집가' else '${role}_name': '담당자',
  },
};

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AuthRepository repository(
  MemoryStorage storage,
  FutureOr<http.Response> Function(http.Request) handler,
) => AuthRepository(
  AuthApiService(
    MockClient((request) async => await handler(request)),
    baseUrl: 'http://test.local',
  ),
  storage,
);

void main() {
  test('login uses server contract and persists only token + expiry when requested', () async {
    final storage = MemoryStorage();
    final repo = repository(storage, (request) {
      expect(request.url.path, '/auth/login');
      expect(request.method, 'POST');
      expect(jsonDecode(request.body), {
        'login_id': 'tester',
        'password': ' password ',
      });
      return response(loginResponse());
    });
    final session = await repo.login('tester', ' password ', remember: true);
    expect(session.account.role, AccountRole.user);
    expect(session.account.name, '카드수집가');
    final saved = jsonDecode(storage.value!) as Map;
    expect(saved.keys, unorderedEquals(['token', 'expires_at']));
    expect(storage.value, isNot(contains('password')));
    expect(repo.session, session);
  });

  test('unchecking remember removes a previously persisted login', () async {
    final storage = MemoryStorage()..value = 'old';
    final repo = repository(storage, (_) => response(loginResponse()));
    await repo.login('tester', 'pw', remember: false);
    expect(storage.value, isNull);
    expect(repo.session, isNotNull);
    await repo.logout();
    expect(repo.session, isNull);
  });

  for (final role in ['user', 'manager', 'director']) {
    test('accepts $role login response', () async {
      final repo = repository(
        MemoryStorage(),
        (_) => response(loginResponse(role: role)),
      );
      expect(
        (await repo.login('tester', 'pw', remember: false)).account.role.name,
        role,
      );
    });
  }

  test(
    'restore validates token with auth/me and logout clears storage',
    () async {
      final storage = MemoryStorage()
        ..value = jsonEncode({
          'token': 'saved-token',
          'expires_at': DateTime.now()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        });
      final repo = repository(storage, (request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/auth/me');
        expect(request.headers['Authorization'], 'Bearer saved-token');
        return response(loginResponse());
      });
      expect((await repo.restore())?.account.id, 'tester');
      await repo.logout();
      expect(storage.value, isNull);
    },
  );

  test(
    'expired and malformed saved sessions are cleared without API call',
    () async {
      for (final raw in [
        'bad-json',
        '{}',
        jsonEncode({'token': 'old', 'expires_at': '2020-01-01T00:00:00Z'}),
      ]) {
        final storage = MemoryStorage()..value = raw;
        final repo = repository(
          storage,
          (_) => throw StateError('must not request'),
        );
        expect(await repo.restore(), isNull);
        expect(storage.value, isNull);
      }
    },
  );

  test('rejected stored token clears session; temporary network error preserves it', () async {
    final saved = jsonEncode({
      'token': 'old',
      'expires_at': DateTime.now()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    });
    final storage = MemoryStorage()..value = saved;
    final rejected = repository(
      storage,
      (_) => response({'detail': 'expired'}, 401),
    );
    expect(await rejected.restore(), isNull);
    expect(storage.value, isNull);
    storage.value = saved;
    final offline = repository(
      storage,
      (_) => throw http.ClientException('offline'),
    );
    await expectLater(offline.restore(), throwsA(isA<AuthException>()));
    expect(storage.value, saved);
  });

  test('server errors and non-JSON bodies become useful errors', () async {
    final rejected = repository(
      MemoryStorage(),
      (_) => response({'detail': '아이디 또는 비밀번호가 올바르지 않습니다.'}, 401),
    );
    await expectLater(
      rejected.login('x', 'y', remember: false),
      throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 401)),
    );
    final html = repository(
      MemoryStorage(),
      (_) => http.Response('<html>failure</html>', 500),
    );
    await expectLater(
      html.login('x', 'y', remember: false),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('서버'),
        ),
      ),
    );
    final malformed = repository(
      MemoryStorage(),
      (_) => response({'access_token': null}),
    );
    await expectLater(
      malformed.login('x', 'y', remember: false),
      throwsA(isA<AuthException>()),
    );
  });

  test('vm blocks duplicate submissions and trims only ID', () async {
    final completer = Completer<http.Response>();
    var requests = 0;
    final repo = repository(MemoryStorage(), (request) {
      requests++;
      expect(jsonDecode(request.body), {
        'login_id': 'tester',
        'password': ' pw ',
      });
      return completer.future;
    });
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    final vm = container.read(loginVmProvider.notifier);
    final first = vm.login(' tester ', ' pw ', remember: false);
    await vm.login('tester', 'pw', remember: false);
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    expect(container.read(loginVmProvider).submitting, isTrue);
    completer.complete(response(loginResponse()));
    await first;
    expect(container.read(loginVmProvider).session?.account.id, 'tester');
    await vm.logout();
    expect(container.read(loginVmProvider).session, isNull);
  });
}
