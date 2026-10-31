import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class ProductSearchVm extends Notifier<String> {
  ProductSearchVm(this.wishlistOnly);
  final bool wishlistOnly;
  Timer? _timer;
  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    return '';
  }

  void search(String query) {
    _timer?.cancel();
    if (wishlistOnly || query.trim().isEmpty) {
      state = query;
      return;
    }
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (ref.mounted) state = query;
    });
  }
}

final productSearchQueryProvider = NotifierProvider.autoDispose
    .family<ProductSearchVm, String, bool>(ProductSearchVm.new);
final productSearchResultsProvider = Provider.autoDispose
    .family<AsyncValue<List<Product>>, bool>((ref, wishlistOnly) {
      final query = ref
          .watch(productSearchQueryProvider(wishlistOnly))
          .trim()
          .toLowerCase();
      bool matches(Product p) =>
          query.isEmpty ||
          '${p.title} ${p.description} ${p.serialCode}'.toLowerCase().contains(
            query,
          );
      if (wishlistOnly) {
        final wishlist = ref.watch(wishlistVmProvider);
        if (wishlist.loading) return const AsyncLoading();
        if (wishlist.error != null) {
          return AsyncError(
            ProductException(wishlist.error!),
            StackTrace.current,
          );
        }
        return AsyncData(wishlist.products.where(matches).toList());
      }
      final sort = ref.watch(productSearchSortProvider);
      return ref
          .watch(marketSearchVmProvider((query: query, sort: sort)))
          .products
          .whenData((items) => items.where((item) => item.isForSale).toList());
    });

class ProductSearchSortVm extends Notifier<ProductSort> {
  @override
  ProductSort build() => ProductSort.newest;
  void select(ProductSort value) => state = value;
}

final productSearchSortProvider =
    NotifierProvider.autoDispose<ProductSearchSortVm, ProductSort>(
      ProductSearchSortVm.new,
    );
