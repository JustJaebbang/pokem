import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/push/push_vm.dart';

class PushSettingsTile extends ConsumerWidget {
  const PushSettingsTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(pushSupportedProvider)) return const SizedBox.shrink();
    final state = ref.watch(pushVmProvider);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('검수 푸시 알림'),
          subtitle: const Text('검수 완료 소식을 휴대폰 알림으로 받아요.'),
          value: state.enabled,
          onChanged: state.busy
              ? null
              : (value) {
                  final vm = ref.read(pushVmProvider.notifier);
                  if (value) {
                    vm.synchronize(ask: true);
                  } else {
                    vm.disable();
                  }
                },
        ),
        if (state.error != null)
          ListTile(
            title: Text(state.error!),
            trailing: TextButton(
              onPressed: state.busy
                  ? null
                  : () => ref
                        .read(pushVmProvider.notifier)
                        .synchronize(ask: true),
              child: const Text('다시 시도'),
            ),
          ),
      ],
    );
  }
}
