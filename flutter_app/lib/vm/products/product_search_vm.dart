import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class ProductSearchVm extends Notifier<String> {
  ProductSearchVm(this.wishlistOnly);
  final bool wishlistOnly;
  @override
  String build() => '';
  void search(String query) => state = query;
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
      return ref
          .watch(productsVmProvider)
          .products
          .whenData(
            (items) => items.where((p) => p.isForSale && matches(p)).toList(),
          );
    });
