import 'package:pokem_app/vm/wallet/wallet_ledger_vm.dart';
import 'package:pokem_app/view/wallet/wallet_ledger_view.dart';
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
    final direction = ref.watch(ledgerDirectionProvider);
    Future<void> refresh() async {
      ref.read(walletVmProvider.notifier).refresh();
      ref.read(walletLedgerVmProvider(direction).notifier).refresh();
      await Future.wait([
        () async {
          try {
            await ref.read(walletVmProvider.future);
          } catch (_) {}
        }(),
        () async {
          try {
            await ref.read(walletLedgerVmProvider(direction).future);
          } catch (_) {}
        }(),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('포켐머니'),
        actions: [
          IconButton(
            onPressed: result.isLoading ? null : refresh,
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
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FilledButton.tonal(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            MoneyTransferView(action: action),
                                      ),
                                    );
                                    if (context.mounted) {
                                      ref
                                          .read(walletVmProvider.notifier)
                                          .refresh();
                                    }
                                  },
                                  child: Text('${action.label}하기'),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '현재 충전·환전은 앱 잔액에만 반영됩니다. 실제 결제나 은행 송금은 지원하지 않습니다.',
                      ),
                      const Divider(height: 40),
                    ],
                  ),
                ),
              ),
              const WalletLedgerSliver(),
            ],
          ),
        ),
      ),
    );
  }
}
