import 'package:pokem_app/view/wishlist/widgets/wishlist_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/products/product_search_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';
import 'package:pokem_app/core/formatters/money.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/view/products/product_detail_view.dart';

class ProductSearchView extends ConsumerWidget {
  const ProductSearchView({super.key, this.wishlistOnly = false});
  final bool wishlistOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(productSearchResultsProvider(wishlistOnly));
    final query = ref
        .watch(productSearchQueryProvider(wishlistOnly))
        .trim()
        .toLowerCase();
    final sort = ref.watch(productSearchSortProvider);
    final marketProvider = marketSearchVmProvider((query: query, sort: sort));
    final page = wishlistOnly ? null : ref.watch(marketProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(wishlistOnly ? '관심상품 검색' : '상품 검색'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: result.isLoading
                ? null
                : () => wishlistOnly
                      ? ref.read(wishlistVmProvider.notifier).refresh()
                      : ref.read(marketProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: '상품명·카드 코드 검색',
                counterText: '',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref
                  .read(productSearchQueryProvider(wishlistOnly).notifier)
                  .search(value),
            ),
          ),
          if (!wishlistOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: DropdownButton<ProductSort>(
                  value: sort,
                  items: [
                    for (final value in ProductSort.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(productSearchSortProvider.notifier)
                          .select(value);
                    }
                  },
                ),
              ),
            ),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => wishlistOnly
                      ? ref.read(wishlistVmProvider.notifier).refresh()
                      : ref.read(marketProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                      itemCount:
                          items.length +
                          (page?.hasMore == true || page?.pageError != null
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == items.length) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                if (page?.pageError != null)
                                  Text(page!.pageError!),
                                OutlinedButton(
                                  onPressed: page!.loadingMore
                                      ? null
                                      : () => ref
                                            .read(marketProvider.notifier)
                                            .loadMore(),
                                  child: Text(
                                    page.loadingMore ? '불러오는 중' : '더 보기',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final item = items[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 48,
                            height: 64,
                            child: ProductImage(url: item.image),
                          ),
                          title: Text(item.title),
                          trailing: WishlistButton(product: item),
                          subtitle: Text(
                            '${item.status} · ${formatWon(item.price)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ProductDetailView(code: item.code),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
