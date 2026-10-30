import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/register_input.dart';
import 'package:pokem_app/model/products/product_form_input.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/auth/register_vm.dart';
import 'package:pokem_app/vm/products/product_create_vm.dart';

import 'auth_test.dart' as fixtures;

void main() {
  test('layer imports keep views away from data access and data away from Riverpod', () {
    final violations = <String>[];
    var checkedViews = 0;
    var checkedDataFiles = 0;
    for (final entity
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final path = entity.path.split(Platform.pathSeparator).join('/');
      final source = entity.readAsStringSync();
      final imports = RegExp(r"(?:import|export) '([^']+)'(?:[^;]*);")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
      if (path.startsWith('lib/view/')) {
        checkedViews++;
        for (final uri in imports) {
          if (uri.contains('/repository/') ||
              uri.contains('/service/') ||
              uri.contains('core/providers/') ||
              uri == 'package:http/http.dart') {
            violations.add('$path imports $uri');
          }
        }
      }
      if (path.startsWith('lib/vm/')) {
        if (imports.any((uri) => uri.contains('package:pokem_app/view/'))) {
          violations.add('$path imports a view');
        }
      }
      if (path.startsWith('lib/repository/') ||
          path.startsWith('lib/service/') ||
          path.startsWith('lib/model/')) {
        checkedDataFiles++;
        if (imports.any(
          (uri) =>
              uri.contains('riverpod') ||
              uri.contains('package:pokem_app/vm/') ||
              uri.contains('package:pokem_app/view/'),
        )) {
          violations.add('$path depends on UI state');
        }
      }
    }
    expect(checkedViews, greaterThan(0));
    expect(checkedDataFiles, greaterThan(0));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('login vm rejects invalid input without API access', () async {
    var requests = 0;
    final repository = fixtures.repository(fixtures.MemoryStorage(), (_) {
      requests++;
      throw StateError('No request expected');
    });
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(loginVmProvider);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(loginVmProvider.notifier)
        .login(' ', '', remember: false);
    expect(container.read(loginVmProvider).error, '아이디를 입력해주세요.');
    expect(requests, 0);
  });

  test(
    'registration vm validates confirmation without a Form widget',
    () async {
      var requests = 0;
      final repository = fixtures.repository(fixtures.MemoryStorage(), (_) {
        requests++;
        throw StateError('No request expected');
      });
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      final sub = container.listen(registerVmProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });
      final result = await container
          .read(registerVmProvider.notifier)
          .register(
            const RegisterInput(
              id: 'user',
              nickname: 'nick',
              name: 'name',
              password: 'secret',
              confirmation: 'different',
              address: 'address',
              phone: '01012345678',
              email: 'a@example.com',
            ),
          );
      expect(result, isNull);
      expect(container.read(registerVmProvider).error, '비밀번호가 일치하지 않습니다.');
      expect(requests, 0);
    },
  );

  test(
    'product vm validates raw price before requesting a photo or session',
    () async {
      final container = ProviderContainer();
      final sub = container.listen(productCreateVmProvider, (_, _) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });
      for (final value in ['not a number', '0', '2147483648']) {
        final result = await container
            .read(productCreateVmProvider.notifier)
            .submit(
              ProductFormInput(
                title: 'card',
                description: 'description',
                price: value,
                regulation: 'SV',
                packType: 'pack',
                element: 'card',
                setNumber: '1',
                rarity: 'R',
              ),
            );
        expect(result, isNull);
        expect(container.read(productCreateVmProvider).error, contains('가격'));
      }
    },
  );
}
