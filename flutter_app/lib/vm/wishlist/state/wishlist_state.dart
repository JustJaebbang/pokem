import 'package:pokem_app/model/products/product.dart';

class WishlistState {
  const WishlistState({
    this.canManage = false,
    this.loading = false,
    this.loaded = false,
    this.codes = const {},
    this.products = const [],
    this.pending = const {},
    this.error,
  });
  final bool canManage, loading, loaded;
  final Set<String> codes, pending;
  final List<Product> products;
  final String? error;
  bool isWished(String code) => codes.contains(code);
  bool canToggle(Product product) =>
      canManage &&
      loaded &&
      !loading &&
      !pending.contains(product.code) &&
      (product.isForSale || isWished(product.code));
  WishlistState copyWith({
    bool? loading,
    bool? loaded,
    Set<String>? codes,
    List<Product>? products,
    Set<String>? pending,
    String? error,
    bool clearError = false,
  }) => WishlistState(
    canManage: canManage,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    codes: codes == null ? this.codes : Set.unmodifiable(codes),
    products: products == null ? this.products : List.unmodifiable(products),
    pending: pending == null ? this.pending : Set.unmodifiable(pending),
    error: clearError ? null : error ?? this.error,
  );
}
