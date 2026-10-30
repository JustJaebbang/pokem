import 'package:pokem_app/model/products/product_form_input.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/vm/products/state/product_create_state.dart';
export 'package:pokem_app/vm/products/state/product_create_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_draft.dart';

class ProductCreateVm extends Notifier<ProductCreateState> {
  @override
  ProductCreateState build() => const ProductCreateState();
  Future<void> pickPhoto({bool recover = false}) async {
    if (state.busy || state.picking) return;
    final previous = state;
    state = ProductCreateState(
      photo: previous.photo,
      uploadedUrl: previous.uploadedUrl,
      picking: true,
    );
    try {
      final picker = ref.read(productPhotoPickerProvider);
      final photo = await (recover ? picker.recover() : picker.pick());
      if (!ref.mounted) return;
      state = photo == null
          ? ProductCreateState(
              photo: previous.photo,
              uploadedUrl: previous.uploadedUrl,
            )
          : ProductCreateState(photo: photo);
    } catch (error) {
      if (ref.mounted) {
        state = ProductCreateState(
          photo: previous.photo,
          uploadedUrl: previous.uploadedUrl,
          photoError: _photoError(error),
        );
      }
    }
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

  void removePhoto() {
    if (!state.busy && !state.picking) state = const ProductCreateState();
  }

  String? validateField(String field, String? value) {
    const labels = {
      'title': '상품명',
      'description': '상품 설명',
      'price': '가격',
      'regulation': '레귤레이션',
      'packType': '카드 팩 구분',
      'element': '세트 구성',
      'setNumber': '세트 번호',
      'rarity': '레어도',
    };
    if (value == null || value.trim().isEmpty) {
      return '${labels[field] ?? field} 항목을 입력해주세요.';
    }
    if (field == 'price') {
      final price = int.tryParse(value);
      if (price == null || price <= 0 || price > 2147483647) {
        return '가격은 1~2,147,483,647원으로 입력해주세요.';
      }
    }
    if (field == 'title' && value.trim().length > 100) {
      return '상품명은 100자 이하여야 합니다.';
    }
    if (field == 'description' && value.trim().length > 500) {
      return '상품 설명은 500자 이하여야 합니다.';
    }
    return null;
  }

  Future<Product?> submit(ProductFormInput input) async {
    if (state.busy || state.picking || state.created != null) return null;
    for (final entry in input.fields.entries) {
      final error = validateField(entry.key, entry.value);
      if (error != null) {
        state = ProductCreateState(
          photo: state.photo,
          uploadedUrl: state.uploadedUrl,
          error: error,
        );
        return null;
      }
    }
    final draft = ProductDraft(
      title: input.title,
      description: input.description,
      price: int.parse(input.price),
      regulation: input.regulation,
      packType: input.packType,
      element: input.element,
      setNumber: input.setNumber,
      rarity: input.rarity,
    );
    final photo = state.photo;
    if (photo == null) {
      state = const ProductCreateState(photoError: '상품 사진을 추가해주세요.');
      return null;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return null;
    }
    var url = state.uploadedUrl;
    state = ProductCreateState(
      photo: photo,
      uploadedUrl: url,
      busy: true,
      phase: url == null ? '사진 업로드 중' : '상품 등록 중',
    );
    try {
      final repository = ref.read(productPublishRepositoryProvider);
      url ??= await repository.uploadPhoto(photo, session.token);
      if (!ref.mounted) return null;
      state = ProductCreateState(
        photo: photo,
        uploadedUrl: url,
        busy: true,
        phase: '상품 등록 중',
      );
      final product = await repository.create(draft, url, session.token);
      if (!ref.mounted) return null;
      state = ProductCreateState(
        photo: photo,
        uploadedUrl: url,
        created: product,
      );
      ref.invalidate(productsVmProvider);
      return product;
    } catch (error) {
      if (!ref.mounted) return null;
      state = ProductCreateState(
        photo: photo,
        uploadedUrl: url,
        error: error is ProductException
            ? error.message
            : '상품을 등록하지 못했습니다. 입력 내용을 확인해주세요.',
      );
      if (error is ProductException && error.statusCode == 401) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      return null;
    }
  }
}

final productCreateVmProvider =
    NotifierProvider.autoDispose<ProductCreateVm, ProductCreateState>(
      ProductCreateVm.new,
    );
