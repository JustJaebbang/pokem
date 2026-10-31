import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/inspection/inspection_request.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/inspection/state/return_state.dart';

class ReturnVm extends AsyncNotifier<ReturnState> {
  ReturnVm(this.inspectCode);
  final String? inspectCode;
  int _generation = 0;
  @override
  Future<ReturnState> build() async {
    _generation++;
    final token = ref.watch(loginVmProvider.select((s) => s.session?.token));
    if (token == null) {
      return const ReturnState(items: [], nextOffset: 0, hasMore: false);
    }
    try {
      final rows = await ref
          .read(returnRepositoryProvider)
          .getReturns(token, inspectCode: inspectCode);
      return ReturnState(
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
      ReturnState(
        items: previous.items,
        nextOffset: previous.nextOffset,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final rows = await ref
          .read(returnRepositoryProvider)
          .getReturns(
            session.token,
            inspectCode: inspectCode,
            offset: previous.nextOffset,
          );
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
        ReturnState(
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
        ReturnState(
          items: previous.items,
          nextOffset: previous.nextOffset,
          hasMore: true,
          error: e is InspectionException ? e.message : '반환내역을 더 불러오지 못했습니다.',
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

final returnVmProvider = AsyncNotifierProvider.autoDispose
    .family<ReturnVm, ReturnState, String?>(
      ReturnVm.new,
      retry: (_, _) => null,
    );
