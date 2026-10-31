import 'package:pokem_app/view/products/product_edit_view.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/sales/sale_record.dart';
import 'package:pokem_app/vm/sales/sales_vm.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';

class SalesView extends ConsumerWidget {
  const SalesView({super.key, this.manage = false});
  final bool manage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(salesVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(manage ? '내 상품 관리' : '판매내역'),
        actions: [
          IconButton(
            onPressed: result.isLoading
                ? null
                : () => ref.read(salesVmProvider.notifier).refresh(),
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
                error is SalesException ? error.message : '판매내역을 불러오지 못했습니다.',
              ),
              TextButton(
                onPressed: () => ref.read(salesVmProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.read(salesVmProvider.notifier).refresh();
            try {
              await ref.read(salesVmProvider.future);
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
                  child: Text('판매내역이 없습니다.'),
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
                                  '${item.typeLabel} · ${item.status ?? '상품 정보 없음'}',
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
                                  item.displayPrice == null
                                      ? '금액 확인 불가'
                                      : '${item.priceLabel} ${formatWon(item.displayPrice!)}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.completedAt != null
                                      ? '거래완료 ${formatPurchaseTime(item.completedAt)}'
                                      : item.postedAt != null
                                      ? '등록 ${formatPurchaseTime(item.postedAt)}'
                                      : '일시 확인 불가',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (manage &&
                                    item.type == 'direct' &&
                                    item.status == '판매중')
                                  OutlinedButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProductEditView(
                                          code: item.productCode,
                                        ),
                                      ),
                                    ),
                                    child: const Text('수정'),
                                  ),
                                if (manage && item.type == 'consign')
                                  const Text('담당자가 관리하는 상품입니다.'),
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
