import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_ledger_vm.dart';
import 'package:pokem_app/vm/wallet/payment_vm.dart';
import 'package:pokem_app/vm/wallet/wallet_vm.dart';
import 'package:pokem_app/vm/products/product_detail_vm.dart';
import 'package:pokem_app/vm/products/products_vm.dart';
import 'package:pokem_app/vm/wishlist/wishlist_vm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/purchase/purchase.dart';
import 'package:pokem_app/model/purchase/purchase_cancellation.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/purchase/purchase_history_vm.dart';
import 'package:pokem_app/vm/purchase/state/purchase_cancel_state.dart';

class PurchaseCancelVm extends Notifier<PurchaseCancelState> {
  PurchaseCancelVm(this.code);
  final String code;
  @override
  PurchaseCancelState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.token));
    Future.microtask(() => load(initial: true));
    return const PurchaseCancelState();
  }

  bool _current(String token) =>
      ref.mounted && ref.read(authRepositoryProvider).session?.token == token;
  String? validateReason(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '취소 사유를 입력해주세요.';
    if (text.length > 255) return '취소 사유는 255자 이하여야 합니다.';
    return null;
  }

  Future<void> load({bool initial = false}) async {
    if (!ref.mounted || state.busy || (!initial && state.loading)) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final previous = state;
    state = PurchaseCancelState(
      snapshot: previous.snapshot,
      pending: previous.pending,
    );
    try {
      final snapshot = await ref
          .read(purchaseCancelRepositoryProvider)
          .snapshot(code, session.token);
      if (!_current(session.token)) return;
      final pending = previous.pending;
      final resolved = pending == CancelPending.request
          ? snapshot.cancellation != null
          : pending == CancelPending.withdraw
          ? snapshot.cancellation != null &&
                snapshot.cancellation!.status != '요청중'
          : true;
      state = PurchaseCancelState(
        snapshot: snapshot,
        loading: false,
        pending: resolved ? null : pending,
        error: resolved ? null : '아직 처리 결과가 확인되지 않았습니다. 잠시 후 다시 확인해주세요.',
      );
      if (snapshot.cancellation != null || (pending != null && resolved)) {
        ref.invalidate(purchaseHistoryVmProvider);
      }
      if (snapshot.cancellation?.status == '승인') {
        ref.invalidate(walletVmProvider);
        ref.invalidate(notificationsVmProvider);
        ref.invalidate(walletLedgerVmProvider);
        ref.invalidate(paymentHistoryVmProvider);
        ref.invalidate(paymentDetailVmProvider);
        ref.invalidate(productsVmProvider);
        ref.invalidate(productDetailVmProvider(snapshot.purchase.productCode));
        ref.invalidate(wishlistVmProvider);
      }
    } catch (e) {
      if (!_current(session.token)) return;
      state = PurchaseCancelState(
        snapshot: previous.snapshot,
        loading: false,
        pending: previous.pending,
        error: e is PurchaseException ? e.message : '취소 정보를 불러오지 못했습니다.',
      );
      await _unauthorized(e);
    }
  }

  Future<void> request(String reason) async {
    if (state.loading ||
        state.busy ||
        state.pending != null ||
        state.snapshot?.canRequest != true) {
      return;
    }
    final error = validateReason(reason);
    if (error != null) {
      state = PurchaseCancelState(
        snapshot: state.snapshot,
        loading: false,
        error: error,
      );
      return;
    }
    await _write(CancelPending.request, reason: reason.trim());
  }

  Future<void> withdraw() async {
    final session = ref.read(authRepositoryProvider).session;
    final cancellation = state.snapshot?.cancellation;
    if (state.loading ||
        state.busy ||
        state.pending != null ||
        cancellation?.status != '요청중' ||
        cancellation?.buyerId != session?.account.id) {
      return;
    }
    await _write(CancelPending.withdraw);
  }

  Future<void> _write(CancelPending action, {String reason = ''}) async {
    final session = ref.read(authRepositoryProvider).session;
    if (session == null || session.isExpired) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final snapshot = state.snapshot!;
    state = PurchaseCancelState(snapshot: snapshot, loading: false, busy: true);
    try {
      final repo = ref.read(purchaseCancelRepositoryProvider);
      final cancellation = action == CancelPending.request
          ? await repo.request(code, reason, session.token)
          : await repo.withdraw(snapshot.cancellation!, session.token);
      if (!_current(session.token)) return;
      state = PurchaseCancelState(
        snapshot: PurchaseCancelSnapshot(snapshot.purchase, cancellation),
        loading: false,
      );
      ref.invalidate(purchaseHistoryVmProvider);
    } catch (e) {
      if (!_current(session.token)) return;
      final uncertain = e is! PurchaseException || e.uncertain;
      state = PurchaseCancelState(
        snapshot: snapshot,
        loading: false,
        pending: uncertain ? action : null,
        error: uncertain ? '처리 결과를 확인하지 못했습니다. 상태를 확인해주세요.' : e.message,
      );
      ref.invalidate(purchaseHistoryVmProvider);
      await _unauthorized(e);
    }
  }

  Future<void> _unauthorized(Object e) async {
    if (e is PurchaseException && e.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final purchaseCancelVmProvider =
    NotifierProvider.family<PurchaseCancelVm, PurchaseCancelState, String>(
      PurchaseCancelVm.new,
    );
