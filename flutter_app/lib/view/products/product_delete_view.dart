import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/products/product_delete_vm.dart';
import 'package:pokem_app/core/formatters/money.dart';

class ProductDeleteView extends ConsumerStatefulWidget {
  const ProductDeleteView({super.key, required this.code});
  final String code;
  @override
  ConsumerState<ProductDeleteView> createState() => _ProductDeleteViewState();
}

class _ProductDeleteViewState extends ConsumerState<ProductDeleteView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(productDeleteVmProvider(widget.code).notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = productDeleteVmProvider(widget.code);
    final state = ref.watch(provider);
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('상품 삭제')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (state.loading)
              const Center(child: CircularProgressIndicator())
            else if (state.deleted) ...[
              const Text('상품이 삭제되었습니다.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('내 상품 관리로'),
              ),
            ] else ...[
              if (state.product != null) ...[
                Text(
                  state.product!.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(formatWon(state.product!.price)),
                const SizedBox(height: 24),
              ],
              const Text(
                '삭제한 상품은 복구할 수 없습니다. 관심상품·채팅·거래 등 연결된 기록이 있으면 삭제할 수 없습니다.',
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (state.uncertain)
                OutlinedButton(
                  onPressed: () => ref.read(provider.notifier).load(),
                  child: const Text('상태 확인'),
                )
              else if (state.product == null)
                TextButton(
                  onPressed: () => ref.read(provider.notifier).load(),
                  child: const Text('상품 다시 확인'),
                )
              else
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('상품을 삭제하시겠어요?'),
                              content: Text(state.product!.title),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await ref.read(provider.notifier).submit();
                          }
                        },
                  child: Text(state.busy ? '삭제 중' : '상품 삭제'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
