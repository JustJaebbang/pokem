import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/wallet/wallet_ledger.dart';
import 'package:pokem_app/vm/wallet/wallet_ledger_vm.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/view/wallet/payment_detail_view.dart';

class WalletLedgerView extends ConsumerWidget {
  const WalletLedgerView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(ledgerDirectionProvider);
    final provider = walletLedgerVmProvider(direction);
    return Scaffold(
      appBar: AppBar(title: const Text('포켐머니 이용내역')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(provider.notifier).refresh();
          try {
            await ref.read(provider.future);
          } catch (_) {}
        },
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [WalletLedgerSliver()],
        ),
      ),
    );
  }
}

class WalletLedgerSliver extends ConsumerWidget {
  const WalletLedgerSliver({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(ledgerDirectionProvider);
    final provider = walletLedgerVmProvider(direction);
    final result = ref.watch(provider);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('이용내역', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SegmentedButton<LedgerDirection>(
                  segments: const [
                    ButtonSegment(
                      value: LedgerDirection.all,
                      label: Text('전체'),
                    ),
                    ButtonSegment(
                      value: LedgerDirection.incoming,
                      label: Text('입금'),
                    ),
                    ButtonSegment(
                      value: LedgerDirection.outgoing,
                      label: Text('출금'),
                    ),
                  ],
                  selected: {direction},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) => ref
                      .read(ledgerDirectionProvider.notifier)
                      .select(values.single),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          result.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(e is LedgerException ? e.message : '이용내역을 불러오지 못했습니다.'),
                  TextButton(
                    onPressed: () => ref.read(provider.notifier).refresh(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
            data: (page) => SliverList.list(
              children: [
                if (page.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('이용내역이 없습니다.'),
                  ),
                for (final item in page.items) _LedgerItem(item: item),
                if (page.error != null)
                  Text(
                    page.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (page.hasMore)
                  OutlinedButton(
                    onPressed: page.loadingMore
                        ? null
                        : () => ref.read(provider.notifier).loadMore(),
                    child: Text(page.loadingMore ? '불러오는 중' : '더 보기'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerItem extends StatelessWidget {
  const _LedgerItem({required this.item});
  final WalletMovement item;
  @override
  Widget build(BuildContext context) {
    final pageContext = context;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Text(item.label),
      subtitle: Text(
        [
          if (item.productTitle?.isNotEmpty == true) item.productTitle!,
          item.date == null || DateTime.tryParse(item.date!) == null
              ? '일시 확인 불가'
              : formatPurchaseTime(item.date),
        ].join(' · '),
      ),
      trailing: Text(
        '${item.amount > 0 ? '+' : ''}${formatWon(item.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: item.amount > 0
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('${item.amount > 0 ? '+' : ''}${formatWon(item.amount)}'),
                if (item.productTitle != null) Text(item.productTitle!),
                const SizedBox(height: 12),
                SelectableText('내역번호 ${item.sourceCode}'),
                if (item.purchaseCode != null)
                  SelectableText('구매번호 ${item.purchaseCode}'),
                if (['payment', 'refund'].contains(item.kind) &&
                    item.paymentCode != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(pageContext).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PaymentDetailView(code: item.paymentCode!),
                        ),
                      );
                    },
                    child: const Text('결제 상세 보기'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
