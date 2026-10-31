import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/state/deposit_refund_state.dart';

class DepositRefundVm extends AsyncNotifier<DepositRefundState> {
  DepositRefundVm(this.payNumber);
  final String payNumber;
  int _generation = 0;
  @override
  Future<DepositRefundState> build() async {
    _generation++;
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) {
      return const DepositRefundState(items: [], nextOffset: 0, hasMore: false);
    }
    try {
      final rows = await ref
          .read(inspectionFeeRepositoryProvider)
          .refunds(payNumber, token);
      return DepositRefundState(
        items: rows,
        nextOffset: rows.length,
        hasMore: rows.length == 20,
      );
    } on InspectionException catch (e) {
      await _unauthorized(e, token);
      rethrow;
    }
  }

  void refresh() => ref.invalidateSelf();
  Future<void> loadMore() async {
    final previous = state.asData?.value;
    if (previous == null || previous.loadingMore || !previous.hasMore) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) return;
    final generation = _generation;
    state = AsyncData(
      DepositRefundState(
        items: previous.items,
        nextOffset: previous.nextOffset,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final rows = await ref
          .read(inspectionFeeRepositoryProvider)
          .refunds(payNumber, session.token, offset: previous.nextOffset);
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      final byId = {for (final row in previous.items) row.number: row};
      for (final row in rows) {
        byId[row.number] = row;
      }
      state = AsyncData(
        DepositRefundState(
          items: byId.values.toList(),
          nextOffset: previous.nextOffset + rows.length,
          hasMore: rows.length == 20,
        ),
      );
    } catch (e) {
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      state = AsyncData(
        DepositRefundState(
          items: previous.items,
          nextOffset: previous.nextOffset,
          hasMore: true,
          error: e is InspectionException ? e.message : '환급내역을 더 불러오지 못했습니다.',
        ),
      );
      await _unauthorized(e, session.token);
    }
  }

  Future<void> _unauthorized(Object e, String token) async {
    if (e is InspectionException &&
        e.status == 401 &&
        ref.mounted &&
        ref.read(authRepositoryProvider).session?.token == token) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }
}

final depositRefundVmProvider = AsyncNotifierProvider.autoDispose
    .family<DepositRefundVm, DepositRefundState, String>(
      DepositRefundVm.new,
      retry: (_, _) => null,
    );
