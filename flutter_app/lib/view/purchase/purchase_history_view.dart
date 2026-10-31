import 'package:pokem_app/view/review/review_view.dart';
import 'package:pokem_app/view/purchase/purchase_cancel_view.dart';
import 'package:pokem_app/view/purchase/widgets/purchase_confirm_action.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/vm/purchase/purchase_history_vm.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';

class PurchaseHistoryView extends ConsumerWidget {
  const PurchaseHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(purchaseHistoryVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('구매내역'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () => ref.read(purchaseHistoryVmProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is PurchaseException
                    ? error.message
                    : '구매내역을 불러오지 못했습니다.',
              ),
              TextButton(
                onPressed: () =>
                    ref.read(purchaseHistoryVmProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.read(purchaseHistoryVmProvider.notifier).refresh();
            try {
              await ref.read(purchaseHistoryVmProvider.future);
            } catch (_) {
              // 조회 실패는 VM의 오류 상태로 표시합니다.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('구매내역이 없습니다.'),
                ),
              for (final item in items)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductDetailView(code: item.productCode),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 80,
                              height: 96,
                              child: ProductImage(
                                url: item.image ?? '',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.statusLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.title == null ||
                                          item.title!.trim().isEmpty
                                      ? '상품 정보 없음'
                                      : item.title!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.paidPrice == null
                                      ? '금액 확인 불가'
                                      : formatWon(item.paidPrice!),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  formatPurchaseTime(item.date),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                PurchaseConfirmAction(purchase: item),
                                if (item.isConfirmed)
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            ReviewView(code: item.code),
                                      ),
                                    ),
                                    child: const Text('후기 작성·보기'),
                                  ),

                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          PurchaseCancelView(code: item.code),
                                    ),
                                  ),
                                  child: const Text('구매취소·처리내역'),
                                ),
                              ],
                            ),
                          ),
                        ],
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
