import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/model/products/product.dart';

class ProductCreateState {
  const ProductCreateState({
    this.photo,
    this.uploadedUrl,
    this.busy = false,
    this.picking = false,
    this.error,
    this.photoError,
    this.phase = '',
    this.created,
  });
  final ProductPhoto? photo;
  final String? uploadedUrl;
  final bool busy, picking;
  final String? error;
  final String? photoError;
  final String phase;
  final Product? created;
}
