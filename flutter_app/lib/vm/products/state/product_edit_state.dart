import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/model/products/product.dart';

class ProductEditState {
  const ProductEditState({
    this.product,
    this.loading = true,
    this.saving = false,
    this.canEdit = false,
    this.error,
    this.photo,
    this.uploadedUrl,
    this.picking = false,
    this.photoError,
  });
  final Product? product;
  final bool loading, saving, canEdit;
  final String? error;
  final ProductPhoto? photo;
  final String? uploadedUrl, photoError;
  final bool picking;
  ProductEditState copyWith({
    Product? product,
    bool? loading,
    bool? saving,
    bool? canEdit,
    String? error,
    bool clearError = false,
    ProductPhoto? photo,
    String? uploadedUrl,
    bool? picking,
    String? photoError,
    bool clearPhoto = false,
    bool clearUploaded = false,
    bool clearPhotoError = false,
  }) => ProductEditState(
    product: product ?? this.product,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    canEdit: canEdit ?? this.canEdit,
    error: clearError ? null : error ?? this.error,
    photo: clearPhoto ? null : photo ?? this.photo,
    uploadedUrl: clearUploaded ? null : uploadedUrl ?? this.uploadedUrl,
    picking: picking ?? this.picking,
    photoError: clearPhotoError ? null : photoError ?? this.photoError,
  );
}
