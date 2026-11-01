import 'package:pokem_app/view/products/widgets/product_listing_card.dart';
import 'package:pokem_app/view/home/product_filters.dart';
import 'package:pokem_app/view/inspection/inspection_history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';

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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD MARKET',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '당신의 다음 카드',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '검수부터 거래까지, 한곳에서.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSecondary
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Transform.rotate(
                          angle: 0.15,
                          child: Container(
                            width: 56,
                            height: 78,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.style_outlined,
                              color: theme.colorScheme.primary,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ProductFilters(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const InspectionHistoryView(),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('검수신청'),
                  ),
                  const SizedBox(height: 20),
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
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(14),
                        style: theme.textTheme.labelLarge,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                        ),
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
                              return ProductListingCard(
                                product: p,
                                actionKey: ValueKey('product-${p.code}'),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ProductDetailView(code: p.code),
                                  ),
                                ),
                              );
                            }, childCount: products.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 250,
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
