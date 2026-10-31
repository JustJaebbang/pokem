import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/vm/profile/quit_vm.dart';

class QuitView extends ConsumerStatefulWidget {
  const QuitView({super.key});
  @override
  ConsumerState<QuitView> createState() => _QuitViewState();
}

class _QuitViewState extends ConsumerState<QuitView> {
  final reason = TextEditingController();
  bool acknowledged = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quitVmProvider);
    final locked = state.loading || state.busy || state.uncertain;
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('회원탈퇴')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('탈퇴 전에 확인해주세요', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('''탈퇴하면 이 계정으로 로그인할 수 없습니다.
포켐머니 잔액을 정리한 후 진행해주세요.
탈퇴 후에도 기존 거래내역은 보관됩니다.'''),
            const SizedBox(height: 20),
            if (state.loading) const LinearProgressIndicator(),
            if (state.balance != null)
              Text('포켐머니 잔액 ${formatWon(state.balance!)}'),
            const SizedBox(height: 20),
            TextField(
              controller: reason,
              enabled: !locked,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '탈퇴 사유 (선택)'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('안내를 확인했으며 탈퇴에 동의합니다.'),
              value: acknowledged,
              onChanged: locked
                  ? null
                  : (value) => setState(() => acknowledged = value ?? false),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.uncertain)
              OutlinedButton(
                onPressed: state.loading
                    ? null
                    : () => ref.read(quitVmProvider.notifier).load(),
                child: const Text('처리 상태 확인'),
              )
            else ...[
              if (state.balance == null || state.balance != 0)
                TextButton(
                  onPressed: locked
                      ? null
                      : () => ref.read(quitVmProvider.notifier).load(),
                  child: const Text('잔액 다시 확인'),
                ),
              FilledButton(
                onPressed: locked || state.balance != 0 || !acknowledged
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('탈퇴하시겠어요?'),
                            content: const Text('탈퇴가 완료되면 로그인 화면으로 이동합니다.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('탈퇴하기'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          await ref
                              .read(quitVmProvider.notifier)
                              .submit(reason.text, acknowledged: acknowledged);
                        }
                      },
                child: Text(state.busy ? '처리 중' : '회원탈퇴'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
