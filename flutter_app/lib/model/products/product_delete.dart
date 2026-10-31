import 'package:pokem_app/model/products/product.dart';

class ProductDeleteState {
  const ProductDeleteState({
    this.loading = true,
    this.busy = false,
    this.uncertain = false,
    this.deleted = false,
    this.product,
    this.error,
  });
  final bool loading, busy, uncertain, deleted;
  final Product? product;
  final String? error;
}

class ProductDeleteException implements Exception {
  const ProductDeleteException(
    this.message, {
    this.status,
    this.uncertain = false,
  });
  final String message;
  final int? status;
  final bool uncertain;
}
