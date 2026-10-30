import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/purchase_history_vm.dart';
import 'package:pokem_app/vm/purchase/state/purchase_confirm_state.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';

class PurchaseConfirmVm extends Notifier<PurchaseConfirmState> {
  PurchaseConfirmVm(this.code);
  final String code;
  @override
  PurchaseConfirmState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const PurchaseConfirmState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> confirm() async {
    if (state.busy || state.confirmed || state.uncertain) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = const PurchaseConfirmState(busy: true);
    var submitted = false;
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final purchase = await repo.getPurchase(code, session.token);
      if (!_current(session.token)) return;
      if (purchase.isConfirmed) {
        _complete(purchase.productCode);
        return;
      }
      if (!purchase.canConfirm) {
        state = const PurchaseConfirmState(error: '현재 상태에서는 구매확정할 수 없습니다.');
        ref.invalidate(purchaseHistoryVmProvider);
        return;
      }
      submitted = true;
      final receipt = await repo.confirm(code, session.token);
      if (_current(session.token)) _complete(receipt.productCode);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = submitted && (e is! PurchaseException || e.uncertain);
      state = PurchaseConfirmState(
        uncertain: uncertain,
        error: uncertain
            ? '구매확정 결과를 확인하지 못했습니다. 처리 상태를 확인해주세요.'
            : e is PurchaseException
            ? e.message
            : '구매 정보를 확인하지 못했습니다.',
      );
      ref.invalidate(purchaseHistoryVmProvider);
      await _unauthorized(e);
    }
  }

  Future<void> checkResult() async {
    if (state.busy || !state.uncertain) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const PurchaseConfirmState(busy: true, uncertain: true);
    try {
      final purchase = await ref
          .read(purchaseRepositoryProvider)
          .getPurchase(code, session.token);
      if (!_current(session.token)) return;
      if (purchase.isConfirmed) {
        _complete(purchase.productCode);
      } else {
        state = const PurchaseConfirmState(
          uncertain: true,
          error: '아직 구매확정이 확인되지 않았습니다. 잠시 후 다시 확인해주세요.',
        );
        ref.invalidate(purchaseHistoryVmProvider);
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = PurchaseConfirmState(
        uncertain: true,
        error: e is PurchaseException ? e.message : '처리 상태를 확인하지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  void _complete(String productCode) {
    state = const PurchaseConfirmState(confirmed: true);
    ref.invalidate(purchaseHistoryVmProvider);
    ref.invalidate(productDetailVmProvider(productCode));
    ref.invalidate(productsVmProvider);
    ref.invalidate(wishlistVmProvider);
    ref.invalidate(walletVmProvider);
  }

  Future<void> _unauthorized(Object e) async {
    if (e is PurchaseException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

// 결과 불확실 상태를 화면 재진입 때도 유지하고 인증 변경 시 초기화합니다.
final purchaseConfirmVmProvider =
    NotifierProvider.family<PurchaseConfirmVm, PurchaseConfirmState, String>(
      PurchaseConfirmVm.new,
    );
