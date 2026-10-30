import 'package:pokem_app/model/wallet/wallet_models.dart';
import 'package:pokem_app/service/wallet/wallet_api_service.dart';

class WalletRepository {
  WalletRepository(this._api);
  final WalletApiService _api;
  Future<int> balance(String id, String token) => _api.balance(id, token);
  Future<WalletSnapshot> snapshot(String id, String token) async {
    final results = await Future.wait<Object>([
      _api.balance(id, token),
      _api.history(MoneyAction.recharge, token),
      _api.history(MoneyAction.exchange, token),
    ]);
    final records = [
      ...results[1] as List<MoneyRecord>,
      ...results[2] as List<MoneyRecord>,
    ];
    records.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    return WalletSnapshot(results[0] as int, records);
  }

  Future<MoneyReceipt> transfer(
    MoneyAction action,
    String account,
    int amount,
    String token,
  ) => _api.transfer(action, account, amount, token);
}
