import 'package:pokem_app/model/wallet/wallet_ledger.dart';
import 'package:pokem_app/service/wallet/wallet_ledger_api_service.dart';

class WalletLedgerRepository {
  WalletLedgerRepository(this._api);
  final WalletLedgerApiService _api;
  Future<List<WalletMovement>> page(
    String ownerId,
    String token,
    LedgerDirection direction,
    int offset,
  ) async {
    final rows = await _api.page(token, direction, offset);
    if (rows.any(
      (r) =>
          r.ownerId != ownerId ||
          direction == LedgerDirection.incoming && r.amount <= 0 ||
          direction == LedgerDirection.outgoing && r.amount >= 0,
    )) {
      throw const LedgerException('요청한 이용내역과 응답이 일치하지 않습니다.');
    }
    return rows;
  }
}
