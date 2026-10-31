import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/model/wallet/product_payment.dart';
import 'package:pokem_app/vm/wallet/payment_vm.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/wallet/payment_detail_view.dart';

String paymentTime(String value) => DateTime.tryParse(value) == null
    ? '결제 일시 확인 불가'
    : formatPurchaseTime(value);

class PaymentHistoryView extends ConsumerWidget {
  const PaymentHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(paymentHistoryVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 결제내역'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: result.isLoading
                ? null
                : () => ref.read(paymentHistoryVmProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is PaymentException ? e.message : '결제내역을 불러오지 못했습니다.'),
              TextButton(
                onPressed: () =>
                    ref.read(paymentHistoryVmProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.read(paymentHistoryVmProvider.notifier).refresh();
            try {
              await ref.read(paymentHistoryVmProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text('결제취소 내역의 금액은 원 결제금액입니다.'),
              const SizedBox(height: 16),
              if (items.isEmpty) const Text('상품 결제내역이 없습니다.'),
              for (final item in items)
                Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 64,
                      child: ProductImage(url: item.image ?? ''),
                    ),
                    title: Text(
                      item.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.status} · ${paymentTime(item.date)}',
                    ),
                    trailing: Text(formatWon(item.amount)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PaymentDetailView(code: item.code),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
