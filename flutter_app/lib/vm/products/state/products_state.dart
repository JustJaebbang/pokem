import 'package:pokem_app/model/products/product_browse.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/products/product.dart';

List<Product> filterProducts(List<Product> items, String query) {
  final term = query.trim().toLowerCase();
  return items
      .where(
        (p) =>
            p.isForSale &&
            (term.isEmpty ||
                '${p.title} ${p.description} ${p.serialCode}'
                    .toLowerCase()
                    .contains(term)),
      )
      .toList();
}

class ProductsState {
  const ProductsState({
    this.products = const AsyncLoading(),
    this.query = '',
    this.category,
    this.brand,
    this.sort = ProductSort.newest,
    this.nextOffset = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.pageError,
  });
  final AsyncValue<List<Product>> products;
  final String query;
  final String? category, brand;
  final ProductSort sort;
  final int nextOffset;
  final bool hasMore, loadingMore;
  final String? pageError;
  AsyncValue<List<Product>> get visibleProducts =>
      products.whenData((items) => filterProducts(items, query));
}
