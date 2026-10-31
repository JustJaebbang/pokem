import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/delivery/delivery.dart';
import 'package:pokem_app/vm/delivery/delivery_vm.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';

class DeliveryView extends ConsumerWidget {
  const DeliveryView({super.key, required this.source});
  final DeliverySource source;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = deliveryVmProvider(source);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('배송 조회'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: result.isLoading
                ? null
                : () => ref.read(provider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
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
                Text(e is DeliveryException ? e.message : '배송 정보를 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (delivery) => RefreshIndicator(
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
              SelectableText(
                source.purchaseCode != null
                    ? '구매번호 ${source.purchaseCode}'
                    : '반환번호 ${source.returnNo}',
              ),
              const SizedBox(height: 24),
              if (delivery == null)
                const Text('아직 등록된 배송 정보가 없습니다.')
              else ...[
                Text(
                  delivery.status?.trim().isNotEmpty == true
                      ? delivery.status!
                      : '배송 상태 확인 중',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                SelectableText('배송번호 ${delivery.number}'),
                const SizedBox(height: 12),
                Text(
                  '배송 등록일 ${delivery.date == null ? '확인되지 않음' : formatPurchaseTime(delivery.date)}',
                ),
                const SizedBox(height: 12),
                SelectableText('배송업체 코드 ${delivery.companyCode}'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
