import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_browse.dart';
import 'package:pokem_app/vm/products/state/products_state.dart';
export 'package:pokem_app/vm/products/state/products_state.dart';
export 'package:pokem_app/model/products/product_browse.dart';

class ProductsVm extends Notifier<ProductsState> {
  ProductsVm({this.initialQuery = '', this.initialSort = ProductSort.newest});
  final String initialQuery;
  final ProductSort initialSort;
  int _generation = 0;
  @override
  ProductsState build() {
    ref.watch(productRepositoryProvider);
    final generation = ++_generation;
    Future.microtask(() => _load(generation));
    return ProductsState(query: initialQuery, sort: initialSort);
  }

  Future<void> _load(int generation, {bool more = false}) async {
    if (!ref.mounted || generation != _generation) return;
    final before = state;
    try {
      final rows = await ref
          .read(productRepositoryProvider)
          .getProducts(
            query: before.query,
            category: before.category,
            brand: before.brand,
            status: '판매중',
            sort: before.sort,
            limit: 20,
            offset: more ? before.nextOffset : 0,
          );
      if (!ref.mounted || generation != _generation) return;
      final byCode = {
        if (more)
          for (final p in before.products.asData?.value ?? <Product>[])
            p.code: p,
      };
      for (final p in rows) {
        byCode[p.code] = p;
      }
      state = ProductsState(
        products: AsyncData(byCode.values.toList()),
        query: before.query,
        category: before.category,
        brand: before.brand,
        sort: before.sort,
        nextOffset: (more ? before.nextOffset : 0) + rows.length,
        hasMore: rows.length == 20,
      );
    } catch (e, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = ProductsState(
        products: more ? before.products : AsyncError(e, stack),
        query: before.query,
        category: before.category,
        brand: before.brand,
        sort: before.sort,
        nextOffset: before.nextOffset,
        hasMore: more && before.hasMore,
        pageError: more
            ? (e is ProductException ? e.message : '상품을 더 불러오지 못했습니다.')
            : null,
      );
    }
  }

  Future<void> refresh() async {
    if (state.products.isLoading) return;
    state = ProductsState(
      query: state.query,
      sort: state.sort,
      category: state.category,
      brand: state.brand,
    );
    await _load(++_generation);
  }

  Future<void> changeSort(ProductSort sort) async {
    if (sort == state.sort) return;
    state = ProductsState(
      query: state.query,
      sort: sort,
      category: state.category,
      brand: state.brand,
    );
    await _load(++_generation);
  }

  void search(String query) {
    state = ProductsState(
      query: query,
      sort: state.sort,
      category: state.category,
      brand: state.brand,
    );
    _load(++_generation);
  }

  Future<void> selectFilters({String? category, String? brand}) async {
    if (state.category == category && state.brand == brand) return;
    state = ProductsState(
      query: state.query,
      sort: state.sort,
      category: category,
      brand: brand,
    );
    await _load(++_generation);
  }

  Future<void> loadMore() async {
    if (state.products.isLoading || state.loadingMore || !state.hasMore) return;
    state = ProductsState(
      products: state.products,
      query: state.query,
      category: state.category,
      brand: state.brand,
      sort: state.sort,
      nextOffset: state.nextOffset,
      hasMore: state.hasMore,
      loadingMore: true,
    );
    await _load(_generation, more: true);
  }
}

final productsVmProvider =
    NotifierProvider.autoDispose<ProductsVm, ProductsState>(ProductsVm.new);
final marketSearchVmProvider = NotifierProvider.autoDispose
    .family<ProductsVm, ProductsState, ProductSearchSpec>(
      (spec) => ProductsVm(initialQuery: spec.query, initialSort: spec.sort),
    );

final productClassificationsProvider =
    FutureProvider.autoDispose<List<ProductClassification>>(
      retry: (_, _) => null,
      (ref) {
        return ref.watch(productRepositoryProvider).getFilters();
      },
    );
