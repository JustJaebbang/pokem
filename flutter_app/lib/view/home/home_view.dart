import 'package:pokem_app/view/home/product_filters.dart';
import 'package:pokem_app/view/inspection/inspection_history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/wishlist/widgets/wishlist_button.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsVmProvider);
    final items = state.visibleProducts;
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(productsVmProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${ref.watch(loginVmProvider).session?.account.name ?? '수집가'}님, 반가워요.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5ECD8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '다음 컬렉션을\n발견하는 즐거움',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('좋아하는 카드의 새로운 주인을 찾아보세요.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const ProductFilters(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InspectionHistoryView(),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('검수신청'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '상품목록',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DropdownButton<ProductSort>(
                        value: state.sort,
                        items: [
                          for (final sort in ProductSort.values)
                            DropdownMenuItem(
                              value: sort,
                              child: Text(sort.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(productsVmProvider.notifier)
                                .changeSort(value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          ...items.when(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (error, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        error is ProductException
                            ? error.message
                            : '상품을 불러오지 못했습니다.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(productsVmProvider.notifier).refresh(),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            data: (products) => products.isEmpty
                ? [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: Text(
                          '표시할 상품이 없습니다.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.crossAxisExtent >= 700
                              ? 3
                              : 2;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final p = products[index];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                margin: EdgeInsets.zero,
                                child: InkWell(
                                  key: ValueKey('product-${p.code}'),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ProductDetailView(code: p.code),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ProductImage(url: p.image),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Material(
                                                color:
                                                    theme.colorScheme.surface,
                                                shape: const CircleBorder(),
                                                child: WishlistButton(
                                                  product: p,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatWon(p.price),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              p.status,
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }, childCount: products.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 245,
                                ),
                          );
                        },
                      ),
                    ),
                  ],
          ),
          if (state.hasMore || state.pageError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (state.pageError != null) Text(state.pageError!),
                    OutlinedButton(
                      onPressed: state.loadingMore
                          ? null
                          : () => ref
                                .read(productsVmProvider.notifier)
                                .loadMore(),
                      child: Text(state.loadingMore ? '불러오는 중' : '더 보기'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
