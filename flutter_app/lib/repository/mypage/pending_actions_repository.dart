import 'package:pokem_app/model/mypage/pending_actions.dart';
import 'package:pokem_app/service/mypage/pending_actions_api_service.dart';

class PendingActionsRepository {
  PendingActionsRepository(this._api);
  final PendingActionsApiService _api;
  Future<PendingActions> get(String token) => _api.get(token);
}
