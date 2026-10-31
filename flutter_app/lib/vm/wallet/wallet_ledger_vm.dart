import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/wallet/wallet_ledger.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

class LedgerDirectionVm extends Notifier<LedgerDirection> {
  @override
  LedgerDirection build() => LedgerDirection.all;
  void select(LedgerDirection value) => state = value;
}

final ledgerDirectionProvider =
    NotifierProvider.autoDispose<LedgerDirectionVm, LedgerDirection>(
      LedgerDirectionVm.new,
    );

class WalletLedgerVm extends AsyncNotifier<LedgerPage> {
  WalletLedgerVm(this.direction);
  final LedgerDirection direction;
  int _generation = 0;
  @override
  Future<LedgerPage> build() async {
    _generation++;
    final session = ref.watch(loginVmProvider.select((s) => s.session));
    if (session == null) {
      return const LedgerPage(items: [], nextOffset: 0, hasMore: false);
    }
    try {
      final rows = await ref
          .read(walletLedgerRepositoryProvider)
          .page(session.account.id, session.token, direction, 0);
      return LedgerPage(
        items: rows,
        nextOffset: rows.length,
        hasMore: rows.length == 30,
      );
    } on LedgerException catch (e) {
      await unauthorized(e, session.token);
      rethrow;
    }
  }

  void refresh() => ref.invalidateSelf();
  Future<void> unauthorized(Object e, String token) async {
    if (e is LedgerException &&
        e.status == 401 &&
        ref.mounted &&
        ref.read(authRepositoryProvider).session?.token == token) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }

  Future<void> loadMore() async {
    final previous = state.asData?.value;
    final session = ref.read(authRepositoryProvider).session;
    if (previous == null ||
        previous.loadingMore ||
        !previous.hasMore ||
        session == null) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      LedgerPage(
        items: previous.items,
        nextOffset: previous.nextOffset,
        hasMore: true,
        loadingMore: true,
      ),
    );
    try {
      final rows = await ref
          .read(walletLedgerRepositoryProvider)
          .page(
            session.account.id,
            session.token,
            direction,
            previous.nextOffset,
          );
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      final byId = {for (final item in previous.items) item.id: item};
      for (final item in rows) {
        byId[item.id] = item;
      }
      state = AsyncData(
        LedgerPage(
          items: byId.values.toList(),
          nextOffset: previous.nextOffset + rows.length,
          hasMore: rows.length == 30,
        ),
      );
    } catch (e) {
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(authRepositoryProvider).session?.token != session.token) {
        return;
      }
      state = AsyncData(
        LedgerPage(
          items: previous.items,
          nextOffset: previous.nextOffset,
          hasMore: true,
          error: e is LedgerException ? e.message : '이용내역을 더 불러오지 못했습니다.',
        ),
      );
      await unauthorized(e, session.token);
    }
  }
}

final walletLedgerVmProvider = AsyncNotifierProvider.autoDispose
    .family<WalletLedgerVm, LedgerPage, LedgerDirection>(
      WalletLedgerVm.new,
      retry: (_, _) => null,
    );
