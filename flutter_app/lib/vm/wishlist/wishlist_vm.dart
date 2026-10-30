import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/wishlist/state/wishlist_state.dart';

class WishlistVm extends Notifier<WishlistState> {
  int _generation = 0;
  @override
  WishlistState build() {
    final identity = ref.watch(
      loginVmProvider.select(
        (s) => (s.session?.account.id, s.session?.account.role),
      ),
    );
    final generation = ++_generation;
    final canManage = identity.$2 == AccountRole.user;
    if (canManage) Future.microtask(() => _load(generation));
    return WishlistState(canManage: canManage, loading: canManage);
  }

  Future<void> _load(int generation) async {
    if (!ref.mounted || generation != _generation) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    try {
      final snapshot = await ref
          .read(wishlistRepositoryProvider)
          .getSnapshot(session.account.id, session.token);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        loading: false,
        loaded: true,
        codes: snapshot.codes,
        products: snapshot.products,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        loading: false,
        error: error is ProductException ? error.message : '관심상품을 불러오지 못했습니다.',
      );
      await _handleUnauthorized(error);
    }
  }

  Future<void> refresh() async {
    if (!state.canManage || state.loading || state.pending.isNotEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    await _load(_generation);
  }

  Future<void> toggle(Product product) async {
    if (!state.canToggle(product)) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final generation = _generation;
    final wasWished = state.isWished(product.code);
    final desired = !wasWished;
    final previousIndex = state.products.indexWhere(
      (p) => p.code == product.code,
    );
    final previousProduct = previousIndex < 0
        ? product
        : state.products[previousIndex];
    final codes = {...state.codes};
    final products = state.products
        .where((p) => p.code != product.code)
        .toList();
    if (desired) {
      codes.add(product.code);
      products.insert(0, product);
    } else {
      codes.remove(product.code);
    }
    // 서버를 기다리기 전에 화면을 갱신한다. 실패 시 이 상품만 복구한다.
    state = state.copyWith(
      codes: codes,
      products: products,
      pending: {...state.pending, product.code},
      clearError: true,
    );
    try {
      await ref
          .read(wishlistRepositoryProvider)
          .setWished(session.account.id, product.code, desired, session.token);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        pending: {...state.pending}..remove(product.code),
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      // 다른 상품의 동시 변경은 유지하고, 실패한 상품의 상태만 되돌린다.
      final restoredCodes = {...state.codes};
      final restoredProducts = state.products
          .where((p) => p.code != product.code)
          .toList();
      if (wasWished) {
        restoredCodes.add(product.code);
        final index = previousIndex < 0
            ? 0
            : previousIndex.clamp(0, restoredProducts.length);
        restoredProducts.insert(index, previousProduct);
      } else {
        restoredCodes.remove(product.code);
      }
      state = state.copyWith(
        codes: restoredCodes,
        products: restoredProducts,
        pending: {...state.pending}..remove(product.code),
        error: error is ProductException ? error.message : '관심상품을 변경하지 못했습니다.',
      );
      await _handleUnauthorized(error);
    }
  }

  Future<void> _handleUnauthorized(Object error) async {
    if (error is ProductException && error.statusCode == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final wishlistVmProvider =
    NotifierProvider.autoDispose<WishlistVm, WishlistState>(WishlistVm.new);
