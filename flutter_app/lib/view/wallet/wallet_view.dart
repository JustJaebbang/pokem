import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:pokem_app/view/wallet/money_transfer_view.dart';

class WalletSummary extends ConsumerWidget {
  const WalletSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(walletVmProvider);
    return Card(
      child: ListTile(
        title: const Text('포켐머니'),
        subtitle: result.when(
          data: (wallet) => Text(formatWon(wallet.balance)),
          loading: () => const Text('잔액 확인 중'),
          error: (_, _) => const Text('잔액을 확인하지 못했습니다.'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const WalletView()));
          if (context.mounted) ref.read(walletVmProvider.notifier).refresh();
        },
      ),
    );
  }
}

class WalletView extends ConsumerWidget {
  const WalletView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(walletVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('포켐머니'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () => ref.read(walletVmProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is WalletException ? e.message : '포켐머니를 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () =>
                      ref.read(walletVmProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (wallet) => RefreshIndicator(
          onRefresh: () async {
            ref.read(walletVmProvider.notifier).refresh();
            try {
              await ref.read(walletVmProvider.future);
            } catch (_) {
              /* 화면의 오류 상태로 표시합니다. */
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Text('사용 가능한 포켐머니'),
              const SizedBox(height: 12),
              Text(
                formatWon(wallet.balance),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (final action in MoneyAction.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton.tonal(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    MoneyTransferView(action: action),
                              ),
                            );
                            if (context.mounted) {
                              ref.read(walletVmProvider.notifier).refresh();
                            }
                          },
                          child: Text('${action.label}하기'),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('현재 충전·환전은 앱 잔액에만 반영됩니다. 실제 결제나 은행 송금은 지원하지 않습니다.'),
              const Divider(height: 40),
              Text('충전·환전 내역', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (wallet.records.isEmpty) const Text('충전·환전 내역이 없습니다.'),
              for (final record in wallet.records)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    record.action == MoneyAction.recharge
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                  ),
                  title: Text(record.action.label),
                  subtitle: Text('${record.date ?? ''}\n내역번호 ${record.seq}'),
                  isThreeLine: true,
                  trailing: Text(
                    '${record.action == MoneyAction.recharge ? '+' : '-'}${formatWon(record.amount)}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
