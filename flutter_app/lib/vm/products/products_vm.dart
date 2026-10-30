import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/vm/products/state/products_state.dart';
export 'package:pokem_app/vm/products/state/products_state.dart';

class ProductsVm extends Notifier<ProductsState> {
  @override
  ProductsState build() {
    final repository = ref.watch(productRepositoryProvider);
    Future.microtask(() => _load(repository));
    return const ProductsState();
  }

  Future<void> _load(ProductRepository repository) async {
    final result = await AsyncValue.guard<List<Product>>(
      repository.getProducts,
    );
    if (ref.mounted) {
      state = ProductsState(products: result, query: state.query);
    }
  }

  Future<void> refresh() async {
    if (state.products.isLoading) return;
    state = ProductsState(query: state.query);
    await _load(ref.read(productRepositoryProvider));
  }

  void search(String value) =>
      state = ProductsState(products: state.products, query: value);
}

final productsVmProvider =
    NotifierProvider.autoDispose<ProductsVm, ProductsState>(ProductsVm.new);
