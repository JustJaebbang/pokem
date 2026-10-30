import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';

class SessionView extends ConsumerWidget {
  const SessionView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginVmProvider);
    final account = state.session!.account;
    return Scaffold(
      appBar: AppBar(title: const Text('포켐')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '${account.name}님, 반가워요.',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('${account.role.label} · ${account.id}'),
              const SizedBox(height: 16),
              const Text(
                '로그인이 완료되었습니다. 다음 단계에서 역할에 맞는 홈 화면을 연결합니다.',
                textAlign: TextAlign.center,
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(state.error!),
                ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: state.submitting
                    ? null
                    : () => ref.read(loginVmProvider.notifier).logout(),
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
