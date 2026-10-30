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
  const ProductsState({this.products = const AsyncLoading(), this.query = ''});
  final AsyncValue<List<Product>> products;
  final String query;
  AsyncValue<List<Product>> get visibleProducts =>
      products.whenData((items) => filterProducts(items, query));
}
