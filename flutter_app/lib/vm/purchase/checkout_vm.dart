import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_ledger_vm.dart';
import 'package:pokem_app/vm/wallet/payment_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/vm/purchase/state/checkout_state.dart';
import 'package:pokem_app/vm/purchase/purchase_history_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';

class CheckoutVm extends Notifier<CheckoutState> {
  CheckoutVm(this.code);
  final String code;
  @override
  CheckoutState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(load);
    return const CheckoutState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  Future<void> load() async {
    if (!ref.mounted ||
        state.paying ||
        state.uncertain ||
        state.purchase != null) {
      return;
    }
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    state = const CheckoutState();
    try {
      final data = await ref
          .read(purchaseRepositoryProvider)
          .checkout(code, session.account.id, session.token);
      if (_current(session.token)) {
        state = CheckoutState(data: data, loading: false);
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = CheckoutState(loading: false, error: _message(e));
      await _unauthorized(e);
    }
  }

  void agree(bool value) {
    if (state.paying || state.purchase != null || state.uncertain) return;
    state = CheckoutState(
      data: state.data,
      loading: state.loading,
      agreed: value,
      error: state.error,
    );
  }

  Future<void> pay() async {
    if (!state.canPay) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final data = state.data!;
    state = CheckoutState(
      data: data,
      loading: false,
      agreed: true,
      paying: true,
    );
    try {
      final purchase = await ref
          .read(purchaseRepositoryProvider)
          .buy(code, data.product.price, session.token);
      if (!_current(session.token)) return;
      _completed(purchase);
    } catch (e) {
      if (!_current(session.token)) return;
      // Unexpected failures after submitting are also ambiguous. Never automatically repeat payment.
      final uncertain = e is! PurchaseException || e.uncertain;
      state = CheckoutState(
        data: uncertain ? data : null,
        loading: false,
        uncertain: uncertain,
        error: uncertain ? '결제 결과를 확인하지 못했습니다. 구매내역을 확인해주세요.' : _message(e),
      );
      await _unauthorized(e);
    }
  }

  Future<void> checkResult() async {
    if (!state.uncertain || state.paying) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final data = state.data;
    state = CheckoutState(
      data: data,
      loading: false,
      paying: true,
      uncertain: true,
    );
    try {
      final purchases = await ref
          .read(purchaseRepositoryProvider)
          .history(session.token);
      if (!_current(session.token)) return;
      final matches = purchases
          .where((p) => p.productCode == code && p.status != '거래취소')
          .toList();
      if (matches.isNotEmpty) {
        _completed(matches.first);
      } else {
        state = CheckoutState(
          data: data,
          loading: false,
          uncertain: true,
          error: '아직 구매내역에 표시되지 않습니다. 잠시 후 다시 확인해주세요.',
        );
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = CheckoutState(
        data: data,
        loading: false,
        uncertain: true,
        error: _message(e),
      );
      await _unauthorized(e);
    }
  }

  void _completed(Purchase purchase) {
    state = CheckoutState(data: state.data, loading: false, purchase: purchase);
    ref.invalidate(walletVmProvider);
    ref.invalidate(notificationsVmProvider);
    ref.invalidate(walletLedgerVmProvider);
    ref.invalidate(paymentHistoryVmProvider);
    ref.invalidate(paymentDetailVmProvider);
    ref.invalidate(productsVmProvider);
    ref.invalidate(marketSearchVmProvider);
    ref.invalidate(productDetailVmProvider(code));
    ref.invalidate(wishlistVmProvider);
    ref.invalidate(purchaseHistoryVmProvider);
  }

  String _message(Object e) => e is PurchaseException
      ? e.message
      : e is ProductException
      ? e.message
      : '정보를 불러오지 못했습니다.';
  Future<void> _unauthorized(Object e) async {
    if (e is PurchaseException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final checkoutVmProvider = NotifierProvider.autoDispose
    .family<CheckoutVm, CheckoutState, String>(CheckoutVm.new);
