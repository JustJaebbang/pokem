import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/seller_cancel_vm.dart';
import 'package:pokem_app/vm/purchase/state/seller_cancel_decision_state.dart';
import 'package:pokem_app/vm/sales/sales_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';

class SellerCancelDecisionVm extends Notifier<SellerCancelDecisionState> {
  SellerCancelDecisionVm(this.code);
  final String code;
  @override
  SellerCancelDecisionState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    return const SellerCancelDecisionState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  String? validateReason(String? reason) =>
      (reason ?? '').trim().length > 255 ? '처리 사유는 255자 이하여야 합니다.' : null;
  Future<void> decide(CancelDecision decision, String reason) async {
    if (state.busy || state.uncertain || state.result != null) return;
    final error = validateReason(reason);
    if (error != null) {
      state = SellerCancelDecisionState(error: error);
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    state = const SellerCancelDecisionState(busy: true);
    var submitted = false;
    try {
      final repo = ref.read(sellerCancelRepositoryProvider);
      final latest = await repo.get(code, session.token);
      if (!_current(session.token)) return;
      if (latest.sellerId != session.account.id) {
        throw const PurchaseException('판매자만 취소 요청을 처리할 수 있습니다.', status: 403);
      }
      if (latest.status != '요청중') {
        _complete(latest);
        return;
      }
      submitted = true;
      final result = await repo.decide(
        latest,
        decision,
        reason.trim(),
        session.token,
      );
      if (_current(session.token)) _complete(result);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = submitted && (e is! PurchaseException || e.uncertain);
      state = SellerCancelDecisionState(
        uncertain: uncertain,
        error: uncertain
            ? '처리 결과를 확인하지 못했습니다. 상태를 확인해주세요.'
            : e is PurchaseException
            ? e.message
            : '취소 요청을 확인하지 못했습니다.',
      );
      ref.invalidate(sellerCancelVmProvider);
      await _unauthorized(e);
    }
  }

  Future<void> checkResult() async {
    if (state.busy || !state.uncertain) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const SellerCancelDecisionState(busy: true, uncertain: true);
    try {
      final result = await ref
          .read(sellerCancelRepositoryProvider)
          .get(code, session.token);
      if (!_current(session.token)) return;
      if (result.sellerId != session.account.id) {
        throw const PurchaseException('조회 권한을 확인해주세요.', status: 403);
      }
      if (result.status != '요청중') {
        _complete(result);
      } else {
        state = const SellerCancelDecisionState(
          uncertain: true,
          error: '아직 처리가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.',
        );
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = SellerCancelDecisionState(
        uncertain: true,
        error: e is PurchaseException ? e.message : '처리 상태를 확인하지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  void _complete(PurchaseCancellation result) {
    state = SellerCancelDecisionState(result: result);
    ref.invalidate(sellerCancelVmProvider);
    ref.invalidate(salesVmProvider);
    ref.invalidate(productsVmProvider);
    ref.invalidate(productDetailVmProvider);
    ref.invalidate(wishlistVmProvider);
    ref.invalidate(walletVmProvider);
  }

  Future<void> _unauthorized(Object e) async {
    if (e is PurchaseException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final sellerCancelDecisionVmProvider =
    NotifierProvider.family<
      SellerCancelDecisionVm,
      SellerCancelDecisionState,
      String
    >(SellerCancelDecisionVm.new);
