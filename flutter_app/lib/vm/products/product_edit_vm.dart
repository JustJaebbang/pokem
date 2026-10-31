import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_edit.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/state/product_edit_state.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/vm/sales/sales_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class ProductEditVm extends Notifier<ProductEditState> {
  ProductEditVm(this.code);
  final String code;
  @override
  ProductEditState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(load);
    return const ProductEditState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> pickPhoto() async {
    if (state.loading || state.saving || state.picking || !state.canEdit) {
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = state.copyWith(
      picking: true,
      clearPhotoError: true,
      clearError: true,
    );
    try {
      final photo = await ref.read(productPhotoPickerProvider).pick();
      if (!_current(session.token)) return;
      if (photo == null) {
        state = state.copyWith(picking: false);
        return;
      }
      if (photo.bytes.isEmpty || photo.bytes.length > 5 * 1024 * 1024) {
        throw const ProductException('사진은 0바이트보다 크고 5MB 이하여야 합니다.');
      }
      state = state.copyWith(photo: photo, clearUploaded: true, picking: false);
    } catch (error) {
      if (!_current(session.token)) return;
      state = state.copyWith(picking: false, photoError: _photoError(error));
    }
  }

  void useOriginalPhoto() {
    if (state.loading || state.saving || state.picking || !state.canEdit) {
      return;
    }
    state = state.copyWith(
      clearPhoto: true,
      clearUploaded: true,
      clearPhotoError: true,
    );
  }

  String _photoError(Object error) {
    if (error is ProductException) return error.message;
    if (error is MissingPluginException ||
        (error is PlatformException && error.code == 'channel-error')) {
      return '사진 기능을 불러오지 못했습니다. 앱을 완전히 종료한 뒤 다시 실행해주세요.';
    }
    if (error is PlatformException &&
        [
          'photo_access_denied',
          'photo_access_restricted',
        ].contains(error.code)) {
      return '사진 접근이 허용되지 않았습니다. 기기 설정에서 권한을 확인해주세요.';
    }
    if (error is PlatformException && error.code == 'already_active') {
      return '사진 선택 창이 이미 열려 있습니다.';
    }
    return '사진을 열지 못했습니다. 다시 시도해주세요.';
  }

  String? validateTitle(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty || text.length > 100 ? '상품명은 1~100자로 입력해주세요.' : null;
  }

  String? validateDescription(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty || text.length > 500 ? '상품 설명은 1~500자로 입력해주세요.' : null;
  }

  String? validatePrice(String? value) {
    final text = value ?? '';
    final price = int.tryParse(text);
    return !RegExp(r'^\d+$').hasMatch(text) ||
            price == null ||
            price <= 0 ||
            price > 2147483647
        ? '가격은 1~2,147,483,647원으로 입력해주세요.'
        : null;
  }

  Future<void> load() async {
    if (!ref.mounted || state.saving || state.picking) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const ProductEditState();
    try {
      final product = await ref
          .read(productEditRepositoryProvider)
          .getProduct(code);
      if (!_current(session.token)) return;
      final allowed =
          session.account.role == AccountRole.user &&
          product.sellerId == session.account.id &&
          product.saleType == 'direct' &&
          product.isForSale;
      state = ProductEditState(
        product: product,
        loading: false,
        canEdit: allowed,
      );
    } catch (e) {
      if (!_current(session.token)) return;
      state = ProductEditState(
        loading: false,
        error: e is ProductException ? e.message : '상품을 불러오지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  Future<bool> save(ProductEditInput input) async {
    if (state.loading ||
        state.picking ||
        state.saving ||
        !state.canEdit ||
        state.product == null) {
      return false;
    }
    final error =
        validateTitle(input.title) ??
        validateDescription(input.description) ??
        validatePrice(input.price);
    if (error != null) {
      state = state.copyWith(loading: false, canEdit: true, error: error);
      return false;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return false;
    }
    final previous = state.product!;
    final photo = state.photo;
    var uploadedUrl = state.uploadedUrl;
    state = state.copyWith(
      saving: true,
      clearError: true,
      clearPhotoError: true,
    );
    try {
      if (photo != null && uploadedUrl == null) {
        uploadedUrl = await ref
            .read(productPublishRepositoryProvider)
            .uploadPhoto(photo, session.token);
        if (!_current(session.token)) return false;
        state = state.copyWith(uploadedUrl: uploadedUrl);
      }
      final product = await ref
          .read(productEditRepositoryProvider)
          .update(
            code,
            ProductEditDraft(
              title: input.title.trim(),
              description: input.description.trim(),
              price: int.parse(input.price),
              image: uploadedUrl ?? previous.image,
            ),
            session.token,
          );
      if (!_current(session.token)) return false;
      state = ProductEditState(product: product, loading: false, canEdit: true);
      ref.invalidate(productsVmProvider);
      ref.invalidate(marketSearchVmProvider);
      ref.invalidate(productDetailVmProvider(code));
      ref.invalidate(salesVmProvider);
      ref.invalidate(wishlistVmProvider);
      return true;
    } catch (e) {
      if (!_current(session.token)) return false;
      state = state.copyWith(
        product: previous,
        loading: false,
        saving: false,
        canEdit:
            !(e is ProductException && [403, 404, 409].contains(e.statusCode)),
        error: e is ProductException ? e.message : '상품을 수정하지 못했습니다.',
      );
      await _unauthorized(e);
      return false;
    }
  }

  Future<void> _unauthorized(Object e) async {
    if (e is ProductException && e.statusCode == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final productEditVmProvider = NotifierProvider.autoDispose
    .family<ProductEditVm, ProductEditState, String>(ProductEditVm.new);
