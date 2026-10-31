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
    return Scaffold(
      appBar: AppBar(title: Text(wishlistOnly ? '관심상품 검색' : '상품 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '상품명·카드 코드 검색',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref
                  .read(productSearchQueryProvider(wishlistOnly).notifier)
                  .search(value),
            ),
          ),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => wishlistOnly
                      ? ref.read(wishlistVmProvider.notifier).refresh()
                      : ref.read(productsVmProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 48,
                            height: 64,
                            child: ProductImage(url: item.image),
                          ),
                          title: Text(item.title),
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
