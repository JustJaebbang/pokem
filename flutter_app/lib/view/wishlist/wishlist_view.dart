import 'package:pokem_app/view/products/widgets/product_listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class WishlistView extends ConsumerWidget {
  const WishlistView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wishlistVmProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(wishlistVmProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '관심목록',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(state.error!, textAlign: TextAlign.center),
                    ),
                    TextButton(
                      onPressed: state.loading
                          ? null
                          : () =>
                                ref.read(wishlistVmProvider.notifier).refresh(),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          if (state.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (state.loaded && state.products.isEmpty && !state.loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('관심상품이 없습니다.', textAlign: TextAlign.center),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.crossAxisExtent >= 700 ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 250,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final p = state.products[index];
                  return ProductListingCard(
                    product: p,
                    actionKey: ValueKey('wished-product-${p.code}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailView(code: p.code),
                      ),
                    ),
                  );
                }, childCount: state.products.length),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
