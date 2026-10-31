import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/inspection/deposit_refund_vm.dart';

class DepositRefundView extends ConsumerWidget {
  const DepositRefundView({super.key, required this.payNumber});
  final String payNumber;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = depositRefundVmProvider(payNumber);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('보증금 환급내역'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () => ref.read(provider.notifier).refresh(),
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
                Text(
                  e is InspectionException ? e.message : '환급내역을 불러오지 못했습니다.',
                ),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: () async {
            ref.read(provider.notifier).refresh();
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              SelectableText('결제번호 $payNumber'),
              const SizedBox(height: 16),
              const Text('환급 처리 기록입니다. 실제 입금 여부는 별도로 확인해주세요.'),
              const SizedBox(height: 24),
              if (page.items.isEmpty) const Text('등록된 환급내역이 없습니다.'),
              for (final item in page.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.price == null
                              ? '금액 확인 불가'
                              : formatWon(item.price!),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.date == null
                              ? '기록 일시 확인 불가'
                              : '기록 일시 ${formatPurchaseTime(item.zonedDate)}',
                        ),
                        const SizedBox(height: 8),
                        SelectableText('환급번호 ${item.number}'),
                      ],
                    ),
                  ),
                ),
              if (page.error != null)
                Text(
                  page.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      ),
    );
  }
}
