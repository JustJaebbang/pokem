import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/consignment/consignment.dart';
import 'package:pokem_app/vm/consignment/consignment_vm.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';
import 'package:pokem_app/view/inspection/return_view.dart';

class ConsignmentView extends ConsumerWidget {
  const ConsignmentView({super.key, required this.source});
  final ConsignmentSource source;
  String time(String? value) =>
      value == null || DateTime.tryParse(value) == null
      ? '확인되지 않음'
      : formatPurchaseTime(value);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = consignmentVmProvider(source);
    final result = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('대리판매 상세'),
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
                Text(
                  e is ConsignmentException
                      ? e.message
                      : '대리판매 정보를 불러오지 못했습니다.',
                ),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => RefreshIndicator(
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
              if (detail == null) ...[
                if (source.inspectCode != null)
                  SelectableText('검수번호 ${source.inspectCode}'),
                const SizedBox(height: 20),
                const Text(
                  '아직 대리판매 상품이 등록되지 않았습니다. 담당자가 등록하면 이곳에서 확인할 수 있습니다.',
                ),
              ] else ...[
                Text(
                  detail.status,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                if (detail.product != null) ...[
                  SizedBox(
                    height: 220,
                    child: ProductImage(url: detail.product!.image),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    detail.product!.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('등록 판매가 ${formatWon(detail.product!.price)}'),
                  Text('검수 등급 ${detail.product!.grade}'),
                ],
                if (detail.productError != null) ...[
                  Text(detail.productError!),
                  TextButton(
                    onPressed: () => ref.read(provider.notifier).refresh(),
                    child: const Text('상품 정보 다시 불러오기'),
                  ),
                ],
                const Divider(height: 32),
                SelectableText('검수번호 ${detail.item.inspectCode}'),
                const SizedBox(height: 12),
                SelectableText('대리판매 등록번호 ${detail.item.code}'),
                const SizedBox(height: 12),
                SelectableText('상품번호 ${detail.item.productCode}'),
                const SizedBox(height: 12),
                Text('등록일 ${time(detail.item.registeredAt)}'),
                const SizedBox(height: 12),
                Text('판매 기한 ${time(detail.item.expiresAt)}'),
                const SizedBox(height: 12),
                if (detail.item.completedAt != null)
                  Text('거래완료일 ${time(detail.item.completedAt)}'),
                if (detail.item.returning) ...[
                  const SizedBox(height: 16),
                  const Text('반환으로 전환되었습니다. 반환내역에서 접수 및 배송 정보를 확인해주세요.'),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ReturnView(inspectCode: detail.item.inspectCode),
                      ),
                    ),
                    child: const Text('반환내역 보기'),
                  ),
                ],
                if (detail.product != null)
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductDetailView(code: detail.item.productCode),
                      ),
                    ),
                    child: const Text('판매상품 보기'),
                  ),
                const SizedBox(height: 16),
                const Text('상품 등록과 관리는 담당자가 진행합니다.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
