import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/model/wallet/product_payment.dart';
import 'package:pokem_app/vm/wallet/payment_vm.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/purchase/purchase_cancel_view.dart';

class PaymentDetailView extends ConsumerWidget {
  const PaymentDetailView({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = paymentDetailVmProvider(code);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('결제 상세'),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is PaymentException ? e.message : '결제내역을 불러오지 못했습니다.'),
              TextButton(
                onPressed: () => ref.read(provider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (item) => item == null
            ? const Center(child: Text('로그인이 필요합니다.'))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SizedBox(
                    height: 200,
                    child: ProductImage(url: item.image ?? ''),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.displayTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(item.status),
                  const SizedBox(height: 16),
                  Text('원 결제금액 ${formatWon(item.amount)}'),
                  const SizedBox(height: 12),
                  Text(
                    '결제 일시 ${DateTime.tryParse(item.date) == null ? '확인 불가' : formatPurchaseTime(item.date)}',
                  ),
                  const Divider(height: 32),
                  SelectableText('결제번호 ${item.code}'),
                  const SizedBox(height: 12),
                  SelectableText('구매번호 ${item.purchaseCode}'),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PurchaseCancelView(code: item.purchaseCode),
                      ),
                    ),
                    child: const Text('구매취소·처리내역'),
                  ),
                ],
              ),
      ),
    );
  }
}
