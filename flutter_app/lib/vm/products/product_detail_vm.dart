import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/state/product_detail_state.dart';

class ProductDetailVm extends AsyncNotifier<ProductDetailState> {
  ProductDetailVm(this.code);
  final String code;
  @override
  Future<ProductDetailState> build() {
    ref.watch(productRepositoryProvider);
    ref.watch(loginVmProvider.select((value) => value.session?.account.role));
    return _load();
  }

  Future<ProductDetailState> _load() async {
    final repository = ref.read(productRepositoryProvider);
    final isUser =
        ref.read(loginVmProvider).session?.account.role == AccountRole.user;
    final product = await repository.getProduct(code);
    return ProductDetailState(
      product: product,
      canChat: isUser,
      canBuy: isUser && product.isForSale,
    );
  }

  Future<void> refresh() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_load);
    if (ref.mounted) state = next;
  }
}

final productDetailVmProvider = AsyncNotifierProvider.autoDispose
    .family<ProductDetailVm, ProductDetailState, String>(
      ProductDetailVm.new,
      retry: (count, error) => null,
    );
