import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_delete.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/vm/sales/sales_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class ProductDeleteVm extends Notifier<ProductDeleteState> {
  ProductDeleteVm(this.code);
  final String code;
  @override
  ProductDeleteState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const ProductDeleteState();
  }

  bool current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> load() async {
    if (state.busy || state.deleted) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final uncertain = state.uncertain;
    state = ProductDeleteState(uncertain: uncertain);
    try {
      final product = await ref
          .read(productDeleteRepositoryProvider)
          .getProduct(code);
      if (!current(session.token)) return;
      if (session.account.role != AccountRole.user ||
          product.code != code ||
          product.sellerId != session.account.id ||
          product.saleType != 'direct') {
        throw const ProductException('본인이 등록한 일반판매 상품만 삭제할 수 있습니다.');
      }
      if (!product.isForSale) {
        throw const ProductException('판매중인 상품만 삭제할 수 있습니다.');
      }
      state = ProductDeleteState(
        loading: false,
        product: product,
        uncertain: uncertain,
        error: uncertain
            ? '상품이 아직 조회됩니다. 삭제 결과가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.'
            : null,
      );
    } catch (e) {
      if (!current(session.token)) return;
      if (uncertain && e is ProductException && e.statusCode == 404) {
        state = const ProductDeleteState(loading: false, deleted: true);
        refresh();
        return;
      }
      state = ProductDeleteState(
        loading: false,
        uncertain: uncertain,
        error: e is ProductException ? e.message : '상품을 불러오지 못했습니다.',
      );
      if (e is ProductException && e.statusCode == 401) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
    }
  }

  Future<void> submit() async {
    if (state.loading ||
        state.busy ||
        state.uncertain ||
        state.deleted ||
        state.product == null) {
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final product = state.product!;
    if (session.account.role != AccountRole.user ||
        product.sellerId != session.account.id ||
        product.saleType != 'direct' ||
        !product.isForSale) {
      return;
    }
    state = ProductDeleteState(loading: false, busy: true, product: product);
    try {
      await ref
          .read(productDeleteRepositoryProvider)
          .delete(code, session.token);
      if (!current(session.token)) return;
      state = const ProductDeleteState(loading: false, deleted: true);
      refresh();
    } catch (e) {
      if (!current(session.token)) return;
      final uncertain = e is! ProductDeleteException || e.uncertain;
      state = ProductDeleteState(
        loading: false,
        uncertain: uncertain,
        product: uncertain ? product : null,
        error: uncertain ? '삭제 결과를 확인하지 못했습니다. 상태 확인을 눌러주세요.' : e.message,
      );
      if (e is ProductDeleteException && e.status == 401) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
      }
      if (!uncertain) refresh();
    }
  }

  void refresh() {
    ref.invalidate(salesVmProvider);
    ref.invalidate(productsVmProvider);
    ref.invalidate(productDetailVmProvider(code));
    ref.invalidate(wishlistVmProvider);
  }
}

final productDeleteVmProvider =
    NotifierProvider.family<ProductDeleteVm, ProductDeleteState, String>(
      ProductDeleteVm.new,
    );
